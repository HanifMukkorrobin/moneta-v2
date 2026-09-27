import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { getOrCreateDefaultUser } from '../src/controllers/chatController.js';
import {
  getCategoryBreakdownQuery,
  getExpensesByCategoryQuery,
} from '../src/services/rekapQueryService.js';

describe('Endpoint Pengeluaran Per Kategori Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  const targetMonth = '2026-07';

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

    // Clean up any existing test records in 2026-07
    db.prepare("DELETE FROM transactions WHERE occurred_at LIKE '2026-07%'").run();

    // Categories
    const foodCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get();
    const transportCat = db.prepare("SELECT id FROM categories WHERE name = 'Transportasi' AND type = 'expense'").get();
    const shoppingCat = db.prepare("SELECT id FROM categories WHERE name = 'Belanja' AND type = 'expense'").get();
    const salaryCat = db.prepare("SELECT id FROM categories WHERE name = 'Gaji' AND type = 'income'").get();

    // Ensure a custom expense category exists
    let customCat = db.prepare("SELECT id FROM categories WHERE name = 'Hobi & Game' AND type = 'expense'").get();
    if (!customCat) {
      const ins = db.prepare(`
        INSERT INTO categories (user_id, name, type, is_default, icon, color)
        VALUES (?, 'Hobi & Game', 'expense', 0, 'sports_esports_rounded', 'purple')
      `).run(testUserId);
      customCat = { id: ins.lastInsertRowid };
    }

    // Seed Confirmed Expenses in 2026-07:
    // 1. Makan & Minuman: 1,200,000 + 800,000 = 2,000,000 (2 tx) -> 50.0%
    // 2. Transportasi: 400,000 + 400,000 + 200,000 = 1,000,000 (3 tx) -> 25.0%
    // 3. Belanja: 600,000 (1 tx) -> 15.0%
    // 4. Hobi & Game (custom): 400,000 (1 tx) -> 10.0%
    // Total Confirmed Expense = 4,000,000 (7 tx)

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Makan & Minuman', 'expense', 1200000, 'Katering Bulanan', '2026-07-03 10:00:00', 1)
    `).run(testUserId, foodCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Makan & Minuman', 'expense', 800000, 'Makan Malam Keluarga', '2026-07-12 19:30:00', 1)
    `).run(testUserId, foodCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Transportasi', 'expense', 400000, 'Isi Bensin Full', '2026-07-05 08:00:00', 1)
    `).run(testUserId, transportCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Transportasi', 'expense', 400000, 'Tiket Kereta', '2026-07-14 09:00:00', 1)
    `).run(testUserId, transportCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Transportasi', 'expense', 200000, 'Ojek Online', '2026-07-18 17:00:00', 1)
    `).run(testUserId, transportCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Belanja', 'expense', 600000, 'Beli Sepatu Kerja', '2026-07-20 15:00:00', 1)
    `).run(testUserId, shoppingCat?.id || null);

    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Hobi & Game', 'expense', 400000, 'Topup Game & Buku', '2026-07-22 21:00:00', 1)
    `).run(testUserId, customCat.id);

    // Seed Confirmed Income in 2026-07: 8,000,000
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Gaji', 'income', 8000000, 'Gaji Juli 2026', '2026-07-01 09:00:00', 1)
    `).run(testUserId, salaryCat?.id || null);

    // Seed Pending Expense (should be excluded from confirmed breakdown)
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Makan & Minuman', 'expense', 500000, 'Pending Traktiran', '2026-07-25 12:00:00', 0)
    `).run(testUserId, foodCat?.id || null);
  });

  after(async () => {
    db.prepare("DELETE FROM transactions WHERE occurred_at LIKE '2026-07%'").run();
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. Service Layer: getExpensesByCategoryQuery & getCategoryBreakdownQuery', () => {
    it('calculates expense breakdown per category with accurate totals, percentages, and ranks', () => {
      const result = getExpensesByCategoryQuery(db, testUserId, { month: targetMonth });

      assert.equal(result.month, '2026-07');
      assert.equal(result.monthLabel, 'Juli 2026');
      assert.equal(result.type, 'expense');
      assert.equal(result.totalExpense, 4000000);
      assert.equal(result.totalAmount, 4000000);
      assert.equal(result.categoryCount, 4);
      assert.equal(result.totalTransactions, 7);

      // Top category
      assert.ok(result.topCategory);
      assert.equal(result.topCategory.categoryName, 'Makan & Minuman');
      assert.equal(result.topCategory.total, 2000000);
      assert.equal(result.topCategory.percentage, 50.0);

      // Categories list ordered by highest nominal
      const cats = result.categories;
      assert.equal(cats.length, 4);

      assert.equal(cats[0].rank, 1);
      assert.equal(cats[0].category, 'Makan & Minuman');
      assert.equal(cats[0].total, 2000000);
      assert.equal(cats[0].percentage, 50.0);
      assert.equal(cats[0].transactionCount, 2);
      assert.equal(cats[0].averagePerTransaction, 1000000);

      assert.equal(cats[1].rank, 2);
      assert.equal(cats[1].category, 'Transportasi');
      assert.equal(cats[1].total, 1000000);
      assert.equal(cats[1].percentage, 25.0);
      assert.equal(cats[1].transactionCount, 3);

      assert.equal(cats[2].rank, 3);
      assert.equal(cats[2].category, 'Belanja');
      assert.equal(cats[2].total, 600000);
      assert.equal(cats[2].percentage, 15.0);
      assert.equal(cats[2].transactionCount, 1);

      assert.equal(cats[3].rank, 4);
      assert.equal(cats[3].category, 'Hobi & Game');
      assert.equal(cats[3].total, 400000);
      assert.equal(cats[3].percentage, 10.0);
      assert.equal(cats[3].isCustom, true);
    });

    it('supports sorting by lowest, most_trx, and name', () => {
      const byMostTrx = getCategoryBreakdownQuery(db, testUserId, targetMonth, 'expense', {
        sortBy: 'most_trx',
      });
      assert.equal(byMostTrx[0].categoryName, 'Transportasi');
      assert.equal(byMostTrx[0].transactionCount, 3);
      assert.equal(byMostTrx[0].rank, 1);

      const byLowest = getCategoryBreakdownQuery(db, testUserId, targetMonth, 'expense', {
        sortBy: 'lowest',
      });
      assert.equal(byLowest[0].categoryName, 'Hobi & Game');
      assert.equal(byLowest[0].total, 400000);

      const byName = getCategoryBreakdownQuery(db, testUserId, targetMonth, 'expense', {
        sortBy: 'name',
      });
      assert.equal(byName[0].categoryName, 'Belanja');
    });

    it('supports search query by category name', () => {
      const searched = getExpensesByCategoryQuery(db, testUserId, {
        month: targetMonth,
        search: 'transport',
      });
      assert.equal(searched.categoryCount, 1);
      assert.equal(searched.categories[0].categoryName, 'Transportasi');
      assert.equal(searched.categories[0].percentage, 25.0);
    });
  });

  describe('2. HTTP Endpoints: GET /api/rekap/expenses-by-category & aliases', () => {
    it('GET /api/rekap/expenses-by-category returns expense breakdown by default', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/expenses-by-category?month=${targetMonth}`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.month, '2026-07');
      assert.equal(body.type, 'expense');
      assert.equal(body.totalExpense, 4000000);
      assert.equal(body.categoryCount, 4);
      assert.equal(body.topCategory.categoryName, 'Makan & Minuman');
      assert.equal(body.categories.length, 4);
      assert.equal(body.expenseBreakdown.length, 4);
    });

    it('GET /api/transactions/expenses-by-category and /api/rekap/breakdown?type=expense return matching data', async () => {
      const res1 = await fetch(`${baseUrl}/api/transactions/expenses-by-category?month=${targetMonth}`);
      assert.equal(res1.status, 200);
      const body1 = await res1.json();

      const res2 = await fetch(`${baseUrl}/api/rekap/breakdown?month=${targetMonth}&type=expense`);
      assert.equal(res2.status, 200);
      const body2 = await res2.json();

      assert.equal(body1.totalExpense, body2.totalExpense);
      assert.equal(body1.categories.length, body2.categoryBreakdown.length);
      assert.equal(body1.categories[0].categoryName, body2.categoryBreakdown[0].categoryName);
    });

    it('supports sorting, search, and custom date range via query params', async () => {
      const res = await fetch(
        `${baseUrl}/api/rekap/expenses-by-category?startDate=2026-07-01&endDate=2026-07-15&sortBy=most_trx`
      );
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      // Between July 1 and July 15:
      // Makan & Minuman: 1,200,000 + 800,000 = 2,000,000 (2 tx)
      // Transportasi: 400,000 + 400,000 = 800,000 (2 tx)
      assert.equal(body.totalExpense, 2800000);
      assert.equal(body.categoryCount, 2);
    });

    it('returns empty state cleanly for month with no expenses', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/expenses-by-category?month=2024-02`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.totalExpense, 0);
      assert.equal(body.categoryCount, 0);
      assert.equal(body.topCategory, null);
      assert.deepEqual(body.categories, []);
    });
  });
});
