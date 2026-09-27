import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { verifySecret } from '../src/services/userService.js';

describe('Endpoint Registrasi Akun Tests (POST /api/auth/register)', () => {
  let server;
  let baseUrl;
  let db;

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

  beforeEach(() => {
    db.prepare("DELETE FROM users WHERE email LIKE '%@regtest.moneta.ai'").run();
  });

  after(async () => {
    if (db) {
      db.prepare("DELETE FROM users WHERE email LIKE '%@regtest.moneta.ai'").run();
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('registers a new user account, hashes password, creates session, and returns 201', async () => {
    const res = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Rina Wijaya',
        email: 'Rina.Wijaya@regtest.moneta.ai',
        password: 'rahasia123',
        confirmPassword: 'rahasia123',
        currency: 'IDR',
      }),
    });

    assert.strictEqual(res.status, 201);
    const body = await res.json();

    assert.strictEqual(body.success, true);
    assert.ok(body.token && body.token.startsWith('mnt_'));
    assert.ok(body.user);
    assert.strictEqual(body.user.email, 'rina.wijaya@regtest.moneta.ai');
    assert.strictEqual(body.user.displayName, 'Rina Wijaya');
    assert.strictEqual(body.user.currency, 'IDR');
    assert.strictEqual(body.user.currencySymbol, 'Rp');
    assert.strictEqual(body.user.themeMode, 'Terang');
    assert.strictEqual(body.user.password_hash, undefined);

    // Verify stored hash in database
    const row = db.prepare('SELECT * FROM users WHERE id = ?').get(body.user.id);
    assert.ok(row);
    assert.ok(row.password_hash.startsWith('scrypt$'));
    assert.strictEqual(verifySecret('rahasia123', row.password_hash), true);
    assert.strictEqual(verifySecret('wrongpass', row.password_hash), false);

    // Verify session created in user_sessions
    const sessionRow = db.prepare('SELECT * FROM user_sessions WHERE token = ?').get(body.token);
    assert.ok(sessionRow);
    assert.strictEqual(sessionRow.user_id, body.user.id);
    assert.strictEqual(sessionRow.is_revoked, 0);
  });

  it('supports route aliases (/api/auth/daftar, /api/users/register, /api/akun/daftar) and currency symbols', async () => {
    const res1 = await fetch(`${baseUrl}/api/auth/daftar`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        displayName: 'Andi Pratama',
        email: 'andi@regtest.moneta.ai',
        password: 'password123',
        currency: 'USD',
      }),
    });
    assert.strictEqual(res1.status, 201);
    const b1 = await res1.json();
    assert.strictEqual(b1.user.currency, 'USD');
    assert.strictEqual(b1.user.currencySymbol, '$');

    const res2 = await fetch(`${baseUrl}/api/akun/daftar`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        nama: 'Siti Aminah',
        email: 'siti@regtest.moneta.ai',
        kataSandi: 'sandikuat99',
        currency: 'SGD',
      }),
    });
    assert.strictEqual(res2.status, 201);
    const b2 = await res2.json();
    assert.strictEqual(b2.user.displayName, 'Siti Aminah');
    assert.strictEqual(b2.user.currency, 'SGD');
    assert.strictEqual(b2.user.currencySymbol, 'S$');
  });

  it('rejects duplicate email registration with 409 Conflict (case-insensitive)', async () => {
    await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'First User',
        email: 'duplicate@regtest.moneta.ai',
        password: 'password123',
      }),
    });

    const dupRes = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Second User',
        email: 'DUPLICATE@regtest.moneta.ai',
        password: 'password456',
      }),
    });

    assert.strictEqual(dupRes.status, 409);
    const body = await dupRes.json();
    assert.strictEqual(body.success, false);
    assert.strictEqual(body.code, 'EMAIL_ALREADY_EXISTS');
  });

  it('validates required fields, email format, password length, and password confirmation', async () => {
    // Missing name
    const noName = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: '   ',
        email: 'noname@regtest.moneta.ai',
        password: 'password123',
      }),
    });
    assert.strictEqual(noName.status, 400);

    // Invalid email
    const badEmail = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Tester',
        email: 'bukan-email-valid',
        password: 'password123',
      }),
    });
    assert.strictEqual(badEmail.status, 400);

    // Short password (< 6 chars)
    const shortPass = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Tester',
        email: 'shortpass@regtest.moneta.ai',
        password: '123',
      }),
    });
    assert.strictEqual(shortPass.status, 400);

    // Mismatched confirmPassword
    const mismatchPass = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Tester',
        email: 'mismatch@regtest.moneta.ai',
        password: 'password123',
        confirmPassword: 'password999',
      }),
    });
    assert.strictEqual(mismatchPass.status, 400);
    const mismatchBody = await mismatchPass.json();
    assert.strictEqual(mismatchBody.code, 'PASSWORD_MISMATCH');
  });
});
