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

/**
 * Helper untuk memvalidasi dan mengekstrak userId dari request
 */
export function resolveUserIdFromRequest(db, req) {
  const rawId = req.query?.userId || req.headers?.['x-user-id'] || req.body?.userId;
  if (rawId !== undefined && rawId !== null && rawId !== '') {
    const num = Number(rawId);
    if (isNaN(num) || num <= 0 || !Number.isInteger(num)) {
      throw new Error('Parameter userId harus berupa bilangan bulat positif.');
    }
    return num;
  }
  return getOrCreateDefaultUser(db);
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
