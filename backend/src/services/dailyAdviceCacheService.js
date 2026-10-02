/**
 * Daily Advice Cache Service (Layanan Cache Saran Pengeluaran Harian)
 *
 * Mengelola penyimpanan cache saran harian pada tabel `daily_advice_cache` /
 * view `cache_saran` & `saran_cache` di SQLite.
 */

import { env } from '../config/env.js';

export function getTodayDateString() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Mengambil cache saran pengeluaran harian untuk user tertentu
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} params
 * @param {number|string} params.userId
 * @param {string} [params.date] - Format YYYY-MM-DD
 * @param {boolean} [params.allowStale=false]
 * @returns {Object|null}
 */
export function getCachedDailyAdvice(db, { userId, date = null, allowStale = false }) {
  if (!userId) {
    throw new Error('userId is required to query daily advice cache');
  }

  const queryDate = date || getTodayDateString();

  const stmt = db.prepare(`
    SELECT *
    FROM daily_advice_cache
    WHERE user_id = ? AND date = ?
    ORDER BY id DESC
    LIMIT 1
  `);

  const row = stmt.get(userId, queryDate);
  if (!row) {
    return null;
  }

  const now = new Date();
  const isExpired = row.expires_at ? new Date(row.expires_at) < now : false;
  const isStale = Boolean(row.is_stale);

  if (!allowStale && (isStale || isExpired)) {
    return null;
  }

  let parsedAdviceDetails = null;
  if (row.advice_json) {
    try {
      parsedAdviceDetails = JSON.parse(row.advice_json);
    } catch {
      parsedAdviceDetails = null;
    }
  }

  return {
    id: row.id,
    userId: row.user_id,
    date: row.date,
    recommendedDailyBudget: Number(row.recommended_daily_budget) || 0,
    estimatedDaysLeft: Number(row.estimated_days_left) || 0,
    dailyAdvice: row.daily_advice || '',
    warnLevel: row.warn_level || 'normal',
    avgDailySpend: Number(row.avg_daily_spend) || 0,
    totalMonthlyBudget: Number(row.total_monthly_budget) || 0,
    totalSpent: Number(row.total_spent) || 0,
    remainingBalance: Number(row.remaining_balance) || 0,
    source: row.source || 'rule_based',
    adviceJson: row.advice_json,
    adviceDetails: parsedAdviceDetails,
    isApplied: Boolean(row.is_applied),
    isStale: isStale || isExpired,
    isExpired,
    expiresAt: row.expires_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/**
 * Menyimpan atau meng-upsert saran harian ke dalam cache
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} params
 * @returns {Object}
 */
export function saveCachedDailyAdvice(db, {
  userId,
  date = null,
  recommendedDailyBudget = 0,
  estimatedDaysLeft = 0,
  dailyAdvice = '',
  warnLevel = 'normal',
  avgDailySpend = 0,
  totalMonthlyBudget = 0,
  totalSpent = 0,
  remainingBalance = 0,
  source = 'rule_based',
  adviceJson = null,
  isApplied = 0,
  ttlHours = env.DAILY_ADVICE_CACHE_TTL_HOURS,
  isStale = 0,
}) {
  if (!userId) {
    throw new Error('userId is required to save daily advice cache');
  }

  const saveDate = date || getTodayDateString();

  let serializedJson = null;
  if (typeof adviceJson === 'string') {
    serializedJson = adviceJson;
  } else if (adviceJson && typeof adviceJson === 'object') {
    serializedJson = JSON.stringify(adviceJson);
  }

  const validWarnLevels = ['normal', 'warning', 'critical'];
  const sanitizedWarnLevel = validWarnLevels.includes(warnLevel) ? warnLevel : 'normal';

  const validSources = ['rule_based', 'ai_generated', 'hybrid', 'fallback'];
  const sanitizedSource = validSources.includes(source) ? source : 'rule_based';

  const expiresDate = new Date(Date.now() + ttlHours * 60 * 60 * 1000);
  const expiresAt = expiresDate.toISOString();

  const upsertStmt = db.prepare(`
    INSERT INTO daily_advice_cache (
      user_id, date, recommended_daily_budget, estimated_days_left, daily_advice,
      warn_level, avg_daily_spend, total_monthly_budget, total_spent,
      remaining_balance, source, advice_json, is_applied, is_stale, expires_at, updated_at
    )
    VALUES (
      @userId, @date, @recommendedDailyBudget, @estimatedDaysLeft, @dailyAdvice,
      @warnLevel, @avgDailySpend, @totalMonthlyBudget, @totalSpent,
      @remainingBalance, @source, @adviceJson, @isApplied, @isStale, @expiresAt, CURRENT_TIMESTAMP
    )
    ON CONFLICT(user_id, date) DO UPDATE SET
      recommended_daily_budget = excluded.recommended_daily_budget,
      estimated_days_left = excluded.estimated_days_left,
      daily_advice = excluded.daily_advice,
      warn_level = excluded.warn_level,
      avg_daily_spend = excluded.avg_daily_spend,
      total_monthly_budget = excluded.total_monthly_budget,
      total_spent = excluded.total_spent,
      remaining_balance = excluded.remaining_balance,
      source = excluded.source,
      advice_json = excluded.advice_json,
      is_applied = excluded.is_applied,
      is_stale = excluded.is_stale,
      expires_at = excluded.expires_at,
      updated_at = CURRENT_TIMESTAMP
  `);

  upsertStmt.run({
    userId,
    date: saveDate,
    recommendedDailyBudget: Math.max(0, Number(recommendedDailyBudget) || 0),
    estimatedDaysLeft: Math.max(0, Math.floor(Number(estimatedDaysLeft) || 0)),
    dailyAdvice: dailyAdvice || '',
    warnLevel: sanitizedWarnLevel,
    avgDailySpend: Math.max(0, Number(avgDailySpend) || 0),
    totalMonthlyBudget: Math.max(0, Number(totalMonthlyBudget) || 0),
    totalSpent: Math.max(0, Number(totalSpent) || 0),
    remainingBalance: Number(remainingBalance) || 0,
    source: sanitizedSource,
    adviceJson: serializedJson,
    isApplied: isApplied ? 1 : 0,
    isStale: isStale ? 1 : 0,
    expiresAt,
  });

  return getCachedDailyAdvice(db, { userId, date: saveDate, allowStale: true });
}

/**
 * Menandai saran harian sebagai diterapkan (applied) oleh user
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} params
 * @param {number|string} params.userId
 * @param {string} [params.date]
 * @param {boolean} [params.isApplied=true]
 * @returns {Object|null}
 */
export function markAdviceAsApplied(db, { userId, date = null, isApplied = true }) {
  if (!userId) {
    throw new Error('userId is required to mark advice as applied');
  }

  const queryDate = date || getTodayDateString();

  const stmt = db.prepare(`
    UPDATE daily_advice_cache
    SET is_applied = ?, updated_at = CURRENT_TIMESTAMP
    WHERE user_id = ? AND date = ?
  `);

  stmt.run(isApplied ? 1 : 0, userId, queryDate);

  return getCachedDailyAdvice(db, { userId, date: queryDate, allowStale: true });
}

/**
 * Menandai cache saran harian sebagai stale (basi)
 *
 * @param {import('better-sqlite3').Database} db
 * @param {number|string} userId
 * @param {string} [date]
 * @returns {number}
 */
export function invalidateDailyAdviceCache(db, userId, date = null) {
  if (!userId) {
    throw new Error('userId is required to invalidate advice cache');
  }

  if (date) {
    const stmt = db.prepare(`
      UPDATE daily_advice_cache
      SET is_stale = 1, updated_at = CURRENT_TIMESTAMP
      WHERE user_id = ? AND date = ?
    `);
    const res = stmt.run(userId, date);
    return res.changes;
  }

  const stmt = db.prepare(`
    UPDATE daily_advice_cache
    SET is_stale = 1, updated_at = CURRENT_TIMESTAMP
    WHERE user_id = ?
  `);
  const res = stmt.run(userId);
  return res.changes;
}

/**
 * Menghapus cache saran harian
 *
 * @param {import('better-sqlite3').Database} db
 * @param {number|string} userId
 * @param {string} [date]
 * @returns {number}
 */
export function deleteCachedDailyAdvice(db, userId, date = null) {
  if (!userId) {
    throw new Error('userId is required to delete advice cache');
  }

  if (date) {
    const stmt = db.prepare('DELETE FROM daily_advice_cache WHERE user_id = ? AND date = ?');
    const res = stmt.run(userId, date);
    return res.changes;
  }

  const stmt = db.prepare('DELETE FROM daily_advice_cache WHERE user_id = ?');
  const res = stmt.run(userId);
  return res.changes;
}

/**
 * Cek apakah ada cache saran harian yang valid
 *
 * @param {import('better-sqlite3').Database} db
 * @param {number|string} userId
 * @param {string} [date]
 * @returns {boolean}
 */
export function hasValidCachedDailyAdvice(db, userId, date = null) {
  const cached = getCachedDailyAdvice(db, { userId, date, allowStale: false });
  return cached !== null;
}
