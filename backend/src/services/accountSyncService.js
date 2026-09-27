/**
 * Account Records Synchronization Service (Layanan Sinkronisasi Catatan Per Akun)
 *
 * Mengelola isolasi & sinkronisasi data keuangan antar perangkat per akun pengguna:
 * - Mengambil snapshot lengkap seluruh catatan milik satu akun (getAccountSyncSnapshot)
 * - Menyinkronkan / mengunggah batch catatan lokal ke akun (syncAccountRecords)
 * - Mengekspor data keuangan akun ke format JSON atau CSV (exportAccountData)
 * - Mereset seluruh catatan keuangan milik satu akun tanpa memengaruhi akun lain (resetAccountRecords)
 */

import {
  getUserById,
  getUserPreferences,
  updateUserPreferences,
  resetUserPreferences,
} from './userService.js';
import { getDebtsByUserId, createDebt } from './debtService.js';
import { getReminderSettings, updateReminderSettings } from './reminderSettingsService.js';

function ensureUserExists(db, userId) {
  const numId = Number(userId);
  if (!numId || isNaN(numId) || numId <= 0 || !Number.isInteger(numId)) {
    const err = new Error('ID pengguna tidak valid.');
    err.statusCode = 400;
    err.code = 'INVALID_USER_ID';
    throw err;
  }

  const user = getUserById(db, numId);
  if (!user) {
    const err = new Error('Akun pengguna tidak ditemukan.');
    err.statusCode = 404;
    err.code = 'USER_NOT_FOUND';
    throw err;
  }

  return user;
}

export function getAccountSyncSnapshot(db, userId) {
  const user = ensureUserExists(db, userId);
  const { preferences } = getUserPreferences(db, user.id);

  // 1. Transactions milik akun ini
  const rawTransactions = db
    .prepare(`
      SELECT
        t.*,
        COALESCE(t.category_name, c.name, 'Lainnya') AS resolved_category_name,
        c.icon AS category_icon,
        c.color AS category_color
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.user_id = ?
      ORDER BY t.occurred_at DESC, t.id DESC
    `)
    .all(user.id);

  const transactions = rawTransactions.map((tx) => ({
    id: tx.id,
    userId: tx.user_id,
    categoryId: tx.category_id,
    categoryName: tx.resolved_category_name,
    type: tx.type,
    amount: Number(tx.amount),
    note: tx.note,
    description: tx.note,
    occurredAt: tx.occurred_at,
    isConfirmed: Boolean(tx.is_confirmed),
    isGuessed: Boolean(tx.is_guessed),
    confidenceScore: tx.confidence_score,
    aiReasoning: tx.ai_reasoning,
    createdAt: tx.created_at,
  }));

  // 2. Chat logs milik akun ini
  const rawChatLogs = db
    .prepare(`
      SELECT * FROM chat_logs
      WHERE user_id = ?
      ORDER BY created_at DESC, id DESC
    `)
    .all(user.id);

  const chatLogs = rawChatLogs.map((log) => ({
    id: log.id,
    userId: log.user_id,
    message: log.message,
    parsedJson: log.parsed_json ? safeParseJson(log.parsed_json) : null,
    transactionId: log.transaction_id,
    status: log.status,
    createdAt: log.created_at,
  }));

  // 3. Categories (bawaan + kustom milik akun ini)
  const rawCategories = db
    .prepare(`
      SELECT * FROM categories
      WHERE user_id IS NULL OR user_id = ?
      ORDER BY is_default DESC, id ASC
    `)
    .all(user.id);

  const categories = rawCategories.map((cat) => ({
    id: cat.id,
    userId: cat.user_id,
    name: cat.name,
    type: cat.type,
    isDefault: Boolean(cat.is_default),
    isCustom: !cat.is_default && cat.user_id === user.id,
    icon: cat.icon,
    color: cat.color,
    createdAt: cat.created_at,
  }));

  const customCategories = categories.filter((c) => c.isCustom);

  // 4. Budgets & Monthly Budgets milik akun ini
  const budgets = db
    .prepare('SELECT * FROM budgets WHERE user_id = ? ORDER BY month DESC, id DESC')
    .all(user.id)
    .map((b) => ({
      id: b.id,
      userId: b.user_id,
      categoryId: b.category_id,
      name: b.name,
      amountLimit: Number(b.amount_limit),
      totalAmount: Number(b.total_amount),
      needsPct: Number(b.needs_pct),
      savingsPct: Number(b.savings_pct),
      funPct: Number(b.fun_pct),
      bucketType: b.bucket_type,
      period: b.period,
      month: b.month,
      alertEnabled: Boolean(b.alert_enabled),
      alertThreshold: Number(b.alert_threshold),
      createdAt: b.created_at,
      updatedAt: b.updated_at,
    }));

  const monthlyBudgets = db
    .prepare('SELECT * FROM monthly_budgets WHERE user_id = ? ORDER BY month DESC')
    .all(user.id)
    .map((mb) => ({
      id: mb.id,
      userId: mb.user_id,
      month: mb.month,
      totalAmount: Number(mb.total_amount),
      needsPct: Number(mb.needs_pct),
      savingsPct: Number(mb.savings_pct),
      funPct: Number(mb.fun_pct),
      alertEnabled: Boolean(mb.alert_enabled),
      alertThreshold: Number(mb.alert_threshold),
      createdAt: mb.created_at,
      updatedAt: mb.updated_at,
    }));

  // 5. Debts milik akun ini
  const debts = getDebtsByUserId(db, user.id);

  // 6. Reminder Settings milik akun ini
  const reminderSettings = getReminderSettings(db, user.id);

  // 7. AI Insights milik akun ini
  const aiInsights = db
    .prepare('SELECT * FROM ai_insights WHERE user_id = ? ORDER BY date DESC LIMIT 30')
    .all(user.id);

  // 8. Ringkasan Statistik Akun
  let totalIncome = 0;
  let totalExpense = 0;
  for (const tx of transactions) {
    if (tx.isConfirmed) {
      if (tx.type === 'income') totalIncome += tx.amount;
      else if (tx.type === 'expense') totalExpense += tx.amount;
    }
  }

  const activeDebts = debts.filter((d) => !d.isPaid);
  const totalRemainingDebt = activeDebts.reduce((acc, d) => acc + Number(d.remainingAmount || 0), 0);

  const syncedAt = new Date().toISOString();
  const stats = {
    transactionsCount: transactions.length,
    chatLogsCount: chatLogs.length,
    customCategoriesCount: customCategories.length,
    budgetsCount: budgets.length + monthlyBudgets.length,
    debtsCount: debts.length,
    activeDebtsCount: activeDebts.length,
    totalIncome,
    totalExpense,
    netBalance: totalIncome - totalExpense,
    totalRemainingDebt,
    syncedAt,
  };

  return {
    userId: user.id,
    syncedAt,
    user,
    preferences,
    stats,
    summary: stats,
    transactions,
    chatLogs,
    categories,
    customCategories,
    budgets: budgets.length > 0 ? budgets : monthlyBudgets,
    monthlyBudgets,
    debts,
    reminderSettings,
    aiInsights,
  };
}

function safeParseJson(str) {
  try {
    return JSON.parse(str);
  } catch {
    return str;
  }
}

export function syncAccountRecords(db, userId, payload = {}) {
  const user = ensureUserExists(db, userId);
  const mode = String(payload.mode || 'merge').toLowerCase() === 'replace' ? 'replace' : 'merge';

  const syncedCounts = {
    mode,
    transactionsSynced: 0,
    transactionsInserted: 0,
    debtsSynced: 0,
    debtsInserted: 0,
    categoriesSynced: 0,
    categoriesInserted: 0,
    budgetsSynced: 0,
    budgetsUpserted: 0,
    chatLogsSynced: 0,
    preferencesUpdated: false,
    reminderSettingsUpdated: false,
  };

  const tx = db.transaction(() => {
    if (mode === 'replace') {
      db.prepare('DELETE FROM transactions WHERE user_id = ?').run(user.id);
      db.prepare('DELETE FROM chat_logs WHERE user_id = ?').run(user.id);
      db.prepare('DELETE FROM debts WHERE user_id = ?').run(user.id);
      db.prepare('DELETE FROM categories WHERE user_id = ? AND is_default = 0').run(user.id);
      db.prepare('DELETE FROM budgets WHERE user_id = ?').run(user.id);
      db.prepare('DELETE FROM monthly_budgets WHERE user_id = ?').run(user.id);
    }

    // 1. Preferences
    if (payload.preferences && typeof payload.preferences === 'object') {
      updateUserPreferences(db, user.id, payload.preferences);
      syncedCounts.preferencesUpdated = true;
    }

    // 2. Reminder Settings
    if (payload.reminderSettings && typeof payload.reminderSettings === 'object') {
      updateReminderSettings(db, user.id, payload.reminderSettings);
      syncedCounts.reminderSettingsUpdated = true;
    }

    // 3. Custom Categories
    const incomingCategories = Array.isArray(payload.categories)
      ? payload.categories
      : (Array.isArray(payload.customCategories) ? payload.customCategories : []);

    for (const cat of incomingCategories) {
      if (!cat || !cat.name) continue;
      const name = String(cat.name).trim();
      const type = cat.type === 'income' ? 'income' : 'expense';
      const icon = cat.icon || 'category_rounded';
      const color = cat.color || 'teal';

      const existingCat = db
        .prepare('SELECT id FROM categories WHERE user_id = ? AND LOWER(name) = LOWER(?) AND type = ?')
        .get(user.id, name, type);

      if (existingCat) {
        db.prepare('UPDATE categories SET icon = ?, color = ? WHERE id = ?').run(
          icon,
          color,
          existingCat.id
        );
      } else {
        db.prepare(`
          INSERT INTO categories (user_id, name, type, is_default, icon, color)
          VALUES (?, ?, ?, 0, ?, ?)
        `).run(user.id, name, type, icon, color);
      }

      syncedCounts.categoriesSynced++;
      syncedCounts.categoriesInserted++;
    }

    // 4. Transactions
    if (Array.isArray(payload.transactions)) {
      const insertTxStmt = db.prepare(`
        INSERT INTO transactions (
          user_id, category_id, category_name, type, amount, note,
          occurred_at, is_confirmed, is_guessed, confidence_score, ai_reasoning
        )
        VALUES (?, ?, ?, ?, ?, ?, COALESCE(?, CURRENT_TIMESTAMP), ?, ?, ?, ?)
      `);

      for (const item of payload.transactions) {
        if (!item) continue;
        const amount = Number(item.amount);
        if (isNaN(amount) || amount <= 0) continue;

        const type = item.type === 'income' ? 'income' : 'expense';
        const note = String(
          item.note || item.description || item.title || 'Catatan Sinkronisasi'
        ).trim();
        const categoryName = item.categoryName || item.category_name || item.category || 'Lainnya';

        // Resolve category_id for this user or default
        const catRow = db
          .prepare(`
            SELECT id, name FROM categories
            WHERE LOWER(name) = LOWER(?) AND type = ? AND (user_id = ? OR user_id IS NULL)
            ORDER BY user_id DESC LIMIT 1
          `)
          .get(categoryName, type, user.id);

        const occurredAt =
          item.occurredAt || item.occurred_at || item.transactionDate || item.date || null;
        const isConfirmed = item.isConfirmed === undefined ? 1 : (item.isConfirmed ? 1 : 0);
        const isGuessed = item.isGuessed === undefined ? 0 : (item.isGuessed ? 1 : 0);

        insertTxStmt.run(
          user.id,
          catRow ? catRow.id : null,
          catRow ? catRow.name : categoryName,
          type,
          amount,
          note,
          occurredAt,
          isConfirmed,
          isGuessed,
          item.confidenceScore ?? item.confidence_score ?? null,
          item.aiReasoning ?? item.ai_reasoning ?? null
        );

        syncedCounts.transactionsSynced++;
        syncedCounts.transactionsInserted++;
      }
    }

    // 5. Debts
    if (Array.isArray(payload.debts)) {
      for (const d of payload.debts) {
        if (!d || !d.name) continue;
        const totalAmount = Number(d.totalAmount ?? d.total_amount ?? d.amount);
        if (isNaN(totalAmount) || totalAmount <= 0) continue;

        createDebt(db, {
          userId: user.id,
          name: d.name,
          totalAmount,
          remainingAmount:
            d.remainingAmount !== undefined || d.remaining_amount !== undefined
              ? Number(d.remainingAmount ?? d.remaining_amount)
              : totalAmount,
          dueDate: d.dueDate || d.due_date || new Date().toISOString().slice(0, 10),
          type: d.type || 'paylater',
          status: d.status === 'paid' ? 'paid' : 'active',
          notes: d.notes || d.creditor || null,
        });

        syncedCounts.debtsSynced++;
        syncedCounts.debtsInserted++;
      }
    }

    // 6. Monthly Budgets
    const incomingBudgets = Array.isArray(payload.budgets)
      ? payload.budgets
      : (Array.isArray(payload.monthlyBudgets) ? payload.monthlyBudgets : []);

    for (const b of incomingBudgets) {
      if (!b) continue;
      const month = b.month || new Date().toISOString().slice(0, 7);
      const totalAmount = Number(b.totalAmount ?? b.total_amount ?? b.amountLimit ?? 0);
      if (isNaN(totalAmount) || totalAmount < 0) continue;

      const needsPct = Number(b.needsPct ?? b.needs_pct ?? 50);
      const savingsPct = Number(b.savingsPct ?? b.savings_pct ?? 30);
      const funPct = Number(b.funPct ?? b.fun_pct ?? 20);

      const existingMb = db
        .prepare('SELECT id FROM monthly_budgets WHERE user_id = ? AND month = ?')
        .get(user.id, month);

      if (existingMb) {
        db.prepare(`
          UPDATE monthly_budgets
          SET total_amount = ?, needs_pct = ?, savings_pct = ?, fun_pct = ?, updated_at = CURRENT_TIMESTAMP
          WHERE id = ?
        `).run(totalAmount, needsPct, savingsPct, funPct, existingMb.id);
      } else {
        db.prepare(`
          INSERT INTO monthly_budgets (user_id, month, total_amount, needs_pct, savings_pct, fun_pct)
          VALUES (?, ?, ?, ?, ?, ?)
        `).run(user.id, month, totalAmount, needsPct, savingsPct, funPct);
      }

      syncedCounts.budgetsSynced++;
      syncedCounts.budgetsUpserted++;
    }

    // 7. Chat Logs
    if (Array.isArray(payload.chatLogs)) {
      const insertLogStmt = db.prepare(`
        INSERT INTO chat_logs (user_id, message, parsed_json, status)
        VALUES (?, ?, ?, ?)
      `);

      for (const log of payload.chatLogs) {
        if (!log || !log.message) continue;
        const parsedStr =
          log.parsedJson && typeof log.parsedJson === 'object'
            ? JSON.stringify(log.parsedJson)
            : (log.parsed_json || null);
        const status = ['pending', 'confirmed', 'deleted', 'failed'].includes(log.status)
          ? log.status
          : 'confirmed';

        insertLogStmt.run(user.id, String(log.message).trim(), parsedStr, status);
        syncedCounts.chatLogsSynced++;
      }
    }
  });

  tx();

  const snapshot = getAccountSyncSnapshot(db, user.id);
  return {
    success: true,
    userId: user.id,
    mode,
    syncedCounts,
    syncStats: syncedCounts,
    snapshot,
    ...snapshot,
  };
}

export function exportAccountData(db, userId, options = {}) {
  const snapshot = getAccountSyncSnapshot(db, userId);
  const format = String(options.format || 'json').trim().toLowerCase();

  if (format === 'csv') {
    const headers = [
      'id',
      'occurred_at',
      'type',
      'category_name',
      'amount',
      'note',
      'is_confirmed',
    ];
    const lines = [headers.join(',')];

    for (const tx of snapshot.transactions) {
      const safeNote = `"${String(tx.note || '').replace(/"/g, '""')}"`;
      const safeCat = `"${String(tx.categoryName || '').replace(/"/g, '""')}"`;
      lines.push(
        [
          tx.id,
          tx.occurredAt,
          tx.type,
          safeCat,
          tx.amount,
          safeNote,
          tx.isConfirmed ? 1 : 0,
        ].join(',')
      );
    }

    return {
      format: 'csv',
      userId: snapshot.userId,
      filename: `moneta_export_user_${snapshot.userId}.csv`,
      contentType: 'text/csv; charset=utf-8',
      csv: lines.join('\n'),
      rowCount: snapshot.transactions.length,
      snapshot,
    };
  }

  return {
    format: 'json',
    userId: snapshot.userId,
    filename: `moneta_export_user_${snapshot.userId}.json`,
    contentType: 'application/json; charset=utf-8',
    exportedAt: snapshot.syncedAt,
    data: snapshot,
    snapshot,
  };
}

export function resetAccountRecords(db, userId, options = {}) {
  const user = ensureUserExists(db, userId);
  const deletedCounts = {};

  const tx = db.transaction(() => {
    deletedCounts.transactions = db
      .prepare('DELETE FROM transactions WHERE user_id = ?')
      .run(user.id).changes;
    deletedCounts.chatLogs = db
      .prepare('DELETE FROM chat_logs WHERE user_id = ?')
      .run(user.id).changes;
    deletedCounts.debts = db
      .prepare('DELETE FROM debts WHERE user_id = ?')
      .run(user.id).changes;
    deletedCounts.customCategories = db
      .prepare('DELETE FROM categories WHERE user_id = ? AND is_default = 0')
      .run(user.id).changes;
    deletedCounts.budgets = db
      .prepare('DELETE FROM budgets WHERE user_id = ?')
      .run(user.id).changes;
    deletedCounts.monthlyBudgets = db
      .prepare('DELETE FROM monthly_budgets WHERE user_id = ?')
      .run(user.id).changes;
    deletedCounts.aiInsights = db
      .prepare('DELETE FROM ai_insights WHERE user_id = ?')
      .run(user.id).changes;
    deletedCounts.dailyAdvice = db
      .prepare('DELETE FROM daily_advice_cache WHERE user_id = ?')
      .run(user.id).changes;

    if (options.resetPreferences) {
      resetUserPreferences(db, user.id);
    }
  });

  tx();

  const snapshot = getAccountSyncSnapshot(db, user.id);
  return {
    success: true,
    userId: user.id,
    deletedCounts,
    deleted: deletedCounts,
    snapshot,
    ...snapshot,
  };
}

