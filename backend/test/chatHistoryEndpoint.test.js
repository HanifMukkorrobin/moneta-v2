import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Chat History Endpoint Integration Tests (GET /chat/history & GET /api/chat/history)', () => {
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

    // Populate distinct chat logs for testing
    // 1. Pending log
    await fetch(`${baseUrl}/api/chat/parse`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Makan soto ayam 20rb' }),
    });

    // 2. Confirmed log
    const parseRes2 = await fetch(`${baseUrl}/api/chat/parse`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Beli paket data internet 50rb' }),
    });
    const parseData2 = await parseRes2.json();
    await fetch(`${baseUrl}/api/transactions/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        transactionId: parseData2.transaction.id,
        chatLogId: parseData2.chatLogId,
      }),
    });

    // 3. Failed/casual log
    await fetch(`${baseUrl}/api/chat/parse`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Halo apa kabar bot' }),
    });
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('retrieves chat history list via GET /api/chat/history', async () => {
    const res = await fetch(`${baseUrl}/api/chat/history`);
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(Array.isArray(body.chatLogs));
    assert.ok(body.total >= 3);
    assert.ok(body.chatLogs.length >= 3);

    // Verify first item structure
    const item = body.chatLogs[0];
    assert.ok(item.id);
    assert.ok(item.message);
    assert.ok(item.status);
    assert.ok(item.createdAt);
  });

  it('filters chat history by status=pending', async () => {
    const res = await fetch(`${baseUrl}/chat/history?status=pending`);
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(body.chatLogs.length > 0);
    assert.ok(body.chatLogs.every((log) => log.status === 'pending'));
  });

  it('filters chat history by status=confirmed and includes transaction details', async () => {
    const res = await fetch(`${baseUrl}/api/chat/history?status=confirmed`);
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(body.chatLogs.length > 0);
    assert.ok(body.chatLogs.every((log) => log.status === 'confirmed'));

    const confirmedItem = body.chatLogs.find((l) => l.message.includes('internet'));
    assert.ok(confirmedItem);
    assert.ok(confirmedItem.transaction);
    assert.equal(confirmedItem.transaction.amount, 50000);
    assert.equal(confirmedItem.transaction.isConfirmed, true);
  });

  it('filters chat history by status=failed for unparsed messages', async () => {
    const res = await fetch(`${baseUrl}/api/chat/history?status=failed`);
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(body.chatLogs.length > 0);
    assert.ok(body.chatLogs.every((log) => log.status === 'failed'));
    assert.ok(body.chatLogs.some((log) => log.message.includes('Halo apa kabar')));
  });

  it('searches chat history by keyword in message or note', async () => {
    const res = await fetch(`${baseUrl}/api/chat/history?search=soto`);
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.success, true);
    assert.ok(body.chatLogs.length >= 1);
    assert.ok(body.chatLogs[0].message.toLowerCase().includes('soto'));
  });

  it('supports pagination with limit and offset', async () => {
    const res = await fetch(`${baseUrl}/api/chat/history?limit=2&offset=0`);
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.limit, 2);
    assert.equal(body.offset, 0);
    assert.equal(body.chatLogs.length, 2);

    const res2 = await fetch(`${baseUrl}/api/chat/history?limit=2&offset=2`);
    assert.equal(res2.status, 200);
    const body2 = await res2.json();
    assert.equal(body2.limit, 2);
    assert.equal(body2.offset, 2);
    assert.notEqual(body.chatLogs[0].id, body2.chatLogs[0].id);
  });

  it('retrieves single chat log by ID via GET /api/chat/history/:id', async () => {
    const listRes = await fetch(`${baseUrl}/api/chat/history?limit=1`);
    const listBody = await listRes.json();
    const targetId = listBody.chatLogs[0].id;

    const res = await fetch(`${baseUrl}/api/chat/history/${targetId}`);
    assert.equal(res.status, 200);

    const body = await res.json();
    assert.equal(body.success, true);
    assert.equal(body.chatLog.id, targetId);
    assert.equal(body.chatLog.message, listBody.chatLogs[0].message);
  });

  it('returns 404 when chat log ID does not exist', async () => {
    const res = await fetch(`${baseUrl}/api/chat/history/999999`);
    assert.equal(res.status, 404);

    const body = await res.json();
    assert.equal(body.success, false);
    assert.equal(body.error, 'Riwayat percakapan tidak ditemukan.');
  });
});
