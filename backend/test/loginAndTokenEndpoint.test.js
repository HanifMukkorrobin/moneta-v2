import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Endpoint Login & Kelola Token Tests (/api/auth/login, /verify, /refresh, /logout)', () => {
  let server;
  let baseUrl;
  let db;
  let registeredUser;

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
    db.prepare("DELETE FROM users WHERE email LIKE '%@logintest.moneta.ai'").run();

    const regRes = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Dimas Saputra',
        email: 'dimas@logintest.moneta.ai',
        password: 'password123',
        currency: 'IDR',
      }),
    });
    const regBody = await regRes.json();
    registeredUser = regBody.user;
  });

  after(async () => {
    if (db) {
      db.prepare("DELETE FROM users WHERE email LIKE '%@logintest.moneta.ai'").run();
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('logs in with valid email and password and issues a new session token', async () => {
    const res = await fetch(`${baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'DIMAS@logintest.moneta.ai',
        password: 'password123',
        deviceName: 'Flutter Android Pixel',
      }),
    });

    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.success, true);
    assert.ok(body.token && body.token.startsWith('mnt_'));
    assert.strictEqual(body.user.id, registeredUser.id);
    assert.strictEqual(body.user.displayName, 'Dimas Saputra');
    assert.strictEqual(body.session.deviceName, 'Flutter Android Pixel');
  });

  it('rejects wrong password or unregistered email with 401 and invalid input with 400', async () => {
    // Wrong password
    const wrongPass = await fetch(`${baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'dimas@logintest.moneta.ai',
        password: 'salahpassword',
      }),
    });
    assert.strictEqual(wrongPass.status, 401);
    const wrongPassBody = await wrongPass.json();
    assert.strictEqual(wrongPassBody.code, 'INVALID_CREDENTIALS');

    // Unknown email
    const unknownUser = await fetch(`${baseUrl}/api/auth/masuk`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'tidakada@logintest.moneta.ai',
        password: 'password123',
      }),
    });
    assert.strictEqual(unknownUser.status, 401);

    // Missing password
    const noPass = await fetch(`${baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'dimas@logintest.moneta.ai',
        password: '',
      }),
    });
    assert.strictEqual(noPass.status, 400);
  });

  it('verifies active session token via GET /api/auth/verify and /api/auth/me', async () => {
    const loginRes = await fetch(`${baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'dimas@logintest.moneta.ai',
        password: 'password123',
      }),
    });
    const { token } = await loginRes.json();

    const verifyRes = await fetch(`${baseUrl}/api/auth/verify`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    assert.strictEqual(verifyRes.status, 200);
    const verifyBody = await verifyRes.json();
    assert.strictEqual(verifyBody.valid, true);
    assert.strictEqual(verifyBody.user.email, 'dimas@logintest.moneta.ai');

    const meRes = await fetch(`${baseUrl}/api/auth/me`, {
      headers: { 'x-auth-token': token },
    });
    assert.strictEqual(meRes.status, 200);
    const meBody = await meRes.json();
    assert.strictEqual(meBody.user.id, registeredUser.id);
  });

  it('rotates token via POST /api/auth/refresh and revokes previous token', async () => {
    const loginRes = await fetch(`${baseUrl}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'dimas@logintest.moneta.ai',
        password: 'password123',
      }),
    });
    const { token: oldToken } = await loginRes.json();

    const refreshRes = await fetch(`${baseUrl}/api/auth/refresh`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${oldToken}`,
      },
      body: JSON.stringify({ deviceName: 'Refreshed iOS Device' }),
    });

    assert.strictEqual(refreshRes.status, 200);
    const refreshBody = await refreshRes.json();
    assert.ok(refreshBody.token);
    assert.notStrictEqual(refreshBody.token, oldToken);
    assert.strictEqual(refreshBody.revokedToken, oldToken);

    // Old token should now be rejected with 401 TOKEN_REVOKED
    const oldCheck = await fetch(`${baseUrl}/api/auth/verify`, {
      headers: { Authorization: `Bearer ${oldToken}` },
    });
    assert.strictEqual(oldCheck.status, 401);
    const oldCheckBody = await oldCheck.json();
    assert.strictEqual(oldCheckBody.code, 'TOKEN_REVOKED');

    // New token should be valid
    const newCheck = await fetch(`${baseUrl}/api/auth/verify`, {
      headers: { Authorization: `Bearer ${refreshBody.token}` },
    });
    assert.strictEqual(newCheck.status, 200);
  });

  it('lists active sessions and revokes token on logout (single and allDevices)', async () => {
    const login1 = await (
      await fetch(`${baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'dimas@logintest.moneta.ai',
          password: 'password123',
          deviceName: 'Device 1',
        }),
      })
    ).json();

    const login2 = await (
      await fetch(`${baseUrl}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'dimas@logintest.moneta.ai',
          password: 'password123',
          deviceName: 'Device 2',
        }),
      })
    ).json();

    // List active sessions
    const sessionsRes = await fetch(`${baseUrl}/api/auth/sessions`, {
      headers: { Authorization: `Bearer ${login1.token}` },
    });
    assert.strictEqual(sessionsRes.status, 200);
    const sessionsBody = await sessionsRes.json();
    assert.ok(sessionsBody.count >= 2);

    // Logout Device 1
    const logout1 = await fetch(`${baseUrl}/api/auth/logout`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${login1.token}` },
    });
    assert.strictEqual(logout1.status, 200);

    // Device 1 token is now revoked
    const verify1 = await fetch(`${baseUrl}/api/auth/verify`, {
      headers: { Authorization: `Bearer ${login1.token}` },
    });
    assert.strictEqual(verify1.status, 401);

    // Device 2 token is still active, now logout allDevices
    const logoutAll = await fetch(`${baseUrl}/api/auth/keluar`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${login2.token}`,
      },
      body: JSON.stringify({ allDevices: true }),
    });
    assert.strictEqual(logoutAll.status, 200);

    const verify2 = await fetch(`${baseUrl}/api/auth/verify`, {
      headers: { Authorization: `Bearer ${login2.token}` },
    });
    assert.strictEqual(verify2.status, 401);
  });
});
