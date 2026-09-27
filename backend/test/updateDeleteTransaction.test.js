import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Update & Delete Chat Transaction Integration Tests', () => {
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

  it('updates a transaction and keeps linked chat_log in sync', async () => {
    // 1. Create a transaction via chat parsing + confirmation
    const parseRes = await fetch(`${baseUrl}/api/chat/parse`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Beli buku tulis 15rb' }),
    });
    const parseData = await parseRes.json();
    const txId = parseData.transaction.id;
    const chatLogId = parseData.chatLogId;

    await fetch(`${baseUrl}/api/transactions/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transactionId: txId, chatLogId }),
    });

    // 2. Update transaction via PUT /api/transactions/:id
    const updateRes = await fetch(`${baseUrl}/api/transactions/${txId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount: 25000,
        note: 'Beli buku tulis + pulpen gel',
        category: 'Belanja',
      }),
    });

    assert.equal(updateRes.status, 200);
    const updateData = await updateRes.json();
    assert.equal(updateData.success, true);
    assert.equal(updateData.transaction.amount, 25000);
    assert.equal(updateData.transaction.note, 'Beli buku tulis + pulpen gel');
    assert.equal(updateData.transaction.category, 'Belanja');

    // 3. Verify SQLite transactions table
    const dbTx = db.prepare('SELECT * FROM transactions WHERE id = ?').get(txId);
    assert.equal(dbTx.amount, 25000);
    assert.equal(dbTx.note, 'Beli buku tulis + pulpen gel');

    // 4. Verify linked chat_log parsed_json is in sync
    const dbLog = db.prepare('SELECT parsed_json FROM chat_logs WHERE id = ?').get(chatLogId);
    const parsed = JSON.parse(dbLog.parsed_json);
    assert.equal(parsed.amount, 25000);
    assert.equal(parsed.note, 'Beli buku tulis + pulpen gel');
    assert.equal(parsed.category, 'Belanja');
  });

  it('partially updates transaction via PATCH /api/transactions/:id', async () => {
    // Create transaction directly
    const user = db.prepare('SELECT id FROM users LIMIT 1').get();
    const insertRes = db.prepare(`
      INSERT INTO transactions (user_id, type, amount, note, is_confirmed)
      VALUES (?, 'expense', 40000, 'Laundry mingguan', 1)
    `).run(user.id);
    const txId = insertRes.lastInsertRowid;

    const patchRes = await fetch(`${baseUrl}/api/transactions/${txId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ amount: 45000 }),
    });

    assert.equal(patchRes.status, 200);
    const patchData = await patchRes.json();
    assert.equal(patchData.transaction.amount, 45000);
    assert.equal(patchData.transaction.note, 'Laundry mingguan');
  });

  it('rejects invalid updates with HTTP 400 or 404', async () => {
    // 404 non-existent
    const res404 = await fetch(`${baseUrl}/api/transactions/88888`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ amount: 10000 }),
    });
    assert.equal(res404.status, 404);

    // 400 negative amount
    const resAmount = await fetch(`${baseUrl}/api/transactions/1`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ amount: -100 }),
    });
    assert.equal(resAmount.status, 400);

    // 400 empty note
    const resNote = await fetch(`${baseUrl}/api/transactions/1`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ note: '   ' }),
    });
    assert.equal(resNote.status, 400);
  });

  it('deletes transaction via DELETE /api/transactions/:id and marks chat_log as deleted', async () => {
    // 1. Create chat message and transaction
    const parseRes = await fetch(`${baseUrl}/api/chat/parse`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Bayar kas kelas 10rb' }),
    });
    const parseData = await parseRes.json();
    const txId = parseData.transaction.id;
    const chatLogId = parseData.chatLogId;

    // 2. Delete transaction
    const delRes = await fetch(`${baseUrl}/api/transactions/${txId}`, {
      method: 'DELETE',
    });
    assert.equal(delRes.status, 200);
    const delData = await delRes.json();
    assert.equal(delData.success, true);
    assert.equal(delData.id, txId);

    // 3. Verify transaction is gone
    const checkTx = db.prepare('SELECT * FROM transactions WHERE id = ?').get(txId);
    assert.equal(checkTx, undefined);

    // 4. Verify chat_logs status changed to 'deleted'
    const checkLog = db.prepare('SELECT status FROM chat_logs WHERE id = ?').get(chatLogId);
    assert.equal(checkLog.status, 'deleted');
  });

  it('deletes chat log via DELETE /api/chat/history/:id and restores via restore endpoint', async () => {
    // 1. Create chat message and confirm
    const parseRes = await fetch(`${baseUrl}/api/chat/parse`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Beli obat flu 35rb' }),
    });
    const parseData = await parseRes.json();
    const chatLogId = parseData.chatLogId;

    // 2. Delete via chat history endpoint
    const delRes = await fetch(`${baseUrl}/api/chat/history/${chatLogId}`, {
      method: 'DELETE',
    });
    assert.equal(delRes.status, 200);

    const logAfterDel = db.prepare('SELECT status FROM chat_logs WHERE id = ?').get(chatLogId);
    assert.equal(logAfterDel.status, 'deleted');

    // 3. Restore via restore endpoint
    const restoreRes = await fetch(`${baseUrl}/api/chat/history/${chatLogId}/restore`, {
      method: 'POST',
    });
    assert.equal(restoreRes.status, 200);
    const restoreData = await restoreRes.json();
    assert.equal(restoreData.success, true);

    const logAfterRestore = db.prepare('SELECT status FROM chat_logs WHERE id = ?').get(chatLogId);
    assert.equal(logAfterRestore.status, 'confirmed');
  });
});
