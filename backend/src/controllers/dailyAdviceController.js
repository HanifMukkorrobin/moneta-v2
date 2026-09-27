/**
 * Daily Advice Controller (Controller Saran Belanja Hari Ini)
 *
 * Menyediakan endpoint HTTP untuk fitur Saran Harian AI:
 * - GET  /api/saran/hari-ini (saran belanja aman hari ini & panduan harian AI)
 * - GET  /api/saran (alias untuk saran hari ini)
 * - POST /api/saran/terapkan (menandai saran hari ini telah diterapkan/disepakati pengguna)
 * - POST /api/saran/refresh (rekalkulasi ulang saran belanja hari ini)
 * - POST /api/saran/simulasi (simulasi what-if batas belanja harian)
 */

import { getDatabase } from '../config/database.js';
import { getOrCreateDefaultUser } from './chatController.js';
import {
  getSafeDailySpendingForUser,
  calculateSafeDailySpending,
  simulateSafeDailySpending,
  getDaysRemainingInMonth,
} from '../services/safeDailySpendingService.js';
import {
  getCachedDailyAdvice,
  markAdviceAsApplied,
  invalidateDailyAdviceCache,
} from '../services/dailyAdviceCacheService.js';
import { formatRupiah, toIsoDateString } from '../services/dailyAverageSpendingService.js';

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
 * Helper untuk memvalidasi tanggal jika diberikan
 */
function resolveDateFromRequest(req) {
  const dateInput = req.query?.date || req.query?.referenceDate || req.body?.date || req.body?.referenceDate;
  if (!dateInput) {
    return new Date();
  }
  const parsed = new Date(dateInput);
  if (isNaN(parsed.getTime())) {
    throw new Error('Format parameter date tidak valid. Gunakan format YYYY-MM-DD.');
  }
  return parsed;
}

/**
 * Format payload saran agar kompatibel dengan model AiInsightItem pada Flutter
 */
function formatInsightPayload(result) {
  return {
    id: result.id || null,
    userId: result.userId,
    date: result.date,
    recommendedDailyBudget: result.safeDailyLimit ?? result.recommendedDailyBudget ?? 0,
    formattedRecommendedDailyBudget: formatRupiah(result.safeDailyLimit ?? result.recommendedDailyBudget ?? 0),
    estimatedDaysLeft: result.remainingDays ?? result.estimatedDaysLeft ?? 0,
    dailyAdvice: result.adviceMessage ?? result.dailyAdvice ?? '',
    warnLevel: result.warnLevel || 'normal',
    avgDailySpend: result.burnRateComparison?.avgDailySpend ?? result.avgDailySpend ?? 0,
    formattedAvgDailySpend: `${formatRupiah(result.burnRateComparison?.avgDailySpend ?? result.avgDailySpend ?? 0)} / hari`,
    totalMonthlyBudget: result.totalMonthlyBudget ?? 0,
    formattedTotalMonthlyBudget: formatRupiah(result.totalMonthlyBudget ?? 0),
    totalSpent: result.totalSpent ?? 0,
    formattedTotalSpent: formatRupiah(result.totalSpent ?? 0),
    remainingBalance: result.remainingBudget ?? result.remainingBalance ?? 0,
    formattedRemainingBalance: formatRupiah(result.remainingBudget ?? result.remainingBalance ?? 0),
    isApplied: Boolean(result.isApplied),
    source: result.source || 'rule_based',
  };
}

/**
 * GET /api/saran/hari-ini & GET /api/saran
 * Mengambil saran belanja aman hari ini terfilter per pengguna
 */
export function getTodayAdviceHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const refDate = resolveDateFromRequest(req);
    const isoDate = toIsoDateString(refDate);

    const forceRefresh = req.query?.refresh === 'true' || req.query?.noCache === 'true';
    const allowStale = req.query?.allowStale === 'true';

    // 1. Cek cache jika tidak dipaksa refresh
    if (!forceRefresh) {
      const cached = getCachedDailyAdvice(db, { userId, date: isoDate, allowStale });
      if (cached && !cached.isStale && !cached.isExpired) {
        const insight = formatInsightPayload(cached);
        return res.status(200).json({
          success: true,
          cached: true,
          date: isoDate,
          userId,
          insight,
          data: {
            ...cached,
            safeDailyLimit: cached.recommendedDailyBudget,
            formattedSafeDailyLimit: `${formatRupiah(cached.recommendedDailyBudget)} / hari`,
            remainingDays: cached.estimatedDaysLeft,
            adviceMessage: cached.dailyAdvice,
            adviceTitle: cached.adviceDetails?.title || 'Saran Belanja Hari Ini',
            bucketAllocation: cached.adviceDetails?.bucketAllocation || null,
            recommendations: cached.adviceDetails?.recommendations || [],
          },
        });
      }
    }

    // 2. Hitung baru dari data aktual database
    const calculation = getSafeDailySpendingForUser(db, {
      userId,
      referenceDate: refDate,
      autoCache: true,
    });

    const insight = formatInsightPayload(calculation);

    return res.status(200).json({
      success: true,
      cached: false,
      date: isoDate,
      userId,
      insight,
      data: calculation,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId') || error.message.includes('date');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat memuat saran belanja hari ini.',
    });
  }
}

/**
 * POST /api/saran/terapkan & POST /api/saran/apply
 * Menandai saran belanja hari ini telah diterapkan/disepakati pengguna
 */
export function applyTodayAdviceHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const refDate = resolveDateFromRequest(req);
    const isoDate = toIsoDateString(refDate);

    const isApplied = req.body?.isApplied !== undefined ? Boolean(req.body.isApplied) : true;

    // Pastikan saran hari ini sudah di-cache / dihitung terlebih dahulu
    let cached = getCachedDailyAdvice(db, { userId, date: isoDate, allowStale: true });
    if (!cached) {
      getSafeDailySpendingForUser(db, { userId, referenceDate: refDate, autoCache: true });
      cached = getCachedDailyAdvice(db, { userId, date: isoDate, allowStale: true });
    }

    const updated = markAdviceAsApplied(db, { userId, date: isoDate, isApplied });

    const message = isApplied
      ? `Saran belanja hari ini berhasil diterapkan: Target belanja dibatasi ${formatRupiah(updated?.recommendedDailyBudget || 0)}.`
      : 'Penerapan saran belanja hari ini telah dibatalkan.';

    return res.status(200).json({
      success: true,
      message,
      userId,
      date: isoDate,
      isApplied: Boolean(updated?.isApplied),
      insight: updated ? formatInsightPayload(updated) : null,
      data: updated,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId') || error.message.includes('date');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat menerapkan saran belanja hari ini.',
    });
  }
}

/**
 * POST /api/saran/refresh & POST /api/saran/recalculate
 * Memaksa hitung ulang saran belanja hari ini dan menyegarkan cache
 */
export function refreshTodayAdviceHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const refDate = resolveDateFromRequest(req);
    const isoDate = toIsoDateString(refDate);

    // Tandai cache lama sebagai stale
    invalidateDailyAdviceCache(db, userId, isoDate);

    // Hitung ulang dan simpan ke cache
    const calculation = getSafeDailySpendingForUser(db, {
      userId,
      referenceDate: refDate,
      autoCache: true,
    });

    const insight = formatInsightPayload(calculation);

    return res.status(200).json({
      success: true,
      message: 'Saran belanja hari ini berhasil diperbarui.',
      userId,
      date: isoDate,
      insight,
      data: calculation,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId') || error.message.includes('date');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat menyegarkan saran belanja hari ini.',
    });
  }
}

/**
 * GET & POST /api/saran/simulasi
 * Simulasi What-If: Menguji skenario batas belanja harian dengan parameter kustom
 */
export function simulateDailyAdviceHandler(req, res) {
  try {
    const src = req.method === 'POST' ? { ...req.query, ...req.body } : req.query || {};

    const remainingBudget = Number(src.remainingBudget ?? src.budget ?? 0);
    const remainingDays = Number(src.remainingDays ?? src.days ?? getDaysRemainingInMonth());
    const simulatedDailySpend = Number(src.simulatedDailySpend ?? src.dailySpend ?? 0);

    if (isNaN(remainingBudget) || isNaN(remainingDays)) {
      return res.status(400).json({
        success: false,
        error: 'Parameter remainingBudget dan remainingDays harus berupa angka valid.',
      });
    }

    const simulation = simulateSafeDailySpending({
      remainingBudget,
      remainingDays,
      simulatedDailySpend,
    });

    return res.status(200).json({
      success: true,
      simulation,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat menjalankan simulasi batas belanja.',
    });
  }
}
