import { getDatabase } from '../config/database.js';
import { getOrCreateDefaultUser, findCategoryByName } from './chatController.js';
import { getMonthlyTransactionsListQuery } from '../services/rekapQueryService.js';
import { recalculateFinancialAnalysis } from '../services/financialAnalysisService.js';

/**
 * Resolves a category by ID or name and type.
 * Falls back to 'Lainnya' if not found.
 */
export function resolveCategory(db, { categoryId, categoryName, type }) {
  if (categoryId) {
    const cat = db.prepare('SELECT id, name, type FROM categories WHERE id = ?').get(categoryId);
    if (cat) return cat;
  }

  if (categoryName) {
    const cat = findCategoryByName(db, categoryName, type);
    if (cat) return cat;
  }

  // Fallback to default 'Lainnya' category for the given type
  const fallback = findCategoryByName(db, 'Lainnya', type);
  return fallback || null;
}

/**
 * Controller to confirm and save a transaction.
 * Supports:
 * - Confirming an existing pending transaction (with optional field modifications)
 * - Creating a new confirmed transaction (e.g., manual entry flow)
 * - Linking and updating associated chat_logs status to 'confirmed'
 */
export async function confirmTransactionHandler(req, res) {
  try {
    const db = getDatabase();
    const paramId = req.params?.id;
    const body = req.body || {};

    const targetTransactionId = paramId ? Number(paramId) : (body.transactionId ? Number(body.transactionId) : null);
    const chatLogId = body.chatLogId ? Number(body.chatLogId) : null;
    const userId = getOrCreateDefaultUser(db, body.userId);

    // If confirming an existing transaction
    if (targetTransactionId) {
      const existingTx = db
        .prepare('SELECT * FROM transactions WHERE id = ? AND user_id = ?')
        .get(targetTransactionId, userId);

      if (!existingTx) {
        return res.status(404).json({
          success: false,
          error: 'Transaksi tidak ditemukan.',
        });
      }

      // Validate amount if provided
      let finalAmount = existingTx.amount;
      if (body.amount !== undefined && body.amount !== null) {
        const numAmount = Number(body.amount);
        if (isNaN(numAmount) || numAmount <= 0) {
          return res.status(400).json({
            success: false,
            error: 'Nominal transaksi harus berupa angka lebih besar dari 0.',
          });
        }
        finalAmount = numAmount;
      }

      // Validate type if provided
      let finalType = existingTx.type;
      if (body.type) {
        if (!['income', 'expense'].includes(body.type)) {
          return res.status(400).json({
            success: false,
            error: 'Jenis transaksi harus berupa income atau expense.',
          });
        }
        finalType = body.type;
      }

      // Resolve category
      let finalCategoryId = existingTx.category_id;
      if (body.categoryId || body.category || body.categoryName || body.type) {
        const resolved = resolveCategory(db, {
          categoryId: body.categoryId,
          categoryName: body.category || body.categoryName,
          type: finalType,
        });
        if (resolved) {
          finalCategoryId = resolved.id;
        }
      }

      const finalNote = (body.note !== undefined && body.note !== null)
        ? String(body.note).trim()
        : existingTx.note;

      if (!finalNote) {
        return res.status(400).json({
          success: false,
          error: 'Catatan transaksi tidak boleh kosong.',
        });
      }

      const finalOccurredAt = body.occurredAt || existingTx.occurred_at;

      const finalCategoryRecord = finalCategoryId ? db.prepare('SELECT name FROM categories WHERE id = ?').get(finalCategoryId) : null;
      const finalCategoryName = finalCategoryRecord?.name || body.category || body.categoryName || existingTx.category_name || 'Lainnya';

      // Update transaction inside a database transaction
      db.transaction(() => {
        db.prepare(`
          UPDATE transactions
          SET amount = ?, type = ?, category_id = ?, category_name = ?, note = ?, occurred_at = ?, is_confirmed = 1, is_guessed = 0
          WHERE id = ?
        `).run(finalAmount, finalType, finalCategoryId, finalCategoryName, finalNote, finalOccurredAt, targetTransactionId);

        // Update chat logs status to 'confirmed'
        if (chatLogId) {
          db.prepare(`
            UPDATE chat_logs
            SET status = 'confirmed', transaction_id = ?
            WHERE id = ?
          `).run(targetTransactionId, chatLogId);
        } else {
          db.prepare(`
            UPDATE chat_logs
            SET status = 'confirmed'
            WHERE transaction_id = ? AND status = 'pending'
          `).run(targetTransactionId);
        }
      })();

      // Fetch updated record with category details
      const updatedTx = db.prepare(`
        SELECT t.*, c.name AS category_name, c.icon AS category_icon, c.color AS category_color
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        WHERE t.id = ?
      `).get(targetTransactionId);

      // Recalculate financial analysis automatically
      let analysis = null;
      try {
        const recalc = recalculateFinancialAnalysis(db, {
          userId,
          referenceDate: updatedTx.occurred_at,
        });
        analysis = recalc.summary;
      } catch (err) {
        console.warn('[TransactionController] Failed to recalculate financial analysis:', err.message);
      }

      return res.status(200).json({
        success: true,
        message: 'Transaksi berhasil dikonfirmasi dan disimpan.',
        transaction: {
          id: updatedTx.id,
          userId: updatedTx.user_id,
          categoryId: updatedTx.category_id,
          category: updatedTx.category_name || finalCategoryName,
          type: updatedTx.type,
          amount: updatedTx.amount,
          note: updatedTx.note,
          occurredAt: updatedTx.occurred_at,
          isConfirmed: Boolean(updatedTx.is_confirmed),
          isGuessedCategory: Boolean(updatedTx.is_guessed),
          confidenceScore: updatedTx.confidence_score,
          aiReasoning: updatedTx.ai_reasoning,
          createdAt: updatedTx.created_at,
        },
        analysis,
        chatLogId: chatLogId || null,
      });
    }

    // Creating a new confirmed transaction (e.g. manual entry or new record)
    const { amount, type, note, occurredAt, category, categoryName, categoryId } = body;

    const numAmount = Number(amount);
    if (!amount || isNaN(numAmount) || numAmount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Nominal transaksi harus berupa angka lebih besar dari 0.',
      });
    }

    if (!type || !['income', 'expense'].includes(type)) {
      return res.status(400).json({
        success: false,
        error: 'Jenis transaksi harus berupa income atau expense.',
      });
    }

    const trimmedNote = (note || '').trim();
    if (!trimmedNote) {
      return res.status(400).json({
        success: false,
        error: 'Catatan transaksi wajib diisi.',
      });
    }

    const resolved = resolveCategory(db, {
      categoryId,
      categoryName: category || categoryName,
      type,
    });
    const finalCategoryId = resolved ? resolved.id : null;
    const finalCategoryName = resolved ? resolved.name : 'Lainnya';
    const txOccurredAt = occurredAt || new Date().toISOString();

    let newTxId = null;

    db.transaction(() => {
      const insertRes = db.prepare(`
        INSERT INTO transactions (
          user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed, is_guessed
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0)
      `).run(userId, finalCategoryId, finalCategoryName, type, numAmount, trimmedNote, txOccurredAt);

      newTxId = insertRes.lastInsertRowid;

      if (chatLogId) {
        db.prepare(`
          UPDATE chat_logs
          SET status = 'confirmed', transaction_id = ?
          WHERE id = ?
        `).run(newTxId, chatLogId);
      }
    })();

    const insertedTx = db.prepare(`
      SELECT t.*, c.name AS category_name, c.icon AS category_icon, c.color AS category_color
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.id = ?
    `).get(newTxId);

    // Recalculate financial analysis automatically
    let analysis = null;
    try {
      const recalc = recalculateFinancialAnalysis(db, {
        userId,
        referenceDate: insertedTx.occurred_at,
      });
      analysis = recalc.summary;
    } catch (err) {
      console.warn('[TransactionController] Failed to recalculate financial analysis:', err.message);
    }

    return res.status(201).json({
      success: true,
      message: 'Transaksi berhasil disimpan.',
      transaction: {
        id: insertedTx.id,
        userId: insertedTx.user_id,
        categoryId: insertedTx.category_id,
        category: insertedTx.category_name || finalCategoryName,
        type: insertedTx.type,
        amount: insertedTx.amount,
        note: insertedTx.note,
        occurredAt: insertedTx.occurred_at,
        isConfirmed: Boolean(insertedTx.is_confirmed),
        isGuessedCategory: Boolean(insertedTx.is_guessed),
        confidenceScore: insertedTx.confidence_score,
        aiReasoning: insertedTx.ai_reasoning,
        createdAt: insertedTx.created_at,
      },
      analysis,
      chatLogId: chatLogId || null,
    });
  } catch (error) {
    console.error('[TransactionController] Error confirming transaction:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan internal saat menyimpan transaksi.',
      details: error.message,
    });
  }
}

/**
 * Controller to list transactions with optional month, date range, category, type, status, amount, search, and sort filters.
 */
export function listTransactionsHandler(req, res) {
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
      defaultToCurrentMonth: false,
    });

    return res.status(200).json({
      success: true,
      ...result,
    });
  } catch (error) {
    console.error('[TransactionController] Error listing transactions:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat daftar transaksi.',
      details: error.message,
    });
  }
}

/**
 * Service helper to fetch full detail of a single transaction by ID.
 */
export function getTransactionDetailById(db, userId, txId) {
  const tx = db.prepare(`
    SELECT
      t.*,
      COALESCE(c.name, t.category_name, 'Lainnya') AS resolved_category_name,
      c.icon AS category_icon,
      c.color AS category_color,
      COALESCE(c.is_default, 1) AS category_is_default
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    WHERE t.id = ? AND t.user_id = ?
  `).get(txId, userId);

  if (!tx) return null;

  const categoryName = tx.resolved_category_name || 'Lainnya';
  const amount = Number(tx.amount);
  const isIncome = tx.type === 'income';
  const isConfirmed = Boolean(tx.is_confirmed);
  const confidenceScore = tx.confidence_score !== null && tx.confidence_score !== undefined
    ? Number(tx.confidence_score)
    : 1.0;
  const confidencePercentage = Math.round(confidenceScore * 100);

  const formattedNum = Math.round(Math.abs(amount)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  const formattedAmount = `${isIncome ? '+ ' : '- '}Rp ${formattedNum}`;

  const occurredStr = tx.occurred_at ? String(tx.occurred_at) : '';
  const datePart = occurredStr.slice(0, 10) || null;
  const monthPart = occurredStr.slice(0, 7) || null;

  // Linked chat log if created from chat
  const chatLogRow = db.prepare(`
    SELECT id, message, parsed_json, status, created_at
    FROM chat_logs
    WHERE transaction_id = ?
    ORDER BY id DESC
    LIMIT 1
  `).get(tx.id);

  let parsedChatJson = null;
  if (chatLogRow?.parsed_json) {
    try {
      parsedChatJson = JSON.parse(chatLogRow.parsed_json);
    } catch {
      parsedChatJson = null;
    }
  }

  // Monthly context (how much this transaction contributes to its category & month)
  let monthlyContext = null;
  if (monthPart) {
    const monthTotalsRow = db.prepare(`
      SELECT
        COALESCE(SUM(CASE WHEN type = ? AND is_confirmed = 1 THEN amount ELSE 0 END), 0) AS monthly_type_total,
        COALESCE(SUM(CASE WHEN type = ? AND is_confirmed = 1 AND LOWER(COALESCE((SELECT name FROM categories WHERE id = transactions.category_id), category_name, 'Lainnya')) = LOWER(?) THEN amount ELSE 0 END), 0) AS category_total,
        COUNT(CASE WHEN type = ? AND is_confirmed = 1 AND LOWER(COALESCE((SELECT name FROM categories WHERE id = transactions.category_id), category_name, 'Lainnya')) = LOWER(?) THEN 1 END) AS category_tx_count
      FROM transactions
      WHERE user_id = ? AND occurred_at LIKE ?
    `).get(tx.type, tx.type, categoryName, tx.type, categoryName, userId, `${monthPart}%`);

    const monthlyTypeTotal = Number(monthTotalsRow?.monthly_type_total || 0);
    const categoryTotalInMonth = Number(monthTotalsRow?.category_total || 0);
    const categoryTransactionCountInMonth = Number(monthTotalsRow?.category_tx_count || 0);

    monthlyContext = {
      month: monthPart,
      categoryTotalInMonth,
      categoryTransactionCountInMonth,
      monthlyTypeTotal,
      shareOfCategoryPct: categoryTotalInMonth > 0
        ? Math.round((amount / categoryTotalInMonth) * 1000) / 10
        : 0,
      shareOfMonthlyTotalPct: monthlyTypeTotal > 0
        ? Math.round((amount / monthlyTypeTotal) * 1000) / 10
        : 0,
    };
  }

  return {
    id: tx.id,
    displayId: `#${tx.id}`,
    userId: tx.user_id,
    categoryId: tx.category_id,
    category: categoryName,
    categoryName,
    categoryIcon: tx.category_icon || (isIncome ? 'attach_money_rounded' : 'more_horiz_rounded'),
    categoryColor: tx.category_color || (isIncome ? 'green' : 'blue'),
    isCustomCategory: tx.category_is_default === 0,
    type: tx.type,
    typeLabel: isIncome ? 'Pemasukan' : 'Pengeluaran',
    amount,
    formattedAmount,
    note: tx.note,
    occurredAt: tx.occurred_at,
    date: datePart,
    month: monthPart,
    isConfirmed,
    verificationStatus: isConfirmed ? 'confirmed' : 'pending',
    verificationStatusLabel: isConfirmed ? 'Terkonfirmasi' : 'Menunggu Konfirmasi',
    isGuessedCategory: Boolean(tx.is_guessed),
    confidenceScore,
    confidencePercentage,
    formattedConfidence: `${confidencePercentage}%`,
    aiReasoning: tx.ai_reasoning || null,
    createdAt: tx.created_at,
    chatLog: chatLogRow ? {
      id: chatLogRow.id,
      message: chatLogRow.message,
      status: chatLogRow.status,
      parsed: parsedChatJson,
      createdAt: chatLogRow.created_at,
    } : null,
    monthlyContext,
  };
}

/**
 * Controller to get a single transaction by ID.
 * Supports GET /api/transactions/:id, GET /api/rekap/transactions/:id
 */
export function getTransactionByIdHandler(req, res) {
  try {
    const db = getDatabase();
    const txId = Number(req.params.id);
    if (!req.params.id || isNaN(txId) || txId <= 0) {
      return res.status(400).json({
        success: false,
        error: 'ID transaksi tidak valid.',
      });
    }

    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const detail = getTransactionDetailById(db, userId, txId);

    if (!detail) {
      return res.status(404).json({
        success: false,
        error: 'Transaksi tidak ditemukan.',
      });
    }

    return res.status(200).json({
      success: true,
      transaction: detail,
    });
  } catch (error) {
    console.error('[TransactionController] Error getting transaction detail:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat detail transaksi.',
      details: error.message,
    });
  }
}

/**
 * Controller to update an existing transaction.
 * Also keeps associated chat_logs parsed_json in sync.
 */
export function updateTransactionHandler(req, res) {
  try {
    const db = getDatabase();
    const txId = Number(req.params.id);
    const userId = getOrCreateDefaultUser(db, req.body?.userId);
    const body = req.body || {};

    const existingTx = db
      .prepare('SELECT * FROM transactions WHERE id = ? AND user_id = ?')
      .get(txId, userId);

    if (!existingTx) {
      return res.status(404).json({
        success: false,
        error: 'Transaksi tidak ditemukan.',
      });
    }

    // Validate amount if provided
    let finalAmount = existingTx.amount;
    if (body.amount !== undefined && body.amount !== null) {
      const numAmount = Number(body.amount);
      if (isNaN(numAmount) || numAmount <= 0) {
        return res.status(400).json({
          success: false,
          error: 'Nominal transaksi harus berupa angka lebih besar dari 0.',
        });
      }
      finalAmount = numAmount;
    }

    // Validate type if provided
    let finalType = existingTx.type;
    if (body.type) {
      if (!['income', 'expense'].includes(body.type)) {
        return res.status(400).json({
          success: false,
          error: 'Jenis transaksi harus berupa income atau expense.',
        });
      }
      finalType = body.type;
    }

    // Resolve category if provided or type changed
    let finalCategoryId = existingTx.category_id;
    if (body.categoryId || body.category || body.categoryName || body.type) {
      const resolved = resolveCategory(db, {
        categoryId: body.categoryId,
        categoryName: body.category || body.categoryName,
        type: finalType,
      });
      if (resolved) {
        finalCategoryId = resolved.id;
      }
    }

    // Validate note
    let finalNote = existingTx.note;
    if (body.note !== undefined && body.note !== null) {
      const trimmedNote = String(body.note).trim();
      if (!trimmedNote) {
        return res.status(400).json({
          success: false,
          error: 'Catatan transaksi tidak boleh kosong.',
        });
      }
      finalNote = trimmedNote;
    }

    const finalOccurredAt = body.occurredAt || existingTx.occurred_at;
    const finalIsConfirmed = body.isConfirmed !== undefined
      ? (body.isConfirmed === true || body.isConfirmed === 1 ? 1 : 0)
      : existingTx.is_confirmed;

    const finalCategoryRecord = finalCategoryId ? db.prepare('SELECT name FROM categories WHERE id = ?').get(finalCategoryId) : null;
    const finalCategoryName = finalCategoryRecord?.name || body.category || body.categoryName || existingTx.category_name || 'Lainnya';

    db.transaction(() => {
      db.prepare(`
        UPDATE transactions
        SET amount = ?, type = ?, category_id = ?, category_name = ?, note = ?, occurred_at = ?, is_confirmed = ?, is_guessed = 0
        WHERE id = ?
      `).run(finalAmount, finalType, finalCategoryId, finalCategoryName, finalNote, finalOccurredAt, finalIsConfirmed, txId);

      // Also update linked chat_log parsed_json if exists
      const chatLog = db.prepare('SELECT id, parsed_json FROM chat_logs WHERE transaction_id = ?').get(txId);
      if (chatLog) {
        let parsed = {};
        try {
          parsed = JSON.parse(chatLog.parsed_json || '{}');
        } catch {
          parsed = {};
        }
        parsed.amount = finalAmount;
        parsed.type = finalType;
        parsed.note = finalNote;
        if (finalCategoryId) {
          const cat = db.prepare('SELECT name FROM categories WHERE id = ?').get(finalCategoryId);
          if (cat) parsed.category = cat.name;
        }

        db.prepare('UPDATE chat_logs SET parsed_json = ? WHERE id = ?')
          .run(JSON.stringify(parsed), chatLog.id);
      }
    })();

    const updatedTx = db.prepare(`
      SELECT t.*, c.name AS category_name, c.icon AS category_icon, c.color AS category_color
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.id = ?
    `).get(txId);

    // Recalculate financial analysis automatically
    let analysis = null;
    try {
      const recalc = recalculateFinancialAnalysis(db, {
        userId,
        referenceDate: updatedTx.occurred_at,
      });
      analysis = recalc.summary;
    } catch (err) {
      console.warn('[TransactionController] Failed to recalculate financial analysis:', err.message);
    }

    return res.status(200).json({
      success: true,
      message: 'Transaksi berhasil diperbarui.',
      transaction: {
        id: updatedTx.id,
        userId: updatedTx.user_id,
        categoryId: updatedTx.category_id,
        category: updatedTx.category_name || finalCategoryName,
        type: updatedTx.type,
        amount: updatedTx.amount,
        note: updatedTx.note,
        occurredAt: updatedTx.occurred_at,
        isConfirmed: Boolean(updatedTx.is_confirmed),
        isGuessedCategory: Boolean(updatedTx.is_guessed),
        confidenceScore: updatedTx.confidence_score,
        aiReasoning: updatedTx.ai_reasoning,
        createdAt: updatedTx.created_at,
      },
      analysis,
    });
  } catch (error) {
    console.error('[TransactionController] Error updating transaction:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memperbarui transaksi.',
      details: error.message,
    });
  }
}

/**
 * Controller to delete a transaction.
 * Synchronizes associated chat_logs status to 'deleted'.
 */
export function deleteTransactionHandler(req, res) {
  try {
    const db = getDatabase();
    const txId = Number(req.params.id);
    const userId = getOrCreateDefaultUser(db, req.body?.userId || req.query?.userId);

    const existingTx = db
      .prepare('SELECT id, note, amount, occurred_at FROM transactions WHERE id = ? AND user_id = ?')
      .get(txId, userId);

    if (!existingTx) {
      return res.status(404).json({
        success: false,
        error: 'Transaksi tidak ditemukan.',
      });
    }

    db.transaction(() => {
      // Mark any chat logs pointing to this transaction as 'deleted'
      db.prepare(`
        UPDATE chat_logs
        SET status = 'deleted'
        WHERE transaction_id = ?
      `).run(txId);

      // Delete the transaction
      db.prepare('DELETE FROM transactions WHERE id = ?').run(txId);
    })();

    // Recalculate financial analysis automatically
    let analysis = null;
    try {
      const recalc = recalculateFinancialAnalysis(db, {
        userId,
        referenceDate: existingTx.occurred_at,
      });
      analysis = recalc.summary;
    } catch (err) {
      console.warn('[TransactionController] Failed to recalculate financial analysis:', err.message);
    }

    return res.status(200).json({
      success: true,
      message: 'Transaksi berhasil dihapus.',
      id: txId,
      analysis,
    });
  } catch (error) {
    console.error('[TransactionController] Error deleting transaction:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menghapus transaksi.',
      details: error.message,
    });
  }
}

/**
 * Controller specifically for updating the category and transaction type of a transaction.
 * Also handles creating a new custom category on-the-fly if requested.
 *
 * Supported endpoints:
 * - PUT /api/transactions/:id/category
 * - PATCH /api/transactions/:id/category
 * - PUT /api/transactions/:id/type
 * - PATCH /api/transactions/:id/type
 * - PUT /api/transactions/:id/category-type
 * - PATCH /api/transactions/:id/category-type
 */
export function updateTransactionCategoryAndTypeHandler(req, res) {
  try {
    const db = getDatabase();
    const txId = Number(req.params.id || req.body?.transactionId);
    const body = req.body || {};
    const userId = getOrCreateDefaultUser(db, body.userId || req.query?.userId);

    const existingTx = db
      .prepare('SELECT * FROM transactions WHERE id = ? AND user_id = ?')
      .get(txId, userId);

    if (!existingTx) {
      return res.status(404).json({
        success: false,
        error: 'Transaksi tidak ditemukan.',
      });
    }

    // Determine type
    let finalType = existingTx.type;
    if (body.type !== undefined) {
      if (!['income', 'expense'].includes(body.type)) {
        return res.status(400).json({
          success: false,
          error: 'Jenis transaksi harus berupa income atau expense.',
        });
      }
      finalType = body.type;
    }

    // Determine category
    let finalCategoryId = existingTx.category_id;
    let finalCategoryName = existingTx.category_name;
    let isCustom = false;

    // Check if user is defining a new custom category on-the-fly
    if (body.isCustom && (body.category || body.categoryName) && !body.categoryId) {
      const customName = String(body.category || body.categoryName).trim();
      let customCat = db.prepare(`
        SELECT id, name, is_default, icon, color FROM categories
        WHERE (user_id IS NULL OR user_id = ?) AND LOWER(name) = LOWER(?) AND type = ?
        LIMIT 1
      `).get(userId, customName, finalType);

      if (!customCat) {
        const ins = db.prepare(`
          INSERT INTO categories (user_id, name, type, is_default, icon, color)
          VALUES (?, ?, ?, 0, ?, ?)
        `).run(userId, customName, finalType, body.icon || 'bookmark_border_rounded', body.color || 'purple');
        finalCategoryId = ins.lastInsertRowid;
        finalCategoryName = customName;
        isCustom = true;
      } else {
        finalCategoryId = customCat.id;
        finalCategoryName = customCat.name;
        isCustom = !Boolean(customCat.is_default);
      }
    } else if (body.categoryId || body.category || body.categoryName || body.type) {
      const resolved = resolveCategory(db, {
        categoryId: body.categoryId,
        categoryName: body.category || body.categoryName,
        type: finalType,
      });

      if (resolved) {
        finalCategoryId = resolved.id;
        finalCategoryName = resolved.name;
        isCustom = !Boolean(resolved.is_default);
      }
    }

    // Optional amount or note edit if provided
    let finalAmount = existingTx.amount;
    if (body.amount !== undefined && body.amount !== null) {
      const num = Number(body.amount);
      if (isNaN(num) || num <= 0) {
        return res.status(400).json({
          success: false,
          error: 'Nominal transaksi harus berupa angka lebih besar dari 0.',
        });
      }
      finalAmount = num;
    }

    let finalNote = existingTx.note;
    if (body.note !== undefined && body.note !== null) {
      const noteStr = String(body.note).trim();
      if (!noteStr) {
        return res.status(400).json({
          success: false,
          error: 'Catatan transaksi tidak boleh kosong.',
        });
      }
      finalNote = noteStr;
    }

    const previousCategory = existingTx.category_name;
    const previousType = existingTx.type;

    db.transaction(() => {
      // Update transaction: is_guessed is reset to 0, confidence set to 1.0
      db.prepare(`
        UPDATE transactions
        SET amount = ?, type = ?, category_id = ?, category_name = ?, note = ?, is_guessed = 0, confidence_score = 1.0, ai_reasoning = 'Kategori diubah/ditentukan oleh pengguna.'
        WHERE id = ?
      `).run(finalAmount, finalType, finalCategoryId, finalCategoryName, finalNote, txId);

      // Keep linked chat_log in sync
      const chatLog = db.prepare('SELECT id, parsed_json FROM chat_logs WHERE transaction_id = ?').get(txId);
      if (chatLog) {
        let parsed = {};
        try {
          parsed = JSON.parse(chatLog.parsed_json || '{}');
        } catch {
          parsed = {};
        }
        parsed.type = finalType;
        parsed.category = finalCategoryName;
        parsed.categoryId = finalCategoryId;
        parsed.isCustomCategory = isCustom;
        parsed.confidenceScore = 1.0;
        parsed.userCorrection = {
          previousCategory,
          newCategory: finalCategoryName,
          previousType,
          newType: finalType,
          correctedAt: new Date().toISOString(),
        };

        db.prepare('UPDATE chat_logs SET parsed_json = ? WHERE id = ?')
          .run(JSON.stringify(parsed), chatLog.id);
      }
    })();

    const updatedTx = db.prepare(`
      SELECT t.*, c.icon AS category_icon, c.color AS category_color, c.is_default
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.id = ?
    `).get(txId);

    // Recalculate financial analysis automatically
    let analysis = null;
    try {
      const recalc = recalculateFinancialAnalysis(db, {
        userId,
        referenceDate: updatedTx.occurred_at,
      });
      analysis = recalc.summary;
    } catch (err) {
      console.warn('[TransactionController] Failed to recalculate financial analysis:', err.message);
    }

    return res.status(200).json({
      success: true,
      message: 'Kategori dan jenis transaksi berhasil diperbarui.',
      transaction: {
        id: updatedTx.id,
        userId: updatedTx.user_id,
        categoryId: updatedTx.category_id,
        category: updatedTx.category_name,
        categoryIcon: updatedTx.category_icon || 'bookmark_border_rounded',
        categoryColor: updatedTx.category_color || 'purple',
        type: updatedTx.type,
        amount: updatedTx.amount,
        note: updatedTx.note,
        occurredAt: updatedTx.occurred_at,
        isConfirmed: Boolean(updatedTx.is_confirmed),
        isGuessedCategory: false,
        confidenceScore: 1.0,
        aiReasoning: updatedTx.ai_reasoning,
        isCustomCategory: isCustom || !Boolean(updatedTx.is_default),
        createdAt: updatedTx.created_at,
      },
      analysis,
      previous: {
        category: previousCategory,
        categoryId: existingTx.category_id,
        type: previousType,
      },
    });
  } catch (error) {
    console.error('[TransactionController] Error updating category and type:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memperbarui kategori dan jenis transaksi.',
      details: error.message,
    });
  }
}


