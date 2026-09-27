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

  return {
    month,
    monthLabel,
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
 * Query 2: Month-over-Month (MoM) Comparison Aggregation
 */
export function getMonthOverMonthComparisonQuery(db, userId, month) {
  const current = getMonthlyTotalsQuery(db, userId, month);
  const previousMonth = getPreviousMonthString(month);
  const previous = getMonthlyTotalsQuery(db, userId, previousMonth);

  const lastMonthTotalExpense = previous.totalExpense;
  const lastMonthTotalIncome = previous.totalIncome;

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

  return {
    currentMonth: month,
    previousMonth,
    previousMonthLabel: getMonthLabel(previousMonth),
    totalExpense: current.totalExpense,
    lastMonthTotalExpense,
    expenseDiffPct,
    isExpenseHigher: current.totalExpense > lastMonthTotalExpense,
    totalIncome: current.totalIncome,
    lastMonthTotalIncome,
    incomeDiffPct,
    isIncomeHigher: current.totalIncome > lastMonthTotalIncome,
  };
}

/**
 * Query 3: Category Breakdown Aggregation
 */
export function getCategoryBreakdownQuery(db, userId, month, filterType = null) {
  const monthPrefix = `${month}%`;

  let query = `
    SELECT
      t.category_id,
      COALESCE(c.name, t.category_name, 'Lainnya') AS category_name,
      c.icon AS category_icon,
      c.color AS category_color,
      COALESCE(c.is_default, 1) AS is_default,
      t.type,
      SUM(t.amount) AS category_total,
      COUNT(t.id) AS tx_count
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    WHERE t.user_id = ? AND t.occurred_at LIKE ? AND t.is_confirmed = 1
  `;
  const params = [userId, monthPrefix];

  if (filterType) {
    query += ` AND t.type = ?`;
    params.push(filterType);
  }

  query += `
    GROUP BY t.category_id, t.type
    ORDER BY category_total DESC
  `;

  const rows = db.prepare(query).all(...params);

  // Get total for denominator
  const totals = getMonthlyTotalsQuery(db, userId, month);

  return rows.map((r) => {
    const total = Number(r.category_total);
    const denominator = r.type === 'expense' ? totals.totalExpense : totals.totalIncome;
    const percentage = denominator > 0
      ? Math.round((total / denominator) * 1000) / 10
      : 0;

    return {
      categoryId: r.category_id,
      categoryName: r.category_name,
      type: r.type,
      total,
      percentage,
      transactionCount: Number(r.tx_count),
      icon: r.category_icon || (r.type === 'income' ? 'attach_money_rounded' : 'more_horiz_rounded'),
      color: r.category_color || (r.type === 'income' ? 'green' : 'blue'),
      isCustom: r.is_default === 0,
    };
  });
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
 * Composite Query: Full Monthly Rekap Aggregation with Totals, Comparison, Breakdown, and Daily
 */
export function getFullMonthlyRekapAggregation(db, userId, month) {
  const totals = getMonthlyTotalsQuery(db, userId, month);
  const comparison = getMonthOverMonthComparisonQuery(db, userId, month);
  const categoryBreakdown = getCategoryBreakdownQuery(db, userId, month);
  const dailyBreakdown = getDailyTotalsQuery(db, userId, month);

  return {
    month,
    monthLabel: totals.monthLabel,
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
    },
    comparison: {
      previousMonth: comparison.previousMonth,
      previousMonthLabel: comparison.previousMonthLabel,
      lastMonthTotalExpense: comparison.lastMonthTotalExpense,
      lastMonthTotalIncome: comparison.lastMonthTotalIncome,
      expenseDiffPct: comparison.expenseDiffPct,
      incomeDiffPct: comparison.incomeDiffPct,
      isExpenseHigher: comparison.isExpenseHigher,
      isIncomeHigher: comparison.isIncomeHigher,
    },
    categoryBreakdown,
    dailyBreakdown,
  };
}
