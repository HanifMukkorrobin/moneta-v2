import { getDatabase } from '../config/database.js';
import { getOrCreateDefaultUser } from './chatController.js';
import {
  getPreviousMonthString,
  getDaysInMonth,
  getMonthLabel,
  getMonthlyTotalsQuery,
  getIncomeExpenseSummaryQuery,
  getMonthOverMonthComparisonQuery,
  getCategoryBreakdownQuery,
  getExpensesByCategoryQuery,
  getDailyTotalsQuery,
  getMonthlyTransactionsListQuery,
  getAvailableRekapMonthsQuery,
  getFullMonthlyRekapAggregation,
} from '../services/rekapQueryService.js';
import {
  getMonthlyBudgetSummaryQuery,
  upsertMonthlyBudgetLimit,
  deleteMonthlyBudgetLimit,
  inferBucketTypeFromCategory,
  getAllocationPercentagesQuery,
  upsertAllocationPercentages,
  resetAllocationPercentages,
  validateAllocationPercentages,
  getRemainingAndBucketNominalsQuery,
  getBudgetWarningStatusQuery,
  getBudgetDailyAdviceQuery,
  updateBudgetAlertSettings,
  toggleBudgetAlert,
} from '../services/budgetService.js';





/**
 * Formats a Date object to YYYY-MM
 */
export function getCurrentMonthString(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

/**
 * Calculates monthly financial summary (rekap), budget tracking, and daily spending advice (saran harian).
 */
export function calculateMonthlyRekap(db, userId, targetMonth, options = {}) {
  const month = targetMonth || getCurrentMonthString();
  const monthPrefix = `${month}%`;

  // 1. Aggregated totals and MoM comparison
  const aggregated = getFullMonthlyRekapAggregation(db, userId, month);

  // 2. Full monthly budget summary, allocation buckets, warnings, and daily advice (saranHarian)
  const monthlyBudget = getMonthlyBudgetSummaryQuery(db, userId, month, options);

  // 3. Budgets for this month with spent tracking
  const budgetRows = db.prepare(`
    SELECT
      b.id,
      b.category_id,
      b.name,
      b.amount_limit,
      b.period,
      b.month,
      c.name AS category_name,
      c.icon AS category_icon,
      c.color AS category_color,
      COALESCE((
        SELECT SUM(amount)
        FROM transactions
        WHERE user_id = b.user_id
          AND category_id = b.category_id
          AND is_confirmed = 1
          AND occurred_at LIKE ?
      ), 0) AS total_spent
    FROM budgets b
    LEFT JOIN categories c ON b.category_id = c.id
    WHERE b.user_id = ? AND (b.month = ? OR b.month IS NULL)
  `).all(monthPrefix, userId, month);

  const budgetStatus = budgetRows.map((b) => {
    const limit = Number(b.amount_limit);
    const spent =
      b.category_id === null
        ? Number(monthlyBudget.totalSpent)
        : Number(b.total_spent);
    const remaining = limit - spent;
    const percentageUsed = limit > 0 ? Math.round((spent / limit) * 1000) / 10 : 0;

    return {
      budgetId: b.id,
      categoryId: b.category_id,
      categoryName: b.category_name || b.name,
      categoryIcon: b.category_icon,
      categoryColor: b.category_color,
      limit,
      spent,
      remaining,
      percentageUsed,
      isOverBudget: spent > limit,
    };
  });

  const enrichedSummary = {
    ...aggregated.summary,
    hasMonthlyBudget: monthlyBudget.hasMonthlyBudget,
    totalBudget: monthlyBudget.totalBudget,
    totalRemainingBudget: monthlyBudget.totalRemaining,
    budgetPercentageUsed: monthlyBudget.percentageUsed,
    budgetRemainingPercentage: monthlyBudget.remainingPercentage,
    isOverBudget: monthlyBudget.isOverBudget,
    remainingStatusLabel: monthlyBudget.remainingStatusLabel,
    dailyRemainingAverage: monthlyBudget.dailyRemainingAverage,
    formattedDailyRemainingAverage: monthlyBudget.formattedDailyRemainingAverage,
    dailySafeSpend: monthlyBudget.saranHarian.dailySafeSpend,
    formattedDailySafeSpend: monthlyBudget.saranHarian.formattedDailySafeSpend,
    warningLevel: monthlyBudget.warning.warningLevel,
    shouldShowWarningBanner: monthlyBudget.warning.shouldShowBanner,
  };

  return {
    month,
    monthLabel: aggregated.monthLabel,
    isEmpty: aggregated.isEmpty,
    hasData: aggregated.hasData,
    hasConfirmedData: aggregated.hasConfirmedData,
    emptyState: aggregated.emptyState,
    emptyStates: aggregated.emptyStates,
    availableMonths: aggregated.availableMonths,
    summary: enrichedSummary,
    comparison: aggregated.comparison,
    categoryBreakdown: aggregated.categoryBreakdown,
    dailyBreakdown: aggregated.dailyBreakdown,
    transactions: aggregated.transactions,
    budgetStatus,
    monthlyBudget,
    budgetSummary: monthlyBudget,
    budgetWarnings: monthlyBudget.warning,
    saranHarian: monthlyBudget.saranHarian,
    dailyAdvice: monthlyBudget.dailyAdvice,
  };
}

/**
 * Controller: GET /api/rekap, GET /rekap, GET /api/summary
 */
export function getMonthlyRekapHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const month = req.query?.month || getCurrentMonthString();
    const isRefresh = req.query?.refresh === 'true' || req.query?.refresh === '1' || req.query?.forceRefresh === 'true';

    if (isRefresh) {
      res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
    }

    const data = calculateMonthlyRekap(db, userId, month, req.query);

    return res.status(200).json({
      success: true,
      ...(isRefresh ? {
        refreshed: true,
        refreshedAt: new Date().toISOString(),
        message: 'Rekap bulanan berhasil diperbarui.',
      } : {}),
      ...data,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error calculating rekap:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menghitung rekap bulanan dan budget.',
      details: error.message,
    });
  }
}

/**
 * Controller: GET /api/rekap/refresh, POST /api/rekap/refresh
 * Forces a fresh recalculation of the monthly rekap and returns updated data + availableMonths.
 */
export function refreshMonthlyRekapHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.body?.userId || req.query?.userId);
    const month = req.body?.month || req.query?.month || getCurrentMonthString();

    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');

    const data = calculateMonthlyRekap(db, userId, month, { ...req.query, ...req.body });

    return res.status(200).json({
      success: true,
      refreshed: true,
      refreshedAt: new Date().toISOString(),
      message: 'Rekap bulanan berhasil diperbarui.',
      ...data,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error refreshing rekap:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menyegarkan data rekap bulanan.',
      details: error.message,
    });
  }
}

/**
 * Controller: GET /api/rekap/months, GET /api/rekap/available-months
 * Returns available months and their transaction counts/empty state status.
 */
export function getAvailableMonthsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const referenceMonth = req.query?.month || getCurrentMonthString();

    const result = getAvailableRekapMonthsQuery(db, userId, referenceMonth);

    return res.status(200).json({
      success: true,
      ...result,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error getting available months:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat daftar bulan rekap.',
      details: error.message,
    });
  }
}

/**
 * Controller: GET /api/rekap/income-expense, GET /api/rekap/summary, GET /api/transactions/summary
 * Returns comprehensive income and expense summary for a month or date range, integrated with monthly budget & daily advice.
 */
export function getIncomeExpenseSummaryHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const { month, startDate, endDate, from, to, includePending } = req.query || {};

    const summary = getIncomeExpenseSummaryQuery(db, userId, {
      month: month || undefined,
      startDate: startDate || from || undefined,
      endDate: endDate || to || undefined,
      includePending: includePending === 'true' || includePending === true,
    });

    const targetMonth = summary.month || month || getCurrentMonthString();
    const monthlyBudget =
      targetMonth && /^\d{4}-\d{2}$/.test(targetMonth)
        ? getMonthlyBudgetSummaryQuery(db, userId, targetMonth, req.query)
        : null;

    return res.status(200).json({
      success: true,
      ...summary,
      ...(monthlyBudget
        ? {
            hasMonthlyBudget: monthlyBudget.hasMonthlyBudget,
            totalBudget: monthlyBudget.totalBudget,
            totalRemainingBudget: monthlyBudget.totalRemaining,
            budgetPercentageUsed: monthlyBudget.percentageUsed,
            budgetRemainingPercentage: monthlyBudget.remainingPercentage,
            isOverBudget: monthlyBudget.isOverBudget,
            remainingStatusLabel: monthlyBudget.remainingStatusLabel,
            dailyRemainingAverage: monthlyBudget.dailyRemainingAverage,
            formattedDailyRemainingAverage: monthlyBudget.formattedDailyRemainingAverage,
            dailySafeSpend: monthlyBudget.saranHarian.dailySafeSpend,
            formattedDailySafeSpend: monthlyBudget.saranHarian.formattedDailySafeSpend,
            monthlyBudget,
            budgetSummary: monthlyBudget,
            saranHarian: monthlyBudget.saranHarian,
            dailyAdvice: monthlyBudget.dailyAdvice,
          }
        : {}),
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error getting income-expense summary:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat mengambil ringkasan pemasukan dan pengeluaran.',
      details: error.message,
    });
  }
}

/**
 * Controller: GET /api/rekap/summary
 * Returns focused monthly totals aggregation
 */
export function getSummaryAggregationHandler(req, res) {
  return getIncomeExpenseSummaryHandler(req, res);
}

/**
 * Controller: GET /api/rekap/comparison, GET /api/rekap/compare, GET /api/rekap/month-comparison
 * Returns Month-over-Month comparison between current month and previous month
 */
export function getComparisonHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const { month, currentMonth, previousMonth, compareWith } = req.query || {};
    const targetMonth = month || currentMonth || getCurrentMonthString();

    const comparison = getMonthOverMonthComparisonQuery(db, userId, targetMonth, {
      previousMonth: previousMonth || compareWith || undefined,
    });

    return res.status(200).json({
      success: true,
      ...comparison,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error getting comparison:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat membandingkan rekap bulanan.',
      details: error.message,
    });
  }
}

/**
 * Controller: GET /api/rekap/breakdown, GET /api/rekap/categories
 * Returns category breakdown (all types or filtered by ?type=expense|income)
 */
export function getCategoryBreakdownHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const { month, startDate, endDate, from, to, type, search, q, sortBy, sort } = req.query || {};

    const result = getExpensesByCategoryQuery(db, userId, {
      month: month || getCurrentMonthString(),
      startDate: startDate || from || undefined,
      endDate: endDate || to || undefined,
      type: type || 'all',
      search: search || q || undefined,
      sortBy: sortBy || sort || 'highest',
    });

    return res.status(200).json({
      success: true,
      ...result,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error getting category breakdown:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat mengambil proporsi kategori.',
      details: error.message,
    });
  }
}

/**
 * Controller: GET /api/rekap/expenses-by-category, GET /api/rekap/expense-categories, GET /api/transactions/expenses-by-category
 * Dedicated endpoint for expenses per category (defaults to type='expense')
 */
export function getExpensesByCategoryHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const { month, startDate, endDate, from, to, type, search, q, sortBy, sort } = req.query || {};

    const result = getExpensesByCategoryQuery(db, userId, {
      month: month || getCurrentMonthString(),
      startDate: startDate || from || undefined,
      endDate: endDate || to || undefined,
      type: type || 'expense',
      search: search || q || undefined,
      sortBy: sortBy || sort || 'highest',
    });

    return res.status(200).json({
      success: true,
      ...result,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error getting expenses by category:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat mengambil pengeluaran per kategori.',
      details: error.message,
    });
  }
}

/**
 * Controller: GET /api/rekap/transactions, GET /rekap/transactions
 * Returns monthly transaction list with month, category, type, status, amount, search, and sort filters
 */
export function getMonthlyTransactionsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const {
      month,
      year,
      startDate,
      endDate,
      from,
      to,
      type,
      status,
      isConfirmed,
      category,
      categoryName,
      categoryId,
      amountFilter,
      amountRange,
      minAmount,
      maxAmount,
      search,
      q,
      sortBy,
      sort,
      limit,
      offset,
    } = req.query || {};

    const result = getMonthlyTransactionsListQuery(db, userId, {
      month,
      year,
      startDate: startDate || from || undefined,
      endDate: endDate || to || undefined,
      type: type || 'all',
      status: status || 'all',
      isConfirmed,
      category: category || categoryName || undefined,
      categoryId,
      amountFilter: amountFilter || amountRange || 'all',
      minAmount,
      maxAmount,
      search: search || q || undefined,
      sortBy: sortBy || sort || 'newest',
      limit,
      offset,
      defaultToCurrentMonth: true,
    });

    return res.status(200).json({
      success: true,
      ...result,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error getting monthly transactions:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat daftar transaksi bulanan.',
      details: error.message,
    });
  }
}

/**
 * Controller: GET /api/rekap/daily
 * Returns daily aggregation trend
 */
export function getDailyAggregationHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const month = req.query?.month || getCurrentMonthString();

    const daily = getDailyTotalsQuery(db, userId, month);

    return res.status(200).json({
      success: true,
      month,
      dailyBreakdown: daily,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error getting daily aggregation:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat mengambil data agregasi harian.',
      details: error.message,
    });
  }
}

/**
 * Controller: GET /api/budgets
 * Returns both category budgets array (`budgets`) and full monthly budget summary (`monthlyBudget`, `summary`, etc.)
 */
export function listBudgetsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const month = req.query?.month || req.params?.month || getCurrentMonthString();
    const monthPrefix = `${month}%`;

    const budgetRows = db.prepare(`
      SELECT
        b.id,
        b.category_id,
        b.name,
        b.amount_limit,
        b.total_amount,
        b.needs_pct,
        b.savings_pct,
        b.fun_pct,
        b.bucket_type,
        b.period,
        b.month,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color,
        COALESCE((
          SELECT SUM(amount)
          FROM transactions
          WHERE user_id = b.user_id
            AND (b.category_id IS NULL OR category_id = b.category_id)
            AND type = 'expense'
            AND is_confirmed = 1
            AND occurred_at LIKE ?
        ), 0) AS total_spent
      FROM budgets b
      LEFT JOIN categories c ON b.category_id = c.id
      WHERE b.user_id = ? AND (b.month = ? OR b.month IS NULL)
      ORDER BY b.id ASC
    `).all(monthPrefix, userId, month);

    const formatted = budgetRows.map((b) => {
      const limit = Number(b.amount_limit || b.total_amount || 0);
      const spent = Number(b.total_spent || 0);
      const remaining = limit - spent;
      const percentageUsed = limit > 0 ? Math.round((spent / limit) * 1000) / 10 : 0;

      return {
        id: b.id,
        categoryId: b.category_id,
        name: b.name,
        categoryName: b.category_name || b.name,
        categoryIcon: b.category_icon,
        categoryColor: b.category_color,
        bucketType: b.bucket_type || 'needs',
        amountLimit: limit,
        totalAmount: Number(b.total_amount || limit),
        needsPct: Number(b.needs_pct ?? 50),
        savingsPct: Number(b.savings_pct ?? 30),
        funPct: Number(b.fun_pct ?? 20),
        totalSpent: spent,
        remaining,
        percentageUsed,
        isOverBudget: limit > 0 && spent > limit,
        period: b.period,
        month: b.month || month,
      };
    });

    const monthlySummary = getMonthlyBudgetSummaryQuery(db, userId, month);

    return res.status(200).json({
      success: true,
      budgets: formatted,
      total: formatted.length,
      monthlyBudget: monthlySummary,
      summary: monthlySummary,
      ...monthlySummary,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error listing budgets:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat daftar budget.',
      details: error.message,
    });
  }
}

/**
 * Controller: GET /api/budgets/monthly, GET /api/budgets/limit, GET /api/budgets/month/:month
 */
export function getMonthlyBudgetHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const month = req.params?.month || req.query?.month || getCurrentMonthString();

    const monthlySummary = getMonthlyBudgetSummaryQuery(db, userId, month);

    return res.status(200).json({
      success: true,
      budget: monthlySummary,
      monthlyBudget: monthlySummary,
      summary: monthlySummary,
      ...monthlySummary,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error getting monthly budget:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat mengambil batas budget bulanan.',
      details: error.message,
    });
  }
}

/**
 * Controller: POST /api/budgets/monthly, PUT /api/budgets/monthly, PATCH /api/budgets/monthly,
 * POST /api/budgets/limit, PUT /api/budgets/limit
 */
export function upsertMonthlyBudgetHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.body?.userId || req.query?.userId);
    const month = req.body?.month || req.params?.month || req.query?.month || getCurrentMonthString();

    const monthlySummary = upsertMonthlyBudgetLimit(db, userId, {
      ...req.body,
      month,
    });

    const statusCode = req.method === 'POST' ? 201 : 200;
    return res.status(statusCode).json({
      success: true,
      message: `Batas budget berhasil diperbarui: ${monthlySummary.formattedTotalBudget}`,
      budget: {
        id: monthlySummary.id,
        userId,
        categoryId: null,
        name: req.body?.name || 'Budget Bulanan',
        amountLimit: monthlySummary.totalBudget,
        totalAmount: monthlySummary.totalBudget,
        totalBudget: monthlySummary.totalBudget,
        needsPct: monthlySummary.needsPercentage,
        savingsPct: monthlySummary.savingsPercentage,
        funPct: monthlySummary.funPercentage,
        period: 'monthly',
        month: monthlySummary.month,
      },
      monthlyBudget: monthlySummary,
      summary: monthlySummary,
      ...monthlySummary,
    });
  } catch (error) {
    if (error.statusCode === 400) {
      return res.status(400).json({
        success: false,
        error: error.message,
      });
    }
    console.error('[SummaryBudgetController] Error saving monthly budget:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menyimpan batas budget bulanan.',
      details: error.message,
    });
  }
}

/**
 * Controller: POST /api/budgets, PUT /api/budgets
 * Handles both monthly root budget limit AND category-specific budget limit
 */
export function createOrUpdateBudgetHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.body?.userId || req.query?.userId);
    const {
      categoryId,
      category_id,
      name,
      amountLimit,
      amount_limit,
      totalAmount,
      total_amount,
      totalBudget,
      amount,
      bucketType,
      bucket_type,
      period = 'monthly',
      month = getCurrentMonthString(),
    } = req.body || {};

    const resolvedCatId = categoryId ?? category_id ? Number(categoryId ?? category_id) : null;
    const rawLimit = amountLimit ?? amount_limit ?? totalAmount ?? total_amount ?? totalBudget ?? amount;

    const hasAllocationFields =
      req.body?.needsPct !== undefined ||
      req.body?.needs_pct !== undefined ||
      req.body?.needsPercentage !== undefined ||
      req.body?.savingsPct !== undefined ||
      req.body?.savings_pct !== undefined ||
      req.body?.savingsPercentage !== undefined ||
      req.body?.funPct !== undefined ||
      req.body?.fun_pct !== undefined ||
      req.body?.funPercentage !== undefined ||
      req.body?.preset !== undefined ||
      req.body?.template !== undefined;

    if (!resolvedCatId && rawLimit === undefined && hasAllocationFields) {
      return upsertAllocationPercentagesHandler(req, res);
    }

    const hasAlertSettingFields =
      req.body?.isAlertEnabled !== undefined ||
      req.body?.alertEnabled !== undefined ||
      req.body?.alert_enabled !== undefined ||
      req.body?.enabled !== undefined ||
      req.body?.isEnabled !== undefined ||
      req.body?.alertThreshold !== undefined ||
      req.body?.alert_threshold !== undefined ||
      req.body?.threshold !== undefined ||
      req.body?.isOverBudgetAlertEnabled !== undefined ||
      req.body?.overBudgetAlertEnabled !== undefined ||
      req.body?.isPushNotificationEnabled !== undefined ||
      req.body?.pushNotificationEnabled !== undefined;

    if (!resolvedCatId && rawLimit === undefined && hasAlertSettingFields) {
      return updateBudgetAlertSettingsHandler(req, res);
    }

    const numLimit = Number(rawLimit);

    if (rawLimit === undefined || rawLimit === null || isNaN(numLimit) || numLimit <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Batas limit budget harus berupa angka lebih besar dari 0.',
      });
    }

    // If no categoryId is provided and either totalAmount/totalBudget is passed OR no custom category name is passed,
    // treat this as a Monthly Root Budget upsert!
    const isMonthlyRootRequest =
      !resolvedCatId &&
      (totalAmount !== undefined ||
        total_amount !== undefined ||
        totalBudget !== undefined ||
        !name ||
        String(name).trim().toLowerCase() === 'budget bulanan');

    if (isMonthlyRootRequest) {
      return upsertMonthlyBudgetHandler(req, res);
    }

    let resolvedName = name ? String(name).trim() : null;
    if (resolvedCatId) {
      const cat = db.prepare('SELECT id, name FROM categories WHERE id = ?').get(resolvedCatId);
      if (cat && !resolvedName) {
        resolvedName = cat.name;
      }
    }

    if (!resolvedName) {
      return res.status(400).json({
        success: false,
        error: 'Nama budget atau kategori wajib diisi.',
      });
    }

    const resolvedBucket = inferBucketTypeFromCategory(resolvedName, bucketType || bucket_type);

    // Insert or replace category budget for this user, category, and month
    const upsertStmt = db.prepare(`
      INSERT INTO budgets (user_id, category_id, name, amount_limit, total_amount, bucket_type, period, month)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(user_id, category_id, month) DO UPDATE SET
        name = excluded.name,
        amount_limit = excluded.amount_limit,
        total_amount = excluded.total_amount,
        bucket_type = excluded.bucket_type,
        period = excluded.period,
        updated_at = CURRENT_TIMESTAMP
    `);

    const result = upsertStmt.run(
      userId,
      resolvedCatId,
      resolvedName,
      numLimit,
      numLimit,
      resolvedBucket,
      period,
      month
    );

    const budgetId =
      result.lastInsertRowid ||
      db
        .prepare('SELECT id FROM budgets WHERE user_id = ? AND category_id = ? AND month = ?')
        .get(userId, resolvedCatId, month)?.id;

    const monthlySummary = getMonthlyBudgetSummaryQuery(db, userId, month);

    return res.status(req.method === 'PUT' || req.method === 'PATCH' ? 200 : 201).json({
      success: true,
      message: 'Budget berhasil disimpan dan diintegrasikan dengan transaksi chat.',
      budget: {
        id: budgetId,
        userId,
        categoryId: resolvedCatId,
        name: resolvedName,
        bucketType: resolvedBucket,
        amountLimit: numLimit,
        totalAmount: numLimit,
        period,
        month,
      },
      monthlyBudget: monthlySummary,
      summary: monthlySummary,
      saranHarian: monthlySummary.saranHarian,
      dailyAdvice: monthlySummary.dailyAdvice,
      rekapIntegration: monthlySummary.rekapIntegration,
      rekapSummary: monthlySummary.rekapSummary,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error saving budget:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menyimpan data budget.',
      details: error.message,
    });
  }
}

/**
 * Controller: PUT /api/budgets/:id, PATCH /api/budgets/:id
 */
export function updateBudgetByIdHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.body?.userId || req.query?.userId);
    const paramId = req.params?.id;

    if (paramId === 'allocation' || paramId === 'allocations' || paramId === 'percentages') {
      return upsertAllocationPercentagesHandler(req, res);
    }

    if (
      paramId === 'warnings' ||
      paramId === 'alerts' ||
      paramId === 'alert-settings' ||
      paramId === 'notification-settings'
    ) {
      return updateBudgetAlertSettingsHandler(req, res);
    }

    const hasAlertOnly =
      req.body?.isAlertEnabled !== undefined ||
      req.body?.alertEnabled !== undefined ||
      req.body?.alert_enabled !== undefined ||
      req.body?.enabled !== undefined ||
      req.body?.isEnabled !== undefined ||
      req.body?.alertThreshold !== undefined ||
      req.body?.alert_threshold !== undefined ||
      req.body?.threshold !== undefined ||
      req.body?.isOverBudgetAlertEnabled !== undefined ||
      req.body?.overBudgetAlertEnabled !== undefined ||
      req.body?.isPushNotificationEnabled !== undefined ||
      req.body?.pushNotificationEnabled !== undefined;

    // Support /api/budgets/2026-09 or /api/budgets/monthly
    if (paramId === 'monthly' || paramId === 'limit' || /^\d{4}-\d{2}$/.test(String(paramId))) {
      if (/^\d{4}-\d{2}$/.test(String(paramId))) {
        req.body = { ...req.body, month: paramId };
      }
      const rawLimit =
        req.body?.amountLimit ??
        req.body?.amount_limit ??
        req.body?.totalAmount ??
        req.body?.total_amount ??
        req.body?.totalBudget ??
        req.body?.amount;
      if (rawLimit === undefined) {
        if (hasAlertOnly && req.body?.needsPct === undefined && req.body?.needs_pct === undefined) {
          return updateBudgetAlertSettingsHandler(req, res);
        }
        return upsertAllocationPercentagesHandler(req, res);
      }
      return upsertMonthlyBudgetHandler(req, res);
    }

    const budgetId = Number(paramId);
    const existingBudget = db
      .prepare('SELECT * FROM budgets WHERE id = ? AND user_id = ?')
      .get(budgetId, userId);
    const existingMonthly = db
      .prepare('SELECT * FROM monthly_budgets WHERE id = ? AND user_id = ?')
      .get(budgetId, userId);

    if (!existingBudget && !existingMonthly) {
      return res.status(404).json({
        success: false,
        error: 'Budget tidak ditemukan.',
      });
    }

    // If updating a monthly root budget row
    if ((existingBudget && existingBudget.category_id === null) || (!existingBudget && existingMonthly)) {
      const month = req.body?.month || existingBudget?.month || existingMonthly?.month;
      req.body = { ...req.body, month };
      const rawLimit =
        req.body?.amountLimit ??
        req.body?.amount_limit ??
        req.body?.totalAmount ??
        req.body?.total_amount ??
        req.body?.totalBudget ??
        req.body?.amount;
      if (rawLimit === undefined) {
        if (hasAlertOnly && req.body?.needsPct === undefined && req.body?.needs_pct === undefined) {
          return updateBudgetAlertSettingsHandler(req, res);
        }
        return upsertAllocationPercentagesHandler(req, res);
      }
      return upsertMonthlyBudgetHandler(req, res);
    }

    // Otherwise update category budget
    const rawLimit =
      req.body?.amountLimit ??
      req.body?.amount_limit ??
      req.body?.totalAmount ??
      req.body?.total_amount ??
      req.body?.amount ??
      existingBudget.amount_limit;

    const numLimit = Number(rawLimit);
    if (isNaN(numLimit) || numLimit <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Batas limit budget harus berupa angka lebih besar dari 0.',
      });
    }

    const updatedName = req.body?.name ? String(req.body.name).trim() : existingBudget.name;
    const updatedBucket = inferBucketTypeFromCategory(
      updatedName,
      req.body?.bucketType || req.body?.bucket_type || existingBudget.bucket_type
    );
    const updatedMonth = req.body?.month || existingBudget.month;

    db.prepare(`
      UPDATE budgets
      SET
        name = ?,
        amount_limit = ?,
        total_amount = ?,
        bucket_type = ?,
        month = ?,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND user_id = ?
    `).run(updatedName, numLimit, numLimit, updatedBucket, updatedMonth, budgetId, userId);

    const monthlySummary = getMonthlyBudgetSummaryQuery(db, userId, updatedMonth);

    return res.status(200).json({
      success: true,
      message: 'Batas budget berhasil diperbarui.',
      budget: {
        id: budgetId,
        userId,
        categoryId: existingBudget.category_id,
        name: updatedName,
        bucketType: updatedBucket,
        amountLimit: numLimit,
        totalAmount: numLimit,
        period: existingBudget.period,
        month: updatedMonth,
      },
      monthlyBudget: monthlySummary,
      summary: monthlySummary,
      saranHarian: monthlySummary.saranHarian,
      dailyAdvice: monthlySummary.dailyAdvice,
      rekapIntegration: monthlySummary.rekapIntegration,
      rekapSummary: monthlySummary.rekapSummary,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error updating budget by id:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memperbarui batas budget.',
      details: error.message,
    });
  }
}

/**
 * Controller: DELETE /api/budgets/monthly, DELETE /api/budgets/limit, DELETE /api/budgets
 */
export function deleteMonthlyBudgetHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.body?.userId || req.query?.userId);
    const month = req.params?.month || req.query?.month || req.body?.month || getCurrentMonthString();

    const deleted = deleteMonthlyBudgetLimit(db, userId, { month });
    if (!deleted) {
      return res.status(404).json({
        success: false,
        error: 'Budget bulanan tidak ditemukan untuk periode ini.',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Batas budget bulanan berhasil dihapus.',
      id: deleted.id,
      month: deleted.month,
      monthlyBudget: deleted.summary,
      summary: deleted.summary,
      ...deleted.summary,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error deleting monthly budget:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menghapus batas budget bulanan.',
      details: error.message,
    });
  }
}

/**
 * Controller: DELETE /api/budgets/:id
 */
export function deleteBudgetHandler(req, res) {
  try {
    const db = getDatabase();
    const paramId = req.params.id;
    const userId = getOrCreateDefaultUser(db, req.body?.userId || req.query?.userId);

    if (paramId === 'allocation' || paramId === 'allocations' || paramId === 'percentages') {
      return resetAllocationPercentagesHandler(req, res);
    }

    if (paramId === 'monthly' || paramId === 'limit' || /^\d{4}-\d{2}$/.test(String(paramId))) {
      if (/^\d{4}-\d{2}$/.test(String(paramId))) {
        req.params.month = paramId;
      }
      return deleteMonthlyBudgetHandler(req, res);
    }

    const budgetId = Number(paramId);
    const deleted = deleteMonthlyBudgetLimit(db, userId, { id: budgetId });

    if (!deleted) {
      return res.status(404).json({
        success: false,
        error: 'Budget tidak ditemukan.',
      });
    }

    const summary = deleted.summary || getMonthlyBudgetSummaryQuery(db, userId, deleted.month);

    return res.status(200).json({
      success: true,
      message:
        deleted.deletedType === 'monthly'
          ? 'Batas budget bulanan berhasil dihapus.'
          : 'Budget berhasil dihapus.',
      id: budgetId,
      month: deleted.month,
      monthlyBudget: summary,
      summary,
      saranHarian: summary.saranHarian,
      dailyAdvice: summary.dailyAdvice,
      rekapIntegration: summary.rekapIntegration,
      rekapSummary: summary.rekapSummary,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menghapus budget.',
    });
  }
}

/**
 * Controller: GET /api/budgets/allocation, GET /api/budgets/allocations, GET /api/budgets/percentages
 */
export function getAllocationPercentagesHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const month = req.params?.month || req.query?.month || getCurrentMonthString();

    const data = getAllocationPercentagesQuery(db, userId, month);

    return res.status(200).json({
      success: true,
      ...data,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error getting allocation percentages:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat mengambil persentase alokasi budget.',
      details: error.message,
    });
  }
}

/**
 * Controller: POST/PUT/PATCH /api/budgets/allocation, /api/budgets/allocations, /api/budgets/percentages
 */
export function upsertAllocationPercentagesHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.body?.userId || req.query?.userId);
    const month = req.body?.month || req.params?.month || req.query?.month || getCurrentMonthString();

    const data = upsertAllocationPercentages(db, userId, {
      ...req.body,
      month,
    });

    const statusCode = req.method === 'POST' ? 201 : 200;
    return res.status(statusCode).json({
      success: true,
      message: `Persentase alokasi berhasil diperbarui: ${data.needsPct}% / ${data.savingsPct}% / ${data.funPct}%`,
      ...data,
    });
  } catch (error) {
    if (error.statusCode === 400) {
      return res.status(400).json({
        success: false,
        error: error.message,
        ...(error.validation || {}),
      });
    }
    console.error('[SummaryBudgetController] Error updating allocation percentages:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memperbarui persentase alokasi budget.',
      details: error.message,
    });
  }
}

/**
 * Controller: DELETE /api/budgets/allocation, POST /api/budgets/allocation/reset, PUT /api/budgets/allocation/reset
 */
export function resetAllocationPercentagesHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.body?.userId || req.query?.userId);
    const month = req.body?.month || req.params?.month || req.query?.month || getCurrentMonthString();

    const data = resetAllocationPercentages(db, userId, month);

    return res.status(200).json({
      success: true,
      message: 'Persentase alokasi berhasil direset ke 50% / 30% / 20%.',
      ...data,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error resetting allocation percentages:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat mereset persentase alokasi budget.',
      details: error.message,
    });
  }
}

/**
 * Controller: POST/GET /api/budgets/allocation/validate
 */
export function validateAllocationPercentagesHandler(req, res) {
  try {
    const src = req.method === 'GET' ? req.query : req.body;
    const rawNeeds = src?.needsPct ?? src?.needs_pct ?? src?.needsPercentage ?? src?.needs;
    const rawSavings = src?.savingsPct ?? src?.savings_pct ?? src?.savingsPercentage ?? src?.savings;
    const rawFun = src?.funPct ?? src?.fun_pct ?? src?.funPercentage ?? src?.fun;

    const validation = validateAllocationPercentages(rawNeeds, rawSavings, rawFun);

    return res.status(validation.isValid ? 200 : 400).json({
      success: validation.isValid,
      ...validation,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memvalidasi persentase alokasi.',
    });
  }
}

/**
 * Controller: GET/POST /api/budgets/remaining, /api/budgets/sisa-batas, /api/budgets/buckets, /api/budgets/pos, /api/budgets/calculation
 */
export function getRemainingAndBucketNominalsHandler(req, res) {
  try {
    const db = getDatabase();
    const src = req.method === 'POST' ? { ...req.query, ...req.body } : req.query || {};
    const userId = getOrCreateDefaultUser(db, src.userId);
    const month = req.params?.month || src.month || getCurrentMonthString();

    const result = getRemainingAndBucketNominalsQuery(db, userId, {
      ...src,
      month,
    });

    return res.status(200).json({
      success: true,
      ...result,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error calculating remaining and bucket nominals:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menghitung sisa batas dan nominal tiap pos.',
      details: error.message,
    });
  }
}

/**
 * Controller: GET /api/budgets/warnings, GET /api/budgets/alerts, GET /api/budgets/alert-settings
 */
export function getBudgetWarningStatusHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const month = req.params?.month || req.query?.month || getCurrentMonthString();

    const result = getBudgetWarningStatusQuery(db, userId, {
      ...req.query,
      month,
    });

    return res.status(200).json({
      success: true,
      ...result,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error detecting budget warning status:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat mendeteksi ambang peringatan budget.',
      details: error.message,
    });
  }
}

/**
 * Controller: POST/PUT/PATCH /api/budgets/alerts, /api/budgets/alert-settings, /api/budgets/warnings, /api/budgets/notification-settings
 */
export function updateBudgetAlertSettingsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.body?.userId || req.query?.userId);
    const month = req.body?.month || req.params?.month || req.query?.month || getCurrentMonthString();

    const isTogglePath = req.path && req.path.endsWith('/toggle');
    const result = isTogglePath
      ? toggleBudgetAlert(db, userId, { ...req.body, month })
      : updateBudgetAlertSettings(db, userId, { ...req.body, month });

    const hasMasterToggleField =
      isTogglePath ||
      req.body?.toggle === true ||
      req.body?.toggleAlert === true ||
      req.body?.isAlertEnabled !== undefined ||
      req.body?.alertEnabled !== undefined ||
      req.body?.alert_enabled !== undefined ||
      req.body?.enabled !== undefined ||
      req.body?.isEnabled !== undefined ||
      req.body?.active !== undefined ||
      req.body?.isActive !== undefined;

    const hasThresholdField =
      req.body?.alertThreshold !== undefined ||
      req.body?.alert_threshold !== undefined ||
      req.body?.threshold !== undefined ||
      req.body?.warningThreshold !== undefined ||
      req.body?.warning_threshold !== undefined;

    const hasOverBudgetToggleField =
      req.body?.isOverBudgetAlertEnabled !== undefined ||
      req.body?.overBudgetAlertEnabled !== undefined ||
      req.body?.over_budget_alert_enabled !== undefined ||
      req.body?.overLimitAlertEnabled !== undefined;

    const hasPushToggleField =
      req.body?.isPushNotificationEnabled !== undefined ||
      req.body?.pushNotificationEnabled !== undefined ||
      req.body?.push_notification_enabled !== undefined ||
      req.body?.dailyReminderEnabled !== undefined;

    let message = 'Pengaturan peringatan budget berhasil diperbarui.';
    if (hasMasterToggleField && !hasThresholdField) {
      message = result.isAlertEnabled
        ? 'Peringatan budget diaktifkan.'
        : 'Peringatan budget dinonaktifkan.';
    } else if (hasThresholdField) {
      message = `Ambang batas peringatan diubah ke ${Math.round(result.alertThreshold)}%.`;
    } else if (hasOverBudgetToggleField && !hasPushToggleField) {
      message = result.isOverBudgetAlertEnabled
        ? 'Peringatan melewati batas diaktifkan.'
        : 'Peringatan melewati batas dinonaktifkan.';
    } else if (hasPushToggleField && !hasOverBudgetToggleField) {
      message = result.isPushNotificationEnabled
        ? 'Notifikasi pengingat harian diaktifkan.'
        : 'Notifikasi pengingat harian dinonaktifkan.';
    }

    return res.status(200).json({
      success: true,
      message,
      ...result,
    });
  } catch (error) {
    if (error.statusCode === 400) {
      return res.status(400).json({
        success: false,
        error: error.message,
      });
    }
    console.error('[SummaryBudgetController] Error updating budget alert settings:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memperbarui pengaturan peringatan budget.',
      details: error.message,
    });
  }
}

/**
 * Controller: POST/PUT/PATCH /api/budgets/alerts/toggle, /api/budgets/alert-settings/toggle
 */
export function toggleBudgetAlertHandler(req, res) {
  req.body = { ...(req.body || {}), toggle: req.body?.toggle ?? true };
  return updateBudgetAlertSettingsHandler(req, res);
}

/**
 * Controller: GET/POST /api/budgets/daily-advice, /api/budgets/saran-harian, /api/rekap/daily-advice, /api/rekap/saran-harian
 */
export function getBudgetDailyAdviceHandler(req, res) {
  try {
    const db = getDatabase();
    const src = req.method === 'POST' ? { ...req.query, ...req.body } : req.query || {};
    const userId = getOrCreateDefaultUser(db, src.userId);
    const month = req.params?.month || src.month || getCurrentMonthString();

    const result = getBudgetDailyAdviceQuery(db, userId, {
      ...src,
      month,
    });

    return res.status(200).json({
      success: true,
      ...result,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error getting budget daily advice:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menghitung saran pengeluaran harian dari budget.',
      details: error.message,
    });
  }
}




