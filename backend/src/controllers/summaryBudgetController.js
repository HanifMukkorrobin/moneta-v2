import { getDatabase } from '../config/database.js';
import { getOrCreateDefaultUser } from './chatController.js';

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

  // 1. Confirmed totals
  const totalsRow = db.prepare(`
    SELECT
      COALESCE(SUM(CASE WHEN type = 'income' AND is_confirmed = 1 THEN amount ELSE 0 END), 0) AS total_income,
      COALESCE(SUM(CASE WHEN type = 'expense' AND is_confirmed = 1 THEN amount ELSE 0 END), 0) AS total_expense,
      COUNT(CASE WHEN is_confirmed = 1 THEN 1 END) AS confirmed_count,
      COUNT(CASE WHEN is_confirmed = 0 THEN 1 END) AS pending_count,
      COALESCE(SUM(CASE WHEN type = 'expense' AND is_confirmed = 0 THEN amount ELSE 0 END), 0) AS pending_expense,
      COALESCE(SUM(CASE WHEN type = 'income' AND is_confirmed = 0 THEN amount ELSE 0 END), 0) AS pending_income
    FROM transactions
    WHERE user_id = ? AND occurred_at LIKE ?
  `).get(userId, monthPrefix);

  const totalIncome = totalsRow ? Number(totalsRow.total_income) : 0;
  const totalExpense = totalsRow ? Number(totalsRow.total_expense) : 0;
  const netSavings = totalIncome - totalExpense;
  const savingsRate = totalIncome > 0 ? Math.round(((totalIncome - totalExpense) / totalIncome) * 1000) / 10 : 0;

  // 2. Category breakdown for confirmed expenses
  const categoryBreakdownRows = db.prepare(`
    SELECT
      t.category_id,
      COALESCE(c.name, 'Lainnya') AS category_name,
      c.icon AS category_icon,
      c.color AS category_color,
      t.type,
      SUM(t.amount) AS category_total,
      COUNT(t.id) AS tx_count
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    WHERE t.user_id = ? AND t.occurred_at LIKE ? AND t.is_confirmed = 1
    GROUP BY t.category_id, t.type
    ORDER BY category_total DESC
  `).all(userId, monthPrefix);

  const categoryBreakdown = categoryBreakdownRows.map((r) => {
    const catTotal = Number(r.category_total);
    const denominator = r.type === 'expense' ? totalExpense : totalIncome;
    const percentage = denominator > 0 ? Math.round((catTotal / denominator) * 1000) / 10 : 0;

    return {
      categoryId: r.category_id,
      categoryName: r.category_name,
      type: r.type,
      icon: r.category_icon || (r.type === 'income' ? 'attach_money_rounded' : 'more_horiz_rounded'),
      color: r.category_color || 'grey',
      total: catTotal,
      percentage,
      transactionCount: r.tx_count,
    };
  });

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
    summary: {
      totalIncome,
      totalExpense,
      netSavings,
      savingsRate,
      confirmedTransactionsCount: totalsRow?.confirmed_count || 0,
      pendingTransactionsCount: totalsRow?.pending_count || 0,
      pendingExpenseTotal: totalsRow?.pending_expense || 0,
      pendingIncomeTotal: totalsRow?.pending_income || 0,
    },
    categoryBreakdown,
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
