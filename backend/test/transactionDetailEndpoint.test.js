import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { getOrCreateDefaultUser } from '../src/controllers/chatController.js';
import { getTransactionDetailById } from '../src/controllers/transactionController.js';

describe('Endpoint Detail Satu Transaksi Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  let confirmedTxId;
  let pendingChatTxId;

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

    // Clean up test transactions in 2026-02
    db.prepare("DELETE FROM transactions WHERE occurred_at LIKE '2026-02%'").run();

    const foodCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get();
    const transportCat = db.prepare("SELECT id FROM categories WHERE name = 'Transportasi' AND type = 'expense'").get();

    // 1. Confirmed Expense Transaction (300,000 in Makan & Minuman)
    const res1 = db.prepare(`
      INSERT INTO transactions (
        user_id, category_id, category_name, type, amount, note, occurred_at,
        is_confirmed, is_guessed, confidence_score, ai_reasoning
      )
      VALUES (?, ?, 'Makan & Minuman', 'expense', 300000, 'Makan Malam Restoran Seafood', '2026-02-14 19:45:00', 1, 0, 0.96, 'Kata kunci restoran dan makan malam')
    `).run(testUserId, foodCat?.id || null);
    confirmedTxId = Number(res1.lastInsertRowid);

    // Another confirmed expense in Makan & Minuman (700,000) so category total in 2026-02 is 1,000,000
    db.prepare(`
      INSERT INTO transactions (
        user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed
      )
      VALUES (?, ?, 'Makan & Minuman', 'expense', 700000, 'Belanja Dapur Bulanan', '2026-02-05 10:00:00', 1)
    `).run(testUserId, foodCat?.id || null);

    // 2. Pending Chat Transaction with linked chat_logs record
    const res2 = db.prepare(`
      INSERT INTO transactions (
        user_id, category_id, category_name, type, amount, note, occurred_at,
        is_confirmed, is_guessed, confidence_score, ai_reasoning
      )
      VALUES (?, ?, 'Transportasi', 'expense', 45000, 'Ojek ke stasiun', '2026-02-16 08:15:00', 0, 1, 0.88, 'Kata kunci ojek dan stasiun')
    `).run(testUserId, transportCat?.id || null);
    pendingChatTxId = Number(res2.lastInsertRowid);

    db.prepare(`
      INSERT INTO chat_logs (user_id, message, parsed_json, transaction_id, status)
      VALUES (?, 'ojek ke stasiun 45rb', ?, ?, 'pending')
    `).run(
      testUserId,
      JSON.stringify({ amount: 45000, type: 'expense', category: 'Transportasi', note: 'Ojek ke stasiun' }),
      pendingChatTxId
    );
  });

  after(async () => {
    db.prepare("DELETE FROM chat_logs WHERE transaction_id IN (?, ?)").run(confirmedTxId, pendingChatTxId);
    db.prepare("DELETE FROM transactions WHERE occurred_at LIKE '2026-02%'").run();
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. Service Layer: getTransactionDetailById', () => {
    it('returns full transaction detail including formatted fields and monthlyContext', () => {
      const detail = getTransactionDetailById(db, testUserId, confirmedTxId);

      assert.ok(detail);
      assert.equal(detail.id, confirmedTxId);
      assert.equal(detail.displayId, `#${confirmedTxId}`);
      assert.equal(detail.category, 'Makan & Minuman');
      assert.equal(detail.categoryName, 'Makan & Minuman');
      assert.equal(detail.type, 'expense');
      assert.equal(detail.typeLabel, 'Pengeluaran');
      assert.equal(detail.amount, 300000);
      assert.equal(detail.formattedAmount, '- Rp 300.000');
      assert.equal(detail.note, 'Makan Malam Restoran Seafood');
      assert.equal(detail.date, '2026-02-14');
      assert.equal(detail.month, '2026-02');
      assert.equal(detail.isConfirmed, true);
      assert.equal(detail.verificationStatus, 'confirmed');
      assert.equal(detail.verificationStatusLabel, 'Terkonfirmasi');
      assert.equal(detail.confidenceScore, 0.96);
      assert.equal(detail.confidencePercentage, 96);
      assert.equal(detail.formattedConfidence, '96%');

      // Monthly context: 300,000 out of 1,000,000 category total = 30.0%
      assert.ok(detail.monthlyContext);
      assert.equal(detail.monthlyContext.month, '2026-02');
      assert.equal(detail.monthlyContext.categoryTotalInMonth, 1000000);
      assert.equal(detail.monthlyContext.categoryTransactionCountInMonth, 2);
      assert.equal(detail.monthlyContext.shareOfCategoryPct, 30.0);
    });

    it('includes linked chatLog metadata when transaction originated from chat', () => {
      const detail = getTransactionDetailById(db, testUserId, pendingChatTxId);

      assert.ok(detail);
      assert.equal(detail.id, pendingChatTxId);
      assert.equal(detail.isConfirmed, false);
      assert.equal(detail.verificationStatus, 'pending');
      assert.equal(detail.verificationStatusLabel, 'Menunggu Konfirmasi');
      assert.equal(detail.formattedConfidence, '88%');
      assert.ok(detail.chatLog);
      assert.equal(detail.chatLog.message, 'ojek ke stasiun 45rb');
      assert.equal(detail.chatLog.status, 'pending');
      assert.equal(detail.chatLog.parsed.amount, 45000);
    });
  });

  describe('2. HTTP Endpoints: GET /api/transactions/:id & GET /api/rekap/transactions/:id', () => {
    it('GET /api/transactions/:id returns single transaction detail', async () => {
      const res = await fetch(`${baseUrl}/api/transactions/${confirmedTxId}`);
      assert.equal(res.status, 200);

      const body = await res.json();
      assert.equal(body.success, true);
      assert.equal(body.transaction.id, confirmedTxId);
      assert.equal(body.transaction.category, 'Makan & Minuman');
      assert.equal(body.transaction.amount, 300000);
      assert.equal(body.transaction.formattedAmount, '- Rp 300.000');
      assert.equal(body.transaction.verificationStatusLabel, 'Terkonfirmasi');
    });

    it('GET /api/rekap/transactions/:id and /api/transactions/:id/detail return matching detail', async () => {
      const res1 = await fetch(`${baseUrl}/api/rekap/transactions/${pendingChatTxId}`);
      assert.equal(res1.status, 200);
      const body1 = await res1.json();

      const res2 = await fetch(`${baseUrl}/api/transactions/${pendingChatTxId}/detail`);
      assert.equal(res2.status, 200);
      const body2 = await res2.json();

      assert.equal(body1.transaction.id, pendingChatTxId);
      assert.equal(body2.transaction.id, pendingChatTxId);
      assert.equal(body1.transaction.chatLog.message, 'ojek ke stasiun 45rb');
    });

    it('returns 404 when transaction ID does not exist', async () => {
      const res = await fetch(`${baseUrl}/api/transactions/9999999`);
      assert.equal(res.status, 404);

      const body = await res.json();
      assert.equal(body.success, false);
      assert.equal(body.error, 'Transaksi tidak ditemukan.');
    });

    it('returns 400 when transaction ID is not a valid positive number', async () => {
      const res = await fetch(`${baseUrl}/api/rekap/transactions/invalid-id`);
      assert.equal(res.status, 400);

      const body = await res.json();
      assert.equal(body.success, false);
      assert.match(body.error, /ID transaksi tidak valid/i);
    });
  });
});
