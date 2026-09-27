import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Budget Alert Settings & Toggle Endpoints (Hidupkan/Matikan Peringatan Budget)', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  const testMonth = '2026-11';

  before(async () => {
    db = getDatabase();
    const userRes = db
      .prepare("INSERT INTO users (email, display_name) VALUES (?, 'Alert Toggle Tester')")
      .run(`alert_toggle_tester_${Date.now()}@example.com`);
    testUserId = Number(userRes.lastInsertRowid);

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  beforeEach(() => {
    db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
    db.prepare('DELETE FROM budgets WHERE user_id = ?').run(testUserId);
    db.prepare('DELETE FROM monthly_budgets WHERE user_id = ?').run(testUserId);
  });

  after(async () => {
    if (testUserId && db) {
      db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM budgets WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM monthly_budgets WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM users WHERE id = ?').run(testUserId);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('toggles master budget warning alert off and on via /api/budgets/alerts/toggle and /api/budgets/alert-settings', async () => {
    // 1. Setup monthly budget of Rp 5.000.000 (default isAlertEnabled = true)
    await fetch(`${baseUrl}/api/budgets/monthly`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        totalAmount: 5000000,
      }),
    });

    // 2. Call POST /api/budgets/alerts/toggle without explicit boolean -> flips true -> false
    const toggleOffRes = await fetch(`${baseUrl}/api/budgets/alerts/toggle`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
      }),
    });
    assert.equal(toggleOffRes.status, 200);
    const toggleOffBody = await toggleOffRes.json();
    assert.equal(toggleOffBody.success, true);
    assert.equal(toggleOffBody.isAlertEnabled, false);
    assert.equal(toggleOffBody.message, 'Peringatan budget dinonaktifkan.');
    assert.equal(toggleOffBody.alertSettings.statusSubtitle, 'Peringatan dinonaktifkan');

    // 3. Call POST /api/budgets/alerts/toggle again -> flips false -> true
    const toggleOnRes = await fetch(`${baseUrl}/api/budgets/alerts/toggle`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
      }),
    });
    assert.equal(toggleOnRes.status, 200);
    const toggleOnBody = await toggleOnRes.json();
    assert.equal(toggleOnBody.success, true);
    assert.equal(toggleOnBody.isAlertEnabled, true);
    assert.equal(toggleOnBody.message, 'Peringatan budget diaktifkan.');
    assert.equal(toggleOnBody.alertSettings.statusSubtitle, 'Notifikasi & peringatan batas aktif');

    // 4. Explicitly set enabled: false via PATCH /api/budgets/alert-settings
    const patchOffRes = await fetch(`${baseUrl}/api/budgets/alert-settings`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        enabled: false,
      }),
    });
    assert.equal(patchOffRes.status, 200);
    const patchOffBody = await patchOffRes.json();
    assert.equal(patchOffBody.isAlertEnabled, false);
    assert.equal(patchOffBody.message, 'Peringatan budget dinonaktifkan.');
  });

  it('updates threshold (80%, 85%, 90%), over-budget toggle, and daily push notification toggle', async () => {
    // 1. Update threshold to 90%
    const threshRes = await fetch(`${baseUrl}/api/budgets/alert-settings`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        alertThreshold: 90,
      }),
    });
    assert.equal(threshRes.status, 200);
    const threshBody = await threshRes.json();
    assert.equal(threshBody.alertThreshold, 90);
    assert.equal(threshBody.message, 'Ambang batas peringatan diubah ke 90%.');

    // 2. Toggle over-budget alert off
    const overOffRes = await fetch(`${baseUrl}/api/budgets/alert-settings`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        isOverBudgetAlertEnabled: false,
      }),
    });
    assert.equal(overOffRes.status, 200);
    const overOffBody = await overOffRes.json();
    assert.equal(overOffBody.isOverBudgetAlertEnabled, false);
    assert.equal(overOffBody.message, 'Peringatan melewati batas dinonaktifkan.');

    // 3. Toggle daily push notification off & on
    const pushOffRes = await fetch(`${baseUrl}/api/budgets/notification-settings`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        isPushNotificationEnabled: false,
      }),
    });
    assert.equal(pushOffRes.status, 200);
    const pushOffBody = await pushOffRes.json();
    assert.equal(pushOffBody.isPushNotificationEnabled, false);
    assert.equal(pushOffBody.message, 'Notifikasi pengingat harian dinonaktifkan.');

    // 4. Verify GET /api/budgets/alert-settings returns persisted settings
    const getRes = await fetch(
      `${baseUrl}/api/budgets/alert-settings?userId=${testUserId}&month=${testMonth}`
    );
    assert.equal(getRes.status, 200);
    const getBody = await getRes.json();
    assert.equal(getBody.isAlertEnabled, true);
    assert.equal(getBody.alertThreshold, 90);
    assert.equal(getBody.isOverBudgetAlertEnabled, false);
    assert.equal(getBody.isPushNotificationEnabled, false);
  });
});
