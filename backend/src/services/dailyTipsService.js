/**
 * Daily Tips Service (Layanan Tips Harian & Rekomendasi Hemat)
 *
 * Mengelola tabel `daily_tips` dan tracking status penerapan tips per pengguna `user_saving_tips`.
 */

import { defaultSavingTips } from '../db/migrate.js';

export function getTodayDateString() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Mengambil daftar master tips hemat
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} [options]
 * @param {string} [options.category]
 * @param {boolean} [options.activeOnly=true]
 * @param {number} [options.limit=50]
 * @param {number} [options.offset=0]
 * @returns {Array<Object>}
 */
export function getAllTips(db, { category = null, activeOnly = true, limit = 50, offset = 0 } = {}) {
  let query = 'SELECT * FROM daily_tips WHERE 1=1';
  const params = [];

  if (activeOnly) {
    query += ' AND is_active = 1';
  }
  if (category && category !== 'Semua') {
    query += ' AND category = ?';
    params.push(category);
  }

  query += ' ORDER BY id ASC LIMIT ? OFFSET ?';
  params.push(limit, offset);

  const rows = db.prepare(query).all(...params);
  return rows.map(formatTipRow);
}

/**
 * Mengambil satu master tip berdasarkan ID
 *
 * @param {import('better-sqlite3').Database} db
 * @param {number|string} id
 * @returns {Object|null}
 */
export function getTipById(db, id) {
  const row = db.prepare('SELECT * FROM daily_tips WHERE id = ?').get(id);
  return row ? formatTipRow(row) : null;
}

/**
 * Mengambil tips harian beserta status penerapan (isApplied) untuk user dan tanggal tertentu
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} params
 * @param {number|string} params.userId
 * @param {string} [params.date] - Format YYYY-MM-DD (default hari ini)
 * @param {string} [params.category]
 * @param {boolean} [params.isApplied]
 * @returns {Array<Object>}
 */
export function getUserSavingTips(db, { userId, date = null, category = null, isApplied = null } = {}) {
  if (!userId) {
    throw new Error('userId is required to query user saving tips');
  }

  const queryDate = date || getTodayDateString();

  let query = `
    SELECT
      dt.id,
      dt.title,
      dt.category,
      dt.description,
      dt.potential_saving,
      dt.impact_level,
      dt.icon,
      dt.action_text,
      dt.is_active,
      dt.created_at,
      dt.updated_at,
      COALESCE(ust.is_applied, 0) AS is_applied,
      ust.applied_at,
      COALESCE(ust.date, ?) AS user_tip_date
    FROM daily_tips dt
    LEFT JOIN user_saving_tips ust
      ON ust.tip_id = dt.id
      AND ust.user_id = ?
      AND ust.date = ?
    WHERE dt.is_active = 1
  `;
  const params = [queryDate, userId, queryDate];

  if (category && category !== 'Semua') {
    query += ' AND dt.category = ?';
    params.push(category);
  }

  if (isApplied !== null && isApplied !== undefined) {
    query += ' AND COALESCE(ust.is_applied, 0) = ?';
    params.push(isApplied ? 1 : 0);
  }

  query += ' ORDER BY dt.id ASC';

  const rows = db.prepare(query).all(...params);
  return rows.map((row) => ({
    id: row.id,
    title: row.title,
    category: row.category,
    description: row.description,
    potentialSaving: Number(row.potential_saving) || 0,
    impactLevel: row.impact_level,
    icon: row.icon || 'lightbulb_outline_rounded',
    actionText: row.action_text || 'Terapkan Hari Ini',
    isApplied: Boolean(row.is_applied),
    appliedAt: row.applied_at || null,
    date: row.user_tip_date,
    isActive: Boolean(row.is_active),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }));
}

/**
 * Mengubah status penerapan (toggle) tip untuk user pada tanggal tertentu
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} params
 * @param {number|string} params.userId
 * @param {number|string} params.tipId
 * @param {boolean} params.isApplied
 * @param {string} [params.date]
 * @returns {Object} Tip yang telah diperbarui
 */
export function toggleUserSavingTip(db, { userId, tipId, isApplied, date = null }) {
  if (!userId || !tipId) {
    throw new Error('userId and tipId are required to toggle saving tip');
  }

  const queryDate = date || getTodayDateString();
  const appliedValue = isApplied ? 1 : 0;
  const appliedAtValue = isApplied ? new Date().toISOString() : null;

  const upsertStmt = db.prepare(`
    INSERT INTO user_saving_tips (user_id, tip_id, is_applied, applied_at, date, updated_at)
    VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(user_id, tip_id, date) DO UPDATE SET
      is_applied = excluded.is_applied,
      applied_at = excluded.applied_at,
      updated_at = CURRENT_TIMESTAMP
  `);

  upsertStmt.run(userId, tipId, appliedValue, appliedAtValue, queryDate);

  const tips = getUserSavingTips(db, { userId, date: queryDate });
  const updated = tips.find((t) => Number(t.id) === Number(tipId));
  return updated || null;
}

/**
 * Membuat master tip baru
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} tipData
 * @returns {Object}
 */
export function createDailyTip(db, {
  title,
  category = 'Umum',
  description,
  potentialSaving = 0,
  impactLevel = 'Sedang',
  icon = 'lightbulb_outline_rounded',
  actionText = 'Terapkan Hari Ini',
  isActive = 1,
}) {
  if (!title || !description) {
    throw new Error('title and description are required to create a daily tip');
  }

  const stmt = db.prepare(`
    INSERT INTO daily_tips (title, category, description, potential_saving, impact_level, icon, action_text, is_active)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `);

  const res = stmt.run(
    title,
    category,
    description,
    Math.max(0, Number(potentialSaving) || 0),
    impactLevel,
    icon,
    actionText,
    isActive ? 1 : 0
  );

  return getTipById(db, res.lastInsertRowid);
}

/**
 * Format baris tabel daily_tips
 */
function formatTipRow(row) {
  return {
    id: row.id,
    title: row.title,
    category: row.category,
    description: row.description,
    potentialSaving: Number(row.potential_saving) || 0,
    impactLevel: row.impact_level,
    icon: row.icon || 'lightbulb_outline_rounded',
    actionText: row.action_text || 'Terapkan Hari Ini',
    isActive: Boolean(row.is_active),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
