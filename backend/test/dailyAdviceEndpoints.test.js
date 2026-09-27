import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { runMigrations } from '../src/db/migrate.js';

describe('Endpoint Saran Belanja Hari Ini (Daily Advice Endpoints) Tests', () => {
  let server;
  let baseUrl;
  let db;
  let user1Id;
  let user2Id;

  before(async () => {
    db = getDatabase();
    runMigrations(db);

    const u1Res = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, 'Ahmad Dani', 'IDR')
    `).run(`saran_u1_${Date.now()}@example.com`);
    user1Id = Number(u1Res.lastInsertRowid);

    const u2Res = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, 'Siti Nurhaliza', 'IDR')
    `).run(`saran_u2_${Date.now()}@example.com`);
    user2Id = Number(u2Res.lastInsertRowid);

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  beforeEach(() => {
    // Clean up test data
    db.prepare('DELETE FROM daily_advice_cache WHERE user_id IN (?, ?)').run(user1Id, user2Id);
    db.prepare('DELETE FROM transactions WHERE user_id IN (?, ?)').run(user1Id, user2Id);
    db.prepare('DELETE FROM monthly_budgets WHERE user_id IN (?, ?)').run(user1Id, user2Id);
    db.prepare('DELETE FROM budgets WHERE user_id IN (?, ?)').run(user1Id, user2Id);

    // Setup User 1: Budget 2.000.000, pengeluaran 1.740.000 di September 2026 (sisa 260.000)
    db.prepare(`
      INSERT INTO monthly_budgets (user_id, month, total_amount, needs_pct, savings_pct, fun_pct)
      VALUES (?, '2026-09', 2000000, 50, 30, 20)
    `).run(user1Id);

    const txStmt = db.prepare(`
      INSERT INTO transactions (user_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, 'expense', ?, ?, ?, 1)
    `);

    txStmt.run(user1Id, 1000000, 'Belanja bulanan', '2026-09-05 10:00:00');
    txStmt.run(user1Id, 500000, 'Utilitas & Listrik', '2026-09-15 11:00:00');
    txStmt.run(user1Id, 200000, 'Makan sepekan', '2026-09-22 12:00:00');
    txStmt.run(user1Id, 40000, 'Jajan hari ini', '2026-09-27 12:30:00');

    // Setup User 2: Budget 5.000.000, pengeluaran 1.000.000 di September 2026 (sisa 4.000.000)
    db.prepare(`
      INSERT INTO monthly_budgets (user_id, month, total_amount, needs_pct, savings_pct, fun_pct)
      VALUES (?, '2026-09', 5000000, 50, 30, 20)
    `).run(user2Id);

    txStmt.run(user2Id, 1000000, 'Belanja User 2', '2026-09-10 10:00:00');
  });

  after(async () => {
    if (db) {
      db.prepare('DELETE FROM daily_advice_cache WHERE user_id IN (?, ?)').run(user1Id, user2Id);
      db.prepare('DELETE FROM transactions WHERE user_id IN (?, ?)').run(user1Id, user2Id);
      db.prepare('DELETE FROM monthly_budgets WHERE user_id IN (?, ?)').run(user1Id, user2Id);
      db.prepare('DELETE FROM users WHERE id IN (?, ?)').run(user1Id, user2Id);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. GET /api/saran/hari-ini - Pengambilan Saran Belanja Hari Ini', () => {
    it('returns accurate safe daily spending limit and Flutter insight model for User 1', async () => {
      const res = await fetch(`${baseUrl}/api/saran/hari-ini?userId=${user1Id}&referenceDate=2026-09-27`);
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.strictEqual(body.userId, user1Id);
      assert.strictEqual(body.date, '2026-09-27');

      // User 1: Budget 2.000.000 - Total spent 1.740.000 = Sisa 260.000
      // 4 hari tersisa (27, 28, 29, 30 Sep) -> Batas aman = 65.000 / hari
      assert.strictEqual(body.data.safeDailyLimit, 65000);
      assert.strictEqual(body.data.formattedSafeDailyLimit, 'Rp 65.000 / hari');
      assert.strictEqual(body.data.remainingDays, 4);
      assert.strictEqual(body.data.todaySpent, 40000);
      assert.strictEqual(body.data.todayRemainingAllowance, 25000);
      assert.strictEqual(body.data.isTodayOverLimit, false);

      // Verify insight payload matching Flutter AiInsightItem
      const insight = body.insight;
      assert.ok(insight);
      assert.strictEqual(insight.userId, user1Id);
      assert.strictEqual(insight.recommendedDailyBudget, 65000);
      assert.strictEqual(insight.formattedRecommendedDailyBudget, 'Rp 65.000');
      assert.strictEqual(insight.estimatedDaysLeft, 4);
      assert.strictEqual(insight.warnLevel, 'normal');
      assert.strictEqual(insight.isApplied, false);
      assert.ok(insight.dailyAdvice.includes('Rp 65.000') || insight.dailyAdvice.includes('aman'));
    });

    it('isolates user data strictly between User 1 and User 2', async () => {
      const res1 = await fetch(`${baseUrl}/api/saran/hari-ini?userId=${user1Id}&referenceDate=2026-09-27`);
      const body1 = await res1.json();

      const res2 = await fetch(`${baseUrl}/api/saran/hari-ini?userId=${user2Id}&referenceDate=2026-09-27`);
      const body2 = await res2.json();

      assert.strictEqual(res1.status, 200);
      assert.strictEqual(res2.status, 200);

      assert.strictEqual(body1.data.safeDailyLimit, 65000);
      assert.strictEqual(body2.data.safeDailyLimit, 1000000);
      assert.notStrictEqual(body1.data.safeDailyLimit, body2.data.safeDailyLimit);
    });

    it('serves cached advice on subsequent call and bypasses cache with ?refresh=true', async () => {
      const firstRes = await fetch(`${baseUrl}/api/saran/hari-ini?userId=${user1Id}&referenceDate=2026-09-27&refresh=true`);
      const firstBody = await firstRes.json();
      assert.strictEqual(firstRes.status, 200);
      assert.strictEqual(firstBody.cached, false);

      const secondRes = await fetch(`${baseUrl}/api/saran/hari-ini?userId=${user1Id}&referenceDate=2026-09-27`);
      const secondBody = await secondRes.json();
      assert.strictEqual(secondRes.status, 200);
      assert.strictEqual(secondBody.cached, true);
      assert.strictEqual(secondBody.insight.recommendedDailyBudget, 65000);

      const thirdRes = await fetch(`${baseUrl}/api/saran/hari-ini?userId=${user1Id}&referenceDate=2026-09-27&refresh=true`);
      const thirdBody = await thirdRes.json();
      assert.strictEqual(thirdRes.status, 200);
      assert.strictEqual(thirdBody.cached, false);
    });

    it('validates parameter userId properly (HTTP 400)', async () => {
      const res = await fetch(`${baseUrl}/api/saran/hari-ini?userId=-99`);
      const body = await res.json();

      assert.strictEqual(res.status, 400);
      assert.strictEqual(body.success, false);
      assert.ok(body.error.includes('userId'));
    });
  });

  describe('2. POST /api/saran/terapkan - Terapkan Saran Hari Ini', () => {
    it('marks daily advice as applied (isApplied = true) and updates cache', async () => {
      const res = await fetch(`${baseUrl}/api/saran/terapkan`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          referenceDate: '2026-09-27',
          isApplied: true,
        }),
      });
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.strictEqual(body.isApplied, true);
      assert.ok(body.message.includes('berhasil diterapkan'));
      assert.strictEqual(body.insight.isApplied, true);

      // Verify on subsequent GET query
      const checkRes = await fetch(`${baseUrl}/api/saran/hari-ini?userId=${user1Id}&referenceDate=2026-09-27`);
      const checkBody = await checkRes.json();

      assert.strictEqual(checkRes.status, 200);
      assert.strictEqual(checkBody.insight.isApplied, true);
    });

    it('allows toggling advice back to unapplied (isApplied = false)', async () => {
      const res = await fetch(`${baseUrl}/api/saran/terapkan`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          referenceDate: '2026-09-27',
          isApplied: false,
        }),
      });
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.isApplied, false);
    });
  });

  describe('3. POST /api/saran/refresh - Refresh / Rekalkulasi Saran', () => {
    it('recalculates today advice and refreshes cache', async () => {
      const res = await fetch(`${baseUrl}/api/saran/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          referenceDate: '2026-09-27',
        }),
      });
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.ok(body.message.includes('berhasil diperbarui'));
      assert.strictEqual(body.data.safeDailyLimit, 65000);
    });
  });

  describe('4. GET & POST /api/saran/simulasi - Simulasi What-If', () => {
    it('simulates safe daily spending and survival days given parameters', async () => {
      const res = await fetch(`${baseUrl}/api/saran/simulasi`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          remainingBudget: 300000,
          remainingDays: 5,
          simulatedDailySpend: 60000,
        }),
      });
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.strictEqual(body.simulation.safeDailyLimit, 60000);
      assert.strictEqual(body.simulation.simulatedDaysSurvival, 5);
      assert.strictEqual(body.simulation.survivesUntilMonthEnd, true);
    });
  });

  describe('5. Route Aliases Compatibility', () => {
    it('supports aliases: GET /api/saran, GET /saran/hari-ini, and GET /api/daily-advice/hari-ini', async () => {
      const r1 = await fetch(`${baseUrl}/api/saran?userId=${user1Id}&referenceDate=2026-09-27`);
      assert.strictEqual(r1.status, 200);

      const r2 = await fetch(`${baseUrl}/saran/hari-ini?userId=${user1Id}&referenceDate=2026-09-27`);
      assert.strictEqual(r2.status, 200);

      const r3 = await fetch(`${baseUrl}/api/daily-advice/hari-ini?userId=${user1Id}&referenceDate=2026-09-27`);
      const b3 = await r3.json();
      assert.strictEqual(r3.status, 200);
      assert.strictEqual(b3.insight.recommendedDailyBudget, 65000);
    });
  });
});
