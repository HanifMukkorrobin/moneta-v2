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
  getDailyTotalsQuery,
  getFullMonthlyRekapAggregation,
} from '../services/rekapQueryService.js';

/**
 * Formats a Date object to YYYY-MM
 */
export function getCurrentMonthString(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

/**
 * Calculates monthly financial summary (rekap) and budget tracking.
 */
export function calculateMonthlyRekap(db, userId, targetMonth) {
  const month = targetMonth || getCurrentMonthString();
  const monthPrefix = `${month}%`;

  // 1. Aggregated totals and MoM comparison
  const aggregated = getFullMonthlyRekapAggregation(db, userId, month);

  // 2. Budgets for this month with spent tracking
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
    const spent = Number(b.total_spent);
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

  return {
    month,
    monthLabel: aggregated.monthLabel,
    summary: aggregated.summary,
    comparison: aggregated.comparison,
    categoryBreakdown: aggregated.categoryBreakdown,
    dailyBreakdown: aggregated.dailyBreakdown,
    budgetStatus,
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

    const data = calculateMonthlyRekap(db, userId, month);

    return res.status(200).json({
      success: true,
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
 * Controller: GET /api/rekap/income-expense, GET /api/rekap/summary, GET /api/transactions/summary
 * Returns comprehensive income and expense summary for a month or date range.
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

    return res.status(200).json({
      success: true,
      ...summary,
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
 * Controller: GET /api/rekap/comparison
 * Returns Month-over-Month comparison
 */
export function getComparisonHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const month = req.query?.month || getCurrentMonthString();

    const comparison = getMonthOverMonthComparisonQuery(db, userId, month);

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
 * Controller: GET /api/rekap/breakdown
 * Returns category breakdown
 */
export function getCategoryBreakdownHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const month = req.query?.month || getCurrentMonthString();
    const type = req.query?.type; // 'expense' | 'income' | undefined

    const breakdown = getCategoryBreakdownQuery(db, userId, month, type);

    return res.status(200).json({
      success: true,
      month,
      type: type || 'all',
      categoryBreakdown: breakdown,
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
 */
export function listBudgetsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const month = req.query?.month || getCurrentMonthString();
    const monthPrefix = `${month}%`;

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
      ORDER BY b.id ASC
    `).all(monthPrefix, userId, month);

    const formatted = budgetRows.map((b) => {
      const limit = Number(b.amount_limit);
      const spent = Number(b.total_spent);
      const remaining = limit - spent;
      const percentageUsed = limit > 0 ? Math.round((spent / limit) * 1000) / 10 : 0;

      return {
        id: b.id,
        categoryId: b.category_id,
        name: b.name,
        categoryName: b.category_name || b.name,
        categoryIcon: b.category_icon,
        categoryColor: b.category_color,
        amountLimit: limit,
        totalSpent: spent,
        remaining,
        percentageUsed,
        isOverBudget: spent > limit,
        period: b.period,
        month: b.month || month,
      };
    });

    return res.status(200).json({
      success: true,
      budgets: formatted,
      month,
      total: formatted.length,
    });
  } catch (error) {
    console.error('[SummaryBudgetController] Error listing budgets:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat daftar budget.',
    });
  }
}

/**
 * Controller: POST /api/budgets
 */
export function createOrUpdateBudgetHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.body?.userId);
    const { categoryId, name, amountLimit, period = 'monthly', month = getCurrentMonthString() } = req.body;

    const numLimit = Number(amountLimit);
    if (!amountLimit || isNaN(numLimit) || numLimit <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Batas limit budget harus berupa angka lebih besar dari 0.',
      });
    }

    let resolvedCatId = categoryId ? Number(categoryId) : null;
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

    // Insert or replace budget for this user, category, and month
    const upsertStmt = db.prepare(`
      INSERT INTO budgets (user_id, category_id, name, amount_limit, period, month)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(user_id, category_id, month) DO UPDATE SET
        name = excluded.name,
        amount_limit = excluded.amount_limit,
        period = excluded.period
    `);

    const result = upsertStmt.run(userId, resolvedCatId, resolvedName, numLimit, period, month);

    const budgetId = result.lastInsertRowid || db.prepare(`
      SELECT id FROM budgets WHERE user_id = ? AND category_id = ? AND month = ?
    `).get(userId, resolvedCatId, month)?.id;

    return res.status(201).json({
      success: true,
      message: 'Budget berhasil disimpan dan diintegrasikan dengan transaksi chat.',
      budget: {
        id: budgetId,
        userId,
        categoryId: resolvedCatId,
        name: resolvedName,
        amountLimit: numLimit,
        period,
        month,
      },
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
 * Controller: DELETE /api/budgets/:id
 */
export function deleteBudgetHandler(req, res) {
  try {
    const db = getDatabase();
    const budgetId = Number(req.params.id);
    const userId = getOrCreateDefaultUser(db, req.body?.userId || req.query?.userId);

    const existing = db.prepare('SELECT id FROM budgets WHERE id = ? AND user_id = ?').get(budgetId, userId);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: 'Budget tidak ditemukan.',
      });
    }

    db.prepare('DELETE FROM budgets WHERE id = ?').run(budgetId);

    return res.status(200).json({
      success: true,
      message: 'Budget berhasil dihapus.',
      id: budgetId,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menghapus budget.',
    });
  }
}
