/**
 * Reminder Settings Controller (Controller Pengaturan Pengingat Harian & Notifikasi AI)
 *
 * Menyediakan endpoint HTTP untuk mengelola preferensi pengingat dan notifikasi harian:
 * - GET  /api/pengaturan-pengingat (mengambil preferensi pengingat pengguna)
 * - PUT & PATCH /api/pengaturan-pengingat (memperbarui preferensi pengingat)
 * - POST /api/pengaturan-pengingat/reset (mereset ke pengaturan default)
 * - POST /api/pengaturan-pengingat/test (simulasi notifikasi uji coba)
 */

import { getDatabase } from '../config/database.js';
import { getOrCreateDefaultUser } from './chatController.js';
import {
  getReminderSettings,
  updateReminderSettings,
  resetReminderSettings,
  DEFAULT_REMINDER_SETTINGS,
} from '../services/reminderSettingsService.js';
import { getSafeDailySpendingForUser } from '../services/safeDailySpendingService.js';
import { formatRupiah } from '../services/dailyAverageSpendingService.js';
import {
  createNotificationLog,
  getNotificationLogs,
  deleteNotificationLog,
  checkAndDispatchRemindersForUser,
  checkAndDispatchAllReminders,
  globalReminderScheduler,
} from '../services/reminderSchedulerService.js';

/**
 * Helper untuk memvalidasi dan mengekstrak userId dari request
 */
export function resolveUserIdFromRequest(db, req) {
  const rawId = req.userId || req.query?.userId || req.headers?.['x-user-id'] || req.body?.userId;
  if (rawId !== undefined && rawId !== null && rawId !== '') {
    const num = Number(rawId);
    if (isNaN(num) || num <= 0 || !Number.isInteger(num)) {
      throw new Error('Parameter userId harus berupa bilangan bulat positif.');
    }
    return num;
  }
  return getOrCreateDefaultUser(db, req.userId);
}

/**
 * Format ringkasan hari aktif dalam Bahasa Indonesia
 */
function formatActiveDaysSummary(activeDays = [1, 2, 3, 4, 5, 6, 7]) {
  if (!Array.isArray(activeDays) || activeDays.length === 0) return 'Tidak Aktif';
  if (activeDays.length === 7) return 'Setiap Hari';

  const isWorkdays = activeDays.length === 5 &&
    [1, 2, 3, 4, 5].every((d) => activeDays.includes(d));
  if (isWorkdays) return 'Hari Kerja (Sen - Jum)';

  const isWeekend = activeDays.length === 2 &&
    activeDays.includes(6) && activeDays.includes(7);
  if (isWeekend) return 'Akhir Pekan (Sab - Min)';

  const dayNames = {
    1: 'Sen', 2: 'Sel', 3: 'Rab', 4: 'Kam', 5: 'Jum', 6: 'Sab', 7: 'Min',
  };
  const sorted = [...activeDays].sort((a, b) => a - b);
  return sorted.map((d) => dayNames[d] || '').filter(Boolean).join(', ');
}

/**
 * Format payload reminder settings lengkap untuk Flutter
 */
function formatSettingsPayload(settings) {
  const morningFormatted = `${settings.morningReminderTime} WIB`;
  const eveningFormatted = `${settings.eveningReminderTime} WIB`;
  const activeDaysSummary = formatActiveDaysSummary(settings.activeDays);

  return {
    ...settings,
    morningTimeFormatted: morningFormatted,
    eveningTimeFormatted: eveningFormatted,
    activeDaysSummary,
    // CamelCase aliases
    is_enabled: settings.isEnabled,
    morning_reminder_time: settings.morningReminderTime,
    is_morning_reminder_enabled: settings.isMorningReminderEnabled,
    evening_reminder_time: settings.eveningReminderTime,
    is_evening_reminder_enabled: settings.isEveningReminderEnabled,
    active_days: settings.activeDays,
    notify_on_overbudget: settings.notifyOnOverbudget,
    notify_saving_tips: settings.notifySavingTips,
    notify_debt_due: settings.notifyDebtDue,
    sound_enabled: settings.soundEnabled,
    vibration_enabled: settings.vibrationEnabled,
    fcm_token: settings.fcmToken,
  };
}

/**
 * GET /api/pengaturan-pengingat & GET /api/reminders/settings
 * Mengambil preferensi pengingat harian pengguna
 */
export function getReminderSettingsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);

    const settings = getReminderSettings(db, userId);
    const payload = formatSettingsPayload(settings);

    return res.status(200).json({
      success: true,
      userId,
      settings: payload,
      data: payload,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat memuat pengaturan pengingat.',
    });
  }
}

/**
 * PUT & PATCH /api/pengaturan-pengingat
 * Memperbarui preferensi pengingat harian pengguna
 */
export function updateReminderSettingsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const body = req.body || {};

    // Validasi format waktu jika dikirim (HH:MM)
    const timeRegex = /^([01]\d|2[0-3]):([0-5]\d)$/;
    if (body.morningReminderTime && !timeRegex.test(body.morningReminderTime)) {
      return res.status(400).json({
        success: false,
        error: 'Format morningReminderTime harus berupa jam 24-format (HH:MM), contoh: 08:00.',
      });
    }
    if (body.eveningReminderTime && !timeRegex.test(body.eveningReminderTime)) {
      return res.status(400).json({
        success: false,
        error: 'Format eveningReminderTime harus berupa jam 24-format (HH:MM), contoh: 20:00.',
      });
    }

    // Validasi activeDays jika dikirim
    if (body.activeDays !== undefined) {
      if (!Array.isArray(body.activeDays) || body.activeDays.length === 0) {
        return res.status(400).json({
          success: false,
          error: 'activeDays harus berupa array minimal 1 hari aktif (1=Senin s/d 7=Minggu).',
        });
      }
      const validDays = body.activeDays.every((d) => Number.isInteger(d) && d >= 1 && d <= 7);
      if (!validDays) {
        return res.status(400).json({
          success: false,
          error: 'Hari aktif pada activeDays harus berupa angka integer antara 1 dan 7.',
        });
      }
    }

    const updated = updateReminderSettings(db, userId, body);
    const payload = formatSettingsPayload(updated);

    return res.status(200).json({
      success: true,
      message: 'Pengaturan pengingat harian berhasil diperbarui.',
      userId,
      settings: payload,
      data: payload,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat memperbarui pengaturan pengingat.',
    });
  }
}

/**
 * POST /api/pengaturan-pengingat/reset
 * Mereset preferensi pengingat harian ke nilai default
 */
export function resetReminderSettingsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);

    const reset = resetReminderSettings(db, userId);
    const payload = formatSettingsPayload(reset);

    return res.status(200).json({
      success: true,
      message: 'Pengaturan pengingat harian berhasil direset ke pengaturan awal.',
      userId,
      settings: payload,
      data: payload,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat mereset pengaturan pengingat.',
    });
  }
}

/**
 * POST /api/pengaturan-pengingat/test
 * Menyimulasikan notifikasi pengingat harian (misal: push notifikasi pagi atau malam)
 */
export function testReminderNotificationHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const type = (req.body?.type || req.query?.type || 'morning').toLowerCase();

    const spending = getSafeDailySpendingForUser(db, { userId, autoCache: false });
    const limitFormatted = formatRupiah(spending.safeDailyLimit || 65000);

    let notification;
    if (type === 'evening') {
      notification = {
        title: 'Moneta AI • Catat Pengeluaran Malam Ini',
        body: 'Luangkan 1 menit untuk mencatat transaksi hari ini agar saldo dan analisa keuangan Anda tetap akurat.',
        type: 'evening_reminder',
        scheduledTime: '20:00',
        data: {
          screen: '/beranda',
          action: 'open_chat',
        },
      };
    } else {
      notification = {
        title: 'Moneta AI • Saran Belanja Hari Ini',
        body: `Batas belanja aman Anda hari ini ${limitFormatted}. Ketuk untuk membuka Beranda dan melihat saran lengkap.`,
        type: 'morning_advice',
        scheduledTime: '08:00',
        data: {
          screen: '/beranda',
          safeDailyLimit: spending.safeDailyLimit,
          remainingDays: spending.remainingDays,
        },
      };
    }

    // Catat ke notification_logs
    try {
      createNotificationLog(db, {
        userId,
        type: notification.type,
        title: notification.title,
        body: notification.body,
        payload: notification.data,
        scheduledTime: notification.scheduledTime,
        status: 'delivered',
      });
    } catch {
      // Non-fatal
    }

    return res.status(200).json({
      success: true,
      message: 'Notifikasi percobaan pengingat harian berhasil disimulasikan.',
      userId,
      type,
      notification,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat menguji notifikasi pengingat.',
    });
  }
}

/**
 * POST /api/pengaturan-pengingat/scheduler/trigger
 * Memicu eksekusi scheduler pengingat harian secara manual atau terjadwal
 */
export async function triggerReminderSchedulerHandler(req, res) {
  try {
    const db = getDatabase();
    const body = req.body || {};
    const query = req.query || {};

    const specificUserId = body.userId || query.userId;
    const simulatedTime = body.time || body.simulatedTime || query.time;
    const simulatedDate = body.date || body.simulatedDate || query.date;
    const simulatedDay = body.dayOfWeek || query.dayOfWeek;
    const force = Boolean(body.force !== undefined ? body.force : query.force === 'true');
    const type = body.type || query.type;

    let result;

    if (specificUserId) {
      const numUserId = Number(specificUserId);
      if (isNaN(numUserId) || numUserId <= 0) {
        return res.status(400).json({
          success: false,
          error: 'Parameter userId harus berupa bilangan bulat positif.',
        });
      }
      const settings = getReminderSettings(db, numUserId);
      const userRes = await checkAndDispatchRemindersForUser(db, settings, {
        force,
        targetType: type,
        simulatedTime,
        simulatedDate,
        simulatedDay,
      });

      result = {
        totalUsersChecked: 1,
        totalDispatched: userRes.dispatchedCount || 0,
        results: [userRes],
      };
    } else {
      result = await checkAndDispatchAllReminders(db, {
        force,
        targetType: type,
        simulatedTime,
        simulatedDate,
        simulatedDay,
      });
    }

    return res.status(200).json({
      success: true,
      message: `Pemeriksaan pengingat harian selesai. ${result.totalDispatched} notifikasi dikirimkan.`,
      ...result,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat memicu scheduler pengingat.',
    });
  }
}

/**
 * GET /api/pengaturan-pengingat/scheduler/status
 * Mengambil status operasional background scheduler
 */
export function getReminderSchedulerStatusHandler(req, res) {
  try {
    const status = globalReminderScheduler.getStatus();
    return res.status(200).json({
      success: true,
      scheduler: status,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat membaca status scheduler.',
    });
  }
}

/**
 * POST /api/pengaturan-pengingat/scheduler/start
 * Memulai background loop scheduler pengingat
 */
export function startReminderSchedulerHandler(req, res) {
  try {
    const intervalMs = Number(req.body?.intervalMs || req.query?.intervalMs) || 60000;
    globalReminderScheduler.start({
      intervalMs,
      dbGetter: getDatabase,
    });

    return res.status(200).json({
      success: true,
      message: `Background scheduler pengingat harian berhasil dimulai (interval: ${intervalMs}ms).`,
      scheduler: globalReminderScheduler.getStatus(),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message || 'Gagal memulai background scheduler.',
    });
  }
}

/**
 * POST /api/pengaturan-pengingat/scheduler/stop
 * Menghentikan background loop scheduler pengingat
 */
export function stopReminderSchedulerHandler(req, res) {
  try {
    globalReminderScheduler.stop();
    return res.status(200).json({
      success: true,
      message: 'Background scheduler pengingat harian berhasil dihentikan.',
      scheduler: globalReminderScheduler.getStatus(),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message || 'Gagal menghentikan background scheduler.',
    });
  }
}

/**
 * GET /api/pengaturan-pengingat/notifikasi & GET /api/notifikasi
 * Mengambil riwayat log notifikasi untuk pengguna
 */
export function getNotificationHistoryHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const type = req.query?.type;
    const limit = Number(req.query?.limit) || 50;
    const offset = Number(req.query?.offset) || 0;

    const notifications = getNotificationLogs(db, { userId, type, limit, offset });

    const totalCount = db.prepare(`
      SELECT COUNT(*) as count FROM notification_logs WHERE user_id = ?
    `).get(userId)?.count || 0;

    return res.status(200).json({
      success: true,
      userId,
      total: totalCount,
      limit,
      offset,
      notifications,
      data: notifications,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Gagal memuat riwayat notifikasi.',
    });
  }
}

/**
 * DELETE /api/pengaturan-pengingat/notifikasi/:id & DELETE /api/notifikasi/:id
 * Menghapus satu atau seluruh entri log notifikasi
 */
export function deleteNotificationHistoryHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const id = req.params?.id;

    const deleted = deleteNotificationLog(db, { userId, id });

    return res.status(200).json({
      success: true,
      message: id ? 'Log notifikasi berhasil dihapus.' : 'Seluruh log notifikasi berhasil dibersihkan.',
      deleted,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Gagal menghapus log notifikasi.',
    });
  }
}
