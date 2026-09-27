/**
 * Service: Rekap Query & Aggregation Service
 * Provides SQL aggregation queries for monthly financial summaries,
 * category breakdowns, month-over-month comparisons, and daily trends.
 */

/**
 * Formats a Date object to YYYY-MM
 */
export function getCurrentMonthString(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

/**
 * Helper to compute previous month formatted as YYYY-MM
 */
export function getPreviousMonthString(monthStr) {
  const parts = monthStr.split('-');
  let year = parseInt(parts[0], 10);
  let month = parseInt(parts[1], 10);

  month -= 1;
  if (month < 1) {
    month = 12;
    year -= 1;
  }
  return `${year}-${String(month).padStart(2, '0')}`;
}

/**
 * Helper to calculate number of days in a given month
 */
export function getDaysInMonth(monthStr) {
  try {
    const parts = monthStr.split('-');
    const year = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10);
    return new Date(year, month, 0).getDate();
  } catch {
    return 30;
  }
}

/**
 * Helper to get Indonesian month label
 */
export function getMonthLabel(monthStr) {
  const months = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  try {
    const parts = monthStr.split('-');
    const year = parseInt(parts[0], 10);
    const month = parseInt(parts[1], 10);
    if (month >= 1 && month <= 12) {
      return `${months[month]} ${year}`;
    }
  } catch {}
  return monthStr;
}

/**
 * Query 1: Income and Expense Summary Aggregation
 * Supports monthly filtering or custom date ranges (startDate & endDate).
 */
export function getIncomeExpenseSummaryQuery(db, userId, options = {}) {
  const {
    month: inputMonth,
    startDate: inputStartDate,
    endDate: inputEndDate,
    includePending = false,
  } = options;

  let timeClause = '';
  let timeParams = [];
  let month = inputMonth;
  let startDate = inputStartDate;
  let endDate = inputEndDate;
  let monthLabel = '';
  let daysInPeriod = 30;

  if (startDate && endDate) {
    timeClause = 'occurred_at >= ? AND occurred_at <= ?';
    const endParam = endDate.length === 10 ? `${endDate} 23:59:59` : endDate;
    timeParams = [startDate, endParam];
    if (!month) {
      month = startDate.slice(0, 7);
    }
    monthLabel = `${startDate} s/d ${endDate}`;
    try {
      const d1 = new Date(startDate);
      const d2 = new Date(endDate);
      const diffTime = Math.abs(d2 - d1);
      daysInPeriod = Math.max(1, Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1);
    } catch {
      daysInPeriod = 30;
    }
  } else {
    month = month || getCurrentMonthString();
    timeClause = 'occurred_at LIKE ?';
    timeParams = [`${month}%`];
    monthLabel = getMonthLabel(month);
    daysInPeriod = getDaysInMonth(month);
    startDate = `${month}-01`;
    endDate = `${month}-${String(daysInPeriod).padStart(2, '0')}`;
  }

  const querySql = `
    SELECT
      COALESCE(SUM(CASE WHEN type = 'income' AND is_confirmed = 1 THEN amount ELSE 0 END), 0) AS total_income,
      COALESCE(SUM(CASE WHEN type = 'expense' AND is_confirmed = 1 THEN amount ELSE 0 END), 0) AS total_expense,
      COUNT(CASE WHEN is_confirmed = 1 THEN 1 END) AS confirmed_count,
      COUNT(CASE WHEN is_confirmed = 0 THEN 1 END) AS pending_count,
      COUNT(CASE WHEN type = 'income' AND is_confirmed = 1 THEN 1 END) AS income_count,
      COUNT(CASE WHEN type = 'expense' AND is_confirmed = 1 THEN 1 END) AS expense_count,
      COALESCE(SUM(CASE WHEN type = 'expense' AND is_confirmed = 0 THEN amount ELSE 0 END), 0) AS pending_expense,
      COALESCE(SUM(CASE WHEN type = 'income' AND is_confirmed = 0 THEN amount ELSE 0 END), 0) AS pending_income
    FROM transactions
    WHERE user_id = ? AND ${timeClause}
  `;

  const row = db.prepare(querySql).get(userId, ...timeParams);

  const totalIncome = row ? Number(row.total_income) : 0;
  const totalExpense = row ? Number(row.total_expense) : 0;
  const netSavings = totalIncome - totalExpense;
  const isSurplus = netSavings >= 0;
  const status = isSurplus ? 'surplus' : 'deficit';
  const statusLabel = isSurplus ? 'Surplus' : 'Defisit';

  const savingsRate = totalIncome > 0
    ? Math.round(((totalIncome - totalExpense) / totalIncome) * 1000) / 10
    : 0;

  const expenseRatio = totalIncome > 0
    ? Math.round((totalExpense / totalIncome) * 1000) / 10
    : 0;

  const averageDailyExpense = daysInPeriod > 0
    ? Math.round((totalExpense / daysInPeriod) * 100) / 100
    : 0;

  const averageDailyIncome = daysInPeriod > 0
    ? Math.round((totalIncome / daysInPeriod) * 100) / 100
    : 0;

  const confirmedTransactionsCount = row ? Number(row.confirmed_count) : 0;
  const pendingTransactionsCount = row ? Number(row.pending_count) : 0;
  const incomeTransactionsCount = row ? Number(row.income_count) : 0;
  const expenseTransactionsCount = row ? Number(row.expense_count) : 0;
  const pendingExpenseTotal = row ? Number(row.pending_expense) : 0;
  const pendingIncomeTotal = row ? Number(row.pending_income) : 0;

  const totalCashflow = totalIncome + totalExpense;
  const incomePercentage = totalCashflow > 0
    ? Math.round((totalIncome / totalCashflow) * 1000) / 10
    : 0;
  const expensePercentage = totalCashflow > 0
    ? Math.round((totalExpense / totalCashflow) * 1000) / 10
    : 0;

  // Query largest confirmed expense
  const largestExpenseSql = `
    SELECT t.id, t.amount, t.note, COALESCE(c.name, t.category_name, 'Lainnya') AS category_name, t.occurred_at
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    WHERE t.user_id = ? AND ${timeClause.replace(/occurred_at/g, 't.occurred_at')} AND t.type = 'expense' AND t.is_confirmed = 1
    ORDER BY t.amount DESC, t.id DESC
    LIMIT 1
  `;
  const largestExpenseRow = db.prepare(largestExpenseSql).get(userId, ...timeParams);

  // Query largest confirmed income
  const largestIncomeSql = `
    SELECT t.id, t.amount, t.note, COALESCE(c.name, t.category_name, 'Lainnya') AS category_name, t.occurred_at
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    WHERE t.user_id = ? AND ${timeClause.replace(/occurred_at/g, 't.occurred_at')} AND t.type = 'income' AND t.is_confirmed = 1
    ORDER BY t.amount DESC, t.id DESC
    LIMIT 1
  `;
  const largestIncomeRow = db.prepare(largestIncomeSql).get(userId, ...timeParams);

  const isEmpty = confirmedTransactionsCount === 0 && pendingTransactionsCount === 0;
  const hasConfirmedData = confirmedTransactionsCount > 0;

  return {
    month,
    monthLabel,
    isEmpty,
    hasData: !isEmpty,
    hasConfirmedData,
    emptyState: {
      isEmpty: !hasConfirmedData,
      badge: 'Belum Ada Data',
      title: 'Belum Ada Catatan Keuangan',
      message: `Belum ada transaksi tercatat di ${monthLabel}. Semua bagian rekap di bawah ini akan terisi otomatis saat Anda mulai mencatat.`,
    },
    period: {
      month,
      startDate,
      endDate,
      daysInPeriod,
    },
    summary: {
      totalIncome,
      totalExpense,
      netSavings,
      isSurplus,
      status,
      statusLabel,
      savingsRate,
      expenseRatio,
      averageDailyExpense,
      averageDailyIncome,
      isEmpty: !hasConfirmedData,
      emptyBadge: 'Belum Ada Data',
    },
    counts: {
      total: confirmedTransactionsCount,
      confirmed: confirmedTransactionsCount,
      pending: pendingTransactionsCount,
      income: incomeTransactionsCount,
      expense: expenseTransactionsCount,
    },
    pending: {
      totalIncome: pendingIncomeTotal,
      totalExpense: pendingExpenseTotal,
      count: pendingTransactionsCount,
    },
    proportions: {
      incomePercentage,
      expensePercentage,
    },
    largestTransactions: {
      largestExpense: largestExpenseRow ? {
        id: largestExpenseRow.id,
        amount: Number(largestExpenseRow.amount),
        note: largestExpenseRow.note,
        categoryName: largestExpenseRow.category_name,
        occurredAt: largestExpenseRow.occurred_at,
      } : null,
      largestIncome: largestIncomeRow ? {
        id: largestIncomeRow.id,
        amount: Number(largestIncomeRow.amount),
        note: largestIncomeRow.note,
        categoryName: largestIncomeRow.category_name,
        occurredAt: largestIncomeRow.occurred_at,
      } : null,
    },
    // Top-level fields for flat access and backwards compatibility:
    totalIncome,
    totalExpense,
    netSavings,
    savingsRate,
    daysInMonth: daysInPeriod,
    averageDailyExpense,
    confirmedTransactionsCount,
    pendingTransactionsCount,
    incomeTransactionsCount,
    expenseTransactionsCount,
    pendingExpenseTotal,
    pendingIncomeTotal,
  };
}

/**
 * Query 1 (Legacy/Standard Alias): Monthly Summary Totals Aggregation
 */
export function getMonthlyTotalsQuery(db, userId, month) {
  return getIncomeExpenseSummaryQuery(db, userId, { month });
}

/**
 * Helper to format Rupiah currency in Indonesian format
 */
export function formatRupiah(amount) {
  const num = Math.round(Math.abs(Number(amount) || 0));
  return `Rp ${num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;
}

/**
 * Query 2: Month-over-Month (MoM) Comparison Aggregation
 */
export function getMonthOverMonthComparisonQuery(db, userId, month, options = {}) {
  const targetMonth = month || getCurrentMonthString();
  const previousMonth = options.previousMonth || options.compareWith || getPreviousMonthString(targetMonth);

  const current = getMonthlyTotalsQuery(db, userId, targetMonth);
  const previous = getMonthlyTotalsQuery(db, userId, previousMonth);

  const lastMonthTotalExpense = previous.totalExpense;
  const lastMonthTotalIncome = previous.totalIncome;
  const hasPreviousMonthData = lastMonthTotalExpense > 0 || lastMonthTotalIncome > 0;

  let expenseDiffPct = 0;
  if (lastMonthTotalExpense > 0) {
    expenseDiffPct = Math.round(((current.totalExpense - lastMonthTotalExpense) / lastMonthTotalExpense) * 1000) / 10;
  } else if (current.totalExpense > 0) {
    expenseDiffPct = 100;
  }

  let incomeDiffPct = 0;
  if (lastMonthTotalIncome > 0) {
    incomeDiffPct = Math.round(((current.totalIncome - lastMonthTotalIncome) / lastMonthTotalIncome) * 1000) / 10;
  } else if (current.totalIncome > 0) {
    incomeDiffPct = 100;
  }

  const expenseNominalDiff = current.totalExpense - lastMonthTotalExpense;
  const expenseNominalDiffAbs = Math.abs(expenseNominalDiff);
  const expenseDiffAbsPct = Math.abs(expenseDiffPct);
  const isExpenseHigher = current.totalExpense > lastMonthTotalExpense;
  const isExpenseLower = expenseDiffPct <= 0;
  const expenseTrend = expenseNominalDiff > 0 ? 'up' : expenseNominalDiff < 0 ? 'down' : 'same';

  const incomeNominalDiff = current.totalIncome - lastMonthTotalIncome;
  const incomeNominalDiffAbs = Math.abs(incomeNominalDiff);
  const isIncomeHigher = current.totalIncome > lastMonthTotalIncome;
  const netSavingsDiff = current.netSavings - previous.netSavings;

  const badgeText = `${isExpenseLower ? 'Hemat' : 'Naik'} ${expenseDiffAbsPct.toFixed(1)}%`;
  const formattedNominalDiff = formatRupiah(expenseNominalDiffAbs);
  const insightMessage = !hasPreviousMonthData
    ? 'Belum ada data transaksi di bulan sebelumnya untuk dibandingkan.'
    : isExpenseLower
      ? `Pengeluaran bulan ini lebih hemat ${formattedNominalDiff} dibandingkan bulan lalu.`
      : `Pengeluaran bulan ini meningkat ${formattedNominalDiff} dibandingkan bulan lalu.`;

  // Per-category expense comparison between current month and previous month
  const currentCatBreakdown = getCategoryBreakdownQuery(db, userId, targetMonth, 'expense');
  const prevCatBreakdown = getCategoryBreakdownQuery(db, userId, previousMonth, 'expense');

  const categoryMap = new Map();
  for (const item of currentCatBreakdown) {
    categoryMap.set(item.categoryName, {
      categoryName: item.categoryName,
      category: item.categoryName,
      icon: item.icon,
      color: item.color,
      currentMonthTotal: item.total,
      previousMonthTotal: 0,
    });
  }
  for (const item of prevCatBreakdown) {
    if (categoryMap.has(item.categoryName)) {
      categoryMap.get(item.categoryName).previousMonthTotal = item.total;
    } else {
      categoryMap.set(item.categoryName, {
        categoryName: item.categoryName,
        category: item.categoryName,
        icon: item.icon,
        color: item.color,
        currentMonthTotal: 0,
        previousMonthTotal: item.total,
      });
    }
  }

  const categoryComparison = Array.from(categoryMap.values()).map((c) => {
    const nominalDiff = c.currentMonthTotal - c.previousMonthTotal;
    let diffPct = 0;
    if (c.previousMonthTotal > 0) {
      diffPct = Math.round(((c.currentMonthTotal - c.previousMonthTotal) / c.previousMonthTotal) * 1000) / 10;
    } else if (c.currentMonthTotal > 0) {
      diffPct = 100;
    }
    return {
      ...c,
      nominalDiff,
      nominalDiffAbs: Math.abs(nominalDiff),
      diffPct,
      trend: nominalDiff > 0 ? 'up' : nominalDiff < 0 ? 'down' : 'same',
    };
  }).sort((a, b) => b.currentMonthTotal - a.currentMonthTotal || b.previousMonthTotal - a.previousMonthTotal);

  return {
    currentMonth: targetMonth,
    currentMonthLabel: getMonthLabel(targetMonth),
    previousMonth,
    previousMonthLabel: getMonthLabel(previousMonth),
    hasPreviousMonthData,
    isEmpty: !hasPreviousMonthData,
    emptyState: {
      isEmpty: !hasPreviousMonthData,
      title: 'Perbandingan Bulan Lalu',
      message: 'Belum ada data transaksi di bulan sebelumnya untuk dibandingkan.',
    },
    totalExpense: current.totalExpense,
    lastMonthTotalExpense,
    expenseNominalDiff,
    expenseNominalDiffAbs,
    expenseDiffPct,
    expenseDiffAbsPct,
    isExpenseHigher,
    isExpenseLower,
    expenseTrend,
    badgeText,
    insightMessage,
    totalIncome: current.totalIncome,
    lastMonthTotalIncome,
    incomeNominalDiff,
    incomeNominalDiffAbs,
    incomeDiffPct,
    isIncomeHigher,
    netSavingsDiff,
    thisMonth: {
      month: targetMonth,
      monthLabel: current.monthLabel,
      totalIncome: current.totalIncome,
      totalExpense: current.totalExpense,
      netSavings: current.netSavings,
      savingsRate: current.savingsRate,
      averageDailyExpense: current.averageDailyExpense,
      transactionCount: current.confirmedTransactionsCount,
    },
    lastMonth: {
      month: previousMonth,
      monthLabel: previous.monthLabel,
      totalIncome: previous.totalIncome,
      totalExpense: previous.totalExpense,
      netSavings: previous.netSavings,
      savingsRate: previous.savingsRate,
      averageDailyExpense: previous.averageDailyExpense,
      transactionCount: previous.confirmedTransactionsCount,
    },
    categoryComparison,
  };
}

/**
 * Query 3: Category Breakdown Aggregation
 */
export function getCategoryBreakdownQuery(db, userId, month, filterType = null, options = {}) {
  const {
    startDate,
    endDate,
    search,
    sortBy = 'highest',
  } = options;

  let timeClause = 't.occurred_at LIKE ?';
  let timeParams = [`${month}%`];

  if (startDate && endDate) {
    timeClause = 't.occurred_at >= ? AND t.occurred_at <= ?';
    const endParam = endDate.length === 10 ? `${endDate} 23:59:59` : endDate;
    timeParams = [startDate, endParam];
  }

  let query = `
    SELECT
      MAX(t.category_id) AS category_id,
      COALESCE(c.name, t.category_name, 'Lainnya') AS category_name,
      MAX(c.icon) AS category_icon,
      MAX(c.color) AS category_color,
      MIN(COALESCE(c.is_default, 1)) AS is_default,
      t.type,
      SUM(t.amount) AS category_total,
      COUNT(t.id) AS tx_count
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    WHERE t.user_id = ? AND ${timeClause} AND t.is_confirmed = 1
  `;
  const params = [userId, ...timeParams];

  if (filterType && filterType !== 'all') {
    query += ` AND t.type = ?`;
    params.push(filterType);
  }

  query += `
    GROUP BY COALESCE(c.name, t.category_name, 'Lainnya'), t.type
    ORDER BY category_total DESC, tx_count DESC, category_name ASC
  `;

  const rows = db.prepare(query).all(...params);

  // Get total for denominator
  const totals = getIncomeExpenseSummaryQuery(db, userId, {
    month,
    startDate,
    endDate,
  });

  let items = rows.map((r, idx) => {
    const total = Number(r.category_total);
    const txCount = Number(r.tx_count);
    const denominator = r.type === 'expense' ? totals.totalExpense : totals.totalIncome;
    const percentage = denominator > 0
      ? Math.round((total / denominator) * 1000) / 10
      : 0;
    const averagePerTransaction = txCount > 0
      ? Math.round((total / txCount) * 100) / 100
      : 0;

    return {
      rank: idx + 1,
      categoryId: r.category_id,
      category: r.category_name,
      categoryName: r.category_name,
      type: r.type,
      total,
      amount: total,
      percentage,
      transactionCount: txCount,
      averagePerTransaction,
      icon: r.category_icon || (r.type === 'income' ? 'attach_money_rounded' : 'more_horiz_rounded'),
      color: r.category_color || (r.type === 'income' ? 'green' : 'blue'),
      isCustom: r.is_default === 0,
    };
  });

  // Optional search filter by category name
  if (search && String(search).trim() !== '') {
    const q = String(search).trim().toLowerCase();
    items = items.filter((item) => item.categoryName.toLowerCase().includes(q));
  }

  // Optional sorting
  if (sortBy === 'lowest' || sortBy === 'amount_asc') {
    items.sort((a, b) => a.total - b.total || a.categoryName.localeCompare(b.categoryName));
  } else if (sortBy === 'most_trx' || sortBy === 'count_desc') {
    items.sort((a, b) => b.transactionCount - a.transactionCount || b.total - a.total);
  } else if (sortBy === 'name' || sortBy === 'name_asc') {
    items.sort((a, b) => a.categoryName.toLowerCase().localeCompare(b.categoryName.toLowerCase()));
  } else {
    items.sort((a, b) => b.total - a.total || b.transactionCount - a.transactionCount);
  }

  // Re-assign rank after sorting/filtering
  return items.map((item, idx) => ({
    ...item,
    rank: idx + 1,
  }));
}

/**
 * Query 3b: Dedicated Expenses (or Income) Per Category Aggregation
 * Returns structured breakdown with totals, top category, counts, and proportions.
 */
export function getExpensesByCategoryQuery(db, userId, options = {}) {
  const {
    month: inputMonth,
    startDate,
    endDate,
    type = 'expense',
    search,
    sortBy = 'highest',
  } = options;

  const month = inputMonth || (startDate ? startDate.slice(0, 7) : getCurrentMonthString());
  const normalizedType = type && ['expense', 'income', 'all'].includes(type) ? type : 'expense';

  const summaryTotals = getIncomeExpenseSummaryQuery(db, userId, {
    month,
    startDate,
    endDate,
  });

  const allMatchingForType = getCategoryBreakdownQuery(
    db,
    userId,
    month,
    normalizedType === 'all' ? null : normalizedType,
    { startDate, endDate, sortBy: 'highest' }
  );

  const filteredItems = getCategoryBreakdownQuery(
    db,
    userId,
    month,
    normalizedType === 'all' ? null : normalizedType,
    { startDate, endDate, search, sortBy }
  );

  const totalExpense = summaryTotals.totalExpense;
  const totalIncome = summaryTotals.totalIncome;
  const totalAmount = normalizedType === 'income'
    ? totalIncome
    : normalizedType === 'expense'
      ? totalExpense
      : totalExpense + totalIncome;

  const totalTransactions = filteredItems.reduce((acc, item) => acc + item.transactionCount, 0);
  const topCategory = allMatchingForType.length > 0 ? allMatchingForType[0] : null;
  const isEmpty = filteredItems.length === 0;
  const isSearchMismatch = isEmpty && Boolean(search && String(search).trim() !== '') && allMatchingForType.length > 0;
  const typeWord = normalizedType === 'income' ? 'pemasukan' : 'pengeluaran';

  return {
    month,
    monthLabel: summaryTotals.monthLabel,
    period: summaryTotals.period,
    type: normalizedType,
    totalAmount,
    totalExpense,
    totalIncome,
    categoryCount: filteredItems.length,
    totalCategories: allMatchingForType.length,
    totalTransactions,
    topCategory,
    isEmpty,
    hasData: !isEmpty,
    isFilteredEmpty: isSearchMismatch,
    emptyState: {
      isEmpty,
      isSearchMismatch,
      message: isSearchMismatch
        ? `Tidak ditemukan kategori untuk "${String(search).trim()}"`
        : `Belum ada transaksi ${typeWord} untuk ditampilkan.`,
      listEmptyMessage: `Tidak ada kategori ${typeWord}.`,
      subtitle: 'Catat transaksi melalui obrolan chat untuk melihat proporsi kategori.',
    },
    categories: filteredItems,
    categoryBreakdown: filteredItems,
    expenseBreakdown: normalizedType === 'expense'
      ? filteredItems
      : filteredItems.filter((i) => i.type === 'expense'),
    incomeBreakdown: normalizedType === 'income'
      ? filteredItems
      : filteredItems.filter((i) => i.type === 'income'),
  };
}

/**
 * Query 4: Daily Totals Aggregation for Month
 */
export function getDailyTotalsQuery(db, userId, month) {
  const monthPrefix = `${month}%`;

  const rows = db.prepare(`
    SELECT
      strftime('%Y-%m-%d', occurred_at) AS date_str,
      CAST(strftime('%d', occurred_at) AS INTEGER) AS day,
      COALESCE(SUM(CASE WHEN type = 'income' AND is_confirmed = 1 THEN amount ELSE 0 END), 0) AS daily_income,
      COALESCE(SUM(CASE WHEN type = 'expense' AND is_confirmed = 1 THEN amount ELSE 0 END), 0) AS daily_expense,
      COUNT(CASE WHEN is_confirmed = 1 THEN 1 END) AS tx_count
    FROM transactions
    WHERE user_id = ? AND occurred_at LIKE ?
    GROUP BY date_str
    ORDER BY date_str ASC
  `).all(userId, monthPrefix);

  return rows.map((r) => ({
    date: r.date_str,
    day: Number(r.day),
    income: Number(r.daily_income),
    expense: Number(r.daily_expense),
    net: Number(r.daily_income) - Number(r.daily_expense),
    transactionCount: Number(r.tx_count),
  }));
}

/**
 * Query 5: Monthly Transaction List with Filters, Search, Sorting, and Date Grouping
 */
export function getMonthlyTransactionsListQuery(db, userId, options = {}) {
  const {
    month: rawMonth,
    year: rawYear,
    startDate,
    endDate,
    type = 'all',
    status = 'all',
    isConfirmed,
    category,
    categoryName,
    categoryId,
    amountFilter = 'all',
    minAmount,
    maxAmount,
    search,
    sortBy = 'newest',
    limit,
    offset,
    defaultToCurrentMonth = false,
  } = options;

  // Normalize month parameter (supports '2026-08', or year='2026' & month='8')
  let resolvedMonth = rawMonth ? String(rawMonth).trim() : null;
  if (resolvedMonth && /^\d{1,2}$/.test(resolvedMonth) && rawYear) {
    resolvedMonth = `${rawYear}-${resolvedMonth.padStart(2, '0')}`;
  } else if (!resolvedMonth && rawYear) {
    resolvedMonth = String(rawYear).trim();
  } else if (!resolvedMonth && !startDate && !endDate && defaultToCurrentMonth) {
    resolvedMonth = getCurrentMonthString();
  }

  let whereSql = 'WHERE t.user_id = ?';
  const params = [userId];

  if (startDate && endDate) {
    const endParam = String(endDate).length === 10 ? `${endDate} 23:59:59` : endDate;
    whereSql += ' AND t.occurred_at >= ? AND t.occurred_at <= ?';
    params.push(startDate, endParam);
  } else if (resolvedMonth) {
    whereSql += ' AND t.occurred_at LIKE ?';
    params.push(`${resolvedMonth}%`);
  }

  // Count total unfiltered transactions in this period (to distinguish empty month vs empty filter result)
  const periodCountRow = db.prepare(`SELECT COUNT(*) AS cnt FROM transactions t ${whereSql}`).get(...params);
  const periodTotalCount = Number(periodCountRow?.cnt || 0);

  // Filter by type ('income' | 'expense')
  if (type && ['income', 'expense'].includes(type)) {
    whereSql += ' AND t.type = ?';
    params.push(type);
  }

  // Filter by confirmation status ('confirmed' | 'pending' or boolean isConfirmed)
  if (isConfirmed !== undefined && isConfirmed !== null && isConfirmed !== '') {
    const confirmedVal = isConfirmed === true || isConfirmed === 'true' || isConfirmed === '1' || isConfirmed === 1 ? 1 : 0;
    whereSql += ' AND t.is_confirmed = ?';
    params.push(confirmedVal);
  } else if (status === 'confirmed') {
    whereSql += ' AND t.is_confirmed = 1';
  } else if (status === 'pending') {
    whereSql += ' AND t.is_confirmed = 0';
  }

  // Filter by categoryId or category name
  const targetCatName = category || categoryName;
  if (categoryId !== undefined && categoryId !== null && categoryId !== '') {
    whereSql += ' AND t.category_id = ?';
    params.push(Number(categoryId));
  } else if (targetCatName && String(targetCatName).trim() !== '' && String(targetCatName).toLowerCase() !== 'all') {
    whereSql += " AND LOWER(COALESCE(c.name, t.category_name, 'Lainnya')) = LOWER(?)";
    params.push(String(targetCatName).trim());
  }

  // Filter by amount range preset or explicit minAmount/maxAmount
  if (amountFilter === 'under_100k') {
    whereSql += ' AND t.amount < 100000';
  } else if (amountFilter === '100k_500k') {
    whereSql += ' AND t.amount >= 100000 AND t.amount <= 500000';
  } else if (amountFilter === 'above_500k') {
    whereSql += ' AND t.amount > 500000';
  }

  if (minAmount !== undefined && minAmount !== null && minAmount !== '' && !isNaN(Number(minAmount))) {
    whereSql += ' AND t.amount >= ?';
    params.push(Number(minAmount));
  }

  if (maxAmount !== undefined && maxAmount !== null && maxAmount !== '' && !isNaN(Number(maxAmount))) {
    whereSql += ' AND t.amount <= ?';
    params.push(Number(maxAmount));
  }

  // Search query across note, category name, and amount
  if (search && String(search).trim() !== '') {
    const q = `%${String(search).trim().toLowerCase()}%`;
    whereSql += ` AND (
      LOWER(COALESCE(t.note, '')) LIKE ?
      OR LOWER(COALESCE(c.name, t.category_name, 'Lainnya')) LIKE ?
      OR CAST(CAST(t.amount AS INTEGER) AS TEXT) LIKE ?
    )`;
    params.push(q, q, q);
  }

  // Sorting order
  let orderSql = 'ORDER BY t.occurred_at DESC, t.id DESC';
  if (sortBy === 'oldest' || sortBy === 'date_asc') {
    orderSql = 'ORDER BY t.occurred_at ASC, t.id ASC';
  } else if (sortBy === 'highest' || sortBy === 'amount_desc') {
    orderSql = 'ORDER BY t.amount DESC, t.occurred_at DESC, t.id DESC';
  } else if (sortBy === 'lowest' || sortBy === 'amount_asc') {
    orderSql = 'ORDER BY t.amount ASC, t.occurred_at DESC, t.id ASC';
  }

  const baseSelectSql = `
    SELECT
      t.*,
      COALESCE(c.name, t.category_name, 'Lainnya') AS resolved_category_name,
      c.icon AS category_icon,
      c.color AS category_color,
      COALESCE(c.is_default, 1) AS category_is_default
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    ${whereSql}
    ${orderSql}
  `;

  const allRows = db.prepare(baseSelectSql).all(...params);

  const formatRow = (r) => {
    const datePart = r.occurred_at ? String(r.occurred_at).slice(0, 10) : null;
    return {
      id: r.id,
      userId: r.user_id,
      categoryId: r.category_id,
      category: r.resolved_category_name || 'Lainnya',
      categoryName: r.resolved_category_name || 'Lainnya',
      categoryIcon: r.category_icon || (r.type === 'income' ? 'attach_money_rounded' : 'more_horiz_rounded'),
      categoryColor: r.category_color || (r.type === 'income' ? 'green' : 'blue'),
      isCustomCategory: r.category_is_default === 0,
      type: r.type,
      amount: Number(r.amount),
      note: r.note,
      occurredAt: r.occurred_at,
      date: datePart,
      isConfirmed: Boolean(r.is_confirmed),
      isGuessedCategory: Boolean(r.is_guessed),
      confidenceScore: r.confidence_score ?? 1.0,
      aiReasoning: r.ai_reasoning || null,
      createdAt: r.created_at,
    };
  };

  const allFormatted = allRows.map(formatRow);

  // Calculate filtered summary totals
  let totalIncome = 0;
  let totalExpense = 0;
  let confirmedCount = 0;
  let pendingCount = 0;
  let incomeCount = 0;
  let expenseCount = 0;

  for (const tx of allFormatted) {
    if (tx.isConfirmed) {
      confirmedCount += 1;
    } else {
      pendingCount += 1;
    }
    if (tx.type === 'income') {
      totalIncome += tx.amount;
      incomeCount += 1;
    } else if (tx.type === 'expense') {
      totalExpense += tx.amount;
      expenseCount += 1;
    }
  }

  // Optional pagination slice
  let paginatedTransactions = allFormatted;
  const numLimit = limit !== undefined && limit !== null && limit !== '' ? Number(limit) : null;
  const numOffset = offset !== undefined && offset !== null && offset !== '' ? Number(offset) : 0;

  if (numLimit && !isNaN(numLimit) && numLimit > 0) {
    const startIdx = !isNaN(numOffset) && numOffset >= 0 ? numOffset : 0;
    paginatedTransactions = allFormatted.slice(startIdx, startIdx + numLimit);
  }

  // Group transactions by YYYY-MM-DD date
  const groupedMap = new Map();
  for (const tx of paginatedTransactions) {
    const dateKey = tx.date || 'Unknown';
    if (!groupedMap.has(dateKey)) {
      groupedMap.set(dateKey, {
        date: dateKey,
        dailyIncome: 0,
        dailyExpense: 0,
        netAmount: 0,
        count: 0,
        transactions: [],
      });
    }
    const group = groupedMap.get(dateKey);
    group.transactions.push(tx);
    group.count += 1;
    if (tx.type === 'income') {
      group.dailyIncome += tx.amount;
    } else {
      group.dailyExpense += tx.amount;
    }
    group.netAmount = group.dailyIncome - group.dailyExpense;
  }

  // Distinct available categories in the selected month/period
  let availableCategoriesQuery = `
    SELECT DISTINCT COALESCE(c.name, t.category_name, 'Lainnya') AS cat_name
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    WHERE t.user_id = ?
  `;
  const availParams = [userId];
  if (startDate && endDate) {
    const endParam = String(endDate).length === 10 ? `${endDate} 23:59:59` : endDate;
    availableCategoriesQuery += ' AND t.occurred_at >= ? AND t.occurred_at <= ?';
    availParams.push(startDate, endParam);
  } else if (resolvedMonth) {
    availableCategoriesQuery += ' AND t.occurred_at LIKE ?';
    availParams.push(`${resolvedMonth}%`);
  }
  availableCategoriesQuery += ' ORDER BY cat_name ASC';
  const availableCategories = db
    .prepare(availableCategoriesQuery)
    .all(...availParams)
    .map((r) => r.cat_name)
    .filter(Boolean);

  const monthLabel = resolvedMonth && resolvedMonth.length === 7
    ? getMonthLabel(resolvedMonth)
    : (startDate && endDate ? `${startDate} s/d ${endDate}` : 'Semua Periode');

  const isEmpty = allFormatted.length === 0;
  const isFilteredEmpty = isEmpty && periodTotalCount > 0;

  return {
    month: resolvedMonth,
    monthLabel,
    isEmpty,
    hasData: !isEmpty,
    isFilteredEmpty,
    emptyState: {
      isEmpty,
      isFilteredEmpty,
      message: isFilteredEmpty
        ? 'Tidak ada transaksi yang cocok.'
        : `Belum ada transaksi di ${monthLabel}.`,
      subtitle: isFilteredEmpty
        ? 'Coba ubah atau reset filter pencarian Anda.'
        : 'Catat transaksi baru melalui chat untuk mulai mencatat keuangan.',
    },
    filters: {
      month: resolvedMonth,
      startDate: startDate || null,
      endDate: endDate || null,
      type: type || 'all',
      status: status || 'all',
      category: targetCatName || null,
      categoryId: categoryId ? Number(categoryId) : null,
      amountFilter: amountFilter || 'all',
      minAmount: minAmount !== undefined && minAmount !== '' ? Number(minAmount) : null,
      maxAmount: maxAmount !== undefined && maxAmount !== '' ? Number(maxAmount) : null,
      search: search || '',
      sortBy: sortBy || 'newest',
    },
    summary: {
      totalIncome,
      totalExpense,
      netAmount: totalIncome - totalExpense,
      confirmedCount,
      pendingCount,
      incomeCount,
      expenseCount,
      totalCount: allFormatted.length,
    },
    availableCategories,
    transactions: paginatedTransactions,
    groupedByDate: Array.from(groupedMap.values()),
    total: allFormatted.length,
    count: paginatedTransactions.length,
  };
}

/**
 * Helper to build structured empty states for all sections of Rekap Bulanan
 */
export function buildRekapEmptyStates(monthLabel, {
  totalTransactionsCount = 0,
  confirmedTransactionsCount = 0,
  expenseTransactionsCount = 0,
  incomeTransactionsCount = 0,
  hasPreviousMonthData = false,
} = {}) {
  const isMonthEmpty = totalTransactionsCount === 0;
  const isSummaryEmpty = confirmedTransactionsCount === 0;
  const isExpenseBreakdownEmpty = expenseTransactionsCount === 0;
  const isIncomeBreakdownEmpty = incomeTransactionsCount === 0;
  const isComparisonEmpty = !hasPreviousMonthData;

  return {
    isEmpty: isMonthEmpty,
    hasData: !isMonthEmpty,
    hasConfirmedData: !isSummaryEmpty,
    banner: {
      isEmpty: isMonthEmpty,
      title: 'Belum Ada Catatan Keuangan',
      message: `Belum ada transaksi tercatat di ${monthLabel}. Semua bagian rekap di bawah ini akan terisi otomatis saat Anda mulai mencatat.`,
    },
    summary: {
      isEmpty: isSummaryEmpty,
      badge: 'Belum Ada Data',
      message: `Belum ada transaksi terkonfirmasi di ${monthLabel}.`,
    },
    comparison: {
      isEmpty: isComparisonEmpty,
      title: 'Perbandingan Bulan Lalu',
      message: 'Belum ada data transaksi di bulan sebelumnya untuk dibandingkan.',
    },
    expenseCategories: {
      isEmpty: isExpenseBreakdownEmpty,
      message: 'Belum ada transaksi pengeluaran untuk ditampilkan.',
      listEmptyMessage: 'Tidak ada kategori pengeluaran.',
      subtitle: 'Catat transaksi melalui obrolan chat untuk melihat proporsi kategori.',
    },
    incomeCategories: {
      isEmpty: isIncomeBreakdownEmpty,
      message: 'Belum ada transaksi pemasukan untuk ditampilkan.',
      listEmptyMessage: 'Tidak ada kategori pemasukan.',
      subtitle: 'Catat transaksi melalui obrolan chat untuk melihat proporsi kategori.',
    },
    transactions: {
      isEmpty: isMonthEmpty,
      message: `Belum ada transaksi di ${monthLabel}.`,
      subtitle: 'Catat transaksi baru melalui chat untuk mulai mencatat keuangan.',
    },
  };
}

/**
 * Query 6: Available Months for Rekap Navigation
 * Returns months that have transactions plus recent surrounding months so user can navigate freely.
 */
export function getAvailableRekapMonthsQuery(db, userId, referenceMonth = null) {
  const currentMonth = referenceMonth || getCurrentMonthString();

  const dbMonthsRows = db.prepare(`
    SELECT
      strftime('%Y-%m', occurred_at) AS month_str,
      COUNT(id) AS total_tx,
      COUNT(CASE WHEN is_confirmed = 1 THEN 1 END) AS confirmed_tx,
      COALESCE(SUM(CASE WHEN type = 'income' AND is_confirmed = 1 THEN amount ELSE 0 END), 0) AS total_income,
      COALESCE(SUM(CASE WHEN type = 'expense' AND is_confirmed = 1 THEN amount ELSE 0 END), 0) AS total_expense
    FROM transactions
    WHERE user_id = ? AND occurred_at IS NOT NULL AND LENGTH(occurred_at) >= 7
    GROUP BY month_str
    ORDER BY month_str DESC
  `).all(userId);

  const monthDataMap = new Map();
  for (const r of dbMonthsRows) {
    if (r.month_str && /^\d{4}-\d{2}$/.test(r.month_str)) {
      monthDataMap.set(r.month_str, {
        month: r.month_str,
        monthLabel: getMonthLabel(r.month_str),
        transactionCount: Number(r.total_tx),
        confirmedCount: Number(r.confirmed_tx),
        totalIncome: Number(r.total_income),
        totalExpense: Number(r.total_expense),
        isEmpty: Number(r.total_tx) === 0,
        hasData: Number(r.total_tx) > 0,
      });
    }
  }

  // Ensure currentMonth and 5 preceding months are always included in navigation list
  let cursor = currentMonth;
  for (let i = 0; i < 6; i++) {
    if (!monthDataMap.has(cursor)) {
      monthDataMap.set(cursor, {
        month: cursor,
        monthLabel: getMonthLabel(cursor),
        transactionCount: 0,
        confirmedCount: 0,
        totalIncome: 0,
        totalExpense: 0,
        isEmpty: true,
        hasData: false,
      });
    }
    cursor = getPreviousMonthString(cursor);
  }

  const monthsDetailed = Array.from(monthDataMap.values()).sort((a, b) => b.month.localeCompare(a.month));
  const availableMonths = monthsDetailed.map((m) => m.month);

  return {
    currentMonth,
    availableMonths,
    months: monthsDetailed,
  };
}

/**
 * Composite Query: Full Monthly Rekap Aggregation with Totals, Comparison, Breakdown, Daily, Transactions, and Empty States
 */
export function getFullMonthlyRekapAggregation(db, userId, month) {
  const totals = getMonthlyTotalsQuery(db, userId, month);
  const comparison = getMonthOverMonthComparisonQuery(db, userId, month);
  const categoryBreakdown = getCategoryBreakdownQuery(db, userId, month);
  const dailyBreakdown = getDailyTotalsQuery(db, userId, month);
  const monthlyTxResult = getMonthlyTransactionsListQuery(db, userId, { month });
  const monthsInfo = getAvailableRekapMonthsQuery(db, userId, month);

  const totalTransactionsCount = monthlyTxResult.total;
  const emptyStates = buildRekapEmptyStates(totals.monthLabel, {
    totalTransactionsCount,
    confirmedTransactionsCount: totals.confirmedTransactionsCount,
    expenseTransactionsCount: totals.expenseTransactionsCount,
    incomeTransactionsCount: totals.incomeTransactionsCount,
    hasPreviousMonthData: comparison.hasPreviousMonthData,
  });

  return {
    month,
    monthLabel: totals.monthLabel,
    isEmpty: emptyStates.isEmpty,
    hasData: emptyStates.hasData,
    hasConfirmedData: emptyStates.hasConfirmedData,
    emptyStates,
    emptyState: emptyStates.banner,
    availableMonths: monthsInfo.availableMonths,
    summary: {
      totalIncome: totals.totalIncome,
      totalExpense: totals.totalExpense,
      netSavings: totals.netSavings,
      savingsRate: totals.savingsRate,
      averageDailyExpense: totals.averageDailyExpense,
      daysInMonth: totals.daysInMonth,
      confirmedTransactionsCount: totals.confirmedTransactionsCount,
      pendingTransactionsCount: totals.pendingTransactionsCount,
      incomeTransactionsCount: totals.incomeTransactionsCount,
      expenseTransactionsCount: totals.expenseTransactionsCount,
      pendingExpenseTotal: totals.pendingExpenseTotal,
      pendingIncomeTotal: totals.pendingIncomeTotal,
      isEmpty: emptyStates.summary.isEmpty,
      emptyBadge: emptyStates.summary.badge,
      emptyMessage: emptyStates.summary.message,
    },
    comparison: {
      previousMonth: comparison.previousMonth,
      previousMonthLabel: comparison.previousMonthLabel,
      hasPreviousMonthData: comparison.hasPreviousMonthData,
      lastMonthTotalExpense: comparison.lastMonthTotalExpense,
      lastMonthTotalIncome: comparison.lastMonthTotalIncome,
      expenseNominalDiff: comparison.expenseNominalDiff,
      expenseNominalDiffAbs: comparison.expenseNominalDiffAbs,
      expenseDiffPct: comparison.expenseDiffPct,
      incomeDiffPct: comparison.incomeDiffPct,
      isExpenseHigher: comparison.isExpenseHigher,
      isExpenseLower: comparison.isExpenseLower,
      isIncomeHigher: comparison.isIncomeHigher,
      badgeText: comparison.badgeText,
      insightMessage: comparison.insightMessage,
      isEmpty: emptyStates.comparison.isEmpty,
      emptyMessage: emptyStates.comparison.message,
    },
    categoryBreakdown,
    dailyBreakdown,
    transactions: monthlyTxResult.transactions,
  };
}
