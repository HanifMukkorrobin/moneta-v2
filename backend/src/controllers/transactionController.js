import { getDatabase } from '../config/database.js';
import { getOrCreateDefaultUser, findCategoryByName } from './chatController.js';

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
 * Controller to list transactions with optional filters.
 */
export function listTransactionsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const type = req.query?.type;
    const isConfirmed = req.query?.isConfirmed;

    let query = `
      SELECT t.*, c.name AS category_name, c.icon AS category_icon, c.color AS category_color
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.user_id = ?
    `;
    const params = [userId];

    if (type && ['income', 'expense'].includes(type)) {
      query += ' AND t.type = ?';
      params.push(type);
    }

    if (isConfirmed !== undefined) {
      query += ' AND t.is_confirmed = ?';
      params.push(isConfirmed === 'true' || isConfirmed === '1' ? 1 : 0);
    }

    query += ' ORDER BY t.occurred_at DESC, t.id DESC';

    const rows = db.prepare(query).all(...params);

    const formatted = rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
      categoryId: r.category_id,
      category: r.category_name || 'Lainnya',
      type: r.type,
      amount: r.amount,
      note: r.note,
      occurredAt: r.occurred_at,
      isConfirmed: Boolean(r.is_confirmed),
      createdAt: r.created_at,
    }));

    return res.status(200).json({
      success: true,
      transactions: formatted,
      total: formatted.length,
    });
  } catch (error) {
    console.error('[TransactionController] Error listing transactions:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat daftar transaksi.',
    });
  }
}

/**
 * Controller to get a single transaction by ID.
 */
export function getTransactionByIdHandler(req, res) {
  try {
    const db = getDatabase();
    const txId = Number(req.params.id);
    const userId = getOrCreateDefaultUser(db, req.query?.userId);

    const tx = db.prepare(`
      SELECT t.*, c.name AS category_name, c.icon AS category_icon, c.color AS category_color
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.id = ? AND t.user_id = ?
    `).get(txId, userId);

    if (!tx) {
      return res.status(404).json({
        success: false,
        error: 'Transaksi tidak ditemukan.',
      });
    }

    return res.status(200).json({
      success: true,
      transaction: {
        id: tx.id,
        userId: tx.user_id,
        categoryId: tx.category_id,
        category: tx.category_name || 'Lainnya',
        type: tx.type,
        amount: tx.amount,
        note: tx.note,
        occurredAt: tx.occurred_at,
        isConfirmed: Boolean(tx.is_confirmed),
        createdAt: tx.created_at,
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat detail transaksi.',
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
      .prepare('SELECT id, note, amount FROM transactions WHERE id = ? AND user_id = ?')
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

    return res.status(200).json({
      success: true,
      message: 'Transaksi berhasil dihapus.',
      id: txId,
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

