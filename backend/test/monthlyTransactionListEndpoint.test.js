import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { getOrCreateDefaultUser } from '../src/controllers/chatController.js';
import { getMonthlyTransactionsListQuery } from '../src/services/rekapQueryService.js';

describe('Endpoint Daftar Transaksi dengan Filter Bulan Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  const targetMonth = '2026-08';

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

    // Clean up existing test transactions in 2026-08 and 2026-03
    db.prepare("DELETE FROM transactions WHERE occurred_at LIKE '2026-08%' OR occurred_at LIKE '2026-03%'").run();

    // Categories
    const foodCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get();
    const transportCat = db.prepare("SELECT id FROM categories WHERE name = 'Transportasi' AND type = 'expense'").get();
    const billCat = db.prepare("SELECT id FROM categories WHERE name = 'Tagihan & Utilitas' AND type = 'expense'").get();
    const salaryCat = db.prepare("SELECT id FROM categories WHERE name = 'Gaji' AND type = 'income'").get();

    // Seed transactions in 2026-08:
    // 1. 2026-08-01: Income Gaji 11,000,000 (confirmed)
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Gaji', 'income', 11000000, 'Gaji Agustus 2026', '2026-08-01 09:00:00', 1)
    `).run(testUserId, salaryCat?.id || null);

    // 2. 2026-08-05: Expense Makan & Minuman 45,000 (confirmed, under_100k)
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Makan & Minuman', 'expense', 45000, 'Nasi Padang Siang', '2026-08-05 12:30:00', 1)
    `).run(testUserId, foodCat?.id || null);

    // 3. 2026-08-05: Expense Transportasi 250,000 (confirmed, 100k_500k)
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Transportasi', 'expense', 250000, 'Isi Bensin Pertamax', '2026-08-05 18:00:00', 1)
    `).run(testUserId, transportCat?.id || null);

    // 4. 2026-08-12: Expense Tagihan & Utilitas 1,200,000 (confirmed, above_500k)
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Tagihan & Utilitas', 'expense', 1200000, 'Bayar Kos & WiFi', '2026-08-12 10:00:00', 1)
    `).run(testUserId, billCat?.id || null);

    // 5. 2026-08-18: Expense Makan & Minuman 80,000 (pending, under_100k)
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Makan & Minuman', 'expense', 80000, 'Kopi Susu & Croissant', '2026-08-18 16:00:00', 0)
    `).run(testUserId, foodCat?.id || null);

    // Seed transaction in another month (2026-03) to verify month isolation
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Makan & Minuman', 'expense', 95000, 'Transaksi Bulan Maret', '2026-03-10 12:00:00', 1)
    `).run(testUserId, foodCat?.id || null);
  });

  after(async () => {
    db.prepare("DELETE FROM transactions WHERE occurred_at LIKE '2026-08%' OR occurred_at LIKE '2026-03%'").run();
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. Service Layer: getMonthlyTransactionsListQuery', () => {
    it('filters transactions strictly by month and groups by date', () => {
      const res = getMonthlyTransactionsListQuery(db, testUserId, { month: targetMonth });

      assert.equal(res.month, '2026-08');
      assert.equal(res.monthLabel, 'Agustus 2026');
      assert.equal(res.total, 5);
      assert.equal(res.transactions.length, 5);

      // Summary counts & totals
      assert.equal(res.summary.totalIncome, 11000000);
      assert.equal(res.summary.totalExpense, 1575000); // 45k + 250k + 1200k + 80k
      assert.equal(res.summary.confirmedCount, 4);
      assert.equal(res.summary.pendingCount, 1);

      // Available categories in 2026-08
      assert.ok(res.availableCategories.includes('Gaji'));
      assert.ok(res.availableCategories.includes('Makan & Minuman'));
      assert.ok(res.availableCategories.includes('Transportasi'));
      assert.ok(res.availableCategories.includes('Tagihan & Utilitas'));

      // Grouped by date (4 distinct dates in 2026-08: 18, 12, 05, 01)
      assert.equal(res.groupedByDate.length, 4);
      const aug05Group = res.groupedByDate.find((g) => g.date === '2026-08-05');
      assert.ok(aug05Group);
      assert.equal(aug05Group.count, 2);
      assert.equal(aug05Group.dailyExpense, 295000);
    });

    it('supports year + month numeric normalization (e.g. year=2026, month=8)', () => {
      const res = getMonthlyTransactionsListQuery(db, testUserId, { year: '2026', month: '8' });
      assert.equal(res.month, '2026-08');
      assert.equal(res.total, 5);
    });

    it('supports type, status, category, and amountFilter', () => {
      const confirmedExpense = getMonthlyTransactionsListQuery(db, testUserId, {
        month: targetMonth,
        type: 'expense',
        status: 'confirmed',
      });
      assert.equal(confirmedExpense.total, 3);

      const under100k = getMonthlyTransactionsListQuery(db, testUserId, {
        month: targetMonth,
        amountFilter: 'under_100k',
      });
      assert.equal(under100k.total, 2); // 45,000 and 80,000

      const midRange = getMonthlyTransactionsListQuery(db, testUserId, {
        month: targetMonth,
        amountFilter: '100k_500k',
      });
      assert.equal(midRange.total, 1);
      assert.equal(midRange.transactions[0].amount, 250000);

      const above500k = getMonthlyTransactionsListQuery(db, testUserId, {
        month: targetMonth,
        amountFilter: 'above_500k',
        type: 'expense',
      });
      assert.equal(above500k.total, 1);
      assert.equal(above500k.transactions[0].amount, 1200000);

      const byCategory = getMonthlyTransactionsListQuery(db, testUserId, {
        month: targetMonth,
        category: 'Makan & Minuman',
      });
      assert.equal(byCategory.total, 2);
    });

    it('supports search query and sorting options (newest, oldest, highest, lowest)', () => {
      const searchRes = getMonthlyTransactionsListQuery(db, testUserId, {
        month: targetMonth,
        search: 'padang',
      });
      assert.equal(searchRes.total, 1);
      assert.equal(searchRes.transactions[0].note, 'Nasi Padang Siang');

      const highestSort = getMonthlyTransactionsListQuery(db, testUserId, {
        month: targetMonth,
        type: 'expense',
        sortBy: 'highest',
      });
      assert.equal(highestSort.transactions[0].amount, 1200000);
      assert.equal(highestSort.transactions[highestSort.transactions.length - 1].amount, 45000);

      const oldestSort = getMonthlyTransactionsListQuery(db, testUserId, {
        month: targetMonth,
        sortBy: 'oldest',
      });
      assert.equal(oldestSort.transactions[0].date, '2026-08-01');
    });
  });

  describe('2. HTTP Endpoints: GET /api/rekap/transactions & GET /api/transactions?month=...', () => {
    it('GET /api/rekap/transactions?month=2026-08 returns filtered monthly transactions', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/transactions?month=${targetMonth}`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.month, '2026-08');
      assert.equal(body.monthLabel, 'Agustus 2026');
      assert.equal(body.total, 5);
      assert.equal(body.transactions.length, 5);
      assert.ok(Array.isArray(body.groupedByDate));
      assert.ok(Array.isArray(body.availableCategories));
    });

    it('GET /api/transactions?month=2026-08&type=expense&status=confirmed filters properly', async () => {
      const res = await fetch(
        `${baseUrl}/api/transactions?month=${targetMonth}&type=expense&status=confirmed&sortBy=highest`
      );
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.month, '2026-08');
      assert.equal(body.total, 3);
      assert.equal(body.transactions[0].amount, 1200000);
      assert.equal(body.transactions[1].amount, 250000);
      assert.equal(body.transactions[2].amount, 45000);
    });

    it('GET /api/transactions/monthly?month=2026-08&search=wifi&amountFilter=above_500k works', async () => {
      const res = await fetch(
        `${baseUrl}/api/transactions/monthly?month=${targetMonth}&search=wifi&amountFilter=above_500k`
      );
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.total, 1);
      assert.equal(body.transactions[0].note, 'Bayar Kos & WiFi');
    });

    it('supports pagination via limit and offset', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/transactions?month=${targetMonth}&limit=2&offset=1`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.total, 5);
      assert.equal(body.count, 2);
      assert.equal(body.transactions.length, 2);
    });
  });
});
