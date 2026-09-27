/**
 * Analysis Controller (Controller Analisa Keuangan AI)
 *
 * Menyediakan endpoint HTTP untuk analisa keuangan pengguna:
 * - GET /api/analisa (analisa lengkap terfilter per pengguna)
 * - GET /api/analisa/summary (ringkasan eksekutif analisa)
 * - GET /api/analisa/daily-average (rata-rata pengeluaran harian & 7 daily points)
 * - GET /api/analisa/depletion (proyeksi perkiraan uang bertahan & tanggal habis)
 * - GET /api/analisa/warning (status peringatan dini 3-tingkat)
 * - POST /api/analisa/recalculate (rekalkulasi paksa dan sinkronisasi cache)
 */

import { getDatabase } from '../config/database.js';
import { getOrCreateDefaultUser } from './chatController.js';
import {
  calculateDailyAverageSpending,
  toIsoDateString,
} from '../services/dailyAverageSpendingService.js';
import {
  calculateMoneyDepletionProjection,
} from '../services/moneyDepletionProjectionService.js';
import {
  evaluateEarlyWarningStatus,
  getWarningDiagnostics,
} from '../services/earlyWarningService.js';
import {
  recalculateFinancialAnalysis,
  getFinancialAnalysis,
} from '../services/financialAnalysisService.js';

/**
 * Helper untuk memvalidasi dan mengekstrak userId dari request
 */
function resolveUserIdFromRequest(db, req) {
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
 * Memeriksa apakah user memiliki transaksi terkonfirmasi
 */
function checkUserHasTransactions(db, userId) {
  const row = db
    .prepare('SELECT COUNT(*) as count FROM transactions WHERE user_id = ? AND is_confirmed = 1')
    .get(userId);
  return Number(row?.count) > 0;
}

/**
 * GET /api/analisa - Endpoint Analisa Keuangan Lengkap Terfilter Per Pengguna
 */
export function getFullFinancialAnalysisHandler(req, res) {
  try {
    const db = getDatabase();
    let userId;
    try {
      userId = resolveUserIdFromRequest(db, req);
    } catch (err) {
      return res.status(400).json({ success: false, error: err.message });
    }

    const refDateInput = req.query?.date || req.query?.referenceDate;
    if (refDateInput && isNaN(Date.parse(refDateInput))) {
      return res.status(400).json({
        success: false,
        error: 'Format tanggal date/referenceDate tidak valid. Gunakan format YYYY-MM-DD.',
      });
    }

    const refDate = refDateInput ? new Date(refDateInput) : new Date();
    const daysWindow = Math.max(1, parseInt(req.query?.days, 10) || 7);
    const forceRefresh = req.query?.refresh === 'true' || req.query?.force === 'true';

    const hasTransactions = checkUserHasTransactions(db, userId);

    const analysis = forceRefresh
      ? recalculateFinancialAnalysis(db, { userId, referenceDate: refDate, daysWindow })
      : getFinancialAnalysis(db, { userId, referenceDate: refDate, daysWindow });

    return res.status(200).json({
      success: true,
      userId,
      referenceDate: toIsoDateString(refDate),
      hasTransactions,
      summary: analysis.summary,
      dailySpending: analysis.dailyAverage,
      moneyDepletion: analysis.depletion,
      earlyWarning: analysis.warning,
      fromCache: Boolean(analysis.fromCache),
      calculatedAt: analysis.summary.recalculatedAt || new Date().toISOString(),
    });
  } catch (error) {
    console.error('[AnalysisController] Error fetching full analysis:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memproses analisa keuangan.',
      details: error.message,
    });
  }
}

/**
 * GET /api/analisa/summary - Ringkasan Eksekutif Analisa Keuangan
 */
export function getAnalysisSummaryHandler(req, res) {
  try {
    const db = getDatabase();
    let userId;
    try {
      userId = resolveUserIdFromRequest(db, req);
    } catch (err) {
      return res.status(400).json({ success: false, error: err.message });
    }

    const refDateInput = req.query?.date || req.query?.referenceDate;
    const refDate = refDateInput ? new Date(refDateInput) : new Date();
    const forceRefresh = req.query?.refresh === 'true';

    const analysis = forceRefresh
      ? recalculateFinancialAnalysis(db, { userId, referenceDate: refDate })
      : getFinancialAnalysis(db, { userId, referenceDate: refDate });

    return res.status(200).json({
      success: true,
      userId,
      referenceDate: toIsoDateString(refDate),
      summary: analysis.summary,
      fromCache: Boolean(analysis.fromCache),
    });
  } catch (error) {
    console.error('[AnalysisController] Error fetching analysis summary:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat mengambil ringkasan analisa.',
      details: error.message,
    });
  }
}

/**
 * GET /api/analisa/daily-average - Rata-rata Pengeluaran Harian & Tren 7 Hari
 */
export function getDailyAverageSpendingHandler(req, res) {
  try {
    const db = getDatabase();
    let userId;
    try {
      userId = resolveUserIdFromRequest(db, req);
    } catch (err) {
      return res.status(400).json({ success: false, error: err.message });
    }

    const refDateInput = req.query?.date || req.query?.referenceDate;
    const refDate = refDateInput ? new Date(refDateInput) : new Date();
    const days = Math.max(1, parseInt(req.query?.days, 10) || 7);

    const result = calculateDailyAverageSpending(db, {
      userId,
      days,
      referenceDate: refDate,
    });

    return res.status(200).json({
      success: true,
      userId,
      ...result,
    });
  } catch (error) {
    console.error('[AnalysisController] Error fetching daily average spending:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menghitung rata-rata pengeluaran harian.',
      details: error.message,
    });
  }
}

/**
 * GET /api/analisa/depletion - Proyeksi Perkiraan Uang Bertahan & Tanggal Habis
 */
export function getMoneyDepletionHandler(req, res) {
  try {
    const db = getDatabase();
    let userId;
    try {
      userId = resolveUserIdFromRequest(db, req);
    } catch (err) {
      return res.status(400).json({ success: false, error: err.message });
    }

    const refDateInput = req.query?.date || req.query?.referenceDate;
    const refDate = refDateInput ? new Date(refDateInput) : new Date();
    const customAvg = req.query?.avgDailySpend ? Number(req.query.avgDailySpend) : null;
    const customBal = req.query?.remainingBalance ? Number(req.query.remainingBalance) : null;

    const result = calculateMoneyDepletionProjection(db, {
      userId,
      referenceDate: refDate,
      avgDailySpend: customAvg,
      customRemainingBalance: customBal,
    });

    return res.status(200).json({
      success: true,
      userId,
      ...result,
    });
  } catch (error) {
    console.error('[AnalysisController] Error fetching money depletion projection:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menghitung perkiraan uang bertahan.',
      details: error.message,
    });
  }
}

/**
 * GET /api/analisa/warning - Status Peringatan Dini 3 Tingkat
 */
export function getEarlyWarningStatusHandler(req, res) {
  try {
    const db = getDatabase();
    let userId;
    try {
      userId = resolveUserIdFromRequest(db, req);
    } catch (err) {
      return res.status(400).json({ success: false, error: err.message });
    }

    const refDateInput = req.query?.date || req.query?.referenceDate;
    const refDate = refDateInput ? new Date(refDateInput) : new Date();

    const result = evaluateEarlyWarningStatus(db, {
      userId,
      referenceDate: refDate,
    });

    return res.status(200).json({
      success: true,
      userId,
      ...result,
    });
  } catch (error) {
    console.error('[AnalysisController] Error fetching early warning status:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat mengevaluasi status peringatan dini.',
      details: error.message,
    });
  }
}

/**
 * POST /api/analisa/recalculate - Paksa Rekalkulasi Analisa Keuangan
 */
export function recalculateAnalysisHandler(req, res) {
  try {
    const db = getDatabase();
    let userId;
    try {
      userId = resolveUserIdFromRequest(db, req);
    } catch (err) {
      return res.status(400).json({ success: false, error: err.message });
    }

    const refDateInput = req.body?.date || req.body?.referenceDate || req.query?.date;
    const refDate = refDateInput ? new Date(refDateInput) : new Date();
    const daysWindow = Math.max(1, parseInt(req.body?.days || req.query?.days, 10) || 7);

    const result = recalculateFinancialAnalysis(db, {
      userId,
      referenceDate: refDate,
      daysWindow,
    });

    return res.status(200).json({
      success: true,
      message: 'Analisa keuangan berhasil direkalkulasi dan diperbarui di cache.',
      userId,
      referenceDate: toIsoDateString(refDate),
      ...result,
    });
  } catch (error) {
    console.error('[AnalysisController] Error recalculating analysis:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat merekalukasi analisa keuangan.',
      details: error.message,
    });
  }
}
