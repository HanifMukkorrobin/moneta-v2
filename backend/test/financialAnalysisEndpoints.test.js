import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Financial Analysis Endpoints (Analisa Keuangan Terfilter Per Pengguna) Tests', () => {
  let server;
  let baseUrl;
  let db;
  let user1Id;
  let user2Id;
  let makanCatId;
  let hiburanCatId;

  before(async () => {
    db = getDatabase();

    const u1 = db.prepare("INSERT INTO users (email, display_name) VALUES (?, 'User Satu')").run(`analisa_u1_${Date.now()}@example.com`);
    user1Id = Number(u1.lastInsertRowid);

    const u2 = db.prepare("INSERT INTO users (email, display_name) VALUES (?, 'User Dua')").run(`analisa_u2_${Date.now()}@example.com`);
    user2Id = Number(u2.lastInsertRowid);

    makanCatId = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get().id;
    hiburanCatId = db.prepare("SELECT id FROM categories WHERE name = 'Hiburan' AND type = 'expense'").get().id;

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  beforeEach(() => {
    db.prepare('DELETE FROM transactions WHERE user_id IN (?, ?)').run(user1Id, user2Id);
    db.prepare('DELETE FROM budgets WHERE user_id IN (?, ?)').run(user1Id, user2Id);
    db.prepare('DELETE FROM monthly_budgets WHERE user_id IN (?, ?)').run(user1Id, user2Id);
    db.prepare('DELETE FROM ai_insights WHERE user_id IN (?, ?)').run(user1Id, user2Id);
  });

  after(async () => {
    if (db) {
      db.prepare('DELETE FROM transactions WHERE user_id IN (?, ?)').run(user1Id, user2Id);
      db.prepare('DELETE FROM budgets WHERE user_id IN (?, ?)').run(user1Id, user2Id);
      db.prepare('DELETE FROM monthly_budgets WHERE user_id IN (?, ?)').run(user1Id, user2Id);
      db.prepare('DELETE FROM ai_insights WHERE user_id IN (?, ?)').run(user1Id, user2Id);
      db.prepare('DELETE FROM users WHERE id IN (?, ?)').run(user1Id, user2Id);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. Full Financial Analysis Endpoint (GET /api/analisa)', () => {
    it('returns full financial analysis structure with daily spending, depletion, and warning', async () => {
      // Setup monthly budget and transactions for user1
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount, needs_pct, savings_pct, fun_pct)
        VALUES (?, '2026-09', 6000000, 50, 30, 20)
      `).run(user1Id);

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES
          (?, ?, 'Makan & Minuman', 'expense', 70000, 'Makan siang', '2026-09-10 12:00:00', 1),
          (?, ?, 'Hiburan', 'expense', 150000, 'Bioskop', '2026-09-11 19:00:00', 1),
          (?, ?, 'Makan & Minuman', 'expense', 80000, 'Makan malam', '2026-09-12 20:00:00', 1)
      `).run(user1Id, makanCatId, user1Id, hiburanCatId, user1Id, makanCatId);

      const res = await fetch(`${baseUrl}/api/analisa?userId=${user1Id}&date=2026-09-12&days=7`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.userId, user1Id);
      assert.equal(body.referenceDate, '2026-09-12');
      assert.equal(body.hasTransactions, true);

      // Verify Summary Section
      assert.ok(body.summary);
      assert.equal(body.summary.totalSpent, 300000);
      assert.equal(body.summary.totalMonthlyBudget, 6000000);
      assert.equal(body.summary.remainingBalance, 5700000);
      assert.equal(body.summary.formattedRemainingBalance, 'Rp 5.700.000');
      assert.ok(body.summary.avgDailySpend > 0);
      assert.ok(body.summary.estimatedDaysLeft > 0);
      assert.ok(body.summary.depletionDate);
      assert.ok(body.summary.warnLevel);

      // Verify Daily Spending Section
      assert.ok(body.dailySpending);
      assert.equal(body.dailySpending.totalSpent, 300000);
      assert.equal(body.dailySpending.dailyPoints.length, 7);
      assert.ok(body.dailySpending.topCategoryName);

      // Verify Money Depletion Section
      assert.ok(body.moneyDepletion);
      assert.equal(body.moneyDepletion.remainingBalance, 5700000);
      assert.ok(body.moneyDepletion.formattedDepletionDate);
      assert.ok(body.moneyDepletion.simulation);

      // Verify Early Warning Section
      assert.ok(body.earlyWarning);
      assert.equal(body.earlyWarning.level, body.summary.warnLevel);
      assert.ok(body.earlyWarning.actionRecommendation);
    });
  });

  describe('2. User Isolation & Strict Filtering', () => {
    it('strictly isolates financial data between different users', async () => {
      // User 1: Budget Rp 4.000.000, Spent Rp 1.000.000 -> Remaining: Rp 3.000.000
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 4000000)
      `).run(user1Id);

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 1000000, 'User 1 Expense', '2026-09-12 12:00:00', 1)
      `).run(user1Id, makanCatId);

      // User 2: Budget Rp 10.000.000, Spent Rp 200.000 -> Remaining: Rp 9.800.000
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 10000000)
      `).run(user2Id);

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 200000, 'User 2 Expense', '2026-09-12 12:00:00', 1)
      `).run(user2Id, makanCatId);

      // 1. Query for User 1
      const res1 = await fetch(`${baseUrl}/api/analisa?userId=${user1Id}&date=2026-09-12`);
      assert.equal(res1.status, 200);
      const body1 = await res1.json();
      assert.equal(body1.userId, user1Id);
      assert.equal(body1.summary.totalSpent, 1000000);
      assert.equal(body1.summary.remainingBalance, 3000000);
      assert.equal(body1.summary.totalMonthlyBudget, 4000000);

      // 2. Query for User 2
      const res2 = await fetch(`${baseUrl}/api/analisa?userId=${user2Id}&date=2026-09-12`);
      assert.equal(res2.status, 200);
      const body2 = await res2.json();
      assert.equal(body2.userId, user2Id);
      assert.equal(body2.summary.totalSpent, 200000);
      assert.equal(body2.summary.remainingBalance, 9800000);
      assert.equal(body2.summary.totalMonthlyBudget, 10000000);
    });

    it('extracts userId via header (x-user-id) as well as query param', async () => {
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 5000000)
      `).run(user1Id);

      const res = await fetch(`${baseUrl}/api/analisa?date=2026-09-12`, {
        headers: { 'x-user-id': String(user1Id) },
      });
      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.userId, user1Id);
      assert.equal(body.summary.totalMonthlyBudget, 5000000);
    });
  });

  describe('3. Specialized Sub-Endpoints', () => {
    beforeEach(() => {
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 5000000)
      `).run(user1Id);

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 700000, 'Belanja', '2026-09-12 12:00:00', 1)
      `).run(user1Id, makanCatId);
    });

    it('GET /api/analisa/summary returns executive summary', async () => {
      const res = await fetch(`${baseUrl}/api/analisa/summary?userId=${user1Id}&date=2026-09-12`);
      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.success, true);
      assert.ok(body.summary);
      assert.equal(body.summary.totalSpent, 700000);
      assert.equal(body.summary.remainingBalance, 4300000);
    });

    it('GET /api/analisa/daily-average returns daily spending breakdown', async () => {
      const res = await fetch(`${baseUrl}/api/analisa/daily-average?userId=${user1Id}&date=2026-09-12&days=7`);
      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.days, 7);
      assert.equal(body.totalSpent, 700000);
      assert.equal(body.dailyPoints.length, 7);
    });

    it('GET /api/analisa/depletion returns depletion projection and simulation', async () => {
      const res = await fetch(`${baseUrl}/api/analisa/depletion?userId=${user1Id}&date=2026-09-12`);
      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.remainingBalance, 4300000);
      assert.ok(body.depletionDate);
      assert.ok(body.simulation);
    });

    it('GET /api/analisa/warning returns early warning 3-tier status', async () => {
      const res = await fetch(`${baseUrl}/api/analisa/warning?userId=${user1Id}&date=2026-09-12`);
      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.success, true);
      assert.ok(['normal', 'warning', 'critical'].includes(body.level));
      assert.ok([1, 2, 3].includes(body.levelNumber));
      assert.ok(body.actionRecommendation);
    });
  });

  describe('4. Force Recalculate Endpoint (POST /api/analisa/recalculate)', () => {
    it('manually forces financial analysis recalculation and updates cache', async () => {
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 5000000)
      `).run(user1Id);

      const res = await fetch(`${baseUrl}/api/analisa/recalculate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          date: '2026-09-12',
        }),
      });

      assert.equal(res.status, 200);
      const body = await res.json();
      assert.equal(body.success, true);
      assert.ok(body.message.includes('berhasil'));
      assert.equal(body.userId, user1Id);

      // Verify row in ai_insights
      const cacheRow = db.prepare("SELECT * FROM ai_insights WHERE user_id = ? AND date = '2026-09-12'").get(user1Id);
      assert.ok(cacheRow);
      assert.equal(cacheRow.is_stale, 0);
    });
  });

  describe('5. Error Handling & Parameter Validation', () => {
    it('returns 400 when userId is invalid', async () => {
      const res = await fetch(`${baseUrl}/api/analisa?userId=-5`);
      assert.equal(res.status, 400);
      const body = await res.json();
      assert.equal(body.success, false);
      assert.ok(body.error.includes('userId'));
    });

    it('returns 400 when date is invalid format', async () => {
      const res = await fetch(`${baseUrl}/api/analisa?userId=${user1Id}&date=not-a-date`);
      assert.equal(res.status, 400);
      const body = await res.json();
      assert.equal(body.success, false);
      assert.ok(body.error.includes('tanggal'));
    });
  });

  describe('6. Route Aliases Verification', () => {
    it('supports route aliases: /analisa, /analysis, and /api/analysis', async () => {
      for (const route of ['/analisa', '/analysis', '/api/analysis']) {
        const res = await fetch(`${baseUrl}${route}?userId=${user1Id}&date=2026-09-12`);
        assert.equal(res.status, 200, `Route ${route} should return 200 OK`);
        const body = await res.json();
        assert.equal(body.success, true);
      }
    });
  });
});
