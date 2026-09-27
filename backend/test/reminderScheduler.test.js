import { describe, it, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import Database from 'better-sqlite3';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { runMigrations } from '../src/db/migrate.js';
import {
  getCurrentTimeInTimezone,
  createNotificationLog,
  hasNotificationBeenSentToday,
  getNotificationLogs,
  deleteNotificationLog,
  buildMorningAdviceNotification,
  buildEveningReminderNotification,
  checkAndDispatchRemindersForUser,
  checkAndDispatchAllReminders,
  ReminderScheduler,
  globalReminderScheduler,
} from '../src/services/reminderSchedulerService.js';
import {
  getReminderSettings,
  updateReminderSettings,
} from '../src/services/reminderSettingsService.js';

describe('Daily Reminder Scheduler & Notification Logs Unit Tests', () => {
  let db;
  let testUserId;
  let testUser2Id;

  beforeEach(() => {
    // In-memory database for fully isolated unit tests
    db = new Database(':memory:');
    db.pragma('foreign_keys = ON');
    runMigrations(db);

    const insertUser = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, ?, ?)
    `);

    const u1 = insertUser.run('sched_u1@example.com', 'Scheduler Tester 1', 'IDR');
    testUserId = u1.lastInsertRowid;

    const u2 = insertUser.run('sched_u2@example.com', 'Scheduler Tester 2', 'IDR');
    testUser2Id = u2.lastInsertRowid;

    // Set budget for testUserId
    const currentMonth = new Date().toISOString().slice(0, 7);
    db.prepare(`
      INSERT INTO budgets (user_id, month, total_amount, amount_limit)
      VALUES (?, ?, 3000000, 3000000)
    `).run(testUserId, currentMonth);
  });

  afterEach(() => {
    if (db) {
      db.close();
    }
  });

  describe('1. Timezone and Current Time Evaluation', () => {
    it('returns formatted timeString, dateString, and dayOfWeek for Asia/Jakarta', () => {
      const fixedDate = new Date('2026-09-27T01:00:00.000Z'); // 08:00 WIB (UTC+7), Minggu
      const result = getCurrentTimeInTimezone(fixedDate, 'Asia/Jakarta');

      assert.strictEqual(result.timeString, '08:00');
      assert.strictEqual(result.dateString, '2026-09-27');
      assert.strictEqual(result.dayOfWeek, 7); // Minggu
      assert.strictEqual(result.hours, 8);
      assert.strictEqual(result.minutes, 0);
    });

    it('handles fallback gracefully when timezone is unknown', () => {
      const result = getCurrentTimeInTimezone(new Date(), 'Invalid/Timezone_Name');
      assert.ok(result.timeString);
      assert.ok(result.dateString);
      assert.ok(result.dayOfWeek >= 1 && result.dayOfWeek <= 7);
    });
  });

  describe('2. Notification Logs CRUD & Views', () => {
    it('creates notification logs and supports view log_notifikasi and riwayat_notifikasi', () => {
      const log = createNotificationLog(db, {
        userId: testUserId,
        type: 'morning_advice',
        title: 'Moneta AI • Saran Pagi',
        body: 'Batas belanja aman hari ini Rp 100.000',
        payload: { safeDailyLimit: 100000 },
        scheduledTime: '08:00',
        date: '2026-09-27',
        status: 'sent',
      });

      assert.ok(log.id);
      assert.strictEqual(log.userId, testUserId);
      assert.strictEqual(log.type, 'morning_advice');

      // Verify direct table
      const fromTable = db.prepare('SELECT * FROM notification_logs WHERE id = ?').get(log.id);
      assert.strictEqual(fromTable.title, 'Moneta AI • Saran Pagi');

      // Verify views
      const fromView1 = db.prepare('SELECT * FROM log_notifikasi WHERE id = ?').get(log.id);
      assert.strictEqual(fromView1.body, 'Batas belanja aman hari ini Rp 100.000');

      const fromView2 = db.prepare('SELECT * FROM riwayat_notifikasi WHERE id = ?').get(log.id);
      assert.strictEqual(fromView2.type, 'morning_advice');
    });

    it('retrieves notification logs with user isolation', () => {
      createNotificationLog(db, {
        userId: testUserId,
        type: 'morning_advice',
        title: 'Notif User 1',
        body: 'Body 1',
      });

      createNotificationLog(db, {
        userId: testUser2Id,
        type: 'evening_reminder',
        title: 'Notif User 2',
        body: 'Body 2',
      });

      const user1Logs = getNotificationLogs(db, { userId: testUserId });
      assert.strictEqual(user1Logs.length, 1);
      assert.strictEqual(user1Logs[0].title, 'Notif User 1');

      const user2Logs = getNotificationLogs(db, { userId: testUser2Id });
      assert.strictEqual(user2Logs.length, 1);
      assert.strictEqual(user2Logs[0].title, 'Notif User 2');
    });

    it('checks duplicate prevention via hasNotificationBeenSentToday', () => {
      assert.strictEqual(
        hasNotificationBeenSentToday(db, { userId: testUserId, type: 'morning_advice', dateString: '2026-09-27' }),
        false
      );

      createNotificationLog(db, {
        userId: testUserId,
        type: 'morning_advice',
        title: 'Morning Advice',
        body: 'Body',
        date: '2026-09-27',
        status: 'sent',
      });

      assert.strictEqual(
        hasNotificationBeenSentToday(db, { userId: testUserId, type: 'morning_advice', dateString: '2026-09-27' }),
        true
      );
    });

    it('deletes notification log by id or clears all for a user', () => {
      const log = createNotificationLog(db, {
        userId: testUserId,
        type: 'morning_advice',
        title: 'ToDelete',
        body: 'Text',
      });

      assert.strictEqual(deleteNotificationLog(db, { userId: testUserId, id: log.id }), true);
      assert.strictEqual(getNotificationLogs(db, { userId: testUserId }).length, 0);
    });
  });

  describe('3. Morning and Evening Notification Builders', () => {
    it('builds morning advice notification with formatted safeDailyLimit and Indonesian text', () => {
      const notif = buildMorningAdviceNotification(db, testUserId, { dateString: '2026-09-27' });

      assert.strictEqual(notif.type, 'morning_advice');
      assert.strictEqual(notif.title, 'Moneta AI • Saran Belanja Hari Ini');
      assert.ok(notif.body.includes('Batas belanja aman Anda hari ini'));
      assert.ok(notif.body.includes('Rp'));
      assert.strictEqual(notif.payload.screen, '/beranda');
      assert.ok(notif.payload.safeDailyLimit >= 0);
    });

    it('builds evening reminder notification when no transactions recorded today', () => {
      const notif = buildEveningReminderNotification(db, testUserId, { dateString: '2026-09-27' });

      assert.strictEqual(notif.type, 'evening_reminder');
      assert.strictEqual(notif.title, 'Moneta AI • Catat Pengeluaran Malam Ini');
      assert.ok(notif.body.includes('Belum ada pengeluaran yang dicatat hari ini'));
      assert.strictEqual(notif.payload.action, 'open_chat');
      assert.strictEqual(notif.payload.todaySpent, 0);
    });

    it('builds evening reminder notification with recorded expenses summary', () => {
      db.prepare(`
        INSERT INTO transactions (user_id, amount, type, note, occurred_at)
        VALUES (?, 35000, 'expense', 'Makan siang', '2026-09-27 12:30:00')
      `).run(testUserId);

      db.prepare(`
        INSERT INTO transactions (user_id, amount, type, note, occurred_at)
        VALUES (?, 15000, 'expense', 'Kopi sore', '2026-09-27 16:00:00')
      `).run(testUserId);

      const notif = buildEveningReminderNotification(db, testUserId, { dateString: '2026-09-27' });

      assert.strictEqual(notif.type, 'evening_reminder');
      assert.ok(notif.body.includes('2 transaksi'));
      assert.ok(notif.body.includes('50.000'));
      assert.strictEqual(notif.payload.todaySpent, 50000);
      assert.strictEqual(notif.payload.transactionCount, 2);
    });
  });

  describe('4. Dispatch Logic & Filter Rules', () => {
    it('skips dispatching when reminders are disabled for user', async () => {
      updateReminderSettings(db, testUserId, { isEnabled: false });
      const settings = getReminderSettings(db, testUserId);

      const result = await checkAndDispatchRemindersForUser(db, settings, {
        simulatedTime: '08:00',
        simulatedDay: 7,
      });

      assert.strictEqual(result.sent, false);
      assert.strictEqual(result.reason, 'reminders_disabled');
    });

    it('skips dispatching on inactive days', async () => {
      // Only Monday to Friday active (1-5), simulated day is Sunday (7)
      updateReminderSettings(db, testUserId, { activeDays: [1, 2, 3, 4, 5] });
      const settings = getReminderSettings(db, testUserId);

      const result = await checkAndDispatchRemindersForUser(db, settings, {
        simulatedTime: '08:00',
        simulatedDay: 7,
      });

      assert.strictEqual(result.sent, false);
      assert.strictEqual(result.reason, 'inactive_day');
    });

    it('dispatches morning advice when morning time matches', async () => {
      updateReminderSettings(db, testUserId, {
        isEnabled: true,
        morningReminderTime: '08:00',
        isMorningReminderEnabled: true,
        activeDays: [1, 2, 3, 4, 5, 6, 7],
      });
      const settings = getReminderSettings(db, testUserId);

      const result = await checkAndDispatchRemindersForUser(db, settings, {
        simulatedTime: '08:00',
        simulatedDate: '2026-09-27',
        simulatedDay: 7,
      });

      assert.strictEqual(result.sent, true);
      assert.strictEqual(result.dispatchedCount, 1);
      assert.strictEqual(result.dispatched[0].type, 'morning_advice');

      // Verify stored in notification_logs
      const logs = getNotificationLogs(db, { userId: testUserId });
      assert.strictEqual(logs.length, 1);
      assert.strictEqual(logs[0].type, 'morning_advice');
    });

    it('prevents sending duplicate morning reminder on same day', async () => {
      const settings = getReminderSettings(db, testUserId);

      // First run: dispatched
      const firstRun = await checkAndDispatchRemindersForUser(db, settings, {
        simulatedTime: '08:00',
        simulatedDate: '2026-09-27',
        simulatedDay: 7,
      });
      assert.strictEqual(firstRun.dispatchedCount, 1);

      // Second run: duplicate skipped
      const secondRun = await checkAndDispatchRemindersForUser(db, settings, {
        simulatedTime: '08:00',
        simulatedDate: '2026-09-27',
        simulatedDay: 7,
      });
      assert.strictEqual(secondRun.dispatchedCount, 0);
    });

    it('dispatches evening reminder when evening time matches', async () => {
      updateReminderSettings(db, testUserId, {
        isEnabled: true,
        eveningReminderTime: '20:00',
        isEveningReminderEnabled: true,
      });
      const settings = getReminderSettings(db, testUserId);

      const result = await checkAndDispatchRemindersForUser(db, settings, {
        simulatedTime: '20:00',
        simulatedDate: '2026-09-27',
        simulatedDay: 7,
      });

      assert.strictEqual(result.sent, true);
      assert.strictEqual(result.dispatched[0].type, 'evening_reminder');
    });

    it('checkAndDispatchAllReminders iterates all active users', async () => {
      updateReminderSettings(db, testUserId, { isEnabled: true });
      updateReminderSettings(db, testUser2Id, { isEnabled: true });

      const result = await checkAndDispatchAllReminders(db, {
        simulatedTime: '08:00',
        simulatedDate: '2026-09-27',
        simulatedDay: 7,
        force: true,
      });

      assert.ok(result.totalUsersChecked >= 2);
      assert.ok(result.totalDispatched >= 2);
    });
  });

  describe('5. ReminderScheduler Class Engine', () => {
    it('manages scheduler lifecycle (start, stop, isRunning, getStatus)', () => {
      const scheduler = new ReminderScheduler();
      assert.strictEqual(scheduler.isRunning(), false);

      scheduler.start({
        intervalMs: 10000,
        dbGetter: () => db,
      });

      assert.strictEqual(scheduler.isRunning(), true);
      const status = scheduler.getStatus();
      assert.strictEqual(status.isRunning, true);
      assert.strictEqual(status.intervalMs, 10000);

      scheduler.stop();
      assert.strictEqual(scheduler.isRunning(), false);
    });

    it('triggerNow executes manual check cycle', async () => {
      const scheduler = new ReminderScheduler();
      const res = await scheduler.triggerNow(db, {
        simulatedTime: '08:00',
        simulatedDate: '2026-09-28',
        simulatedDay: 1,
        force: true,
      });

      assert.ok(res.totalUsersChecked >= 2);
      const status = scheduler.getStatus();
      assert.ok(status.lastTickAt);
      assert.ok(status.totalDispatched >= 0);
    });
  });
});

describe('HTTP Endpoints for Scheduler and Notifications Integration Tests', () => {
  let server;
  let baseUrl;
  let db;
  let isolatedUserId;

  before(async () => {
    db = getDatabase();
    runMigrations(db);

    const email = `scheduler_it_${Date.now()}@example.com`;
    const res = db.prepare("INSERT INTO users (email, display_name) VALUES (?, 'Scheduler IT User')").run(email);
    isolatedUserId = res.lastInsertRowid;

    // Create default reminder settings for this user
    getReminderSettings(db, isolatedUserId);

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    globalReminderScheduler.stop();
    if (db && isolatedUserId) {
      db.prepare('DELETE FROM notification_logs WHERE user_id = ?').run(isolatedUserId);
      db.prepare('DELETE FROM reminder_settings WHERE user_id = ?').run(isolatedUserId);
      db.prepare('DELETE FROM users WHERE id = ?').run(isolatedUserId);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('GET /api/pengaturan-pengingat/scheduler/status returns scheduler status', async () => {
    const res = await fetch(`${baseUrl}/api/pengaturan-pengingat/scheduler/status`);
    assert.strictEqual(res.status, 200);

    const data = await res.json();
    assert.strictEqual(data.success, true);
    assert.ok(data.scheduler);
    assert.ok(typeof data.scheduler.isRunning === 'boolean');
  });

  it('POST /api/pengaturan-pengingat/scheduler/trigger triggers manual evaluation', async () => {
    const res = await fetch(`${baseUrl}/api/pengaturan-pengingat/scheduler/trigger`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: isolatedUserId,
        time: '08:00',
        date: '2026-09-29',
        dayOfWeek: 2,
        force: true,
      }),
    });

    assert.strictEqual(res.status, 200);
    const data = await res.json();
    assert.strictEqual(data.success, true);
    assert.ok(data.totalDispatched >= 1);
    assert.strictEqual(data.results[0].userId, isolatedUserId);
  });

  it('GET /api/pengaturan-pengingat/notifikasi returns notification history for user', async () => {
    const res = await fetch(`${baseUrl}/api/pengaturan-pengingat/notifikasi?userId=${isolatedUserId}`);
    assert.strictEqual(res.status, 200);

    const data = await res.json();
    assert.strictEqual(data.success, true);
    assert.strictEqual(data.userId, isolatedUserId);
    assert.ok(Array.isArray(data.notifications));
    assert.ok(data.notifications.length >= 1);
    assert.strictEqual(data.notifications[0].userId, isolatedUserId);
  });

  it('GET /api/notifikasi alias returns notification history', async () => {
    const res = await fetch(`${baseUrl}/api/notifikasi?userId=${isolatedUserId}`);
    assert.strictEqual(res.status, 200);

    const data = await res.json();
    assert.strictEqual(data.success, true);
    assert.ok(Array.isArray(data.notifications));
  });

  it('DELETE /api/pengaturan-pengingat/notifikasi/:id deletes single notification', async () => {
    // Get latest notification id
    const listRes = await fetch(`${baseUrl}/api/pengaturan-pengingat/notifikasi?userId=${isolatedUserId}`);
    const listData = await listRes.json();
    const notifId = listData.notifications[0].id;

    const delRes = await fetch(`${baseUrl}/api/pengaturan-pengingat/notifikasi/${notifId}?userId=${isolatedUserId}`, {
      method: 'DELETE',
    });
    assert.strictEqual(delRes.status, 200);
    const delData = await delRes.json();
    assert.strictEqual(delData.success, true);
    assert.strictEqual(delData.deleted, true);
  });

  it('POST /api/pengaturan-pengingat/scheduler/start and stop toggles background scheduler', async () => {
    const startRes = await fetch(`${baseUrl}/api/pengaturan-pengingat/scheduler/start`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ intervalMs: 30000 }),
    });
    assert.strictEqual(startRes.status, 200);
    const startData = await startRes.json();
    assert.strictEqual(startData.success, true);
    assert.strictEqual(startData.scheduler.isRunning, true);

    const stopRes = await fetch(`${baseUrl}/api/pengaturan-pengingat/scheduler/stop`, {
      method: 'POST',
    });
    assert.strictEqual(stopRes.status, 200);
    const stopData = await stopRes.json();
    assert.strictEqual(stopData.success, true);
    assert.strictEqual(stopData.scheduler.isRunning, false);
  });
});
