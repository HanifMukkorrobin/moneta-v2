import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Endpoint Logout & Hapus Sesi Tests (/api/auth/logout, /session, /sessions/:id)', () => {
  let server;
  let baseUrl;
  let db;
  let testUser;

  before(async () => {
    db = getDatabase();
    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const { port } = server.address();
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  beforeEach(async () => {
    db.prepare("DELETE FROM users WHERE email LIKE '%@logouttest.moneta.ai'").run();

    const regRes = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Putri Handayani',
        email: 'putri@logouttest.moneta.ai',
        password: 'password123',
      }),
    });
    const regBody = await regRes.json();
    testUser = regBody.user;
  });

  after(async () => {
    if (db) {
      db.prepare("DELETE FROM users WHERE email LIKE '%@logouttest.moneta.ai'").run();
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('deletes session row physically on DELETE /api/auth/session or hardDelete=true', async () => {
    const loginRes = await fetch(`${baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'putri@logouttest.moneta.ai',
        password: 'password123',
        deviceName: 'iPhone 15 Pro',
      }),
    });
    const { token } = await loginRes.json();

    const delRes = await fetch(`${baseUrl}/api/auth/session`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    assert.strictEqual(delRes.status, 200);
    const delBody = await delRes.json();
    assert.strictEqual(delBody.success, true);
    assert.strictEqual(delBody.deleted, true);

    const row = db.prepare('SELECT * FROM user_sessions WHERE token = ?').get(token);
    assert.strictEqual(row, undefined);
  });

  it('deletes a specific device session by ID via DELETE /api/auth/sessions/:id', async () => {
    const login1 = await (
      await fetch(`${baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'putri@logouttest.moneta.ai',
          password: 'password123',
          deviceName: 'Tablet Android',
        }),
      })
    ).json();

    const delById = await fetch(`${baseUrl}/api/auth/sessions/${login1.session.id}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${login1.token}` },
    });
    assert.strictEqual(delById.status, 200);
    const delBody = await delById.json();
    assert.strictEqual(delBody.deleted, true);
    assert.strictEqual(delBody.sessionId, login1.session.id);

    // Deleting again returns 404
    const delAgain = await fetch(`${baseUrl}/api/auth/sessions/${login1.session.id}`, {
      method: 'DELETE',
    });
    assert.strictEqual(delAgain.status, 404);
  });

  it('clears all other sessions while keeping current session when keepCurrent=true', async () => {
    const s1 = await (
      await fetch(`${baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'putri@logouttest.moneta.ai',
          password: 'password123',
          deviceName: 'Current Phone',
        }),
      })
    ).json();

    const s2 = await (
      await fetch(`${baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'putri@logouttest.moneta.ai',
          password: 'password123',
          deviceName: 'Old Laptop',
        }),
      })
    ).json();

    const clearRes = await fetch(`${baseUrl}/api/auth/sessions/clear`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${s1.token}`,
      },
      body: JSON.stringify({ keepCurrent: true }),
    });
    assert.strictEqual(clearRes.status, 200);
    const clearBody = await clearRes.json();
    assert.strictEqual(clearBody.deleted, true);
    assert.ok(clearBody.deletedCount >= 1);

    // Current token (s1) is still valid
    const v1 = await fetch(`${baseUrl}/api/auth/verify`, {
      headers: { Authorization: `Bearer ${s1.token}` },
    });
    assert.strictEqual(v1.status, 200);

    // Other token (s2) was deleted
    const v2 = await fetch(`${baseUrl}/api/auth/verify`, {
      headers: { Authorization: `Bearer ${s2.token}` },
    });
    assert.strictEqual(v2.status, 401);
  });

  it('cleans up expired and revoked sessions via expiredOnly=true and rejects empty logout', async () => {
    // Insert an expired session
    db.prepare(`
      INSERT INTO user_sessions (user_id, token, device_name, expires_at, is_revoked)
      VALUES (?, 'mnt_expired_tok_999', 'Old Device', '2020-01-01T00:00:00.000Z', 0)
    `).run(testUser.id);

    const cleanupRes = await fetch(`${baseUrl}/api/auth/sessions/clear`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ expiredOnly: true }),
    });
    assert.strictEqual(cleanupRes.status, 200);
    const cleanupBody = await cleanupRes.json();
    assert.ok(cleanupBody.deletedCount >= 1);

    const row = db.prepare("SELECT * FROM user_sessions WHERE token = 'mnt_expired_tok_999'").get();
    assert.strictEqual(row, undefined);

    // Empty logout without token or userId returns 400
    const badLogout = await fetch(`${baseUrl}/api/auth/logout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({}),
    });
    assert.strictEqual(badLogout.status, 400);
  });
});
