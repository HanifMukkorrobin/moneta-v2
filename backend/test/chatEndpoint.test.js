import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Chat Parsing Endpoint Integration Tests (POST /chat & POST /api/chat/parse)', () => {
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

  it('rejects request with missing or empty message with HTTP 400', async () => {
    const res = await fetch(`${baseUrl}/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: '' }),
    });

    assert.equal(res.status, 400);
    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'Pesan chat wajib diisi.');
  });

  it('parses expense message successfully and records pending transaction and chat_log', async () => {
    const res = await fetch(`${baseUrl}/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: 'Makan siang nasi padang 25rb',
      }),
    });

    assert.equal(res.status, 200);
    const body = await res.json();

    assert.equal(body.success, true);
    assert.ok(body.chatLogId, 'Should return chatLogId');
    assert.ok(body.transaction, 'Should return transaction object');
    assert.equal(body.transaction.amount, 25000);
    assert.equal(body.transaction.type, 'expense');
    assert.equal(body.transaction.category, 'Makan & Minuman');
    assert.equal(body.transaction.isConfirmed, false);

    // Verify database state: transaction exists with is_confirmed = 0
    const tx = db.prepare('SELECT * FROM transactions WHERE id = ?').get(body.transaction.id);
    assert.ok(tx);
    assert.equal(tx.amount, 25000);
    assert.equal(tx.type, 'expense');
    assert.equal(tx.is_confirmed, 0);

    // Verify database state: chat_log exists with status = 'pending' and linked transaction_id
    const log = db.prepare('SELECT * FROM chat_logs WHERE id = ?').get(body.chatLogId);
    assert.ok(log);
    assert.equal(log.status, 'pending');
    assert.equal(log.transaction_id, tx.id);
    assert.equal(log.message, 'Makan siang nasi padang 25rb');
  });

  it('parses income message via /api/chat/parse successfully', async () => {
    const res = await fetch(`${baseUrl}/api/chat/parse`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: 'Gajian proyek freelance 2.5jt',
      }),
    });

    assert.equal(res.status, 200);
    const body = await res.json();

    assert.equal(body.success, true);
    assert.equal(body.transaction.amount, 2500000);
    assert.equal(body.transaction.type, 'income');
    assert.equal(body.transaction.category, 'Freelance');
  });

  it('handles unrecognized casual message gracefully with fallbackManual = true', async () => {
    const res = await fetch(`${baseUrl}/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: 'Halo apa kabar bot, lagi bingung nih',
      }),
    });

    assert.equal(res.status, 200);
    const body = await res.json();

    assert.equal(body.success, false);
    assert.equal(body.fallbackManual, true);
    assert.ok(body.chatLogId);

    // Verify database state: recorded as failed in chat_logs
    const log = db.prepare('SELECT * FROM chat_logs WHERE id = ?').get(body.chatLogId);
    assert.ok(log);
    assert.equal(log.status, 'failed');
    assert.equal(log.transaction_id, null);
  });

  it('matches user custom category when present in database', async () => {
    // 1. Get default user ID
    const user = db.prepare('SELECT id FROM users ORDER BY id ASC LIMIT 1').get();

    // 2. Add custom category 'Gym & Fitness'
    db.prepare(`
      INSERT OR IGNORE INTO categories (user_id, name, type, is_default, icon, color)
      VALUES (?, 'Gym & Fitness', 'expense', 0, 'fitness_center', 'amber')
    `).run(user.id);

    // 3. Send transaction mentioning gym
    const res = await fetch(`${baseUrl}/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: 'Bayar membership gym 150rb',
        userId: user.id,
      }),
    });

    assert.equal(res.status, 200);
    const body = await res.json();

    assert.equal(body.success, true);
    assert.equal(body.transaction.amount, 150000);
    assert.equal(body.transaction.category, 'Gym & Fitness');
  });
});
