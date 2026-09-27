/**
 * Early Warning Service (Layanan Status Peringatan Dini Finansial Tiga Tingkat)
 *
 * Mendeteksi dini risiko belanja boros berdasarkan 3 tingkat:
 * 1. Normal (Aman / Finansial Terkendali)
 * 2. Warning (Waspada / Peringatan Belanja Meningkat)
 * 3. Critical (Kritis / Kondisi Kritis & Darurat)
 */

import { calculateDailyAverageSpending, formatRupiah, toIsoDateString } from './dailyAverageSpendingService.js';
import { calculateMoneyDepletionProjection, calculateDaysUntilEndOfMonth } from './moneyDepletionProjectionService.js';
import { getCachedAnalysis, saveCachedAnalysis } from './analysisCacheService.js';

export const WARN_LEVEL_DETAILS = {
  normal: {
    level: 'normal',
    levelNumber: 1,
    label: 'Keuangan Aman',
    shortLabel: 'Aman',
    title: 'Tingkat 1: Finansial Terkendali',
    subtitle: 'Pengeluaran stabil',
    description:
      'Rasio pengeluaran harian berada di bawah ambang batas aman. Proyeksi saldo bertahan melampaui tanggal gajian.',
    actionRecommendation:
      'Pertahankan kebiasaan mencatat transaksi dan kontrol budget.',
    colorHex: '#10B981', // Green
  },
  warning: {
    level: 'warning',
    levelNumber: 2,
    label: 'Perlu Waspada',
    shortLabel: 'Waspada',
    title: 'Tingkat 2: Peringatan Belanja Meningkat',
    subtitle: 'Mulai meningkat',
    description:
      'Terdeteksi lonjakan belanja dalam beberapa hari terakhir. Jika tidak dikurangi, uang berpotensi habis sebelum akhir bulan.',
    actionRecommendation:
      'Pangkas pos hiburan dan tunda belanja barang non-esensial.',
    colorHex: '#F59E0B', // Amber
  },
  critical: {
    level: 'critical',
    levelNumber: 3,
    label: 'Kondisi Kritis',
    shortLabel: 'Kritis',
    title: 'Tingkat 3: Kondisi Kritis / Darurat',
    subtitle: 'Saldo terancam',
    description:
      'Sisa saldo menipis drastis dengan laju belanja tinggi. Proyeksi ketahanan uang kurang dari 5 hari ke depan.',
    actionRecommendation:
      'Kunci pengeluaran gaya hidup, fokus 100% pada kebutuhan primer.',
    colorHex: '#EF4444', // Red
  },
};

/**
 * Mengambil metadata diagnostik untuk tingkat peringatan tertentu
 *
 * @param {'normal'|'warning'|'critical'} level
 */
export function getWarningDiagnostics(level = 'normal') {
  const normalized = String(level).toLowerCase();
  return WARN_LEVEL_DETAILS[normalized] || WARN_LEVEL_DETAILS.normal;
}

/**
 * Mengevaluasi status peringatan dini 3 tingkat berdasarkan data keuangan pengguna
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} options
 * @param {number|string} options.userId
 * @param {string|Date} [options.referenceDate=null]
 * @param {number} [options.daysWindow=7]
 * @returns {Object} Hasil evaluasi peringatan dini 3-tingkat lengkap
 */
export function evaluateEarlyWarningStatus(db, {
  userId,
  referenceDate = null,
  daysWindow = 7,
} = {}) {
  if (!userId) {
    throw new Error('userId is required to evaluate early warning status');
  }

  const refDate = referenceDate ? new Date(referenceDate) : new Date();
  const refDateStr = toIsoDateString(refDate);

  // 1. Dapatkan analisa rata-rata pengeluaran harian
  const dailyAvg = calculateDailyAverageSpending(db, {
    userId,
    days: daysWindow,
    referenceDate: refDate,
  });

  // 2. Dapatkan proyeksi ketahanan uang dan sisa saldo
  const depletion = calculateMoneyDepletionProjection(db, {
    userId,
    referenceDate: refDate,
    avgDailySpend: dailyAvg.avgDailySpend,
  });

  const remainingBalance = depletion.remainingBalance;
  const totalMonthlyBudget = depletion.totalMonthlyBudget;
  const estimatedDaysLeft = depletion.estimatedDaysLeft;
  const daysUntilEndOfMonth = depletion.daysUntilEndOfMonth;
  const runsOutBeforeEndOfMonth = depletion.runsOutBeforeEndOfMonth;
  const avgDailySpend = dailyAvg.avgDailySpend;
  const targetDailySpend = dailyAvg.targetDailySpend;
  const weekOverWeekPercent = dailyAvg.weekOverWeekPercent;

  const reasons = [];

  // ==========================================
  // ATURAN EVALUASI 3-TINGKAT:
  // ==========================================

  // Evaluasi Kritis (Level 3):
  // - Saldo negatif atau sudah habis (<= 0)
  // - Uang habis dalam <= 3 hari
  // - Sisa saldo tinggal < 10% budget sementara bulan masih tersisa > 7 hari
  let isCritical = false;

  if (remainingBalance <= 0) {
    isCritical = true;
    reasons.push('Saldo atau sisa anggaran telah habis terpakai.');
  } else if (estimatedDaysLeft <= 3 && avgDailySpend > 0) {
    isCritical = true;
    reasons.push(`Proyeksi ketahanan saldo sangat singkat (~${estimatedDaysLeft} hari ke depan).`);
  } else if (
    totalMonthlyBudget > 0 &&
    remainingBalance < totalMonthlyBudget * 0.1 &&
    daysUntilEndOfMonth > 7
  ) {
    isCritical = true;
    reasons.push(
      `Sisa anggaran kritis (< 10%) padahal bulan masih tersisa ${daysUntilEndOfMonth} hari.`
    );
  }

  // Evaluasi Waspada (Level 2):
  // - Saldo habis sebelum akhir bulan (runsOutBeforeEndOfMonth)
  // - Ketahanan uang <= 7 hari
  // - Laju harian melebihi target budget harian (avgDailySpend > targetDailySpend)
  // - Lonjakan belanja mingguan (weekOverWeekPercent >= 25%)
  let isWarning = false;

  if (!isCritical) {
    if (runsOutBeforeEndOfMonth) {
      isWarning = true;
      reasons.push(
        `Saldo diperkirakan habis ${depletion.daysDifferenceWithEndOfMonth} hari sebelum akhir bulan.`
      );
    }

    if (estimatedDaysLeft <= 7 && avgDailySpend > 0) {
      isWarning = true;
      reasons.push(`Uang diperkirakan hanya bertahan ~${estimatedDaysLeft} hari.`);
    }

    if (targetDailySpend > 0 && avgDailySpend > targetDailySpend) {
      const overPct = Math.round(((avgDailySpend - targetDailySpend) / targetDailySpend) * 100);
      isWarning = true;
      reasons.push(
        `Rata-rata pengeluaran harian (${formatRupiah(avgDailySpend)}) melebihi target aman (${formatRupiah(targetDailySpend)}) sebesar +${overPct}%.`
      );
    }

    const prevTotalSpent = dailyAvg.prevTotalSpent || 0;
    if (prevTotalSpent > 0 && weekOverWeekPercent >= 25) {
      isWarning = true;
      reasons.push(
        `Pengeluaran meningkat ${weekOverWeekPercent.toFixed(1)}% dibanding pekan sebelumnya.`
      );
    }
  }

  // Tentukan Level
  let level = 'normal';
  if (isCritical) {
    level = 'critical';
  } else if (isWarning) {
    level = 'warning';
  } else {
    level = 'normal';
    reasons.push('Pengeluaran harian dan proyeksi saldo dalam batas aman stabil.');
  }

  const diagnostics = getWarningDiagnostics(level);

  return {
    userId,
    referenceDate: refDateStr,
    level,
    levelNumber: diagnostics.levelNumber,
    label: diagnostics.label,
    shortLabel: diagnostics.shortLabel,
    title: diagnostics.title,
    subtitle: diagnostics.subtitle,
    description: diagnostics.description,
    actionRecommendation: diagnostics.actionRecommendation,
    colorHex: diagnostics.colorHex,
    reasons,
    isNormal: level === 'normal',
    isWarning: level === 'warning',
    isCritical: level === 'critical',
    metrics: {
      avgDailySpend,
      formattedAvgDailySpend: formatRupiah(avgDailySpend),
      targetDailySpend,
      formattedTargetDailySpend: formatRupiah(targetDailySpend),
      estimatedDaysLeft,
      daysUntilEndOfMonth,
      depletionDate: depletion.depletionDate,
      formattedDepletionDate: depletion.formattedDepletionDate,
      runsOutBeforeEndOfMonth,
      remainingBalance,
      formattedRemainingBalance: formatRupiah(remainingBalance),
      totalMonthlyBudget,
      formattedTotalMonthlyBudget: formatRupiah(totalMonthlyBudget),
      totalSpent: depletion.totalSpent,
      formattedTotalSpent: formatRupiah(depletion.totalSpent),
      weekOverWeekPercent,
      highestSpendAmount: dailyAvg.highestSpendAmount,
      highestSpendDay: dailyAvg.highestSpendDay,
      topCategoryName: dailyAvg.topCategoryName,
    },
    evaluatedAt: new Date().toISOString(),
  };
}

/**
 * Mengambil status peringatan dini dengan sinkronisasi ke tabel cache ai_insights
 */
export function getOrUpdateCachedEarlyWarning(db, {
  userId,
  referenceDate = null,
  forceRefresh = false,
} = {}) {
  const refDate = referenceDate ? new Date(referenceDate) : new Date();
  const dateStr = toIsoDateString(refDate);

  if (!forceRefresh) {
    const cached = getCachedAnalysis(db, { userId, date: dateStr, allowStale: false });
    if (cached && cached.analysis && cached.analysis.level) {
      return {
        ...cached.analysis,
        fromCache: true,
        cachedAt: cached.updatedAt,
      };
    }
  }

  const warningResult = evaluateEarlyWarningStatus(db, {
    userId,
    referenceDate: refDate,
  });

  // Simpan / update status di ai_insights
  saveCachedAnalysis(db, {
    userId,
    date: dateStr,
    avgDailySpend: warningResult.metrics.avgDailySpend,
    estimatedDaysLeft: warningResult.metrics.estimatedDaysLeft,
    warnLevel: warningResult.level,
    dailyAdvice: warningResult.actionRecommendation,
    totalMonthlyBudget: warningResult.metrics.totalMonthlyBudget,
    totalSpent: warningResult.metrics.totalSpent,
    remainingBalance: warningResult.metrics.remainingBalance,
    analysis: warningResult,
    ttlHours: 12,
  });

  return {
    ...warningResult,
    fromCache: false,
  };
}
