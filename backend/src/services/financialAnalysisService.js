/**
 * Financial Analysis Service (Orkestrasi & Rekalkulasi Analisa Keuangan AI)
 *
 * Mengkoordinasikan kalkulasi menyeluruh analisa keuangan:
 * - Rata-rata pengeluaran harian (Daily Average Spending)
 * - Proyeksi uang bertahan & tanggal habis (Money Depletion Projection)
 * - Evaluasi status peringatan dini 3-tingkat (Early Warning Status)
 * - Otomatis memperbarui cache ai_insights / financial_analysis_cache
 */

import { calculateDailyAverageSpending, toIsoDateString } from './dailyAverageSpendingService.js';
import { calculateMoneyDepletionProjection } from './moneyDepletionProjectionService.js';
import { evaluateEarlyWarningStatus } from './earlyWarningService.js';
import { saveCachedAnalysis, getCachedAnalysis } from './analysisCacheService.js';

/**
 * Melakukan rekalkulasi analisa keuangan otomatis dan menyimpan hasilnya ke cache ai_insights
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} options
 * @param {number|string} options.userId
 * @param {string|Date} [options.referenceDate=null]
 * @param {number} [options.daysWindow=7]
 * @returns {Object} Bundel hasil rekalkulasi analisa keuangan lengkap
 */
export function recalculateFinancialAnalysis(db, {
  userId,
  referenceDate = null,
  daysWindow = 7,
} = {}) {
  if (!userId) {
    throw new Error('userId is required to recalculate financial analysis');
  }

  const refDate = referenceDate ? new Date(referenceDate) : new Date();
  const dateStr = toIsoDateString(refDate);

  // 1. Hitung rata-rata pengeluaran harian
  const dailyAverage = calculateDailyAverageSpending(db, {
    userId,
    days: daysWindow,
    referenceDate: refDate,
  });

  // 2. Hitung proyeksi uang bertahan & tanggal habis
  const depletion = calculateMoneyDepletionProjection(db, {
    userId,
    referenceDate: refDate,
    avgDailySpend: dailyAverage.avgDailySpend,
  });

  // 3. Evaluasi status peringatan dini 3-tingkat
  const warning = evaluateEarlyWarningStatus(db, {
    userId,
    referenceDate: refDate,
    daysWindow,
  });

  // 4. Bangun ringkasan analisa terpadu (compact summary)
  const summary = {
    userId,
    date: dateStr,
    avgDailySpend: dailyAverage.avgDailySpend,
    formattedAvgDailySpend: dailyAverage.formattedAvgDailySpend,
    targetDailySpend: dailyAverage.targetDailySpend,
    formattedTargetDailySpend: dailyAverage.formattedTargetDailySpend,
    isAboveTarget: dailyAverage.isAboveTarget,
    estimatedDaysLeft: depletion.estimatedDaysLeft,
    depletionDate: depletion.depletionDate,
    formattedDepletionDate: depletion.formattedDepletionDate,
    formattedShortDepletionDate: depletion.formattedShortDepletionDate,
    runsOutBeforeEndOfMonth: depletion.runsOutBeforeEndOfMonth,
    depletionStatusMessage: depletion.depletionStatusMessage,
    statusBannerText: depletion.statusBannerText,
    warnLevel: warning.level,
    warningNumber: warning.levelNumber,
    warningLabel: warning.label,
    warningTitle: warning.title,
    actionRecommendation: warning.actionRecommendation,
    reasons: warning.reasons,
    remainingBalance: depletion.remainingBalance,
    formattedRemainingBalance: depletion.formattedRemainingBalance,
    totalMonthlyBudget: depletion.totalMonthlyBudget,
    formattedTotalMonthlyBudget: depletion.formattedTotalMonthlyBudget,
    totalSpent: depletion.totalSpent,
    formattedTotalSpent: depletion.formattedTotalSpent,
    topCategoryName: dailyAverage.topCategoryName,
    topCategoryPercentage: dailyAverage.topCategoryPercentage,
    weekOverWeekPercent: dailyAverage.weekOverWeekPercent,
    isSpendingIncreasing: dailyAverage.isSpendingIncreasing,
    recalculatedAt: new Date().toISOString(),
  };

  // 5. Simpan / perbarui ke tabel cache ai_insights
  saveCachedAnalysis(db, {
    userId,
    date: dateStr,
    avgDailySpend: summary.avgDailySpend,
    estimatedDaysLeft: summary.estimatedDaysLeft,
    dailyAdvice: summary.actionRecommendation || summary.depletionStatusMessage,
    warnLevel: summary.warnLevel,
    recommendedDailyBudget: summary.targetDailySpend,
    totalMonthlyBudget: summary.totalMonthlyBudget,
    totalSpent: summary.totalSpent,
    remainingBalance: summary.remainingBalance,
    analysis: {
      summary,
      dailyAverage,
      depletion,
      warning,
    },
    ttlHours: 24,
    isStale: 0,
  });

  return {
    summary,
    dailyAverage,
    depletion,
    warning,
  };
}

/**
 * Mengambil analisa keuangan lengkap (dari cache bila tersedia, atau kalkulasi ulang)
 */
export function getFinancialAnalysis(db, {
  userId,
  referenceDate = null,
  forceRefresh = false,
  daysWindow = 7,
} = {}) {
  const refDate = referenceDate ? new Date(referenceDate) : new Date();
  const dateStr = toIsoDateString(refDate);

  if (!forceRefresh) {
    const cached = getCachedAnalysis(db, { userId, date: dateStr, allowStale: false });
    if (cached && cached.analysis && cached.analysis.summary) {
      return {
        ...cached.analysis,
        fromCache: true,
        cachedAt: cached.updatedAt,
      };
    }
  }

  const result = recalculateFinancialAnalysis(db, {
    userId,
    referenceDate: refDate,
    daysWindow,
  });

  return {
    ...result,
    fromCache: false,
  };
}
