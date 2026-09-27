/**
 * Daily Tips Service (Layanan Tips Harian & Rekomendasi Hemat)
 *
 * Mengelola tabel `daily_tips` dan tracking status penerapan tips per pengguna `user_saving_tips`.
 */

import { defaultSavingTips } from '../db/migrate.js';
import { formatRupiah } from './dailyAverageSpendingService.js';

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

const SHORT_MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

function toDateOnlyString(d) {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Format tanggal ramah tampilan ke Bahasa Indonesia (contoh: "Hari Ini, 27 Sep 2026", "Kemarin, 26 Sep 2026", "24 Sep 2026")
 *
 * @param {Date|string} dateInput
 * @param {Date|string} [referenceDate=new Date()]
 * @returns {string}
 */
export function formatTipDisplayDate(dateInput, referenceDate = new Date()) {
  if (!dateInput) return null;
  const d = new Date(dateInput);
  if (isNaN(d.getTime())) return String(dateInput);

  const ref = new Date(referenceDate);
  const todayStr = toDateOnlyString(ref);
  const yesterday = new Date(ref);
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayStr = toDateOnlyString(yesterday);

  const inputStr = toDateOnlyString(d);
  const day = d.getDate();
  const month = SHORT_MONTHS[d.getMonth()] || '';
  const year = d.getFullYear();

  if (inputStr === todayStr) {
    return `Hari Ini, ${day} ${month} ${year}`;
  } else if (inputStr === yesterdayStr) {
    return `Kemarin, ${day} ${month} ${year}`;
  } else {
    return `${day} ${month} ${year}`;
  }
}

/**
 * Mengambil riwayat tips hemat lengkap untuk pengguna
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} params
 * @param {number|string} params.userId
 * @param {string} [params.search]
 * @param {string} [params.status='semua']
 * @param {string} [params.category]
 * @param {Date|string} [params.referenceDate=new Date()]
 * @returns {Object}
 */
export function getUserTipsHistory(db, {
  userId,
  search = '',
  status = 'semua',
  category = null,
  referenceDate = new Date(),
} = {}) {
  if (!userId) {
    throw new Error('userId is required to query user tips history');
  }

  const queryDate = toDateOnlyString(new Date(referenceDate));

  // Ambil semua tips master yang aktif
  const tips = getUserSavingTips(db, {
    userId,
    date: queryDate,
    category: category && category !== 'Semua' ? category : null,
  });

  // Ambil seluruh riwayat tanggal penerapan unik pengguna di masa lalu jika ada
  const pastAppliedRows = db.prepare(`
    SELECT ust.tip_id, ust.date, ust.applied_at, dt.title, dt.category, dt.description,
           dt.potential_saving, dt.impact_level, dt.icon, dt.action_text, dt.is_active
    FROM user_saving_tips ust
    JOIN daily_tips dt ON dt.id = ust.tip_id
    WHERE ust.user_id = ? AND ust.is_applied = 1 AND ust.date != ?
    ORDER BY ust.date DESC, ust.applied_at DESC
  `).all(userId, queryDate);

  const allItems = [];

  // 1. Tambahkan item tips hari ini
  for (const t of tips) {
    allItems.push({
      ...t,
      formattedDate: formatTipDisplayDate(t.date || queryDate, referenceDate),
    });
  }

  // 2. Tambahkan riwayat hari-hari sebelumnya yang pernah diterapkan
  for (const row of pastAppliedRows) {
    allItems.push({
      id: `hist_${row.tip_id}_${row.date}`,
      tipId: row.tip_id,
      title: row.title,
      category: row.category,
      description: row.description,
      potentialSaving: Number(row.potential_saving) || 0,
      impactLevel: row.impact_level,
      icon: row.icon || 'lightbulb_outline_rounded',
      actionText: row.action_text || 'Terapkan Hari Ini',
      isApplied: true,
      appliedAt: row.applied_at,
      date: row.date,
      formattedDate: formatTipDisplayDate(row.date, referenceDate),
      isActive: Boolean(row.is_active),
    });
  }

  // 3. Filter berdasarkan status
  let filtered = allItems;
  const normalizedStatus = (status || 'semua').toLowerCase();
  if (normalizedStatus === 'diterapkan' || normalizedStatus === 'applied') {
    filtered = filtered.filter((t) => t.isApplied);
  } else if (normalizedStatus === 'belum_diterapkan' || normalizedStatus === 'unapplied') {
    filtered = filtered.filter((t) => !t.isApplied);
  }

  // 4. Filter berdasarkan search query
  if (search && search.trim()) {
    const q = search.toLowerCase().trim();
    filtered = filtered.filter((t) =>
      t.title.toLowerCase().includes(q) ||
      t.description.toLowerCase().includes(q) ||
      t.category.toLowerCase().includes(q)
    );
  }

  // 5. Kalkulasi metrik ringkasan
  const appliedCount = filtered.filter((t) => t.isApplied).length;
  const unappliedCount = filtered.filter((t) => !t.isApplied).length;
  const totalCount = filtered.length;
  const successRate = totalCount > 0 ? Math.round((appliedCount / totalCount) * 100) : 0;

  let totalAppliedSavings = 0;
  let totalPotentialSavingsAll = 0;
  for (const t of filtered) {
    totalPotentialSavingsAll += t.potentialSaving;
    if (t.isApplied) {
      totalAppliedSavings += t.potentialSaving;
    }
  }

  return {
    userId,
    status: normalizedStatus,
    category: category || 'Semua',
    search: search || '',
    count: filtered.length,
    summary: {
      appliedCount,
      unappliedCount,
      totalCount,
      totalAppliedSavings,
      formattedTotalAppliedSavings: formatRupiah(totalAppliedSavings),
      totalPotentialSavingsAll,
      formattedTotalPotentialSavingsAll: formatRupiah(totalPotentialSavingsAll),
      successRate,
      summaryText: `${appliedCount} dari ${totalCount} tips berhasil dijalankan`,
    },
    tips: filtered,
  };
}

