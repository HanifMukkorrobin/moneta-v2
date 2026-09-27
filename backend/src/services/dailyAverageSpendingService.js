/**
 * Daily Average Spending Service (Layanan Kalkulasi Rata-rata Pengeluaran Harian)
 *
 * Menghitung rata-rata pengeluaran harian pengguna (7 hari terakhir, 30 hari,
 * atau month-to-date), perbandingan week-over-week (WoW), hari pengeluaran tertinggi & terhemat,
 * serta kontribusi kategori terbesar untuk Analisa Keuangan AI.
 */

import { getCachedAnalysis, saveCachedAnalysis } from './analysisCacheService.js';

export const ID_DAY_NAMES = [
  'Minggu',
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
];

export const ID_DAY_SHORT_LABELS = [
  'Min',
  'Sen',
  'Sel',
  'Rab',
  'Kam',
  'Jum',
  'Sab',
];

/**
 * Format angka ke format mata uang Rupiah standar (contoh: "Rp 78.500")
 */
export function formatRupiah(amount) {
  const num = Math.round(Math.abs(Number(amount) || 0));
  const formatted = num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return Number(amount) < 0 ? `- Rp ${formatted}` : `Rp ${formatted}`;
}

/**
 * Format nominal Rupiah ringkas untuk grafik batang (contoh: "65rb", "1.5jt", dsb)
 */
export function formatCompactRupiah(amount, withSymbol = false) {
  const num = Math.abs(Number(amount) || 0);
  let result = '0';

  if (num >= 1000000000) {
    const val = (num / 1000000000).toFixed(1).replace(/\.0$/, '');
    result = `${val}M`;
  } else if (num >= 1000000) {
    const val = (num / 1000000).toFixed(1).replace(/\.0$/, '');
    result = `${val}jt`;
  } else if (num >= 1000) {
    const val = (num / 1000).toFixed(0);
    result = `${val}rb`;
  } else if (num > 0) {
    result = num.toString();
  }

  return withSymbol ? `Rp ${result}` : result;
}

/**
 * Mendapatkan nama hari bahasa Indonesia (contoh: "Senin")
 */
export function getDayName(dateInput) {
  const d = new Date(dateInput);
  const dayIndex = d.getDay();
  return ID_DAY_NAMES[dayIndex] || 'Hari';
}

/**
 * Mendapatkan singkatan hari bahasa Indonesia (contoh: "Sen")
 */
export function getDayShortLabel(dateInput) {
  const d = new Date(dateInput);
  const dayIndex = d.getDay();
  return ID_DAY_SHORT_LABELS[dayIndex] || '-';
}

/**
 * Konversi Date object atau string ke format string YYYY-MM-DD
 */
export function toIsoDateString(inputDate = new Date()) {
  if (typeof inputDate === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(inputDate)) {
    return inputDate;
  }
  const d = new Date(inputDate);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Menghitung array tanggal YYYY-MM-DD dalam rentang
 */
export function getDatesInRange(startDateStr, endDateStr) {
  const dates = [];
  const start = new Date(startDateStr);
  const end = new Date(endDateStr);

  const curr = new Date(start);
  while (curr <= end) {
    dates.push(toIsoDateString(curr));
    curr.setDate(curr.getDate() + 1);
  }

  return dates;
}

/**
 * Mengambil target pengeluaran harian dari tabel budget bulanan pengguna
 */
export function getTargetDailySpend(db, userId, targetDate = new Date()) {
  const dateStr = toIsoDateString(targetDate);
  const monthStr = dateStr.substring(0, 7);

  // Cek pada monthly_budgets
  const monthlyRow = db
    .prepare(`
      SELECT total_amount
      FROM monthly_budgets
      WHERE user_id = ? AND month = ?
      LIMIT 1
    `)
    .get(userId, monthStr);

  let totalBudget = 0;
  if (monthlyRow && monthlyRow.total_amount > 0) {
    totalBudget = Number(monthlyRow.total_amount);
  } else {
    // Fallback ke tabel budgets root (category_id IS NULL)
    const rootRow = db
      .prepare(`
        SELECT COALESCE(total_amount, amount_limit, 0) as total_budget
        FROM budgets
        WHERE user_id = ? AND month = ? AND category_id IS NULL
        LIMIT 1
      `)
      .get(userId, monthStr);

    if (rootRow && rootRow.total_budget > 0) {
      totalBudget = Number(rootRow.total_budget);
    }
  }

  if (totalBudget <= 0) {
    return 0;
  }

  // Hitung jumlah hari dalam bulan tersebut
  const [yearStr, mStr] = monthStr.split('-');
  const daysInMonth = new Date(Number(yearStr), Number(mStr), 0).getDate();

  return Math.round(totalBudget / daysInMonth);
}

/**
 * Menghitung titik-titik pengeluaran harian (daily points) untuk chart dan metrik
 */
export function calculateDailySpendingPoints(db, {
  userId,
  startDateStr,
  endDateStr,
}) {
  const dates = getDatesInRange(startDateStr, endDateStr);

  // Ambil transaksi pengeluaran terkonfirmasi per tanggal
  const rows = db
    .prepare(`
      SELECT
        strftime('%Y-%m-%d', occurred_at) as tx_date,
        SUM(amount) as daily_total
      FROM transactions
      WHERE user_id = ?
        AND type = 'expense'
        AND is_confirmed = 1
        AND strftime('%Y-%m-%d', occurred_at) BETWEEN ? AND ?
      GROUP BY strftime('%Y-%m-%d', occurred_at)
    `)
    .all(userId, startDateStr, endDateStr);

  const expenseByDate = new Map();
  for (const r of rows) {
    expenseByDate.set(r.tx_date, Number(r.daily_total) || 0);
  }

  let totalSpent = 0;
  let highestSpendAmount = 0;
  let highestSpendDay = 'Senin';
  let highestSpendDate = startDateStr;

  let lowestSpendAmount = Infinity;
  let lowestSpendDay = 'Senin';
  let lowestSpendDate = startDateStr;

  const rawPoints = [];

  for (const dateStr of dates) {
    const amount = expenseByDate.get(dateStr) || 0;
    totalSpent += amount;

    const dateObj = new Date(`${dateStr}T12:00:00`);
    const dayName = getDayName(dateObj);
    const dayLabel = getDayShortLabel(dateObj);

    if (amount > highestSpendAmount) {
      highestSpendAmount = amount;
      highestSpendDay = dayName;
      highestSpendDate = dateStr;
    }

    if (amount < lowestSpendAmount) {
      lowestSpendAmount = amount;
      lowestSpendDay = dayName;
      lowestSpendDate = dateStr;
    }

    rawPoints.push({
      dateStr,
      date: dateObj,
      dayLabel,
      dayName,
      amount,
      formattedAmount: formatRupiah(amount),
      formattedShortAmount: formatCompactRupiah(amount, false),
    });
  }

  // Jika semua amount 0
  if (lowestSpendAmount === Infinity) {
    lowestSpendAmount = 0;
    if (rawPoints.length > 0) {
      lowestSpendDay = rawPoints[0].dayName;
      lowestSpendDate = rawPoints[0].dateStr;
    }
  }

  const daysCount = dates.length || 1;
  const avgDailySpend = Math.round(totalSpent / daysCount);

  // Tandai isAboveAverage pada masing-masing point
  const dailyPoints = rawPoints.map((p) => ({
    ...p,
    isAboveAverage: p.amount > avgDailySpend,
  }));

  return {
    dailyPoints,
    totalSpent,
    avgDailySpend,
    highestSpendAmount,
    highestSpendDay,
    highestSpendDate,
    lowestSpendAmount,
    lowestSpendDay,
    lowestSpendDate,
  };
}

/**
 * Menghitung kategori pengeluaran dengan kontribusi nominal terbesar pada periode
 */
export function calculateTopSpendingCategory(db, {
  userId,
  startDateStr,
  endDateStr,
  totalSpent,
}) {
  if (totalSpent <= 0) {
    return {
      topCategoryName: 'Lainnya',
      topCategoryPercentage: 0,
      topCategoryAmount: 0,
      categoryBreakdown: [],
    };
  }

  const rows = db
    .prepare(`
      SELECT
        COALESCE(c.name, t.category_name, 'Lainnya') as category_name,
        SUM(t.amount) as category_total
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.user_id = ?
        AND t.type = 'expense'
        AND t.is_confirmed = 1
        AND strftime('%Y-%m-%d', t.occurred_at) BETWEEN ? AND ?
      GROUP BY category_name
      ORDER BY category_total DESC
    `)
    .all(userId, startDateStr, endDateStr);

  if (rows.length === 0) {
    return {
      topCategoryName: 'Lainnya',
      topCategoryPercentage: 0,
      topCategoryAmount: 0,
      categoryBreakdown: [],
    };
  }

  const topRow = rows[0];
  const topAmount = Number(topRow.category_total) || 0;
  const topPercentage = Number(((topAmount / totalSpent) * 100).toFixed(1));

  const categoryBreakdown = rows.map((r) => {
    const amt = Number(r.category_total) || 0;
    return {
      categoryName: r.category_name,
      amount: amt,
      formattedAmount: formatRupiah(amt),
      percentage: Number(((amt / totalSpent) * 100).toFixed(1)),
    };
  });

  return {
    topCategoryName: topRow.category_name,
    topCategoryPercentage: topPercentage,
    topCategoryAmount: topAmount,
    categoryBreakdown,
  };
}

/**
 * Menghitung perbandingan pengeluaran pekan berjalan vs pekan sebelumnya (Week-over-Week)
 */
export function calculateWeekOverWeekChange(db, {
  userId,
  currentStartDateStr,
  currentEndDateStr,
  days = 7,
  currentTotalSpent = 0,
}) {
  // Hitung tanggal periode sebelumnya (mis. 7 hari sebelum currentStartDate)
  const currStart = new Date(currentStartDateStr);
  const prevEnd = new Date(currStart);
  prevEnd.setDate(prevEnd.getDate() - 1);

  const prevStart = new Date(prevEnd);
  prevStart.setDate(prevStart.getDate() - (days - 1));

  const prevStartStr = toIsoDateString(prevStart);
  const prevEndStr = toIsoDateString(prevEnd);

  const prevRow = db
    .prepare(`
      SELECT SUM(amount) as prev_total
      FROM transactions
      WHERE user_id = ?
        AND type = 'expense'
        AND is_confirmed = 1
        AND strftime('%Y-%m-%d', occurred_at) BETWEEN ? AND ?
    `)
    .get(userId, prevStartStr, prevEndStr);

  const prevTotalSpent = Number(prevRow?.prev_total) || 0;

  let weekOverWeekPercent = 0;
  if (prevTotalSpent > 0) {
    const diff = currentTotalSpent - prevTotalSpent;
    weekOverWeekPercent = Number(((diff / prevTotalSpent) * 100).toFixed(1));
  } else if (currentTotalSpent > 0) {
    weekOverWeekPercent = 100.0;
  } else {
    weekOverWeekPercent = 0.0;
  }

  const isSpendingIncreasing = weekOverWeekPercent > 0;
  const sign = weekOverWeekPercent > 0 ? '+' : '';
  const comparisonBadgeLabel = `${sign}${weekOverWeekPercent.toFixed(1)}% vs pekan lalu`;

  return {
    prevTotalSpent,
    prevStartDateStr: prevStartStr,
    prevEndDateStr: prevEndStr,
    weekOverWeekPercent,
    isSpendingIncreasing,
    comparisonBadgeLabel,
  };
}

/**
 * Service Utama: Menghitung Rata-rata Pengeluaran Harian Lengkap (Analisa Keuangan AI)
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} options
 * @param {number|string} options.userId
 * @param {number} [options.days=7] - Jumlah hari window (default 7 hari)
 * @param {string|Date} [options.referenceDate=null] - Tanggal acuan (default hari ini)
 * @returns {Object} Hasil kalkulasi rata-rata pengeluaran harian lengkap
 */
export function calculateDailyAverageSpending(db, {
  userId,
  days = 7,
  referenceDate = null,
} = {}) {
  if (!userId) {
    throw new Error('userId is required to calculate daily average spending');
  }

  const windowDays = Math.max(1, parseInt(days, 10) || 7);
  const refDate = referenceDate ? new Date(referenceDate) : new Date();
  const endDateStr = toIsoDateString(refDate);

  const startDateObj = new Date(refDate);
  startDateObj.setDate(startDateObj.getDate() - (windowDays - 1));
  const startDateStr = toIsoDateString(startDateObj);

  // 1. Hitung daily spending points
  const pointsData = calculateDailySpendingPoints(db, {
    userId,
    startDateStr,
    endDateStr,
  });

  const {
    dailyPoints,
    totalSpent,
    avgDailySpend,
    highestSpendAmount,
    highestSpendDay,
    highestSpendDate,
    lowestSpendAmount,
    lowestSpendDay,
    lowestSpendDate,
  } = pointsData;

  // 2. Hitung target pengeluaran harian dari budget
  const targetDailySpend = getTargetDailySpend(db, userId, refDate);
  const isAboveTarget = targetDailySpend > 0 ? avgDailySpend > targetDailySpend : false;

  // 3. Hitung kontribusi kategori terbesar
  const categoryData = calculateTopSpendingCategory(db, {
    userId,
    startDateStr,
    endDateStr,
    totalSpent,
  });

  // 4. Hitung week-over-week change
  const wowData = calculateWeekOverWeekChange(db, {
    userId,
    currentStartDateStr: startDateStr,
    currentEndDateStr: endDateStr,
    days: windowDays,
    currentTotalSpent: totalSpent,
  });

  return {
    userId,
    days: windowDays,
    startDate: startDateStr,
    endDate: endDateStr,
    totalSpent,
    avgDailySpend,
    targetDailySpend,
    isAboveTarget,
    formattedAvgDailySpend: formatRupiah(avgDailySpend),
    formattedTargetDailySpend: formatRupiah(targetDailySpend),
    highestSpendAmount,
    highestSpendDay,
    highestSpendDate,
    formattedHighestSpend: formatRupiah(highestSpendAmount),
    lowestSpendAmount,
    lowestSpendDay,
    lowestSpendDate,
    formattedLowestSpend: formatRupiah(lowestSpendAmount),
    topCategoryName: categoryData.topCategoryName,
    topCategoryPercentage: categoryData.topCategoryPercentage,
    topCategoryAmount: categoryData.topCategoryAmount,
    categoryBreakdown: categoryData.categoryBreakdown,
    prevTotalSpent: wowData.prevTotalSpent,
    weekOverWeekPercent: wowData.weekOverWeekPercent,
    isSpendingIncreasing: wowData.isSpendingIncreasing,
    comparisonBadgeLabel: wowData.comparisonBadgeLabel,
    dailyPoints,
    calculatedAt: new Date().toISOString(),
  };
}

/**
 * Menghitung rata-rata pengeluaran Month-To-Date (MTD) sejak awal bulan hingga hari ini
 */
export function calculateMonthToDateDailyAverage(db, {
  userId,
  month = null,
  referenceDate = null,
} = {}) {
  if (!userId) {
    throw new Error('userId is required for month-to-date calculation');
  }

  const refDate = referenceDate ? new Date(referenceDate) : new Date();
  const targetMonth = month || toIsoDateString(refDate).substring(0, 7);

  const [yearStr, monthStr] = targetMonth.split('-');
  const year = parseInt(yearStr, 10);
  const m = parseInt(monthStr, 10);

  const daysInMonth = new Date(year, m, 0).getDate();
  const startDateStr = `${targetMonth}-01`;

  // Tentukan batas hari: jika bulan berjalan, sampai hari tanggal refDate; jika bulan lampau, akhir bulan
  const isCurrentMonth = toIsoDateString(refDate).startsWith(targetMonth);
  const currentDayOfMonth = isCurrentMonth ? Math.min(refDate.getDate(), daysInMonth) : daysInMonth;
  const endDateStr = `${targetMonth}-${String(currentDayOfMonth).padStart(2, '0')}`;

  const row = db
    .prepare(`
      SELECT SUM(amount) as mtd_total
      FROM transactions
      WHERE user_id = ?
        AND type = 'expense'
        AND is_confirmed = 1
        AND strftime('%Y-%m-%d', occurred_at) BETWEEN ? AND ?
    `)
    .get(userId, startDateStr, endDateStr);

  const totalSpent = Number(row?.mtd_total) || 0;
  const daysElapsed = Math.max(1, currentDayOfMonth);
  const avgDailySpend = Math.round(totalSpent / daysElapsed);
  const projectedMonthExpense = Math.round(avgDailySpend * daysInMonth);
  const remainingDaysInMonth = Math.max(0, daysInMonth - currentDayOfMonth);

  return {
    userId,
    month: targetMonth,
    daysInMonth,
    daysElapsed,
    remainingDays: remainingDaysInMonth,
    totalSpent,
    avgDailySpend,
    projectedMonthExpense,
    formattedAvgDailySpend: formatRupiah(avgDailySpend),
    formattedTotalSpent: formatRupiah(totalSpent),
    formattedProjectedMonthExpense: formatRupiah(projectedMonthExpense),
  };
}

/**
 * Mengambil analisa rata-rata pengeluaran harian dengan fallback cache ai_insights
 */
export function getOrUpdateCachedDailyAverage(db, {
  userId,
  days = 7,
  referenceDate = null,
  forceRefresh = false,
} = {}) {
  const refDate = referenceDate ? new Date(referenceDate) : new Date();
  const dateStr = toIsoDateString(refDate);

  // Cek cache jika tidak dipaksa refresh
  if (!forceRefresh) {
    const cached = getCachedAnalysis(db, { userId, date: dateStr, allowStale: false });
    if (cached && cached.analysis && cached.analysis.dailyPoints) {
      return {
        ...cached.analysis,
        fromCache: true,
        cachedAt: cached.updatedAt,
      };
    }
  }

  // Hitung ulang analisa secara realtime
  const analysisResult = calculateDailyAverageSpending(db, {
    userId,
    days,
    referenceDate: refDate,
  });

  // Simpan / update ke cache ai_insights
  saveCachedAnalysis(db, {
    userId,
    date: dateStr,
    avgDailySpend: analysisResult.avgDailySpend,
    recommendedDailyBudget: analysisResult.targetDailySpend,
    totalSpent: analysisResult.totalSpent,
    analysis: analysisResult,
    ttlHours: 12,
  });

  return {
    ...analysisResult,
    fromCache: false,
  };
}
