import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Endpoint Preferensi Aplikasi Pengguna Tests (/api/preferences & /api/preferensi)', () => {
  let server;
  let baseUrl;
  let db;
  let testUser;
  let authToken;

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
    db.prepare("DELETE FROM users WHERE email LIKE '%@preftest.moneta.ai'").run();

    const regRes = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Budi Santoso',
        email: 'budi@preftest.moneta.ai',
        password: 'password123',
        currency: 'IDR',
      }),
    });
    const regBody = await regRes.json();
    testUser = regBody.user;
    authToken = regBody.token;
  });

  after(async () => {
    if (db) {
      db.prepare("DELETE FROM users WHERE email LIKE '%@preftest.moneta.ai'").run();
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('retrieves default user preferences via GET /api/preferences and /api/preferensi', async () => {
    const res = await fetch(`${baseUrl}/api/preferences`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });

    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.currency, 'IDR');
    assert.strictEqual(body.currencySymbol, 'Rp');
    assert.strictEqual(body.dateFormat, 'DD/MM/YYYY');
    assert.strictEqual(body.firstDayOfWeek, 'Senin');
    assert.strictEqual(body.themeMode, 'Terang');
    assert.strictEqual(body.aiAdviceTone, 'Standar');
    assert.strictEqual(body.autoConfirmChat, false);
    assert.strictEqual(body.budgetAlertThreshold, 80);
    assert.strictEqual(body.hideBalance, false);
    assert.strictEqual(body.hapticFeedback, true);

    const aliasRes = await fetch(`${baseUrl}/api/preferensi?userId=${testUser.id}`);
    assert.strictEqual(aliasRes.status, 200);
  });

  it('updates regional, AI, theme, and privacy preferences via PUT and PATCH /api/preferences', async () => {
    const updateRes = await fetch(`${baseUrl}/api/preferences`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        displayName: 'Budi Santoso Updated',
        currency: 'USD',
        dateFormat: 'YYYY-MM-DD',
        firstDayOfWeek: 'Minggu',
        themeMode: 'Gelap',
        aiAdviceTone: 'Tegas',
        budgetAlertThreshold: 90,
        autoConfirmChat: true,
        hideBalance: true,
        hapticFeedback: false,
      }),
    });

    assert.strictEqual(updateRes.status, 200);
    const body = await updateRes.json();
    assert.strictEqual(body.displayName, 'Budi Santoso Updated');
    assert.strictEqual(body.currency, 'USD');
    assert.strictEqual(body.currencySymbol, '$');
    assert.strictEqual(body.dateFormat, 'YYYY-MM-DD');
    assert.strictEqual(body.firstDayOfWeek, 'Minggu');
    assert.strictEqual(body.themeMode, 'Gelap');
    assert.strictEqual(body.aiAdviceTone, 'Tegas');
    assert.strictEqual(body.budgetAlertThreshold, 90);
    assert.strictEqual(body.autoConfirmChat, true);
    assert.strictEqual(body.hideBalance, true);
    assert.strictEqual(body.hapticFeedback, false);

    // Partial update via PATCH /api/preferences/theme
    const patchTheme = await fetch(`${baseUrl}/api/preferences/theme`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({ themeMode: 'system' }),
    });
    assert.strictEqual(patchTheme.status, 200);
    const patchBody = await patchTheme.json();
    assert.strictEqual(patchBody.themeMode, 'Ikuti Sistem');
  });

  it('rejects invalid preference values with 400 Bad Request', async () => {
    // Invalid themeMode
    const badTheme = await fetch(`${baseUrl}/api/preferences`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({ themeMode: 'NeonPink' }),
    });
    assert.strictEqual(badTheme.status, 400);

    // Invalid aiAdviceTone
    const badTone = await fetch(`${baseUrl}/api/preferences`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({ aiAdviceTone: 'GalakSekali' }),
    });
    assert.strictEqual(badTone.status, 400);

    // Out-of-range budgetAlertThreshold
    const badThresh = await fetch(`${baseUrl}/api/preferences`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({ budgetAlertThreshold: 120 }),
    });
    assert.strictEqual(badThresh.status, 400);
  });

  it('resets preferences back to default values via POST /api/preferences/reset', async () => {
    // First customize
    await fetch(`${baseUrl}/api/preferences`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${authToken}`,
      },
      body: JSON.stringify({
        currency: 'EUR',
        themeMode: 'Gelap',
        aiAdviceTone: 'Santai',
        hideBalance: true,
        budgetAlertThreshold: 95,
      }),
    });

    // Then reset
    const resetRes = await fetch(`${baseUrl}/api/preferences/reset`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${authToken}` },
    });
    assert.strictEqual(resetRes.status, 200);
    const resetBody = await resetRes.json();

    assert.strictEqual(resetBody.currency, 'IDR');
    assert.strictEqual(resetBody.currencySymbol, 'Rp');
    assert.strictEqual(resetBody.themeMode, 'Terang');
    assert.strictEqual(resetBody.aiAdviceTone, 'Standar');
    assert.strictEqual(resetBody.hideBalance, false);
    assert.strictEqual(resetBody.budgetAlertThreshold, 80);
  });
});
