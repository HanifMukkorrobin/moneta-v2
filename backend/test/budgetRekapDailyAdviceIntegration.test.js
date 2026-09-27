import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Budget Changes Integration with Monthly Rekap & Daily Spending Advice (Saran Harian)', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  const testMonth = '2026-09'; // 30 days in September

  before(async () => {
    db = getDatabase();
    const userRes = db
      .prepare("INSERT INTO users (email, display_name) VALUES (?, 'Budget Rekap Integration Tester')")
      .run(`budget_rekap_integ_${Date.now()}@example.com`);
    testUserId = Number(userRes.lastInsertRowid);

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  beforeEach(() => {
    db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
    db.prepare('DELETE FROM budgets WHERE user_id = ?').run(testUserId);
    db.prepare('DELETE FROM monthly_budgets WHERE user_id = ?').run(testUserId);
  });

  after(async () => {
    if (testUserId && db) {
      db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM budgets WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM monthly_budgets WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM users WHERE id = ?').run(testUserId);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('synchronizes monthly budget creation, limit changes, allocation changes, and deletion with Rekap Bulanan and Saran Harian', async () => {
    // 1. Seed income (Rp 10.000.000) and expense (Rp 2.400.000: Rp 1.800.000 Needs + Rp 600.000 Fun)
    const gajiCat = db
      .prepare("SELECT id FROM categories WHERE name = 'Gaji' AND type = 'income'")
      .get();
    const makanCat = db
      .prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'")
      .get();
    const hiburanCat = db
      .prepare("SELECT id FROM categories WHERE name = 'Hiburan' AND type = 'expense'")
      .get();

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES
        (?, ?, 'Gaji', 'income', 10000000, 'Gaji bulanan', '2026-09-01 09:00:00', 1),
        (?, ?, 'Makan & Minuman', 'expense', 1800000, 'Makan harian', '2026-09-08 12:00:00', 1),
        (?, ?, 'Hiburan', 'expense', 600000, 'Nonton & kopi', '2026-09-12 19:00:00', 1)
    `).run(testUserId, gajiCat.id, testUserId, makanCat.id, testUserId, hiburanCat.id);

    // 2. Create monthly budget of Rp 6.000.000 (50/30/20)
    const createRes = await fetch(`${baseUrl}/api/budgets/monthly`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        totalAmount: 6000000,
        needsPct: 50,
        savingsPct: 30,
        funPct: 20,
      }),
    });
    assert.equal(createRes.status, 201);
    const createBody = await createRes.json();

    // Remaining = 6.000.000 - 2.400.000 = 3.600.000 over 30 days -> Rp 120.000 / hari
    assert.equal(createBody.saranHarian.totalBudget, 6000000);
    assert.equal(createBody.saranHarian.totalSpent, 2400000);
    assert.equal(createBody.saranHarian.totalRemaining, 3600000);
    assert.equal(createBody.saranHarian.dailySafeSpend, 120000);
    assert.equal(createBody.saranHarian.formattedDailySafeSpend, 'Rp 120.000 / hari');
    // Needs remaining = 3.000.000 - 1.800.000 = 1.200.000 / 30 = 40.000 / hari
    assert.equal(createBody.saranHarian.needsDailySafeSpend, 40000);
    // Fun remaining = 1.200.000 - 600.000 = 600.000 / 30 = 20.000 / hari
    assert.equal(createBody.saranHarian.funDailySafeSpend, 20000);
    assert.equal(createBody.rekapSummary.totalIncome, 10000000);
    assert.equal(createBody.rekapSummary.totalExpense, 2400000);

    // 3. Verify GET /api/rekap immediately reflects the budget and daily advice
    const rekapRes1 = await fetch(`${baseUrl}/api/rekap?userId=${testUserId}&month=${testMonth}`);
    assert.equal(rekapRes1.status, 200);
    const rekapBody1 = await rekapRes1.json();

    assert.equal(rekapBody1.summary.hasMonthlyBudget, true);
    assert.equal(rekapBody1.summary.totalBudget, 6000000);
    assert.equal(rekapBody1.summary.totalRemainingBudget, 3600000);
    assert.equal(rekapBody1.summary.dailySafeSpend, 120000);
    assert.equal(rekapBody1.saranHarian.dailySafeSpend, 120000);
    assert.equal(rekapBody1.saranHarian.status, 'safe');

    // 4. Update allocation percentages to 40% Needs / 40% Savings / 20% Fun
    const allocRes = await fetch(`${baseUrl}/api/budgets/allocation`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        needsPct: 40,
        savingsPct: 40,
        funPct: 20,
      }),
    });
    assert.equal(allocRes.status, 200);
    const allocBody = await allocRes.json();

    // Needs limit = 2.400.000, spent = 1.800.000 -> remaining = 600.000 / 30 = 20.000 / hari
    assert.equal(allocBody.saranHarian.needsDailySafeSpend, 20000);
    // Savings limit = 2.400.000, spent = 0 -> remaining = 2.400.000 / 30 = 80.000 / hari
    assert.equal(allocBody.saranHarian.savingsDailySafeSpend, 80000);

    // 5. Lower monthly budget limit to Rp 2.700.000 (spent is 2.400.000 -> remaining 300.000 = 11.1% -> critical / nearLimit)
    const lowerRes = await fetch(`${baseUrl}/api/budgets/monthly`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        totalAmount: 2700000,
      }),
    });
    assert.equal(lowerRes.status, 200);
    const lowerBody = await lowerRes.json();

    assert.equal(lowerBody.saranHarian.totalRemaining, 300000);
    assert.equal(lowerBody.saranHarian.dailySafeSpend, 10000); // 300.000 / 30
    assert.equal(lowerBody.saranHarian.status, 'critical');
    assert.equal(lowerBody.saranHarian.warningLevel, 'nearLimit');

    // 6. Query dedicated GET /api/budgets/saran-harian with custom remainingDays=10
    const adviceRes = await fetch(
      `${baseUrl}/api/budgets/saran-harian?userId=${testUserId}&month=${testMonth}&remainingDays=10`
    );
    assert.equal(adviceRes.status, 200);
    const adviceBody = await adviceRes.json();
    assert.equal(adviceBody.remainingDays, 10);
    assert.equal(adviceBody.dailySafeSpend, 30000); // 300.000 / 10 days
    assert.equal(adviceBody.formattedDailySafeSpend, 'Rp 30.000 / hari');

    // 7. Delete monthly budget and verify Rekap & Saran Harian reset to no_budget
    const delRes = await fetch(
      `${baseUrl}/api/budgets/monthly?userId=${testUserId}&month=${testMonth}`,
      { method: 'DELETE' }
    );
    assert.equal(delRes.status, 200);
    const delBody = await delRes.json();
    assert.equal(delBody.saranHarian.hasBudget, false);
    assert.equal(delBody.saranHarian.status, 'no_budget');

    const rekapRes2 = await fetch(`${baseUrl}/api/rekap?userId=${testUserId}&month=${testMonth}`);
    const rekapBody2 = await rekapRes2.json();
    assert.equal(rekapBody2.summary.hasMonthlyBudget, false);
    assert.equal(rekapBody2.saranHarian.status, 'no_budget');
  });
});
