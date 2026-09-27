import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { getOrCreateDefaultUser } from '../src/controllers/chatController.js';
import { getIncomeExpenseSummaryQuery } from '../src/services/rekapQueryService.js';

describe('Endpoint Ringkasan Pemasukan dan Pengeluaran Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  const targetMonth = '2026-06';

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

    // Clean up any test records in 2026-06
    db.prepare("DELETE FROM transactions WHERE occurred_at LIKE '2026-06%'").run();

    // Categories
    const salaryCat = db.prepare("SELECT id FROM categories WHERE name = 'Gaji' AND type = 'income'").get();
    const bonusCat = db.prepare("SELECT id FROM categories WHERE name = 'Bonus' AND type = 'income'").get();
    const foodCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get();
    const transportCat = db.prepare("SELECT id FROM categories WHERE name = 'Transportasi' AND type = 'expense'").get();
    const billCat = db.prepare("SELECT id FROM categories WHERE name = 'Tagihan & Utilitas' AND type = 'expense'").get();

    // 1. Confirmed Income transactions:
    // Income 1: 10,000,000 (Gaji Bulanan) - 2026-06-01
    // Income 2: 2,000,000 (Bonus Kinerja) - 2026-06-15
    // Total Confirmed Income: 12,000,000
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'income', 10000000, 'Gaji Bulanan Juni', '2026-06-01 09:00:00', 1)
    `).run(testUserId, salaryCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'income', 2000000, 'Bonus Proyek Kinerja', '2026-06-15 14:00:00', 1)
    `).run(testUserId, bonusCat?.id || null);

    // 2. Confirmed Expense transactions:
    // Expense 1: 2,500,000 (Makan & Minuman) - 2026-06-05
    // Expense 2: 1,500,000 (Tagihan Listrik & Air) - 2026-06-10
    // Expense 3: 800,000 (Bensin & Servis Motor) - 2026-06-20
    // Total Confirmed Expense: 4,800,000
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'expense', 2500000, 'Belanja Mingguan Supermarket', '2026-06-05 11:00:00', 1)
    `).run(testUserId, foodCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'expense', 1500000, 'Tagihan Listrik Rumah', '2026-06-10 16:30:00', 1)
    `).run(testUserId, billCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'expense', 800000, 'Servis Motor Rutin', '2026-06-20 10:15:00', 1)
    `).run(testUserId, transportCat?.id || null);

    // 3. Pending transactions:
    // Pending Expense: 450,000
    // Pending Income: 500,000
    db.prepare(`
      INSERT INTO transactions (user_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, 'expense', 450000, 'Pending Chat Makan Siang Tim', '2026-06-22 13:00:00', 0)
    `).run(testUserId);

    db.prepare(`
      INSERT INTO transactions (user_id, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, 'income', 500000, 'Pending Uang Penggantian Kantor', '2026-06-23 15:00:00', 0)
    `).run(testUserId);
  });

  after(async () => {
    db.prepare("DELETE FROM transactions WHERE occurred_at LIKE '2026-06%'").run();
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. Unit / Service Layer: getIncomeExpenseSummaryQuery', () => {
    it('aggregates income and expense with totals, savings, counts, and largest items', () => {
      const res = getIncomeExpenseSummaryQuery(db, testUserId, { month: targetMonth });

      assert.equal(res.month, '2026-06');
      assert.equal(res.monthLabel, 'Juni 2026');

      // Totals
      assert.equal(res.totalIncome, 12000000);
      assert.equal(res.totalExpense, 4800000);
      assert.equal(res.netSavings, 7200000);
      // savingsRate = (12000000 - 4800000) / 12000000 = 60.0%
      assert.equal(res.savingsRate, 60.0);
      assert.equal(res.daysInMonth, 30);
      // averageDailyExpense = 4800000 / 30 = 160000
      assert.equal(res.averageDailyExpense, 160000);

      // Nested summary object
      assert.equal(res.summary.totalIncome, 12000000);
      assert.equal(res.summary.totalExpense, 4800000);
      assert.equal(res.summary.netSavings, 7200000);
      assert.equal(res.summary.isSurplus, true);
      assert.equal(res.summary.status, 'surplus');
      assert.equal(res.summary.statusLabel, 'Surplus');
      assert.equal(res.summary.savingsRate, 60.0);
      // expenseRatio = 4800000 / 12000000 = 40.0%
      assert.equal(res.summary.expenseRatio, 40.0);
      assert.equal(res.summary.averageDailyExpense, 160000);

      // Counts
      assert.equal(res.counts.confirmed, 5);
      assert.equal(res.counts.pending, 2);
      assert.equal(res.counts.income, 2);
      assert.equal(res.counts.expense, 3);
      assert.equal(res.counts.total, 5);

      // Pending
      assert.equal(res.pending.totalIncome, 500000);
      assert.equal(res.pending.totalExpense, 450000);
      assert.equal(res.pending.count, 2);

      // Largest transactions
      assert.ok(res.largestTransactions.largestExpense);
      assert.equal(res.largestTransactions.largestExpense.amount, 2500000);
      assert.equal(res.largestTransactions.largestExpense.categoryName, 'Makan & Minuman');

      assert.ok(res.largestTransactions.largestIncome);
      assert.equal(res.largestTransactions.largestIncome.amount, 10000000);
      assert.equal(res.largestTransactions.largestIncome.categoryName, 'Gaji');

      // Proportions
      // totalCashflow = 16800000
      // incomePercentage = 12000000 / 16800000 = 71.4%
      // expensePercentage = 4800000 / 16800000 = 28.6%
      assert.equal(res.proportions.incomePercentage, 71.4);
      assert.equal(res.proportions.expensePercentage, 28.6);
    });

    it('handles custom date range (startDate & endDate)', () => {
      // Filter only transactions between 2026-06-05 and 2026-06-15
      // Included:
      // - 2026-06-05 Expense: 2,500,000
      // - 2026-06-10 Expense: 1,500,000 -> Total Expense: 4,000,000
      // - 2026-06-15 Income: 2,000,000 -> Total Income: 2,000,000
      // Excluded:
      // - 2026-06-01 Income: 10,000,000
      // - 2026-06-20 Expense: 800,000
      const res = getIncomeExpenseSummaryQuery(db, testUserId, {
        startDate: '2026-06-05',
        endDate: '2026-06-15',
      });

      assert.equal(res.totalIncome, 2000000);
      assert.equal(res.totalExpense, 4000000);
      assert.equal(res.netSavings, -2000000);
      assert.equal(res.summary.isSurplus, false);
      assert.equal(res.summary.status, 'deficit');
      assert.equal(res.summary.statusLabel, 'Defisit');
      assert.equal(res.counts.confirmed, 3);
      assert.equal(res.counts.income, 1);
      assert.equal(res.counts.expense, 2);
    });
  });

  describe('2. HTTP Endpoints: GET /api/rekap/summary & GET /api/rekap/income-expense', () => {
    it('GET /api/rekap/summary returns complete income and expense summary', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/summary?month=${targetMonth}`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.month, '2026-06');
      assert.equal(body.totalIncome, 12000000);
      assert.equal(body.totalExpense, 4800000);
      assert.equal(body.netSavings, 7200000);
      assert.equal(body.summary.isSurplus, true);
      assert.equal(body.summary.statusLabel, 'Surplus');
      assert.ok(body.largestTransactions.largestExpense);
      assert.ok(body.largestTransactions.largestIncome);
    });

    it('GET /api/rekap/income-expense returns dedicated income-expense structure', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/income-expense?month=${targetMonth}`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.month, '2026-06');
      assert.equal(body.totalIncome, 12000000);
      assert.equal(body.totalExpense, 4800000);
      assert.equal(body.counts.confirmed, 5);
      assert.equal(body.proportions.incomePercentage, 71.4);
    });

    it('GET /api/transactions/summary alias returns matching summary', async () => {
      const res = await fetch(`${baseUrl}/api/transactions/summary?month=${targetMonth}`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.month, '2026-06');
      assert.equal(body.totalIncome, 12000000);
      assert.equal(body.totalExpense, 4800000);
    });

    it('supports date range query params (?startDate=...&endDate=...)', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/summary?startDate=2026-06-05&endDate=2026-06-15`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.totalIncome, 2000000);
      assert.equal(body.totalExpense, 4000000);
      assert.equal(body.netSavings, -2000000);
      assert.equal(body.summary.status, 'deficit');
    });

    it('returns clean zero state for empty month with no transactions', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/summary?month=2024-01`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.month, '2024-01');
      assert.equal(body.totalIncome, 0);
      assert.equal(body.totalExpense, 0);
      assert.equal(body.netSavings, 0);
      assert.equal(body.savingsRate, 0);
      assert.equal(body.summary.isSurplus, true);
      assert.equal(body.counts.confirmed, 0);
      assert.equal(body.largestTransactions.largestExpense, null);
      assert.equal(body.largestTransactions.largestIncome, null);
    });
  });
});
