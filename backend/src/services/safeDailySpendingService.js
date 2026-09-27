/**
 * Safe Daily Spending Service (Layanan Hitung Batas Aman Belanja Harian)
 *
 * Menghitung batas aman belanja harian pengguna agar anggaran / saldo bertahan hingga
 * awal bulan berikutnya, memantau pengeluaran hari ini terhadap limit aman,
 * membandingkan laju pengeluaran riil (burn rate), serta menghasilkan rekomendasi
 * alokasi pos 50/30/20 dan pesan saran harian ramah pengguna dalam Bahasa Indonesia.
 */

import { formatRupiah, calculateDailyAverageSpending, toIsoDateString } from './dailyAverageSpendingService.js';
import { saveCachedDailyAdvice, getCachedDailyAdvice } from './dailyAdviceCacheService.js';

/**
 * Menghitung jumlah hari tersisa dalam bulan berjalan dari tanggal acuan
 *
 * @param {Date|string} [referenceDate=new Date()]
 * @param {Object} [options]
 * @param {boolean} [options.includeToday=true] - Menyertakan hari ini dalam hitungan belanja
 * @returns {number}
 */
export function getDaysRemainingInMonth(referenceDate = new Date(), { includeToday = true } = {}) {
  const d = new Date(referenceDate);
  const year = d.getFullYear();
  const month = d.getMonth();

  // Hari terakhir dalam bulan (misal 30 untuk September, 31 untuk Oktober)
  const lastDayOfMonth = new Date(year, month + 1, 0).getDate();
  const currentDay = d.getDate();

  const daysLeft = lastDayOfMonth - currentDay + (includeToday ? 1 : 0);
  return Math.max(1, daysLeft);
}

/**
 * Mendapatkan informasi total hari dalam bulan dan hari berjalan
 *
 * @param {Date|string} [referenceDate=new Date()]
 * @returns {{ daysInMonth: number, currentDay: number, monthString: string }}
 */
export function getMonthDateMetrics(referenceDate = new Date()) {
  const d = new Date(referenceDate);
  const year = d.getFullYear();
  const month = d.getMonth();
  const monthString = `${year}-${String(month + 1).padStart(2, '0')}`;
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const currentDay = d.getDate();

  return {
    daysInMonth,
    currentDay,
    monthString,
  };
}

/**
 * Fungsi Murni (Pure Function) untuk mengkalkulasi batas aman belanja harian
 *
 * @param {Object} params
 * @param {number} params.remainingBudget - Sisa anggaran atau saldo yang tersedia
 * @param {number} params.remainingDays - Jumlah hari tersisa sampai akhir bulan (termasuk hari ini)
 * @param {number} [params.todaySpent=0] - Total pengeluaran yang sudah terjadi hari ini
 * @param {number} [params.avgDailySpend=0] - Rata-rata pengeluaran harian riil (7 hari terakhir)
 * @param {number} [params.totalMonthlyBudget=0] - Total pagu anggaran bulanan
 * @param {number} [params.totalSpent=0] - Total pengeluaran bulan berjalan hingga saat ini
 * @returns {Object}
 */
export function calculateSafeDailySpending({
  remainingBudget = 0,
  remainingDays = 1,
  todaySpent = 0,
  avgDailySpend = 0,
  totalMonthlyBudget = 0,
  totalSpent = 0,
} = {}) {
  const safeRemainingDays = Math.max(1, Math.floor(Number(remainingDays) || 1));
  const numRemainingBudget = Number(remainingBudget) || 0;
  const numTodaySpent = Math.max(0, Number(todaySpent) || 0);
  const numAvgDailySpend = Math.max(0, Number(avgDailySpend) || 0);
  const numTotalBudget = Math.max(0, Number(totalMonthlyBudget) || 0);
  const numTotalSpent = Math.max(0, Number(totalSpent) || 0);

  // 1. Hitung batas belanja harian aman
  let safeDailyLimit = 0;
  if (numRemainingBudget > 0) {
    safeDailyLimit = Math.floor(numRemainingBudget / safeRemainingDays);
  }

  // 2. Evaluasi pengeluaran hari ini terhadap batas aman
  const isTodayOverLimit = safeDailyLimit > 0 ? numTodaySpent > safeDailyLimit : numTodaySpent > 0;
  const todayRemainingAllowance = Math.max(0, safeDailyLimit - numTodaySpent);
  const todayOverLimitAmount = Math.max(0, numTodaySpent - safeDailyLimit);
  const todayUsagePercentage = safeDailyLimit > 0 ? Math.round((numTodaySpent / safeDailyLimit) * 100) : (numTodaySpent > 0 ? 100 : 0);

  // 3. Perbandingan laju belanja riil (burn rate) vs batas aman
  const burnRateDifference = numAvgDailySpend - safeDailyLimit;
  const isBurnRateExceedingSafe = safeDailyLimit > 0 && numAvgDailySpend > safeDailyLimit;
  const burnRateOverPercentage = safeDailyLimit > 0 && numAvgDailySpend > safeDailyLimit
    ? Math.round(((numAvgDailySpend - safeDailyLimit) / safeDailyLimit) * 100)
    : 0;

  // 4. Pembagian rekomendasi belanja per pos (Kebutuhan 50%, Tabungan 30%, Hiburan 20%)
  const needsDaily = Math.round(safeDailyLimit * 0.5);
  const savingsDaily = Math.round(safeDailyLimit * 0.3);
  const funDaily = Math.round(safeDailyLimit * 0.2);

  // 5. Tentukan Status & Level Peringatan
  let status = 'safe'; // 'safe' | 'warning' | 'critical' | 'exhausted' | 'no_budget'
  let warnLevel = 'normal'; // 'normal' | 'warning' | 'critical'
  let adviceTitle = 'Saran Belanja Hari Ini';
  let adviceMessage = '';
  const recommendations = [];

  if (numTotalBudget <= 0 && numRemainingBudget <= 0) {
    status = 'no_budget';
    warnLevel = 'normal';
    adviceTitle = 'Belum Ada Budget Bulanan';
    adviceMessage = 'Atur batas budget bulanan terlebih dahulu agar Moneta AI dapat menghitung batas aman belanja harian Anda.';
    recommendations.push('Buat budget bulanan di tab Budgeting untuk mendapatkan panduan belanja harian otomatis.');
  } else if (numRemainingBudget <= 0) {
    status = 'exhausted';
    warnLevel = 'critical';
    adviceTitle = 'Anggaran Bulan Ini Habis';
    adviceMessage = 'Anggaran bulan berjalan telah habis terpakai. Hindari pengeluaran non-pokok hingga awal bulan depan.';
    recommendations.push('Tunda seluruh pengeluaran hiburan dan belanja non-pokok.');
    recommendations.push('Manfaatkan persediaan dapur rumah untuk memangkas jajan harian.');
  } else if (safeDailyLimit < 15000 && safeRemainingDays > 1) {
    status = 'critical';
    warnLevel = 'critical';
    adviceTitle = 'Batas Belanja Sangat Terbatas';
    adviceMessage = `Sisa anggaran sangat menipis (${formatRupiah(numRemainingBudget)}). Batas belanja hanya ${formatRupiah(safeDailyLimit)} / hari untuk ${safeRemainingDays} hari ke depan.`;
    recommendations.push('Perketat belanja harian ke kebutuhan darurat saja.');
    recommendations.push(`Terapkan batas ketat ${formatRupiah(safeDailyLimit)} hari ini.`);
  } else if (isTodayOverLimit) {
    status = 'warning';
    warnLevel = 'warning';
    adviceTitle = 'Batas Belanja Hari Ini Terlampaui';
    adviceMessage = `Pengeluaran hari ini sudah mencapai ${formatRupiah(numTodaySpent)}, melampaui batas aman harian (${formatRupiah(safeDailyLimit)}). Tunda belanja tambahan hari ini.`;
    recommendations.push(`Kelebihan belanja hari ini: ${formatRupiah(todayOverLimitAmount)}.`);
    recommendations.push('Kompensasikan dengan berhemat lebih ekstra pada hari esok.');
  } else if (isBurnRateExceedingSafe) {
    status = 'warning';
    warnLevel = 'warning';
    adviceTitle = 'Laju Belanja Mulai Melampaui Batas Aman';
    adviceMessage = `Rata-rata pengeluaran Anda (${formatRupiah(numAvgDailySpend)}/hari) lebih tinggi dari batas aman (${formatRupiah(safeDailyLimit)}/hari). Turunkan ritme belanja agar saldo cukup sampai awal bulan.`;
    recommendations.push(`Kurangi belanja harian sekitar ${formatRupiah(burnRateDifference)} agar kembali ke ritme aman.`);
    recommendations.push(`Alokasikan maksimal ${formatRupiah(needsDaily)} untuk kebutuhan pokok dan ${formatRupiah(funDaily)} untuk hiburan hari ini.`);
  } else {
    status = 'safe';
    warnLevel = 'normal';
    adviceTitle = 'Ritme Belanja Aman';
    adviceMessage = `Batas belanja aman Anda hari ini adalah ${formatRupiah(safeDailyLimit)} agar saldo bertahan sampai awal bulan (${safeRemainingDays} hari tersisa).`;
    recommendations.push(`Gunakan maksimal ${formatRupiah(needsDaily)} untuk pos kebutuhan pokok hari ini.`);
    recommendations.push(`Alokasikan maksimal ${formatRupiah(funDaily)} jika ingin jajan atau hiburan ringan.`);
    if (numTodaySpent > 0) {
      recommendations.push(`Sisa jatah belanja aman hari ini: ${formatRupiah(todayRemainingAllowance)}.`);
    }
  }

  return {
    safeDailyLimit,
    formattedSafeDailyLimit: `${formatRupiah(safeDailyLimit)} / hari`,
    remainingBudget: numRemainingBudget,
    formattedRemainingBudget: formatRupiah(numRemainingBudget),
    remainingDays: safeRemainingDays,
    todaySpent: numTodaySpent,
    formattedTodaySpent: formatRupiah(numTodaySpent),
    todayRemainingAllowance,
    formattedTodayRemainingAllowance: formatRupiah(todayRemainingAllowance),
    isTodayOverLimit,
    todayOverLimitAmount,
    formattedTodayOverLimitAmount: formatRupiah(todayOverLimitAmount),
    todayUsagePercentage,
    burnRateComparison: {
      avgDailySpend: numAvgDailySpend,
      formattedAvgDailySpend: `${formatRupiah(numAvgDailySpend)} / hari`,
      difference: burnRateDifference,
      formattedDifference: formatRupiah(Math.abs(burnRateDifference)),
      isExceedingSafeLimit: isBurnRateExceedingSafe,
      overPercentage: burnRateOverPercentage,
      paceStatus: isBurnRateExceedingSafe ? 'over_pace' : 'on_track',
    },
    bucketAllocation: {
      needs: needsDaily,
      formattedNeeds: `${formatRupiah(needsDaily)} / hari`,
      savings: savingsDaily,
      formattedSavings: `${formatRupiah(savingsDaily)} / hari`,
      fun: funDaily,
      formattedFun: `${formatRupiah(funDaily)} / hari`,
    },
    status,
    warnLevel,
    adviceTitle,
    adviceMessage,
    recommendations,
  };
}

/**
 * Mengambil data keuangan pengguna dari database dan menghitung batas aman belanja harian
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} params
 * @param {number|string} params.userId
 * @param {Date|string} [params.referenceDate=new Date()]
 * @param {boolean} [params.autoCache=true]
 * @returns {Object}
 */
export function getSafeDailySpendingForUser(db, {
  userId,
  referenceDate = new Date(),
  autoCache = true,
} = {}) {
  if (!userId) {
    throw new Error('userId is required to calculate safe daily spending');
  }

  const refDateObj = new Date(referenceDate);
  const isoDate = toIsoDateString(refDateObj);
  const { monthString, daysInMonth, currentDay } = getMonthDateMetrics(refDateObj);
  const remainingDays = getDaysRemainingInMonth(refDateObj, { includeToday: true });

  // 1. Ambil monthly budget user jika ada
  const budgetStmt = db.prepare(`
    SELECT total_amount, needs_pct, savings_pct, fun_pct
    FROM monthly_budgets
    WHERE user_id = ? AND month = ?
    LIMIT 1
  `);
  const budgetRow = budgetStmt.get(userId, monthString);

  // Jika tidak ada di monthly_budgets, cek budgets root
  let totalMonthlyBudget = 0;
  if (budgetRow) {
    totalMonthlyBudget = Number(budgetRow.total_amount) || 0;
  } else {
    const rootBudgetStmt = db.prepare(`
      SELECT total_amount, amount_limit
      FROM budgets
      WHERE user_id = ? AND month = ? AND category_id IS NULL
      LIMIT 1
    `);
    const rootRow = rootBudgetStmt.get(userId, monthString);
    if (rootRow) {
      totalMonthlyBudget = Number(rootRow.total_amount || rootRow.amount_limit) || 0;
    }
  }

  // 2. Hitung total pengeluaran bulan berjalan sampai hari ini
  const monthSpentStmt = db.prepare(`
    SELECT COALESCE(SUM(amount), 0) AS total_spent
    FROM transactions
    WHERE user_id = ?
      AND type = 'expense'
      AND is_confirmed = 1
      AND strftime('%Y-%m', occurred_at) = ?
  `);
  const { total_spent: totalSpent } = monthSpentStmt.get(userId, monthString);

  // 3. Hitung total pengeluaran khusus hari ini
  const todaySpentStmt = db.prepare(`
    SELECT COALESCE(SUM(amount), 0) AS today_spent
    FROM transactions
    WHERE user_id = ?
      AND type = 'expense'
      AND is_confirmed = 1
      AND strftime('%Y-%m-%d', occurred_at) = ?
  `);
  const { today_spent: todaySpent } = todaySpentStmt.get(userId, isoDate);

  // 4. Hitung total pemasukan bulan berjalan untuk fallback balance
  const monthIncomeStmt = db.prepare(`
    SELECT COALESCE(SUM(amount), 0) AS total_income
    FROM transactions
    WHERE user_id = ?
      AND type = 'income'
      AND is_confirmed = 1
      AND strftime('%Y-%m', occurred_at) = ?
  `);
  const { total_income: totalIncome } = monthIncomeStmt.get(userId, monthString);

  // Jika pengguna belum menentukan budget, fallback ke pemasukan - pengeluaran
  let effectiveBudget = totalMonthlyBudget;
  let remainingBudget = 0;

  if (totalMonthlyBudget > 0) {
    remainingBudget = totalMonthlyBudget - Number(totalSpent);
  } else if (Number(totalIncome) > 0) {
    effectiveBudget = Number(totalIncome);
    remainingBudget = Number(totalIncome) - Number(totalSpent);
  } else {
    effectiveBudget = 0;
    remainingBudget = -Number(totalSpent);
  }

  // 5. Ambil rata-rata pengeluaran harian 7 hari terakhir
  const avgResult = calculateDailyAverageSpending(db, {
    userId,
    referenceDate: refDateObj,
    daysWindow: 7,
  });
  const avgDailySpend = avgResult.averageDailySpend || 0;

  // 6. Jalankan kalkulasi batas aman
  const calculation = calculateSafeDailySpending({
    remainingBudget,
    remainingDays,
    todaySpent: Number(todaySpent),
    avgDailySpend,
    totalMonthlyBudget: effectiveBudget,
    totalSpent: Number(totalSpent),
  });

  const fullResult = {
    userId,
    date: isoDate,
    month: monthString,
    daysInMonth,
    currentDay,
    totalMonthlyBudget: effectiveBudget,
    formattedTotalMonthlyBudget: formatRupiah(effectiveBudget),
    totalSpent: Number(totalSpent),
    formattedTotalSpent: formatRupiah(Number(totalSpent)),
    totalIncome: Number(totalIncome),
    formattedTotalIncome: formatRupiah(Number(totalIncome)),
    ...calculation,
  };

  // 7. Simpan ke daily_advice_cache jika autoCache diaktifkan
  if (autoCache) {
    saveCachedDailyAdvice(db, {
      userId,
      date: isoDate,
      recommendedDailyBudget: calculation.safeDailyLimit,
      estimatedDaysLeft: remainingDays,
      dailyAdvice: calculation.adviceMessage,
      warnLevel: calculation.warnLevel,
      avgDailySpend,
      totalMonthlyBudget: effectiveBudget,
      totalSpent: Number(totalSpent),
      remainingBalance: remainingBudget,
      source: 'rule_based',
      adviceJson: {
        title: calculation.adviceTitle,
        status: calculation.status,
        todaySpent: calculation.todaySpent,
        todayRemainingAllowance: calculation.todayRemainingAllowance,
        isTodayOverLimit: calculation.isTodayOverLimit,
        bucketAllocation: calculation.bucketAllocation,
        recommendations: calculation.recommendations,
      },
    });
  }

  return fullResult;
}

/**
 * Simulasi What-If: Menghitung skenario batas belanja dengan variasi budget atau pengeluaran
 *
 * @param {Object} params
 * @param {number} params.remainingBudget
 * @param {number} params.remainingDays
 * @param {number} [params.simulatedDailySpend]
 * @returns {Object}
 */
export function simulateSafeDailySpending({
  remainingBudget = 0,
  remainingDays = 1,
  simulatedDailySpend = 0,
} = {}) {
  const calculation = calculateSafeDailySpending({
    remainingBudget,
    remainingDays,
    avgDailySpend: simulatedDailySpend,
  });

  const simulatedDaysSurvival = simulatedDailySpend > 0 && remainingBudget > 0
    ? Math.floor(remainingBudget / simulatedDailySpend)
    : (remainingBudget <= 0 ? 0 : 999);

  return {
    ...calculation,
    simulatedDailySpend,
    formattedSimulatedDailySpend: `${formatRupiah(simulatedDailySpend)} / hari`,
    simulatedDaysSurvival,
    survivesUntilMonthEnd: simulatedDaysSurvival >= remainingDays,
  };
}
