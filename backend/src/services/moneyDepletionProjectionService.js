/**
 * Money Depletion Projection Service (Layanan Proyeksi Perkiraan Uang Bertahan & Tanggal Habis)
 *
 * Menghitung perkiraan berapa hari uang/saldo pengguna dapat bertahan berdasarkan
 * laju rata-rata pengeluaran harian, mengestimasi tanggal habis (depletion date),
 * serta mengevaluasi apakah saldo cukup hingga akhir bulan (runs out early vs safe).
 */

import { calculateDailyAverageSpending, formatRupiah, toIsoDateString } from './dailyAverageSpendingService.js';
import { getCachedAnalysis, saveCachedAnalysis } from './analysisCacheService.js';

export const ID_MONTH_NAMES = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

export const ID_SHORT_MONTH_NAMES = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/**
 * Format Date object ke tanggal bahasa Indonesia lengkap (contoh: "18 Oktober 2026")
 */
export function formatIndonesianDate(dateInput) {
  const d = new Date(dateInput);
  const day = d.getDate();
  const monthName = ID_MONTH_NAMES[d.getMonth()] || '';
  const year = d.getFullYear();
  return `${day} ${monthName} ${year}`;
}

/**
 * Format Date object ke tanggal bahasa Indonesia ringkas (contoh: "18 Okt 2026")
 */
export function formatShortIndonesianDate(dateInput) {
  const d = new Date(dateInput);
  const day = d.getDate();
  const shortMonth = ID_SHORT_MONTH_NAMES[d.getMonth()] || '';
  const year = d.getFullYear();
  return `${day} ${shortMonth} ${year}`;
}

/**
 * Menghitung sisa hari dari tanggal acuan hingga akhir bulan
 */
export function calculateDaysUntilEndOfMonth(referenceDate = new Date()) {
  const d = new Date(referenceDate);
  const year = d.getFullYear();
  const month = d.getMonth();

  // Tanggal 0 bulan berikutnya adalah hari terakhir bulan ini
  const lastDayOfMonth = new Date(year, month + 1, 0).getDate();
  const currentDay = d.getDate();

  const remaining = lastDayOfMonth - currentDay;
  return Math.max(1, remaining);
}

/**
 * Simulasi What-If: Menghitung ulang proyeksi habis berdasarkan nominal belanja harian tertentu
 */
export function simulateDepletion({
  dailySpend,
  remainingBalance,
  referenceDate = new Date(),
}) {
  const ref = new Date(referenceDate);
  const numSpend = Number(dailySpend) || 0;
  const numBalance = Number(remainingBalance) || 0;

  let simulatedDaysLeft = 0;
  if (numSpend > 0 && numBalance > 0) {
    simulatedDaysLeft = Math.floor(numBalance / numSpend);
  } else if (numBalance <= 0) {
    simulatedDaysLeft = 0;
  } else {
    simulatedDaysLeft = 999;
  }

  const simulatedDate = new Date(ref);
  simulatedDate.setDate(simulatedDate.getDate() + simulatedDaysLeft);

  const daysToEnd = calculateDaysUntilEndOfMonth(ref);
  const runsOutBeforeEndOfMonth = simulatedDaysLeft < daysToEnd;

  return {
    simulatedDailySpend: numSpend,
    formattedSimulatedDailySpend: formatRupiah(numSpend),
    simulatedDaysLeft,
    simulatedDate: toIsoDateString(simulatedDate),
    formattedSimulatedDate: formatIndonesianDate(simulatedDate),
    formattedShortSimulatedDate: formatShortIndonesianDate(simulatedDate),
    runsOutBeforeEndOfMonth,
    daysUntilEndOfMonth: daysToEnd,
  };
}

/**
 * Mengambil ringkasan saldo, budget, dan pengeluaran bulan berjalan untuk user
 */
export function getMonthlyFinancialContext(db, userId, targetDate = new Date()) {
  const dateStr = toIsoDateString(targetDate);
  const monthStr = dateStr.substring(0, 7);

  // 1. Ambil monthly budget
  let totalMonthlyBudget = 0;
  const mbRow = db
    .prepare(`
      SELECT total_amount
      FROM monthly_budgets
      WHERE user_id = ? AND month = ?
      LIMIT 1
    `)
    .get(userId, monthStr);

  if (mbRow && mbRow.total_amount > 0) {
    totalMonthlyBudget = Number(mbRow.total_amount);
  } else {
    const rootBudget = db
      .prepare(`
        SELECT COALESCE(total_amount, amount_limit, 0) as total_budget
        FROM budgets
        WHERE user_id = ? AND month = ? AND category_id IS NULL
        LIMIT 1
      `)
      .get(userId, monthStr);

    if (rootBudget && rootBudget.total_budget > 0) {
      totalMonthlyBudget = Number(rootBudget.total_budget);
    }
  }

  // 2. Ambil total pengeluaran dan pemasukan bulan berjalan
  const txSummary = db
    .prepare(`
      SELECT
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as total_expense,
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as total_income
      FROM transactions
      WHERE user_id = ?
        AND is_confirmed = 1
        AND strftime('%Y-%m', occurred_at) = ?
    `)
    .get(userId, monthStr);

  const totalSpent = Number(txSummary?.total_expense) || 0;
  const totalIncome = Number(txSummary?.total_income) || 0;

  // Sisa saldo: prioritaskan sisa budget bila ada budget, atau sisa net cash (income - expense)
  let remainingBalance = 0;
  let hasBudget = false;

  if (totalMonthlyBudget > 0) {
    hasBudget = true;
    remainingBalance = totalMonthlyBudget - totalSpent;
  } else if (totalIncome > 0) {
    remainingBalance = totalIncome - totalSpent;
  } else {
    // Tanpa budget & tanpa pemasukan: saldo minus jika ada pengeluaran
    remainingBalance = -totalSpent;
  }

  return {
    month: monthStr,
    hasBudget,
    totalMonthlyBudget,
    totalSpent,
    totalIncome,
    remainingBalance,
    formattedTotalMonthlyBudget: formatRupiah(totalMonthlyBudget),
    formattedTotalSpent: formatRupiah(totalSpent),
    formattedTotalIncome: formatRupiah(totalIncome),
    formattedRemainingBalance: formatRupiah(remainingBalance),
  };
}

/**
 * Service Utama: Menghitung Perkiraan Uang Bertahan dan Tanggal Habis (Money Depletion Projection)
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} options
 * @param {number|string} options.userId
 * @param {string|Date} [options.referenceDate=null]
 * @param {number} [options.avgDailySpend=null] - Opsional; bila null, dihitung otomatis dari 7 hari terakhir
 * @param {number} [options.daysWindow=7]
 * @param {number} [options.customRemainingBalance=null] - Opsional override sisa saldo
 * @returns {Object} Proyeksi perkiraan uang bertahan & tanggal habis lengkap
 */
export function calculateMoneyDepletionProjection(db, {
  userId,
  referenceDate = null,
  avgDailySpend = null,
  daysWindow = 7,
  customRemainingBalance = null,
} = {}) {
  if (!userId) {
    throw new Error('userId is required to calculate money depletion projection');
  }

  const refDate = referenceDate ? new Date(referenceDate) : new Date();
  const refDateStr = toIsoDateString(refDate);

  // 1. Ambil data keuangan bulanan
  const finContext = getMonthlyFinancialContext(db, userId, refDate);

  const effectiveRemainingBalance =
    customRemainingBalance !== null && customRemainingBalance !== undefined
      ? Number(customRemainingBalance)
      : finContext.remainingBalance;

  // 2. Ambil atau hitung rata-rata pengeluaran harian
  let dailySpend = 0;
  if (avgDailySpend !== null && avgDailySpend !== undefined) {
    dailySpend = Math.max(0, Number(avgDailySpend) || 0);
  } else {
    const dailyAvgResult = calculateDailyAverageSpending(db, {
      userId,
      days: daysWindow,
      referenceDate: refDate,
    });
    dailySpend = dailyAvgResult.avgDailySpend;
  }

  // 3. Hitung estimasi hari bertahan (estimatedDaysLeft)
  let estimatedDaysLeft = 0;
  if (effectiveRemainingBalance <= 0) {
    estimatedDaysLeft = 0;
  } else if (dailySpend > 0) {
    estimatedDaysLeft = Math.floor(effectiveRemainingBalance / dailySpend);
  } else {
    // Pengeluaran 0, saldo tidak akan habis
    estimatedDaysLeft = 999;
  }

  // 4. Hitung tanggal habis (projected depletion date)
  const depletionDateObj = new Date(refDate);
  depletionDateObj.setDate(depletionDateObj.getDate() + estimatedDaysLeft);

  const depletionDateStr = toIsoDateString(depletionDateObj);
  const formattedDepletionDate = formatIndonesianDate(depletionDateObj);
  const formattedShortDepletionDate = formatShortIndonesianDate(depletionDateObj);

  // 5. Analisa komparasi terhadap akhir bulan
  const daysUntilEndOfMonth = calculateDaysUntilEndOfMonth(refDate);
  const runsOutBeforeEndOfMonth = estimatedDaysLeft < daysUntilEndOfMonth;
  const daysDifference = Math.abs(estimatedDaysLeft - daysUntilEndOfMonth);

  // 6. Tentukan warn_level ('normal', 'warning', 'critical')
  let warnLevel = 'normal';
  if (effectiveRemainingBalance <= 0 || estimatedDaysLeft <= 3) {
    warnLevel = 'critical';
  } else if (runsOutBeforeEndOfMonth || estimatedDaysLeft <= 7) {
    warnLevel = 'warning';
  } else {
    warnLevel = 'normal';
  }

  // 7. Bentuk teks status dan pesan penjelas
  let depletionStatusMessage = '';
  let statusBannerText = '';

  if (effectiveRemainingBalance <= 0) {
    depletionStatusMessage = 'Saldo telah habis / defisit';
    statusBannerText = 'Peringatan: Saldo sudah habis terpakai bulan ini!';
  } else if (runsOutBeforeEndOfMonth) {
    depletionStatusMessage = `Habis ${daysDifference} hari sebelum akhir bulan`;
    statusBannerText = `Saldo diperkirakan habis sebelum akhir bulan (${formattedDepletionDate})`;
  } else {
    depletionStatusMessage = `Aman melampaui akhir bulan (+${daysDifference} hari)`;
    statusBannerText = `Saldo bertahan aman melampaui akhir bulan (s/d ${formattedDepletionDate})`;
  }

  // 8. Siapkan data simulasi bawaan untuk slider
  const simulation = simulateDepletion({
    dailySpend: dailySpend > 0 ? dailySpend : 65000,
    remainingBalance: effectiveRemainingBalance,
    referenceDate: refDate,
  });

  return {
    userId,
    referenceDate: refDateStr,
    avgDailySpend: dailySpend,
    formattedAvgDailySpend: formatRupiah(dailySpend),
    estimatedDaysLeft,
    depletionDate: depletionDateStr,
    formattedDepletionDate,
    formattedShortDepletionDate,
    daysUntilEndOfMonth,
    runsOutBeforeEndOfMonth,
    daysDifferenceWithEndOfMonth: daysDifference,
    warnLevel,
    isNormal: warnLevel === 'normal',
    isWarning: warnLevel === 'warning',
    isCritical: warnLevel === 'critical',
    depletionStatusMessage,
    statusBannerText,
    totalMonthlyBudget: finContext.totalMonthlyBudget,
    totalSpent: finContext.totalSpent,
    totalIncome: finContext.totalIncome,
    remainingBalance: effectiveRemainingBalance,
    formattedRemainingBalance: formatRupiah(effectiveRemainingBalance),
    hasBudget: finContext.hasBudget,
    simulation,
    calculatedAt: new Date().toISOString(),
  };
}

/**
 * Mengambil proyeksi perkiraan uang bertahan dengan sinkronisasi ke tabel cache ai_insights
 */
export function getOrUpdateCachedDepletionProjection(db, {
  userId,
  referenceDate = null,
  forceRefresh = false,
} = {}) {
  const refDate = referenceDate ? new Date(referenceDate) : new Date();
  const dateStr = toIsoDateString(refDate);

  if (!forceRefresh) {
    const cached = getCachedAnalysis(db, { userId, date: dateStr, allowStale: false });
    if (cached && cached.analysis && cached.analysis.depletionDate) {
      return {
        ...cached.analysis,
        fromCache: true,
        cachedAt: cached.updatedAt,
      };
    }
  }

  const projection = calculateMoneyDepletionProjection(db, {
    userId,
    referenceDate: refDate,
  });

  // Sinkronkan ke cache ai_insights
  saveCachedAnalysis(db, {
    userId,
    date: dateStr,
    avgDailySpend: projection.avgDailySpend,
    estimatedDaysLeft: projection.estimatedDaysLeft,
    warnLevel: projection.warnLevel,
    dailyAdvice: projection.statusBannerText,
    totalMonthlyBudget: projection.totalMonthlyBudget,
    totalSpent: projection.totalSpent,
    remainingBalance: projection.remainingBalance,
    analysis: projection,
    ttlHours: 12,
  });

  return {
    ...projection,
    fromCache: false,
  };
}
