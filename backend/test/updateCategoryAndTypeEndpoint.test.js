import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Endpoint Ubah Kategori dan Jenis Transaksi Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;

  before(async () => {
    db = getDatabase();
    db.prepare('DELETE FROM categories WHERE is_default = 0').run();
    const user = db.prepare('SELECT id FROM users LIMIT 1').get();
    testUserId = user ? user.id : 1;

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    if (db) {
      db.prepare('DELETE FROM categories WHERE is_default = 0').run();
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. Update Transaction Category (PUT & PATCH /api/transactions/:id/category)', () => {
    it('updates transaction category and resets isGuessed to false', async () => {
      // 1. Create a pending unconfirmed transaction with guessed category
      const parseRes = await fetch(`${baseUrl}/api/chat/parse`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: 'Beli makan siang 25rb', userId: testUserId }),
      });
      const parseData = await parseRes.json();
      const txId = parseData.transaction.id;

      assert.equal(parseData.transaction.isConfirmed, false);

      // 2. Change category to 'Hiburan'
      const res = await fetch(`${baseUrl}/api/transactions/${txId}/category`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category: 'Hiburan',
          userId: testUserId,
        }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.transaction.category, 'Hiburan');
      assert.equal(data.transaction.isGuessedCategory, false);
      assert.equal(data.transaction.confidenceScore, 1.0);
      assert.equal(data.previous.category, 'Makan & Minuman');

      // 3. Verify database row
      const row = db.prepare('SELECT * FROM transactions WHERE id = ?').get(txId);
      assert.equal(row.category_name, 'Hiburan');
      assert.equal(row.is_guessed, 0);
      assert.equal(row.confidence_score, 1.0);

      // 4. Verify linked chat_log has userCorrection recorded
      const chatLog = db.prepare('SELECT parsed_json FROM chat_logs WHERE transaction_id = ?').get(txId);
      assert.ok(chatLog);
      const parsed = JSON.parse(chatLog.parsed_json);
      assert.equal(parsed.category, 'Hiburan');
      assert.ok(parsed.userCorrection);
      assert.equal(parsed.userCorrection.newCategory, 'Hiburan');
    });

    it('updates transaction category via PATCH method', async () => {
      // Create transaction
      const txRes = db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed, is_guessed)
        VALUES (?, NULL, 'Lainnya', 'expense', 45000, 'Bensin motor 45rb', CURRENT_TIMESTAMP, 1, 1)
      `).run(testUserId);
      const txId = txRes.lastInsertRowid;

      const res = await fetch(`${baseUrl}/api/transactions/${txId}/category`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category: 'Transportasi',
        }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.transaction.category, 'Transportasi');
      assert.equal(data.transaction.isGuessedCategory, false);

      const updated = db.prepare('SELECT category_name, is_guessed FROM transactions WHERE id = ?').get(txId);
      assert.equal(updated.category_name, 'Transportasi');
      assert.equal(updated.is_guessed, 0);
    });
  });

  describe('2. Switch Transaction Type (PUT & PATCH /api/transactions/:id/type)', () => {
    it('switches transaction type from expense to income and updates category', async () => {
      // Create expense transaction
      const txRes = db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed, is_guessed)
        VALUES (?, NULL, 'Lainnya', 'expense', 1500000, 'Uang masuk proyek 1.500.000', CURRENT_TIMESTAMP, 1, 1)
      `).run(testUserId);
      const txId = txRes.lastInsertRowid;

      const res = await fetch(`${baseUrl}/api/transactions/${txId}/type`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: 'income',
          category: 'Freelance',
        }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.transaction.type, 'income');
      assert.equal(data.transaction.category, 'Freelance');
      assert.equal(data.previous.type, 'expense');

      // Verify DB row
      const row = db.prepare('SELECT type, category_name FROM transactions WHERE id = ?').get(txId);
      assert.equal(row.type, 'income');
      assert.equal(row.category_name, 'Freelance');
    });

    it('rejects invalid transaction type with HTTP 400', async () => {
      const tx = db.prepare('SELECT id FROM transactions LIMIT 1').get();
      assert.ok(tx);

      const res = await fetch(`${baseUrl}/api/transactions/${tx.id}/type`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: 'invalid_type',
        }),
      });

      assert.equal(res.status, 400);
      const data = await res.json();
      assert.equal(data.success, false);
      assert.ok(data.error.includes('income atau expense'));
    });
  });

  describe('3. On-the-Fly Custom Category Creation during Category Update', () => {
    it('creates custom category automatically when isCustom=true and assigns it', async () => {
      const txRes = db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed, is_guessed)
        VALUES (?, NULL, 'Lainnya', 'expense', 100000, 'Donasi panti asuhan 100rb', CURRENT_TIMESTAMP, 1, 1)
      `).run(testUserId);
      const txId = txRes.lastInsertRowid;

      const res = await fetch(`${baseUrl}/api/transactions/${txId}/category`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category: 'Donasi & Amal',
          isCustom: true,
          icon: 'volunteer_activism_rounded',
          color: 'teal',
          userId: testUserId,
        }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.transaction.category, 'Donasi & Amal');
      assert.equal(data.transaction.isCustomCategory, true);

      // Verify custom category exists in categories table
      const catRow = db.prepare("SELECT * FROM categories WHERE name = 'Donasi & Amal' AND user_id = ?").get(testUserId);
      assert.ok(catRow);
      assert.equal(catRow.is_default, 0);
      assert.equal(catRow.icon, 'volunteer_activism_rounded');

      // Verify transaction row references the new category
      const txRow = db.prepare('SELECT category_id, category_name FROM transactions WHERE id = ?').get(txId);
      assert.equal(txRow.category_id, catRow.id);
      assert.equal(txRow.category_name, 'Donasi & Amal');
    });
  });

  describe('4. Integration with Rekap and Budgeting', () => {
    it('immediately reflects category change in monthly rekap and category breakdown', async () => {
      const now = new Date();
      const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

      // Insert confirmed transaction in 'Belanja'
      const txRes = db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed, is_guessed)
        VALUES (?, (SELECT id FROM categories WHERE name = 'Belanja' AND type = 'expense' LIMIT 1), 'Belanja', 'expense', 85000, 'Beli barang 85rb', CURRENT_TIMESTAMP, 1, 1)
      `).run(testUserId);
      const txId = txRes.lastInsertRowid;

      // Check initial rekap spent on Belanja
      const rekapRes1 = await fetch(`${baseUrl}/api/rekap?month=${currentMonth}`);
      const rekapData1 = await rekapRes1.json();
      const belanjaBreakdown1 = rekapData1.categoryBreakdown.find((c) => c.categoryName === 'Belanja');
      const initialBelanjaTotal = belanjaBreakdown1 ? belanjaBreakdown1.total : 0;

      // Change category to 'Kesehatan'
      const updateRes = await fetch(`${baseUrl}/api/transactions/${txId}/category`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category: 'Kesehatan',
        }),
      });
      assert.equal(updateRes.status, 200);

      // Check updated rekap
      const rekapRes2 = await fetch(`${baseUrl}/api/rekap?month=${currentMonth}`);
      const rekapData2 = await rekapRes2.json();

      const belanjaBreakdown2 = rekapData2.categoryBreakdown.find((c) => c.categoryName === 'Belanja');
      const updatedBelanjaTotal = belanjaBreakdown2 ? belanjaBreakdown2.total : 0;
      assert.equal(updatedBelanjaTotal, initialBelanjaTotal - 85000);

      const kesehatanBreakdown2 = rekapData2.categoryBreakdown.find((c) => c.categoryName === 'Kesehatan');
      assert.ok(kesehatanBreakdown2);
      assert.ok(kesehatanBreakdown2.total >= 85000);
    });
  });

  describe('5. Route Aliases and Error Handling', () => {
    it('supports route alias /api/categories/transactions/:id', async () => {
      const tx = db.prepare('SELECT id FROM transactions LIMIT 1').get();
      assert.ok(tx);

      const res = await fetch(`${baseUrl}/api/categories/transactions/${tx.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category: 'Hiburan',
        }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
    });

    it('returns 404 when transaction ID does not exist', async () => {
      const res = await fetch(`${baseUrl}/api/transactions/9999999/category`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category: 'Makan & Minuman',
        }),
      });

      assert.equal(res.status, 404);
      const data = await res.json();
      assert.equal(data.success, false);
      assert.ok(data.error.includes('tidak ditemukan'));
    });
  });
});
