import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import {
  getPreviousMonthString,
  getDaysInMonth,
  getMonthLabel,
  getMonthlyTotalsQuery,
  getMonthOverMonthComparisonQuery,
  getCategoryBreakdownQuery,
  getDailyTotalsQuery,
  getFullMonthlyRekapAggregation,
} from '../src/services/rekapQueryService.js';
import { getOrCreateDefaultUser } from '../src/controllers/chatController.js';

describe('Rekap Monthly Aggregation Queries and Endpoints Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  const targetMonth = '2026-05';
  const previousMonth = '2026-04';

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

    // Seed test transactions in previous month (2026-04) and target month (2026-05)
    // 2026-04 transactions:
    // Income: 6,000,000
    // Expense: 4,000,000
    db.prepare(`
      INSERT INTO transactions (user_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, 'income', 6000000, 'Gaji April 2026', '2026-04-25 10:00:00', 1)
    `).run(testUserId);

    db.prepare(`
      INSERT INTO transactions (user_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, 'expense', 4000000, 'Biaya Hidup April 2026', '2026-04-20 12:00:00', 1)
    `).run(testUserId);

    // 2026-05 transactions:
    // Confirmed Income 1: 7,500,000 (Gaji)
    // Confirmed Income 2: 1,500,000 (Freelance) -> Total Income: 9,000,000
    // Confirmed Expense 1: 2,000,000 (Makan & Minuman)
    // Confirmed Expense 2: 1,000,000 (Transportasi)
    // Confirmed Expense 3: 500,000 (Hiburan) -> Total Expense: 3,500,000
    // Pending Expense: 250,000
    // Pending Income: 300,000
    const foodCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get();
    const transportCat = db.prepare("SELECT id FROM categories WHERE name = 'Transportasi' AND type = 'expense'").get();
    const entertainmentCat = db.prepare("SELECT id FROM categories WHERE name = 'Hiburan' AND type = 'expense'").get();
    const salaryCat = db.prepare("SELECT id FROM categories WHERE name = 'Gaji' AND type = 'income'").get();

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'income', 7500000, 'Gaji Pokok Mei', '2026-05-25 09:00:00', 1)
    `).run(testUserId, salaryCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'income', 1500000, 'Side project Mei', '2026-05-18 15:30:00', 1)
    `).run(testUserId, salaryCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'expense', 2000000, 'Restoran dan Belanja Pangan', '2026-05-10 12:00:00', 1)
    `).run(testUserId, foodCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'expense', 1000000, 'Bensin dan Tol', '2026-05-15 08:30:00', 1)
    `).run(testUserId, transportCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'expense', 500000, 'Tiket Konser Musik', '2026-05-20 20:00:00', 1)
    `).run(testUserId, entertainmentCat?.id || null);

    // Pending transactions in 2026-05
    db.prepare(`
      INSERT INTO transactions (user_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, 'expense', 250000, 'Pending Chat Kopi & Donat', '2026-05-22 14:00:00', 0)
    `).run(testUserId);

    db.prepare(`
      INSERT INTO transactions (user_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, 'income', 300000, 'Pending Cashback Promo', '2026-05-23 11:00:00', 0)
    `).run(testUserId);
  });

  after(async () => {
    // Clean up test transactions for 2026-05 and 2026-04
    db.prepare("DELETE FROM transactions WHERE occurred_at LIKE '2026-05%' OR occurred_at LIKE '2026-04%'").run();
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('Rekap Query Helpers & Date Calculations', () => {
    it('computes previous month correctly including year rollover', () => {
      assert.equal(getPreviousMonthString('2026-05'), '2026-04');
      assert.equal(getPreviousMonthString('2026-01'), '2025-12');
      assert.equal(getPreviousMonthString('2026-10'), '2026-09');
    });

    it('calculates days in month properly', () => {
      assert.equal(getDaysInMonth('2026-05'), 31);
      assert.equal(getDaysInMonth('2026-04'), 30);
      assert.equal(getDaysInMonth('2026-02'), 28);
    });

    it('formats month label in Indonesian', () => {
      assert.equal(getMonthLabel('2026-05'), 'Mei 2026');
      assert.equal(getMonthLabel('2026-09'), 'September 2026');
      assert.equal(getMonthLabel('2026-12'), 'Desember 2026');
    });
  });

  describe('Service Query Functions', () => {
    it('getMonthlyTotalsQuery aggregates confirmed and pending financial totals correctly', () => {
      const totals = getMonthlyTotalsQuery(db, testUserId, targetMonth);

      assert.equal(totals.month, '2026-05');
      assert.equal(totals.monthLabel, 'Mei 2026');
      assert.equal(totals.totalIncome, 9000000);
      assert.equal(totals.totalExpense, 3500000);
      assert.equal(totals.netSavings, 5500000);
      // savingsRate = (9000000 - 3500000) / 9000000 = 61.1%
      assert.equal(totals.savingsRate, 61.1);
      assert.equal(totals.daysInMonth, 31);
      // averageDailyExpense = 3500000 / 31 = 112903.23
      assert.equal(totals.averageDailyExpense, 112903.23);
      assert.equal(totals.confirmedTransactionsCount, 5);
      assert.equal(totals.pendingTransactionsCount, 2);
      assert.equal(totals.incomeTransactionsCount, 2);
      assert.equal(totals.expenseTransactionsCount, 3);
      assert.equal(totals.pendingExpenseTotal, 250000);
      assert.equal(totals.pendingIncomeTotal, 300000);
    });

    it('getMonthOverMonthComparisonQuery computes MoM differences accurately', () => {
      const comparison = getMonthOverMonthComparisonQuery(db, testUserId, targetMonth);

      assert.equal(comparison.currentMonth, '2026-05');
      assert.equal(comparison.previousMonth, '2026-04');
      assert.equal(comparison.previousMonthLabel, 'April 2026');
      assert.equal(comparison.totalExpense, 3500000);
      assert.equal(comparison.lastMonthTotalExpense, 4000000);
      // (3500000 - 4000000) / 4000000 = -12.5%
      assert.equal(comparison.expenseDiffPct, -12.5);
      assert.equal(comparison.isExpenseHigher, false);

      assert.equal(comparison.totalIncome, 9000000);
      assert.equal(comparison.lastMonthTotalIncome, 6000000);
      // (9000000 - 6000000) / 6000000 = +50.0%
      assert.equal(comparison.incomeDiffPct, 50.0);
      assert.equal(comparison.isIncomeHigher, true);
    });

    it('getCategoryBreakdownQuery groups and calculates percentages for categories', () => {
      const breakdown = getCategoryBreakdownQuery(db, testUserId, targetMonth, 'expense');

      assert.ok(Array.isArray(breakdown));
      assert.equal(breakdown.length, 3);

      // Highest expense first: Makan & Minuman (2,000,000 / 3,500,000 = 57.1%)
      const foodItem = breakdown.find((b) => b.categoryName === 'Makan & Minuman');
      assert.ok(foodItem);
      assert.equal(foodItem.total, 2000000);
      assert.equal(foodItem.percentage, 57.1);
      assert.equal(foodItem.transactionCount, 1);

      // Transportasi (1,000,000 / 3,500,000 = 28.6%)
      const transportItem = breakdown.find((b) => b.categoryName === 'Transportasi');
      assert.ok(transportItem);
      assert.equal(transportItem.total, 1000000);
      assert.equal(transportItem.percentage, 28.6);

      // Hiburan (500,000 / 3,500,000 = 14.3%)
      const entertainmentItem = breakdown.find((b) => b.categoryName === 'Hiburan');
      assert.ok(entertainmentItem);
      assert.equal(entertainmentItem.total, 500000);
      assert.equal(entertainmentItem.percentage, 14.3);
    });

    it('getDailyTotalsQuery aggregates daily income and expense', () => {
      const daily = getDailyTotalsQuery(db, testUserId, targetMonth);

      assert.ok(Array.isArray(daily));
      assert.ok(daily.length >= 4);

      // 2026-05-10 has 2,000,000 expense
      const day10 = daily.find((d) => d.date === '2026-05-10');
      assert.ok(day10);
      assert.equal(day10.day, 10);
      assert.equal(day10.expense, 2000000);
      assert.equal(day10.income, 0);

      // 2026-05-25 has 7,500,000 income
      const day25 = daily.find((d) => d.date === '2026-05-25');
      assert.ok(day25);
      assert.equal(day25.day, 25);
      assert.equal(day25.income, 7500000);
    });

    it('getFullMonthlyRekapAggregation bundles all monthly aggregation data', () => {
      const full = getFullMonthlyRekapAggregation(db, testUserId, targetMonth);

      assert.equal(full.month, '2026-05');
      assert.equal(full.monthLabel, 'Mei 2026');
      assert.ok(full.summary);
      assert.equal(full.summary.totalIncome, 9000000);
      assert.ok(full.comparison);
      assert.equal(full.comparison.previousMonth, '2026-04');
      assert.ok(Array.isArray(full.categoryBreakdown));
      assert.ok(Array.isArray(full.dailyBreakdown));
    });
  });

  describe('HTTP API Endpoints Integration', () => {
    it('GET /api/rekap returns full monthly rekap with summary, comparison, breakdown, and daily', async () => {
      const res = await fetch(`${baseUrl}/api/rekap?month=${targetMonth}`);
      assert.equal(res.status, 200);

      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.month, '2026-05');
      assert.equal(data.monthLabel, 'Mei 2026');
      assert.equal(data.summary.totalIncome, 9000000);
      assert.equal(data.summary.totalExpense, 3500000);
      assert.equal(data.summary.netSavings, 5500000);
      assert.ok(data.comparison);
      assert.equal(data.comparison.expenseDiffPct, -12.5);
      assert.ok(Array.isArray(data.categoryBreakdown));
      assert.ok(Array.isArray(data.dailyBreakdown));
    });

    it('GET /api/rekap/summary returns focused monthly totals aggregation', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/summary?month=${targetMonth}`);
      assert.equal(res.status, 200);

      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.month, '2026-05');
      assert.equal(data.totalIncome, 9000000);
      assert.equal(data.totalExpense, 3500000);
      assert.equal(data.netSavings, 5500000);
      assert.equal(data.savingsRate, 61.1);
      assert.equal(data.confirmedTransactionsCount, 5);
      assert.equal(data.pendingTransactionsCount, 2);
    });

    it('GET /api/rekap/comparison returns Month-over-Month comparison', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/comparison?month=${targetMonth}`);
      assert.equal(res.status, 200);

      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.currentMonth, '2026-05');
      assert.equal(data.previousMonth, '2026-04');
      assert.equal(data.expenseDiffPct, -12.5);
      assert.equal(data.incomeDiffPct, 50.0);
    });

    it('GET /api/rekap/breakdown returns category proportions filtered by type', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/breakdown?month=${targetMonth}&type=expense`);
      assert.equal(res.status, 200);

      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.month, '2026-05');
      assert.equal(data.type, 'expense');
      assert.ok(Array.isArray(data.categoryBreakdown));
      assert.equal(data.categoryBreakdown.length, 3);
      assert.equal(data.categoryBreakdown[0].categoryName, 'Makan & Minuman');
    });

    it('GET /api/rekap/daily returns daily timeline trends', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/daily?month=${targetMonth}`);
      assert.equal(res.status, 200);

      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.month, '2026-05');
      assert.ok(Array.isArray(data.dailyBreakdown));
      assert.ok(data.dailyBreakdown.length >= 4);
    });
  });
});
