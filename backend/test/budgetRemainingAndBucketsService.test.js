import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import {
  calculateRemainingAndBucketNominals,
  getRemainingAndBucketNominalsQuery,
} from '../src/services/budgetService.js';

describe('Budget Remaining Limit & Nominal Per Pos Service & Endpoint Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  const testMonth = '2026-09';

  before(async () => {
    db = getDatabase();
    const userRes = db
      .prepare("INSERT INTO users (email, display_name) VALUES (?, 'Remaining Pos Tester')")
      .run(`rem_pos_tester_${Date.now()}@example.com`);
    testUserId = Number(userRes.lastInsertRowid);

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    if (testUserId && db) {
      db.prepare('DELETE FROM users WHERE id = ?').run(testUserId);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('pure service calculates safe remaining budget, daily average (30 days), and 50/30/20 pos nominals accurately', () => {
    const calc = calculateRemainingAndBucketNominals({
      month: '2026-09',
      totalBudget: 6000000,
      totalSpent: 2850000,
      needsPct: 50,
      savingsPct: 30,
      funPct: 20,
      needsSpent: 1600000,
      savingsSpent: 800000,
      funSpent: 450000,
    });

    assert.equal(calc.totalBudget, 6000000);
    assert.equal(calc.totalSpent, 2850000);
    assert.equal(calc.totalRemaining, 3150000);
    assert.equal(calc.formattedTotalRemaining, 'Rp 3.150.000');
    assert.equal(calc.formattedRemainingWithSign, 'Rp 3.150.000');
    assert.equal(calc.remainingPercentage, 52.5);
    assert.equal(calc.isOverBudget, false);
    assert.equal(calc.remainingStatusLabel, 'Batas Aman');
    assert.equal(calc.daysInMonth, 30);
    assert.equal(calc.dailyRemainingAverage, 105000);
    assert.equal(calc.formattedDailyRemainingAverage, 'Rp 105.000 / hari');
    assert.match(calc.persentaseText, /Tersisa 52\.5% dari total plafon Rp 6\.000\.000/);
    assert.match(calc.keteranganText, /Estimasi aman belanja: Rp 105\.000 \/ hari \(tersisa 30 hari\)/);

    // Check 3 pos nominals & remaining per pos
    assert.equal(calc.posAlokasi.length, 3);
    const [needsPos, savingsPos, funPos] = calc.posAlokasi;

    assert.equal(needsPos.nominalPos, 3000000);
    assert.equal(needsPos.amountSpent, 1600000);
    assert.equal(needsPos.amountRemaining, 1400000);
    assert.equal(needsPos.statusLabel, 'Sisa Rp 1.400.000');

    assert.equal(savingsPos.nominalPos, 1800000);
    assert.equal(savingsPos.amountSpent, 800000);
    assert.equal(savingsPos.amountRemaining, 1000000);

    assert.equal(funPos.nominalPos, 1200000);
    assert.equal(funPos.amountSpent, 450000);
    assert.equal(funPos.amountRemaining, 750000);
  });

  it('pure service handles August (31 days) low remaining state and over-budget state accurately', () => {
    const lowCalc = calculateRemainingAndBucketNominals({
      month: '2026-08',
      totalBudget: 6000000,
      totalSpent: 5400000,
    });

    assert.equal(lowCalc.daysInMonth, 31);
    assert.equal(lowCalc.totalRemaining, 600000);
    assert.equal(lowCalc.remainingPercentage, 10);
    assert.equal(lowCalc.remainingStatusLabel, 'Batas Menipis');
    assert.equal(lowCalc.dailyRemainingAverage, 19355);

    const overCalc = calculateRemainingAndBucketNominals({
      month: '2026-09',
      totalBudget: 5000000,
      totalSpent: 5500000,
      needsSpent: 3200000, // exceeds 2.5M needs limit
      savingsSpent: 1000000,
      funSpent: 1300000, // exceeds 1.0M fun limit
    });

    assert.equal(overCalc.totalRemaining, -500000);
    assert.equal(overCalc.isOverBudget, true);
    assert.equal(overCalc.formattedTotalRemaining, 'Rp 500.000');
    assert.equal(overCalc.formattedRemainingWithSign, '- Rp 500.000');
    assert.equal(overCalc.remainingStatusLabel, 'Batas Terlampaui');
    assert.equal(overCalc.dailyRemainingAverage, 0);
    assert.match(overCalc.persentaseText, /Pengeluaran Rp 5\.500\.000 telah melebihi plafon Rp 5\.000\.000/);
    assert.deepEqual(overCalc.overBudgetBuckets, ['Kebutuhan Pokok', 'Hiburan & Keinginan']);
  });

  it('integrates real DB transactions into GET /api/budgets/sisa-batas and /api/budgets/pos', async () => {
    // 1. Set monthly budget of 6,000,000 with 50/30/20 allocation
    await fetch(`${baseUrl}/api/budgets/monthly`, {
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

    // 2. Insert confirmed expenses in Needs (Makan & Minuman: 1,600,000) and Fun (Hiburan: 450,000)
    const makanCat = db
      .prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'")
      .get();
    const hiburanCat = db
      .prepare("SELECT id FROM categories WHERE name = 'Hiburan' AND type = 'expense'")
      .get();

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES
        (?, ?, 'Makan & Minuman', 'expense', 1600000, 'Belanja makan bulanan', '2026-09-10 12:00:00', 1),
        (?, ?, 'Hiburan', 'expense', 450000, 'Nonton & rekreasi', '2026-09-15 19:00:00', 1)
    `).run(testUserId, makanCat.id, testUserId, hiburanCat.id);

    // 3. Query GET /api/budgets/sisa-batas
    const res = await fetch(`${baseUrl}/api/budgets/sisa-batas?userId=${testUserId}&month=${testMonth}`);
    assert.equal(res.status, 200);
    const data = await res.json();

    assert.equal(data.success, true);
    assert.equal(data.totalBudget, 6000000);
    assert.equal(data.totalSpent, 2050000);
    assert.equal(data.totalRemaining, 3950000);
    assert.equal(data.sisaBatas.totalRemaining, 3950000);
    assert.equal(data.sisaBatas.remainingStatusLabel, 'Batas Aman');

    // Verify bucket spent & remaining
    assert.equal(data.bucketsByType.needs.nominalPos, 3000000);
    assert.equal(data.bucketsByType.needs.amountSpent, 1600000);
    assert.equal(data.bucketsByType.needs.amountRemaining, 1400000);

    assert.equal(data.bucketsByType.fun.nominalPos, 1200000);
    assert.equal(data.bucketsByType.fun.amountSpent, 450000);
    assert.equal(data.bucketsByType.fun.amountRemaining, 750000);

    // 4. Test live simulation override via POST /api/budgets/calculation
    const simRes = await fetch(`${baseUrl}/api/budgets/calculation`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        totalBudget: 8000000,
        needsPct: 40,
        savingsPct: 40,
        funPct: 20,
      }),
    });
    assert.equal(simRes.status, 200);
    const simData = await simRes.json();
    assert.equal(simData.totalBudget, 8000000);
    assert.equal(simData.totalRemaining, 5950000); // 8M - 2.05M
    assert.equal(simData.bucketsByType.needs.nominalPos, 3200000); // 40% of 8M
    assert.equal(simData.bucketsByType.savings.nominalPos, 3200000); // 40% of 8M
    assert.equal(simData.bucketsByType.fun.nominalPos, 1600000); // 20% of 8M
  });
});
