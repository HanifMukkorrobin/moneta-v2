/**
 * Analysis Cache Service (Layanan Cache Analisa Keuangan & AI Insights)
 *
 * Mengelola penyimpanan cache hasil kalkulasi analisa keuangan dan saran harian AI
 * pada tabel `ai_insights` / view `financial_analysis_cache` di SQLite.
 */

import { env } from '../config/env.js';

/**
 * Format tanggal hari ini (YYYY-MM-DD) sesuai lokalitas atau waktu server
 */
export function getTodayDateString() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Mengambil cache analisa keuangan untuk user tertentu pada tanggal tertentu
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} params
 * @param {number|string} params.userId
 * @param {string} [params.date] - Format YYYY-MM-DD (default: hari ini)
 * @param {boolean} [params.allowStale=false] - Jika true, mengabaikan status stale dan expired
 * @returns {Object|null}
 */
export function getCachedAnalysis(db, { userId, date = null, allowStale = false }) {
  if (!userId) {
    throw new Error('userId is required to query analysis cache');
  }

  const queryDate = date || getTodayDateString();

  const stmt = db.prepare(`
    SELECT *
    FROM ai_insights
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

  let parsedAnalysis = null;
  if (row.analysis_json) {
    try {
      parsedAnalysis = JSON.parse(row.analysis_json);
    } catch {
      parsedAnalysis = null;
    }
  }

  return {
    id: row.id,
    userId: row.user_id,
    date: row.date,
    avgDailySpend: Number(row.avg_daily_spend) || 0,
    estimatedDaysLeft: Number(row.estimated_days_left) || 0,
    dailyAdvice: row.daily_advice || '',
    warnLevel: row.warn_level || 'normal',
    recommendedDailyBudget: Number(row.recommended_daily_budget) || 0,
    totalMonthlyBudget: Number(row.total_monthly_budget) || 0,
    totalSpent: Number(row.total_spent) || 0,
    remainingBalance: Number(row.remaining_balance) || 0,
    analysisJson: row.analysis_json,
    analysis: parsedAnalysis,
    isStale: isStale || isExpired,
    isExpired,
    expiresAt: row.expires_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/**
 * Menyimpan atau memperbarui (upsert) hasil analisa ke tabel ai_insights cache
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} params
 * @param {number|string} params.userId
 * @param {string} [params.date]
 * @param {number} [params.avgDailySpend]
 * @param {number} [params.estimatedDaysLeft]
 * @param {string} [params.dailyAdvice]
 * @param {'normal'|'warning'|'critical'} [params.warnLevel]
 * @param {number} [params.recommendedDailyBudget]
 * @param {number} [params.totalMonthlyBudget]
 * @param {number} [params.totalSpent]
 * @param {number} [params.remainingBalance]
 * @param {string|Object} [params.analysis]
 * @param {number} [params.ttlHours=24]
 * @param {number} [params.isStale=0]
 * @returns {Object}
 */
export function saveCachedAnalysis(db, {
  userId,
  date = null,
  avgDailySpend = 0,
  estimatedDaysLeft = 0,
  dailyAdvice = '',
  warnLevel = 'normal',
  recommendedDailyBudget = 0,
  totalMonthlyBudget = 0,
  totalSpent = 0,
  remainingBalance = 0,
  analysis = null,
  ttlHours = env.ANALYSIS_CACHE_TTL_HOURS,
  isStale = 0,
}) {
  if (!userId) {
    throw new Error('userId is required to save analysis cache');
  }

  const saveDate = date || getTodayDateString();

  let serializedAnalysis = null;
  if (typeof analysis === 'string') {
    serializedAnalysis = analysis;
  } else if (analysis && typeof analysis === 'object') {
    serializedAnalysis = JSON.stringify(analysis);
  }

  const validWarnLevels = ['normal', 'warning', 'critical'];
  const sanitizedWarnLevel = validWarnLevels.includes(warnLevel) ? warnLevel : 'normal';

  const expiresDate = new Date(Date.now() + ttlHours * 60 * 60 * 1000);
  const expiresAt = expiresDate.toISOString();

  const upsertStmt = db.prepare(`
    INSERT INTO ai_insights (
      user_id, date, avg_daily_spend, estimated_days_left, daily_advice,
      warn_level, recommended_daily_budget, total_monthly_budget, total_spent,
      remaining_balance, analysis_json, is_stale, expires_at, updated_at
    )
    VALUES (
      @userId, @date, @avgDailySpend, @estimatedDaysLeft, @dailyAdvice,
      @warnLevel, @recommendedDailyBudget, @totalMonthlyBudget, @totalSpent,
      @remainingBalance, @analysisJson, @isStale, @expiresAt, CURRENT_TIMESTAMP
    )
    ON CONFLICT(user_id, date) DO UPDATE SET
      avg_daily_spend = excluded.avg_daily_spend,
      estimated_days_left = excluded.estimated_days_left,
      daily_advice = excluded.daily_advice,
      warn_level = excluded.warn_level,
      recommended_daily_budget = excluded.recommended_daily_budget,
      total_monthly_budget = excluded.total_monthly_budget,
      total_spent = excluded.total_spent,
      remaining_balance = excluded.remaining_balance,
      analysis_json = excluded.analysis_json,
      is_stale = excluded.is_stale,
      expires_at = excluded.expires_at,
      updated_at = CURRENT_TIMESTAMP
  `);

  upsertStmt.run({
    userId,
    date: saveDate,
    avgDailySpend: Math.max(0, Number(avgDailySpend) || 0),
    estimatedDaysLeft: Math.max(0, Math.floor(Number(estimatedDaysLeft) || 0)),
    dailyAdvice: dailyAdvice || '',
    warnLevel: sanitizedWarnLevel,
    recommendedDailyBudget: Math.max(0, Number(recommendedDailyBudget) || 0),
    totalMonthlyBudget: Math.max(0, Number(totalMonthlyBudget) || 0),
    totalSpent: Math.max(0, Number(totalSpent) || 0),
    remainingBalance: Number(remainingBalance) || 0,
    analysisJson: serializedAnalysis,
    isStale: isStale ? 1 : 0,
    expiresAt,
  });

  return getCachedAnalysis(db, { userId, date: saveDate, allowStale: true });
}

/**
 * Menandai cache analisa sebagai stale (basi) untuk memicu kalkulasi ulang
 *
 * @param {import('better-sqlite3').Database} db
 * @param {number|string} userId
 * @param {string} [date] - Opsional, bila ingin membatalkan tanggal spesifik saja
 * @returns {number} Jumlah baris yang terpengaruh
 */
export function invalidateAnalysisCache(db, userId, date = null) {
  if (!userId) {
    throw new Error('userId is required to invalidate analysis cache');
  }

  if (date) {
    const stmt = db.prepare(`
      UPDATE ai_insights
      SET is_stale = 1, updated_at = CURRENT_TIMESTAMP
      WHERE user_id = ? AND date = ?
    `);
    const res = stmt.run(userId, date);
    return res.changes;
  }

  const stmt = db.prepare(`
    UPDATE ai_insights
    SET is_stale = 1, updated_at = CURRENT_TIMESTAMP
    WHERE user_id = ?
  `);
  const res = stmt.run(userId);
  return res.changes;
}

/**
 * Menghapus cache analisa user
 *
 * @param {import('better-sqlite3').Database} db
 * @param {number|string} userId
 * @param {string} [date]
 * @returns {number}
 */
export function deleteCachedAnalysis(db, userId, date = null) {
  if (!userId) {
    throw new Error('userId is required to delete analysis cache');
  }

  if (date) {
    const stmt = db.prepare('DELETE FROM ai_insights WHERE user_id = ? AND date = ?');
    const res = stmt.run(userId, date);
    return res.changes;
  }

  const stmt = db.prepare('DELETE FROM ai_insights WHERE user_id = ?');
  const res = stmt.run(userId);
  return res.changes;
}

/**
 * Memeriksa apakah ada cache analisa yang masih valid (tidak basi & belum expired)
 *
 * @param {import('better-sqlite3').Database} db
 * @param {number|string} userId
 * @param {string} [date]
 * @returns {boolean}
 */
export function hasValidCachedAnalysis(db, userId, date = null) {
  const cached = getCachedAnalysis(db, { userId, date, allowStale: false });
  return cached !== null;
}
