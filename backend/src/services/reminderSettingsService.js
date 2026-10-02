/**
 * Reminder Settings Service (Layanan Pengaturan Pengingat Harian & Notifikasi AI)
 *
 * Mengelola tabel `reminder_settings` per pengguna di SQLite.
 */

import { env } from '../config/env.js';

export const DEFAULT_REMINDER_SETTINGS = {
  isEnabled: true,
  morningReminderTime: env.DEFAULT_MORNING_REMINDER_TIME,
  isMorningReminderEnabled: true,
  eveningReminderTime: env.DEFAULT_EVENING_REMINDER_TIME,
  isEveningReminderEnabled: true,
  activeDays: [1, 2, 3, 4, 5, 6, 7],
  notifyOnOverbudget: true,
  notifySavingTips: true,
  notifyDebtDue: true,
  soundEnabled: true,
  vibrationEnabled: true,
  fcmToken: null,
  timezone: env.DEFAULT_TIMEZONE,
};

/**
 * Mengambil pengaturan pengingat untuk user.
 * Jika belum ada, otomatis membuatkan record default untuk user tersebut.
 *
 * @param {import('better-sqlite3').Database} db
 * @param {number|string} userId
 * @returns {Object}
 */
export function getReminderSettings(db, userId) {
  if (!userId) {
    throw new Error('userId is required to get reminder settings');
  }

  const stmt = db.prepare('SELECT * FROM reminder_settings WHERE user_id = ?');
  let row = stmt.get(userId);

  if (!row) {
    // Inisialisasi default settings
    const insertStmt = db.prepare(`
      INSERT INTO reminder_settings (
        user_id, is_enabled, morning_reminder_time, is_morning_reminder_enabled,
        evening_reminder_time, is_evening_reminder_enabled, active_days,
        notify_on_overbudget, notify_saving_tips, notify_debt_due,
        sound_enabled, vibration_enabled, fcm_token, timezone
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    insertStmt.run(
      userId,
      DEFAULT_REMINDER_SETTINGS.isEnabled ? 1 : 0,
      DEFAULT_REMINDER_SETTINGS.morningReminderTime,
      DEFAULT_REMINDER_SETTINGS.isMorningReminderEnabled ? 1 : 0,
      DEFAULT_REMINDER_SETTINGS.eveningReminderTime,
      DEFAULT_REMINDER_SETTINGS.isEveningReminderEnabled ? 1 : 0,
      JSON.stringify(DEFAULT_REMINDER_SETTINGS.activeDays),
      DEFAULT_REMINDER_SETTINGS.notifyOnOverbudget ? 1 : 0,
      DEFAULT_REMINDER_SETTINGS.notifySavingTips ? 1 : 0,
      DEFAULT_REMINDER_SETTINGS.notifyDebtDue ? 1 : 0,
      DEFAULT_REMINDER_SETTINGS.soundEnabled ? 1 : 0,
      DEFAULT_REMINDER_SETTINGS.vibrationEnabled ? 1 : 0,
      DEFAULT_REMINDER_SETTINGS.fcmToken,
      DEFAULT_REMINDER_SETTINGS.timezone
    );

    row = stmt.get(userId);
  }

  return formatReminderSettingsRow(row);
}

/**
 * Memperbarui pengaturan pengingat untuk user
 *
 * @param {import('better-sqlite3').Database} db
 * @param {number|string} userId
 * @param {Object} updates
 * @returns {Object}
 */
export function updateReminderSettings(db, userId, updates = {}) {
  if (!userId) {
    throw new Error('userId is required to update reminder settings');
  }

  // Ensure record exists
  getReminderSettings(db, userId);

  const current = getReminderSettings(db, userId);

  const updatedSettings = {
    isEnabled: updates.isEnabled !== undefined ? updates.isEnabled : (updates.is_enabled !== undefined ? updates.is_enabled : current.isEnabled),
    morningReminderTime: updates.morningReminderTime || updates.morning_reminder_time || current.morningReminderTime,
    isMorningReminderEnabled: updates.isMorningReminderEnabled !== undefined ? updates.isMorningReminderEnabled : (updates.is_morning_reminder_enabled !== undefined ? updates.is_morning_reminder_enabled : current.isMorningReminderEnabled),
    eveningReminderTime: updates.eveningReminderTime || updates.evening_reminder_time || current.eveningReminderTime,
    isEveningReminderEnabled: updates.isEveningReminderEnabled !== undefined ? updates.isEveningReminderEnabled : (updates.is_evening_reminder_enabled !== undefined ? updates.is_evening_reminder_enabled : current.isEveningReminderEnabled),
    activeDays: updates.activeDays || updates.active_days || current.activeDays,
    notifyOnOverbudget: updates.notifyOnOverbudget !== undefined ? updates.notifyOnOverbudget : (updates.notify_on_overbudget !== undefined ? updates.notify_on_overbudget : current.notifyOnOverbudget),
    notifySavingTips: updates.notifySavingTips !== undefined ? updates.notifySavingTips : (updates.notify_saving_tips !== undefined ? updates.notify_saving_tips : current.notifySavingTips),
    notifyDebtDue: updates.notifyDebtDue !== undefined ? updates.notifyDebtDue : (updates.notify_debt_due !== undefined ? updates.notify_debt_due : current.notifyDebtDue),
    soundEnabled: updates.soundEnabled !== undefined ? updates.soundEnabled : (updates.sound_enabled !== undefined ? updates.sound_enabled : current.soundEnabled),
    vibrationEnabled: updates.vibrationEnabled !== undefined ? updates.vibrationEnabled : (updates.vibration_enabled !== undefined ? updates.vibration_enabled : current.vibrationEnabled),
    fcmToken: updates.fcmToken !== undefined ? updates.fcmToken : (updates.fcm_token !== undefined ? updates.fcm_token : current.fcmToken),
    timezone: updates.timezone || current.timezone,
  };

  let activeDaysString = typeof updatedSettings.activeDays === 'string'
    ? updatedSettings.activeDays
    : JSON.stringify(updatedSettings.activeDays);

  const stmt = db.prepare(`
    UPDATE reminder_settings
    SET
      is_enabled = @isEnabled,
      morning_reminder_time = @morningReminderTime,
      is_morning_reminder_enabled = @isMorningReminderEnabled,
      evening_reminder_time = @eveningReminderTime,
      is_evening_reminder_enabled = @isEveningReminderEnabled,
      active_days = @activeDays,
      notify_on_overbudget = @notifyOnOverbudget,
      notify_saving_tips = @notifySavingTips,
      notify_debt_due = @notifyDebtDue,
      sound_enabled = @soundEnabled,
      vibration_enabled = @vibrationEnabled,
      fcm_token = @fcmToken,
      timezone = @timezone,
      updated_at = CURRENT_TIMESTAMP
    WHERE user_id = @userId
  `);

  stmt.run({
    userId,
    isEnabled: updatedSettings.isEnabled ? 1 : 0,
    morningReminderTime: updatedSettings.morningReminderTime,
    isMorningReminderEnabled: updatedSettings.isMorningReminderEnabled ? 1 : 0,
    eveningReminderTime: updatedSettings.eveningReminderTime,
    isEveningReminderEnabled: updatedSettings.isEveningReminderEnabled ? 1 : 0,
    activeDays: activeDaysString,
    notifyOnOverbudget: updatedSettings.notifyOnOverbudget ? 1 : 0,
    notifySavingTips: updatedSettings.notifySavingTips ? 1 : 0,
    notifyDebtDue: updatedSettings.notifyDebtDue ? 1 : 0,
    soundEnabled: updatedSettings.soundEnabled ? 1 : 0,
    vibrationEnabled: updatedSettings.vibrationEnabled ? 1 : 0,
    fcmToken: updatedSettings.fcmToken,
    timezone: updatedSettings.timezone,
  });

  return getReminderSettings(db, userId);
}

/**
 * Mereset pengaturan pengingat ke pengaturan awal (default)
 *
 * @param {import('better-sqlite3').Database} db
 * @param {number|string} userId
 * @returns {Object}
 */
export function resetReminderSettings(db, userId) {
  if (!userId) {
    throw new Error('userId is required to reset reminder settings');
  }

  const deleteStmt = db.prepare('DELETE FROM reminder_settings WHERE user_id = ?');
  deleteStmt.run(userId);

  return getReminderSettings(db, userId);
}

/**
 * Format baris tabel reminder_settings ke bentuk objek JavaScript ramah JSON
 */
function formatReminderSettingsRow(row) {
  let activeDays = [1, 2, 3, 4, 5, 6, 7];
  if (row.active_days) {
    try {
      activeDays = JSON.parse(row.active_days);
    } catch {
      activeDays = [1, 2, 3, 4, 5, 6, 7];
    }
  }

  return {
    id: row.id,
    userId: row.user_id,
    isEnabled: Boolean(row.is_enabled),
    morningReminderTime: row.morning_reminder_time || '08:00',
    isMorningReminderEnabled: Boolean(row.is_morning_reminder_enabled),
    eveningReminderTime: row.evening_reminder_time || '20:00',
    isEveningReminderEnabled: Boolean(row.is_evening_reminder_enabled),
    activeDays,
    notifyOnOverbudget: Boolean(row.notify_on_overbudget),
    notifySavingTips: Boolean(row.notify_saving_tips),
    notifyDebtDue: Boolean(row.notify_debt_due),
    soundEnabled: Boolean(row.sound_enabled),
    vibrationEnabled: Boolean(row.vibration_enabled),
    fcmToken: row.fcm_token || null,
    timezone: row.timezone || 'Asia/Jakarta',
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
