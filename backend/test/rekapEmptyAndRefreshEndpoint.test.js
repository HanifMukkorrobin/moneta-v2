import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { getOrCreateDefaultUser } from '../src/controllers/chatController.js';
import {
  buildRekapEmptyStates,
  getAvailableRekapMonthsQuery,
  getFullMonthlyRekapAggregation,
} from '../src/services/rekapQueryService.js';

describe('Respon Kosong dan Penyegaran Data Rekap Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  const emptyMonth = '2023-08';
  const refreshMonth = '2026-01';

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

    // Ensure emptyMonth (2023-08) and previous month (2023-07) have zero records
    db.prepare("DELETE FROM transactions WHERE occurred_at LIKE '2023-08%' OR occurred_at LIKE '2023-07%' OR occurred_at LIKE '2026-01%'").run();
  });

  after(async () => {
    db.prepare("DELETE FROM transactions WHERE occurred_at LIKE '2026-01%'").run();
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. Empty State Responses (Respon Kosong)', () => {
    it('buildRekapEmptyStates returns structured Indonesian empty messages for all Rekap sections', () => {
      const states = buildRekapEmptyStates('Agustus 2023', {
        totalTransactionsCount: 0,
        confirmedTransactionsCount: 0,
        expenseTransactionsCount: 0,
        incomeTransactionsCount: 0,
        hasPreviousMonthData: false,
      });

      assert.equal(states.isEmpty, true);
      assert.equal(states.hasData, false);
      assert.equal(states.banner.isEmpty, true);
      assert.equal(states.banner.title, 'Belum Ada Catatan Keuangan');
      assert.match(states.banner.message, /Belum ada transaksi tercatat di Agustus 2023/);

      assert.equal(states.summary.isEmpty, true);
      assert.equal(states.summary.badge, 'Belum Ada Data');

      assert.equal(states.comparison.isEmpty, true);
      assert.equal(states.comparison.message, 'Belum ada data transaksi di bulan sebelumnya untuk dibandingkan.');

      assert.equal(states.expenseCategories.isEmpty, true);
      assert.equal(states.expenseCategories.message, 'Belum ada transaksi pengeluaran untuk ditampilkan.');

      assert.equal(states.incomeCategories.isEmpty, true);
      assert.equal(states.incomeCategories.message, 'Belum ada transaksi pemasukan untuk ditampilkan.');

      assert.equal(states.transactions.isEmpty, true);
      assert.equal(states.transactions.message, 'Belum ada transaksi di Agustus 2023.');
    });

    it('GET /api/rekap on an empty month returns clean zero values and emptyStates', async () => {
      const res = await fetch(`${baseUrl}/api/rekap?month=${emptyMonth}`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.month, '2023-08');
      assert.equal(body.monthLabel, 'Agustus 2023');
      assert.equal(body.isEmpty, true);
      assert.equal(body.hasData, false);
      assert.equal(body.summary.totalIncome, 0);
      assert.equal(body.summary.totalExpense, 0);
      assert.equal(body.summary.isEmpty, true);
      assert.equal(body.summary.emptyBadge, 'Belum Ada Data');
      assert.equal(body.comparison.isEmpty, true);
      assert.deepEqual(body.categoryBreakdown, []);
      assert.deepEqual(body.transactions, []);
      assert.ok(body.emptyStates);
      assert.equal(body.emptyStates.banner.title, 'Belum Ada Catatan Keuangan');
    });

    it('GET /api/rekap/expenses-by-category and /api/rekap/transactions return emptyState metadata when empty or search mismatches', async () => {
      const resCat = await fetch(`${baseUrl}/api/rekap/expenses-by-category?month=${emptyMonth}`);
      assert.equal(resCat.status, 200);
      const bodyCat = await resCat.json();
      assert.equal(bodyCat.isEmpty, true);
      assert.equal(bodyCat.emptyState.message, 'Belum ada transaksi pengeluaran untuk ditampilkan.');

      const resTx = await fetch(`${baseUrl}/api/rekap/transactions?month=${emptyMonth}`);
      assert.equal(resTx.status, 200);
      const bodyTx = await resTx.json();
      assert.equal(bodyTx.isEmpty, true);
      assert.equal(bodyTx.emptyState.message, 'Belum ada transaksi di Agustus 2023.');
    });
  });

  describe('2. Rekap Data Refresh & Available Months (Penyegaran Data Rekap)', () => {
    it('dynamically updates rekap from empty state to populated state upon new transaction and POST /api/rekap/refresh', async () => {
      // 1. Before adding transaction: 2026-01 is empty
      const initialRes = await fetch(`${baseUrl}/api/rekap?month=${refreshMonth}`);
      const initialBody = await initialRes.json();
      assert.equal(initialBody.isEmpty, true);
      assert.equal(initialBody.summary.totalExpense, 0);

      // 2. Insert a new confirmed transaction in 2026-01
      const foodCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get();
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Makan & Minuman', 'expense', 150000, 'Sarapan Keluarga Tahun Baru', '2026-01-02 08:30:00', 1)
      `).run(testUserId, foodCat?.id || null);

      // 3. Call POST /api/rekap/refresh
      const refreshRes = await fetch(`${baseUrl}/api/rekap/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ month: refreshMonth }),
      });
      assert.equal(refreshRes.status, 200);
      assert.match(refreshRes.headers.get('cache-control') || '', /no-store/i);

      const refreshBody = await refreshRes.json();
      assert.equal(refreshBody.success, true);
      assert.equal(refreshBody.refreshed, true);
      assert.ok(refreshBody.refreshedAt);
      assert.equal(refreshBody.message, 'Rekap bulanan berhasil diperbarui.');
      assert.equal(refreshBody.isEmpty, false);
      assert.equal(refreshBody.hasData, true);
      assert.equal(refreshBody.summary.totalExpense, 150000);
      assert.equal(refreshBody.transactions.length, 1);
      assert.equal(refreshBody.categoryBreakdown.length, 1);
    });

    it('supports GET /api/rekap?month=2026-01&refresh=true and GET /api/rekap/months', async () => {
      const res1 = await fetch(`${baseUrl}/api/rekap?month=${refreshMonth}&refresh=true`);
      assert.equal(res1.status, 200);
      const body1 = await res1.json();
      assert.equal(body1.refreshed, true);
      assert.equal(body1.message, 'Rekap bulanan berhasil diperbarui.');

      const resMonths = await fetch(`${baseUrl}/api/rekap/months?month=2026-09`);
      assert.equal(resMonths.status, 200);
      const bodyMonths = await resMonths.json();
      assert.equal(bodyMonths.success, true);
      assert.ok(Array.isArray(bodyMonths.availableMonths));
      assert.ok(bodyMonths.availableMonths.includes('2026-09'));
      assert.ok(bodyMonths.availableMonths.includes('2026-01'));
      assert.ok(Array.isArray(bodyMonths.months));
    });
  });
});
