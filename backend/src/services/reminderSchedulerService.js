/**
 * Reminder Scheduler Service (Layanan Penjadwal Notifikasi & Pengingat Harian AI)
 *
 * Mengelola penjadwalan, evaluasi waktu, pembentukan konten saran/pengingat harian,
 * serta pencatatan log riwayat notifikasi ke tabel `notification_logs`.
 */

import { env } from '../config/env.js';
import { getSafeDailySpendingForUser } from './safeDailySpendingService.js';
import { formatRupiah } from './dailyAverageSpendingService.js';
import { getReminderSettings } from './reminderSettingsService.js';

/**
 * Menghitung waktu lokal saat ini berdasarkan zona waktu pengguna.
 * Default: 'Asia/Jakarta' (WIB).
 *
 * @param {Date} [date=new Date()]
 * @param {string} [timezone=env.DEFAULT_TIMEZONE]
 * @returns {{ timeString: string, dateString: string, dayOfWeek: number, hours: number, minutes: number, timezone: string }}
 */
export function getCurrentTimeInTimezone(date = new Date(), timezone = env.DEFAULT_TIMEZONE) {
  try {
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: timezone,
      hour12: false,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      weekday: 'short',
    });

    const parts = formatter.formatToParts(date);
    const map = {};
    for (const p of parts) {
      map[p.type] = p.value;
    }

    const rawHour = map.hour === '24' ? '00' : (map.hour || '00');
    const rawMinute = map.minute || '00';
    const timeString = `${rawHour.padStart(2, '0')}:${rawMinute.padStart(2, '0')}`;
    const dateString = `${map.year}-${map.month}-${map.day}`;

    const dayMap = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };
    const dayOfWeek = dayMap[map.weekday] || 1;

    return {
      timeString,
      dateString,
      dayOfWeek,
      hours: parseInt(rawHour, 10),
      minutes: parseInt(rawMinute, 10),
      timezone,
    };
  } catch {
    // Fallback jika timezone string tidak valid
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const timeString = `${hours}:${minutes}`;
    const dateString = date.toISOString().slice(0, 10);
    const dayOfWeek = date.getDay() === 0 ? 7 : date.getDay();
    return {
      timeString,
      dateString,
      dayOfWeek,
      hours: date.getHours(),
      minutes: date.getMinutes(),
      timezone: 'Asia/Jakarta',
    };
  }
}

/**
 * Mencatat log notifikasi ke tabel `notification_logs`
 */
export function createNotificationLog(db, {
  userId,
  type,
  title,
  body,
  payload = {},
  scheduledTime = null,
  date = null,
  status = 'sent',
}) {
  if (!userId) {
    throw new Error('userId is required to log notification');
  }

  const dateStr = date || new Date().toISOString().slice(0, 10);
  const payloadStr = typeof payload === 'string' ? payload : JSON.stringify(payload);

  const stmt = db.prepare(`
    INSERT INTO notification_logs (
      user_id, type, title, body, payload_json, scheduled_time, date, status, created_at
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
  `);

  const result = stmt.run(userId, type, title, body, payloadStr, scheduledTime, dateStr, status);

  return {
    id: result.lastInsertRowid,
    userId,
    type,
    title,
    body,
    payload,
    scheduledTime,
    date: dateStr,
    status,
    createdAt: new Date().toISOString(),
  };
}

/**
 * Cek apakah notifikasi tipe tertentu sudah terkirim ke user pada tanggal tertentu
 */
export function hasNotificationBeenSentToday(db, { userId, type, dateString }) {
  const targetDate = dateString || new Date().toISOString().slice(0, 10);
  const row = db.prepare(`
    SELECT COUNT(*) as count
    FROM notification_logs
    WHERE user_id = ? AND type = ? AND date = ? AND status != 'failed'
  `).get(userId, type, targetDate);

  return Boolean(row && row.count > 0);
}

/**
 * Mengambil riwayat log notifikasi untuk pengguna tertentu
 */
export function getNotificationLogs(db, { userId, type, limit = 50, offset = 0 } = {}) {
  let query = 'SELECT * FROM notification_logs';
  const conditions = [];
  const params = [];

  if (userId) {
    conditions.push('user_id = ?');
    params.push(userId);
  }
  if (type) {
    conditions.push('type = ?');
    params.push(type);
  }

  if (conditions.length > 0) {
    query += ' WHERE ' + conditions.join(' AND ');
  }

  query += ' ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?';
  params.push(Number(limit) || 50, Number(offset) || 0);

  const rows = db.prepare(query).all(...params);

  return rows.map((row) => {
    let payload = {};
    if (row.payload_json) {
      try {
        payload = JSON.parse(row.payload_json);
      } catch {
        payload = { raw: row.payload_json };
      }
    }

    return {
      id: row.id,
      userId: row.user_id,
      type: row.type,
      title: row.title,
      body: row.body,
      payload,
      scheduledTime: row.scheduled_time,
      date: row.date,
      status: row.status,
      createdAt: row.created_at,
    };
  });
}

/**
 * Menghapus satu atau seluruh log notifikasi
 */
export function deleteNotificationLog(db, { userId, id } = {}) {
  if (id) {
    const stmt = userId
      ? db.prepare('DELETE FROM notification_logs WHERE id = ? AND user_id = ?')
      : db.prepare('DELETE FROM notification_logs WHERE id = ?');
    const res = userId ? stmt.run(id, userId) : stmt.run(id);
    return res.changes > 0;
  }
  if (userId) {
    const res = db.prepare('DELETE FROM notification_logs WHERE user_id = ?').run(userId);
    return res.changes > 0;
  }
  return false;
}

/**
 * Membentuk pesan notifikasi saran belanja pagi hari (Morning Advice)
 */
export function buildMorningAdviceNotification(db, userId, { dateString } = {}) {
  const spending = getSafeDailySpendingForUser(db, { userId, date: dateString, autoCache: true });
  const limitFormatted = formatRupiah(spending.safeDailyLimit || 0);
  const remainingDays = spending.remainingDays || 1;

  // Cari tips hemat aktif jika ada
  let tip = null;
  try {
    tip = db.prepare(`
      SELECT id, title, category, potential_saving, action_text
      FROM daily_tips
      WHERE is_active = 1
      ORDER BY id ASC
      LIMIT 1
    `).get();
  } catch {
    tip = null;
  }

  let body = '';
  if (spending.safeDailyLimit > 0) {
    body = `Batas belanja aman Anda hari ini ${limitFormatted}. Tersisa ${remainingDays} hari menuju akhir bulan. Tetap jaga pengeluaran!`;
  } else {
    body = `Peringatan: Anggaran belanja Anda untuk sisa bulan ini sudah menipis. Prioritaskan kebutuhan pokok!`;
  }

  if (tip && tip.title) {
    body += ` Tips hari ini: ${tip.title}.`;
  }

  return {
    type: 'morning_advice',
    title: 'Moneta AI • Saran Belanja Hari Ini',
    body,
    scheduledTime: '08:00',
    payload: {
      screen: '/beranda',
      action: 'view_daily_advice',
      safeDailyLimit: spending.safeDailyLimit,
      remainingDays,
      warnLevel: spending.warnLevel,
      todaySpent: spending.todaySpent,
      tip: tip ? { id: tip.id, title: tip.title, category: tip.category } : null,
    },
  };
}

/**
 * Membentuk pesan notifikasi pengingat pencatatan malam hari (Evening Reminder)
 */
export function buildEveningReminderNotification(db, userId, { dateString } = {}) {
  const targetDate = dateString || new Date().toISOString().slice(0, 10);

  // Ambil total pengeluaran hari ini yang sudah dicatat user
  const stats = db.prepare(`
    SELECT
      COALESCE(SUM(amount), 0) as total_spent,
      COUNT(*) as transaction_count
    FROM transactions
    WHERE user_id = ? AND type = 'expense' AND date(occurred_at) = date(?)
  `).get(userId, targetDate);

  const spending = getSafeDailySpendingForUser(db, { userId, date: targetDate, autoCache: false });
  const totalSpent = stats?.total_spent || 0;
  const count = stats?.transaction_count || 0;
  const spentFormatted = formatRupiah(totalSpent);
  const limitFormatted = formatRupiah(spending.safeDailyLimit || 0);

  let body = '';
  if (count > 0) {
    body = `Hari ini Anda mencatat ${count} transaksi (${spentFormatted}) dari batas aman ${limitFormatted}. Yuk cek dan pastikan tidak ada transaksi yang terlewat!`;
  } else {
    body = `Belum ada pengeluaran yang dicatat hari ini. Yuk luangkan 1 menit untuk mencatat transaksi hari ini di tab Chat!`;
  }

  return {
    type: 'evening_reminder',
    title: 'Moneta AI • Catat Pengeluaran Malam Ini',
    body,
    scheduledTime: '20:00',
    payload: {
      screen: '/beranda',
      action: 'open_chat',
      todaySpent: totalSpent,
      transactionCount: count,
      safeDailyLimit: spending.safeDailyLimit,
    },
  };
}

/**
 * Pengirim notifikasi bawaan (mock / log)
 */
export async function defaultNotificationSender(notification, userSettings) {
  // Dalam lingkungan produksi, fungsi ini memanggil FCM / push provider via userSettings.fcmToken
  return {
    delivered: true,
    recipient: userSettings.fcmToken || `user_${userSettings.userId}`,
    channel: userSettings.fcmToken ? 'fcm' : 'local_notification',
    timestamp: new Date().toISOString(),
  };
}

/**
 * Mengevaluasi dan mengirim notifikasi pengingat untuk satu pengguna
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} userSettings
 * @param {Object} [options={}]
 * @returns {Promise<{ userId: number, sent: boolean, results: Array }>}
 */
export async function checkAndDispatchRemindersForUser(db, userSettings, options = {}) {
  const {
    now = new Date(),
    force = false,
    targetType = null,
    senderFn = defaultNotificationSender,
    simulatedTime = null,
    simulatedDate = null,
    simulatedDay = null,
  } = options;

  const timezone = userSettings.timezone || 'Asia/Jakarta';
  const timeInfo = getCurrentTimeInTimezone(now, timezone);

  const timeString = simulatedTime || timeInfo.timeString;
  const dateString = simulatedDate || timeInfo.dateString;
  const dayOfWeek = simulatedDay !== null && simulatedDay !== undefined ? Number(simulatedDay) : timeInfo.dayOfWeek;

  const dispatched = [];

  // 1. Cek apakah pengingat aktif secara umum
  if (!userSettings.isEnabled && !force) {
    return {
      userId: userSettings.userId,
      sent: false,
      reason: 'reminders_disabled',
      dispatched,
    };
  }

  // 2. Cek apakah hari ini termasuk hari aktif
  const activeDays = Array.isArray(userSettings.activeDays) ? userSettings.activeDays : [1, 2, 3, 4, 5, 6, 7];
  if (!activeDays.includes(dayOfWeek) && !force) {
    return {
      userId: userSettings.userId,
      sent: false,
      reason: 'inactive_day',
      dayOfWeek,
      dispatched,
    };
  }

  // 3. Evaluasi Pengingat Pagi (Morning Advice)
  const shouldCheckMorning = targetType ? targetType === 'morning_advice' : true;
  if (shouldCheckMorning && (userSettings.isMorningReminderEnabled || force)) {
    const isMorningTimeMatch = force || (timeString === userSettings.morningReminderTime);
    const alreadySentMorning = !force && hasNotificationBeenSentToday(db, {
      userId: userSettings.userId,
      type: 'morning_advice',
      dateString,
    });

    if (isMorningTimeMatch && !alreadySentMorning) {
      const notif = buildMorningAdviceNotification(db, userSettings.userId, { dateString });
      notif.scheduledTime = userSettings.morningReminderTime;

      let deliveryStatus = 'sent';
      try {
        await senderFn(notif, userSettings);
      } catch (err) {
        deliveryStatus = 'failed';
      }

      const log = createNotificationLog(db, {
        userId: userSettings.userId,
        type: notif.type,
        title: notif.title,
        body: notif.body,
        payload: notif.payload,
        scheduledTime: notif.scheduledTime,
        date: dateString,
        status: deliveryStatus,
      });

      dispatched.push({
        type: 'morning_advice',
        title: notif.title,
        body: notif.body,
        scheduledTime: notif.scheduledTime,
        status: deliveryStatus,
        logId: log.id,
      });
    }
  }

  // 4. Evaluasi Pengingat Malam (Evening Reminder)
  const shouldCheckEvening = targetType ? targetType === 'evening_reminder' : true;
  if (shouldCheckEvening && (userSettings.isEveningReminderEnabled || force)) {
    const isEveningTimeMatch = force || (timeString === userSettings.eveningReminderTime);
    const alreadySentEvening = !force && hasNotificationBeenSentToday(db, {
      userId: userSettings.userId,
      type: 'evening_reminder',
      dateString,
    });

    if (isEveningTimeMatch && !alreadySentEvening) {
      const notif = buildEveningReminderNotification(db, userSettings.userId, { dateString });
      notif.scheduledTime = userSettings.eveningReminderTime;

      let deliveryStatus = 'sent';
      try {
        await senderFn(notif, userSettings);
      } catch (err) {
        deliveryStatus = 'failed';
      }

      const log = createNotificationLog(db, {
        userId: userSettings.userId,
        type: notif.type,
        title: notif.title,
        body: notif.body,
        payload: notif.payload,
        scheduledTime: notif.scheduledTime,
        date: dateString,
        status: deliveryStatus,
      });

      dispatched.push({
        type: 'evening_reminder',
        title: notif.title,
        body: notif.body,
        scheduledTime: notif.scheduledTime,
        status: deliveryStatus,
        logId: log.id,
      });
    }
  }

  return {
    userId: userSettings.userId,
    sent: dispatched.length > 0,
    dispatchedCount: dispatched.length,
    timeString,
    dateString,
    dispatched,
  };
}

/**
 * Memeriksa dan mengirimkan pengingat untuk semua user yang terdaftar
 */
export async function checkAndDispatchAllReminders(db, options = {}) {
  // Ambil semua pengguna yang mengaktifkan pengingat (termasuk user yang memakai pengaturan default)
  const rows = db.prepare(`
    SELECT DISTINCT u.id as user_id
    FROM users u
    LEFT JOIN reminder_settings rs ON rs.user_id = u.id
    WHERE (rs.is_enabled = 1 OR rs.is_enabled IS NULL)
  `).all();

  const results = [];
  let totalDispatched = 0;

  for (const row of rows) {
    const settings = getReminderSettings(db, row.user_id);
    const res = await checkAndDispatchRemindersForUser(db, settings, options);
    results.push(res);
    if (res.dispatchedCount) {
      totalDispatched += res.dispatchedCount;
    }
  }

  return {
    timestamp: new Date().toISOString(),
    totalUsersChecked: rows.length,
    totalDispatched,
    results,
  };
}

/**
 * Kelas Pengelola Background Scheduler
 */
export class ReminderScheduler {
  constructor() {
    this.intervalId = null;
    this.intervalMs = 60000; // 1 menit default
    this.dbGetter = null;
    this.senderFn = defaultNotificationSender;
    this.lastTickAt = null;
    this.lastResult = null;
    this.totalTicks = 0;
    this.totalDispatched = 0;
  }

  /**
   * Menjalankan loop penjadwal otomatis
   */
  start({ intervalMs = 60000, dbGetter, senderFn = defaultNotificationSender } = {}) {
    if (this.intervalId) {
      return this; // Sudah berjalan
    }

    this.intervalMs = intervalMs;
    this.dbGetter = dbGetter;
    this.senderFn = senderFn;

    this.intervalId = setInterval(async () => {
      await this.tick();
    }, this.intervalMs);

    // Agar tidak memblokir process exit pada test runners
    if (this.intervalId.unref) {
      this.intervalId.unref();
    }

    return this;
  }

  /**
   * Menghentikan background scheduler
   */
  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
    return this;
  }

  /**
   * Status scheduler
   */
  isRunning() {
    return this.intervalId !== null;
  }

  /**
   * Mengambil status lengkap scheduler
   */
  getStatus() {
    return {
      isRunning: this.isRunning(),
      intervalMs: this.intervalMs,
      totalTicks: this.totalTicks,
      totalDispatched: this.totalDispatched,
      lastTickAt: this.lastTickAt,
      lastResult: this.lastResult,
    };
  }

  /**
   * Menjalankan 1 siklus pemeriksaan waktu
   */
  async tick() {
    if (!this.dbGetter) return null;
    this.totalTicks += 1;
    this.lastTickAt = new Date().toISOString();

    try {
      const db = this.dbGetter();
      const res = await checkAndDispatchAllReminders(db, {
        senderFn: this.senderFn,
      });
      this.lastResult = res;
      this.totalDispatched += res.totalDispatched || 0;
      return res;
    } catch (err) {
      this.lastResult = { error: err.message, timestamp: this.lastTickAt };
      return this.lastResult;
    }
  }

  /**
   * Memicu evaluasi pengingat secara langsung (manual trigger)
   */
  async triggerNow(db, options = {}) {
    this.lastTickAt = new Date().toISOString();
    const res = await checkAndDispatchAllReminders(db, {
      ...options,
      senderFn: this.senderFn,
    });
    this.lastResult = res;
    this.totalDispatched += res.totalDispatched || 0;
    return res;
  }
}

// Global Singleton Instance
export const globalReminderScheduler = new ReminderScheduler();
