import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { getOrCreateDefaultUser } from '../src/controllers/chatController.js';
import { getMonthOverMonthComparisonQuery } from '../src/services/rekapQueryService.js';

describe('Endpoint Perbandingan Bulan Ini dan Lalu Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  const prevMonth = '2026-10';
  const currMonth = '2026-11';
  const spikeMonth = '2026-12';

  before(async () => {
    db = getDatabase();
    testUserId = getOrCreateDefaultUser(db);

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });

    // Clean up test transactions in 2026-10, 2026-11, 2026-12
    db.prepare(`
      DELETE FROM transactions
      WHERE occurred_at LIKE '2026-10%' OR occurred_at LIKE '2026-11%' OR occurred_at LIKE '2026-12%'
    `).run();

    const foodCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get();
    const transportCat = db.prepare("SELECT id FROM categories WHERE name = 'Transportasi' AND type = 'expense'").get();
    const salaryCat = db.prepare("SELECT id FROM categories WHERE name = 'Gaji' AND type = 'income'").get();

    // 1. Seed 2026-10 (Previous Month):
    // Income: 10,000,000
    // Expense: 5,000,000 (Makan: 3,000,000, Transportasi: 2,000,000)
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Gaji', 'income', 10000000, 'Gaji Oktober', '2026-10-01 09:00:00', 1)
    `).run(testUserId, salaryCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Makan & Minuman', 'expense', 3000000, 'Makan Oktober', '2026-10-10 12:00:00', 1)
    `).run(testUserId, foodCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Transportasi', 'expense', 2000000, 'Transport Oktober', '2026-10-15 17:00:00', 1)
    `).run(testUserId, transportCat?.id || null);

    // 2. Seed 2026-11 (Current Month - Lower Expense / Hemat 20%):
    // Income: 12,000,000 (+20%)
    // Expense: 4,000,000 (-20%) (Makan: 2,500,000, Transportasi: 1,500,000)
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Gaji', 'income', 12000000, 'Gaji November', '2026-11-01 09:00:00', 1)
    `).run(testUserId, salaryCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Makan & Minuman', 'expense', 2500000, 'Makan November', '2026-11-10 12:00:00', 1)
    `).run(testUserId, foodCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Transportasi', 'expense', 1500000, 'Transport November', '2026-11-15 17:00:00', 1)
    `).run(testUserId, transportCat?.id || null);

    // 3. Seed 2026-12 (Spike Month - Higher Expense vs Nov / Naik 25%):
    // Expense: 5,000,000 vs 4,000,000 (+25%)
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Makan & Minuman', 'expense', 5000000, 'Liburan Akhir Tahun', '2026-12-20 12:00:00', 1)
    `).run(testUserId, foodCat?.id || null);
  });

  after(async () => {
    db.prepare(`
      DELETE FROM transactions
      WHERE occurred_at LIKE '2026-10%' OR occurred_at LIKE '2026-11%' OR occurred_at LIKE '2026-12%'
    `).run();
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. Service Layer: getMonthOverMonthComparisonQuery', () => {
    it('computes lower expense (Hemat) comparison with nominal diffs, badge, insight, and category comparison', () => {
      const comp = getMonthOverMonthComparisonQuery(db, testUserId, currMonth);

      assert.equal(comp.currentMonth, '2026-11');
      assert.equal(comp.currentMonthLabel, 'November 2026');
      assert.equal(comp.previousMonth, '2026-10');
      assert.equal(comp.previousMonthLabel, 'Oktober 2026');
      assert.equal(comp.hasPreviousMonthData, true);

      // Expense comparison: 4,000,000 vs 5,000,000 -> -1,000,000 (-20.0%)
      assert.equal(comp.totalExpense, 4000000);
      assert.equal(comp.lastMonthTotalExpense, 5000000);
      assert.equal(comp.expenseNominalDiff, -1000000);
      assert.equal(comp.expenseNominalDiffAbs, 1000000);
      assert.equal(comp.expenseDiffPct, -20.0);
      assert.equal(comp.isExpenseHigher, false);
      assert.equal(comp.isExpenseLower, true);
      assert.equal(comp.expenseTrend, 'down');
      assert.equal(comp.badgeText, 'Hemat 20.0%');
      assert.match(comp.insightMessage, /lebih hemat Rp 1\.000\.000/i);

      // Income comparison: 12,000,000 vs 10,000,000 -> +2,000,000 (+20.0%)
      assert.equal(comp.totalIncome, 12000000);
      assert.equal(comp.lastMonthTotalIncome, 10000000);
      assert.equal(comp.incomeNominalDiff, 2000000);
      assert.equal(comp.incomeDiffPct, 20.0);

      // Category comparison
      assert.ok(Array.isArray(comp.categoryComparison));
      assert.equal(comp.categoryComparison.length, 2);
      const foodComp = comp.categoryComparison.find((c) => c.categoryName === 'Makan & Minuman');
      assert.ok(foodComp);
      assert.equal(foodComp.currentMonthTotal, 2500000);
      assert.equal(foodComp.previousMonthTotal, 3000000);
      assert.equal(foodComp.nominalDiff, -500000);
      assert.equal(foodComp.trend, 'down');
    });

    it('computes higher expense (Naik) comparison accurately', () => {
      const comp = getMonthOverMonthComparisonQuery(db, testUserId, spikeMonth);

      assert.equal(comp.currentMonth, '2026-12');
      assert.equal(comp.previousMonth, '2026-11');
      assert.equal(comp.totalExpense, 5000000);
      assert.equal(comp.lastMonthTotalExpense, 4000000);
      assert.equal(comp.expenseNominalDiff, 1000000);
      assert.equal(comp.expenseDiffPct, 25.0);
      assert.equal(comp.isExpenseHigher, true);
      assert.equal(comp.isExpenseLower, false);
      assert.equal(comp.expenseTrend, 'up');
      assert.equal(comp.badgeText, 'Naik 25.0%');
      assert.match(comp.insightMessage, /meningkat Rp 1\.000\.000/i);
    });
  });

  describe('2. HTTP Endpoints: GET /api/rekap/comparison & aliases', () => {
    it('GET /api/rekap/comparison?month=2026-11 returns full comparison response', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/comparison?month=${currMonth}`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.currentMonth, '2026-11');
      assert.equal(body.previousMonth, '2026-10');
      assert.equal(body.expenseDiffPct, -20.0);
      assert.equal(body.badgeText, 'Hemat 20.0%');
      assert.ok(body.thisMonth);
      assert.ok(body.lastMonth);
      assert.equal(body.thisMonth.totalExpense, 4000000);
      assert.equal(body.lastMonth.totalExpense, 5000000);
    });

    it('GET /api/rekap/compare and /api/transactions/comparison support custom compareWith month', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/compare?month=2026-12&compareWith=2026-10`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.currentMonth, '2026-12');
      assert.equal(body.previousMonth, '2026-10');
      assert.equal(body.totalExpense, 5000000);
      assert.equal(body.lastMonthTotalExpense, 5000000);
      assert.equal(body.expenseDiffPct, 0);
      assert.equal(body.expenseTrend, 'same');
    });

    it('returns hasPreviousMonthData=false when previous month has no transactions', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/comparison?month=2024-05`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.hasPreviousMonthData, false);
      assert.match(body.insightMessage, /Belum ada data transaksi di bulan sebelumnya/i);
    });
  });
});
