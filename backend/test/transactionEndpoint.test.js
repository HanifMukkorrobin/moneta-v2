import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Transaction Confirmation Endpoint Integration Tests', () => {
  let server;
  let baseUrl;
  let db;

  before(async () => {
    db = getDatabase();
    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('confirms an existing pending transaction and updates chat_log status to confirmed', async () => {
    // 1. Create a pending transaction and chat_log via chat endpoint
    const parseRes = await fetch(`${baseUrl}/api/chat/parse`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Beli bensin pertalite 30rb' }),
    });
    const parseData = await parseRes.json();
    assert.equal(parseData.success, true);
    assert.equal(parseData.transaction.isConfirmed, false);
    const txId = parseData.transaction.id;
    const chatLogId = parseData.chatLogId;

    // 2. Confirm the transaction via POST /api/transactions/confirm
    const confirmRes = await fetch(`${baseUrl}/api/transactions/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        transactionId: txId,
        chatLogId: chatLogId,
      }),
    });

    assert.equal(confirmRes.status, 200);
    const confirmData = await confirmRes.json();
    assert.equal(confirmData.success, true);
    assert.equal(confirmData.transaction.id, txId);
    assert.equal(confirmData.transaction.isConfirmed, true);
    assert.equal(confirmData.transaction.amount, 30000);
    assert.equal(confirmData.transaction.category, 'Transportasi');

    // 3. Verify in SQLite database
    const dbTx = db.prepare('SELECT * FROM transactions WHERE id = ?').get(txId);
    assert.equal(dbTx.is_confirmed, 1);

    const dbChat = db.prepare('SELECT * FROM chat_logs WHERE id = ?').get(chatLogId);
    assert.equal(dbChat.status, 'confirmed');
  });

  it('allows editing fields (amount, category, note) while confirming', async () => {
    // 1. Create pending transaction
    const parseRes = await fetch(`${baseUrl}/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Ngopi sore 20rb' }),
    });
    const parseData = await parseRes.json();
    const txId = parseData.transaction.id;
    const chatLogId = parseData.chatLogId;

    // 2. Confirm with modified amount and custom note
    const confirmRes = await fetch(`${baseUrl}/transactions/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        transactionId: txId,
        chatLogId: chatLogId,
        amount: 28000,
        note: 'Ngopi sore + roti bakar',
      }),
    });

    assert.equal(confirmRes.status, 200);
    const confirmData = await confirmRes.json();
    assert.equal(confirmData.success, true);
    assert.equal(confirmData.transaction.amount, 28000);
    assert.equal(confirmData.transaction.note, 'Ngopi sore + roti bakar');
    assert.equal(confirmData.transaction.isConfirmed, true);

    const dbTx = db.prepare('SELECT * FROM transactions WHERE id = ?').get(txId);
    assert.equal(dbTx.amount, 28000);
    assert.equal(dbTx.note, 'Ngopi sore + roti bakar');
    assert.equal(dbTx.is_confirmed, 1);
  });

  it('confirms via route param POST /api/transactions/:id/confirm', async () => {
    // Insert a pending transaction directly
    const user = db.prepare('SELECT id FROM users LIMIT 1').get();
    const res = db.prepare(`
      INSERT INTO transactions (user_id, type, amount, note, is_confirmed)
      VALUES (?, 'expense', 15000, 'Parkir mall', 0)
    `).run(user.id);
    const txId = res.lastInsertRowid;

    const confirmRes = await fetch(`${baseUrl}/api/transactions/${txId}/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });

    assert.equal(confirmRes.status, 200);
    const confirmData = await confirmRes.json();
    assert.equal(confirmData.success, true);
    assert.equal(confirmData.transaction.isConfirmed, true);

    const check = db.prepare('SELECT is_confirmed FROM transactions WHERE id = ?').get(txId);
    assert.equal(check.is_confirmed, 1);
  });

  it('confirms via chat alias route POST /api/chat/confirm', async () => {
    const user = db.prepare('SELECT id FROM users LIMIT 1').get();
    const res = db.prepare(`
      INSERT INTO transactions (user_id, type, amount, note, is_confirmed)
      VALUES (?, 'income', 100000, 'Bonus cashback', 0)
    `).run(user.id);
    const txId = res.lastInsertRowid;

    const confirmRes = await fetch(`${baseUrl}/api/chat/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transactionId: txId }),
    });

    assert.equal(confirmRes.status, 200);
    const confirmData = await confirmRes.json();
    assert.equal(confirmData.success, true);
    assert.equal(confirmData.transaction.isConfirmed, true);
  });

  it('creates and confirms a manual transaction directly via POST /api/transactions', async () => {
    const manualRes = await fetch(`${baseUrl}/api/transactions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount: 75000,
        type: 'expense',
        category: 'Tagihan & Utilitas',
        note: 'Beli token listrik PLN',
      }),
    });

    assert.equal(manualRes.status, 201);
    const manualData = await manualRes.json();
    assert.equal(manualData.success, true);
    assert.equal(manualData.transaction.amount, 75000);
    assert.equal(manualData.transaction.type, 'expense');
    assert.equal(manualData.transaction.category, 'Tagihan & Utilitas');
    assert.equal(manualData.transaction.isConfirmed, true);
  });

  it('returns 404 when transactionId does not exist', async () => {
    const res = await fetch(`${baseUrl}/api/transactions/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transactionId: 999999 }),
    });

    assert.equal(res.status, 404);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'Transaksi tidak ditemukan.');
  });

  it('returns 400 when amount is invalid (<= 0 or not a number)', async () => {
    const res = await fetch(`${baseUrl}/api/transactions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount: -5000,
        type: 'expense',
        note: 'Minus test',
      }),
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.match(body.error, /angka lebih besar dari 0/i);
  });

  it('returns 400 when type is invalid', async () => {
    const res = await fetch(`${baseUrl}/api/transactions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount: 50000,
        type: 'invalid_type',
        note: 'Invalid type test',
      }),
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.match(body.error, /income atau expense/i);
  });

  it('returns 400 when note is empty for new manual transaction', async () => {
    const res = await fetch(`${baseUrl}/api/transactions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount: 50000,
        type: 'expense',
        note: '   ',
      }),
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'Catatan transaksi wajib diisi.');
  });

  it('queries confirmed transactions via GET /api/transactions', async () => {
    const res = await fetch(`${baseUrl}/api/transactions?isConfirmed=true`);
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.success, true);
    assert.ok(Array.isArray(data.transactions));
    assert.ok(data.transactions.length >= 3);
    assert.ok(data.transactions.every((tx) => tx.isConfirmed === true));
  });
});
