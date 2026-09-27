import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { runMigrations } from '../src/db/migrate.js';

describe('Endpoint Pengaturan Pengingat Harian (Reminder Settings Endpoints) Tests', () => {
  let server;
  let baseUrl;
  let db;
  let user1Id;
  let user2Id;

  before(async () => {
    db = getDatabase();
    runMigrations(db);

    const u1Res = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, 'Nadia Saphira', 'IDR')
    `).run(`reminder_u1_${Date.now()}@example.com`);
    user1Id = Number(u1Res.lastInsertRowid);

    const u2Res = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, 'Reza Rahadian', 'IDR')
    `).run(`reminder_u2_${Date.now()}@example.com`);
    user2Id = Number(u2Res.lastInsertRowid);

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  beforeEach(() => {
    db.prepare('DELETE FROM reminder_settings WHERE user_id IN (?, ?)').run(user1Id, user2Id);
  });

  after(async () => {
    if (db) {
      db.prepare('DELETE FROM reminder_settings WHERE user_id IN (?, ?)').run(user1Id, user2Id);
      db.prepare('DELETE FROM users WHERE id IN (?, ?)').run(user1Id, user2Id);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. GET /api/pengaturan-pengingat - Ambil Pengaturan', () => {
    it('creates and returns default reminder settings on initial request', async () => {
      const res = await fetch(`${baseUrl}/api/pengaturan-pengingat?userId=${user1Id}`);
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.strictEqual(body.userId, user1Id);

      const settings = body.settings;
      assert.strictEqual(settings.isEnabled, true);
      assert.strictEqual(settings.morningReminderTime, '08:00');
      assert.strictEqual(settings.eveningReminderTime, '20:00');
      assert.strictEqual(settings.morningTimeFormatted, '08:00 WIB');
      assert.strictEqual(settings.eveningTimeFormatted, '20:00 WIB');
      assert.strictEqual(settings.activeDaysSummary, 'Setiap Hari');
      assert.deepStrictEqual(settings.activeDays, [1, 2, 3, 4, 5, 6, 7]);
      assert.strictEqual(settings.notifyOnOverbudget, true);
      assert.strictEqual(settings.notifySavingTips, true);
      assert.strictEqual(settings.soundEnabled, true);
    });

    it('isolates reminder settings strictly between User 1 and User 2', async () => {
      // Modify User 1
      await fetch(`${baseUrl}/api/pengaturan-pengingat`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          morningReminderTime: '06:45',
          activeDays: [1, 2, 3, 4, 5],
        }),
      });

      // Query User 1 vs User 2
      const res1 = await fetch(`${baseUrl}/api/pengaturan-pengingat?userId=${user1Id}`);
      const body1 = await res1.json();
      assert.strictEqual(body1.settings.morningReminderTime, '06:45');
      assert.strictEqual(body1.settings.activeDaysSummary, 'Hari Kerja (Sen - Jum)');

      const res2 = await fetch(`${baseUrl}/api/pengaturan-pengingat?userId=${user2Id}`);
      const body2 = await res2.json();
      assert.strictEqual(body2.settings.morningReminderTime, '08:00');
      assert.strictEqual(body2.settings.activeDaysSummary, 'Setiap Hari');
    });
  });

  describe('2. PUT & PATCH /api/pengaturan-pengingat - Perbarui Pengaturan', () => {
    it('updates reminder times, toggles, and device FCM token via PUT', async () => {
      const res = await fetch(`${baseUrl}/api/pengaturan-pengingat`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          morningReminderTime: '07:15',
          eveningReminderTime: '21:30',
          activeDays: [6, 7], // Akhir Pekan
          notifyDebtDue: false,
          fcmToken: 'fcm_sample_token_xyz',
        }),
      });
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.strictEqual(body.settings.morningReminderTime, '07:15');
      assert.strictEqual(body.settings.eveningReminderTime, '21:30');
      assert.strictEqual(body.settings.activeDaysSummary, 'Akhir Pekan (Sab - Min)');
      assert.strictEqual(body.settings.notifyDebtDue, false);
      assert.strictEqual(body.settings.fcmToken, 'fcm_sample_token_xyz');
    });

    it('partially updates settings via PATCH', async () => {
      const res = await fetch(`${baseUrl}/api/pengaturan-pengingat`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          isEnabled: false,
        }),
      });
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.settings.isEnabled, false);
    });
  });

  describe('3. POST /api/pengaturan-pengingat/reset - Reset ke Default', () => {
    it('resets all reminder settings back to factory defaults', async () => {
      // First change settings
      await fetch(`${baseUrl}/api/pengaturan-pengingat`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          morningReminderTime: '05:00',
          soundEnabled: false,
        }),
      });

      // Reset
      const res = await fetch(`${baseUrl}/api/pengaturan-pengingat/reset`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: user1Id }),
      });
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.strictEqual(body.settings.morningReminderTime, '08:00');
      assert.strictEqual(body.settings.soundEnabled, true);
    });
  });

  describe('4. POST /api/pengaturan-pengingat/test - Simulasi Notifikasi Pengingat', () => {
    it('simulates morning reminder notification preview', async () => {
      const res = await fetch(`${baseUrl}/api/pengaturan-pengingat/test`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: user1Id, type: 'morning' }),
      });
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.strictEqual(body.notification.type, 'morning_advice');
      assert.ok(body.notification.title.includes('Saran Belanja'));
    });

    it('simulates evening reminder notification preview', async () => {
      const res = await fetch(`${baseUrl}/api/pengaturan-pengingat/test`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: user1Id, type: 'evening' }),
      });
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.notification.type, 'evening_reminder');
      assert.ok(body.notification.title.includes('Catat Pengeluaran'));
    });
  });

  describe('5. Validation & Error Handling', () => {
    it('rejects invalid time format (HTTP 400)', async () => {
      const res = await fetch(`${baseUrl}/api/pengaturan-pengingat`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          morningReminderTime: '25:99',
        }),
      });
      const body = await res.json();

      assert.strictEqual(res.status, 400);
      assert.strictEqual(body.success, false);
      assert.ok(body.error.includes('morningReminderTime'));
    });

    it('rejects empty activeDays (HTTP 400)', async () => {
      const res = await fetch(`${baseUrl}/api/pengaturan-pengingat`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          activeDays: [],
        }),
      });
      const body = await res.json();

      assert.strictEqual(res.status, 400);
      assert.strictEqual(body.success, false);
      assert.ok(body.error.includes('activeDays'));
    });

    it('rejects invalid userId (HTTP 400)', async () => {
      const res = await fetch(`${baseUrl}/api/pengaturan-pengingat?userId=-10`);
      const body = await res.json();

      assert.strictEqual(res.status, 400);
      assert.strictEqual(body.success, false);
    });
  });

  describe('6. Route Aliases Compatibility', () => {
    it('supports aliases /pengaturan-pengingat, /reminders, /api/reminders/settings', async () => {
      const r1 = await fetch(`${baseUrl}/reminders?userId=${user1Id}`);
      assert.strictEqual(r1.status, 200);

      const r2 = await fetch(`${baseUrl}/api/reminders/settings?userId=${user1Id}`);
      assert.strictEqual(r2.status, 200);
      const b2 = await r2.json();
      assert.strictEqual(b2.settings.morningReminderTime, '08:00');
    });
  });
});
