import { getDatabase } from '../config/database.js';
import { defaultAiParser } from '../services/aiParserService.js';

/**
 * Ensures a default user exists in the database and returns its ID.
 */
export function getOrCreateDefaultUser(db, userId) {
  if (userId) {
    const existing = db.prepare('SELECT id FROM users WHERE id = ?').get(userId);
    if (existing) return existing.id;
  }

  // Find first user or create default user
  let user = db.prepare('SELECT id FROM users ORDER BY id ASC LIMIT 1').get();
  if (!user) {
    const res = db
      .prepare(`
        INSERT INTO users (email, display_name, currency)
        VALUES ('user@moneta.local', 'Pengguna Moneta', 'IDR')
      `)
      .run();
    return res.lastInsertRowid;
  }
  return user.id;
}

/**
 * Retrieves category names available for a user (defaults + user's custom categories).
 */
export function getUserCategoryNames(db, userId) {
  const rows = db
    .prepare(`
      SELECT name FROM categories
      WHERE user_id IS NULL OR user_id = ?
    `)
    .all(userId);
  return rows.map((r) => r.name);
}

/**
 * Finds or matches category by name in database.
 */
export function findCategoryByName(db, categoryName, type) {
  return db
    .prepare(`
      SELECT id, name, type FROM categories
      WHERE LOWER(name) = LOWER(?) AND type = ?
      LIMIT 1
    `)
    .get(categoryName, type);
}

/**
 * Controller to handle POST /chat and POST /api/chat/parse
 */
export async function parseChatHandler(req, res, customParser) {
  try {
    const parser = (customParser && typeof customParser.parseTransaction === 'function')
      ? customParser
      : defaultAiParser;
    const { message, userId: reqUserId } = req.body;

    if (!message || typeof message !== 'string' || message.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'Pesan chat wajib diisi.',
      });
    }

    const trimmed = message.trim();
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, reqUserId);

    // 1. Fetch available categories
    const availableCategories = getUserCategoryNames(db, userId);

    // 2. Parse text via 9Router AI Parser Service
    const parseResult = await parser.parseTransaction(trimmed, { availableCategories });

    // 3. Handle parsing failure (AI could not recognize transaction)
    if (!parseResult.success) {
      // Record failed chat log for traceability
      const logRes = db
        .prepare(`
          INSERT INTO chat_logs (user_id, message, parsed_json, status)
          VALUES (?, ?, ?, 'failed')
        `)
        .run(userId, trimmed, JSON.stringify({ error: parseResult.error }));

      return res.status(200).json({
        success: false,
        chatLogId: logRes.lastInsertRowid,
        error: parseResult.error || 'AI belum dapat membaca format transaksi dari pesanmu.',
        fallbackManual: true,
        rawText: trimmed,
      });
    }

    // 4. Match category ID in database (fallback to 'Lainnya' if not found)
    let categoryRecord = findCategoryByName(db, parseResult.category, parseResult.type);
    if (!categoryRecord) {
      categoryRecord = findCategoryByName(db, 'Lainnya', parseResult.type);
    }

    const categoryId = categoryRecord ? categoryRecord.id : null;
    const finalCategoryName = categoryRecord ? categoryRecord.name : parseResult.category;

    // 5. Create pending transaction and chat_log inside a database transaction
    let transactionId = null;
    let chatLogId = null;

    const dbTx = db.transaction(() => {
      // Create pending unconfirmed transaction
      const txRes = db
        .prepare(`
          INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
          VALUES (?, ?, ?, ?, ?, ?, 0)
        `)
        .run(
          userId,
          categoryId,
          parseResult.type,
          parseResult.amount,
          parseResult.note,
          parseResult.occurredAt || new Date().toISOString()
        );
      transactionId = txRes.lastInsertRowid;

      // Store chat log linking to the transaction with status 'pending'
      const parsedJsonString = JSON.stringify({
        amount: parseResult.amount,
        type: parseResult.type,
        typeReasoning: parseResult.typeReasoning,
        category: finalCategoryName,
        categoryId,
        confidence: parseResult.confidence,
        reasoning: parseResult.reasoning,
        note: parseResult.note,
      });

      const logRes = db
        .prepare(`
          INSERT INTO chat_logs (user_id, message, parsed_json, transaction_id, status)
          VALUES (?, ?, ?, ?, 'pending')
        `)
        .run(userId, trimmed, parsedJsonString, transactionId);
      chatLogId = logRes.lastInsertRowid;
    });

    dbTx();

    return res.status(200).json({
      success: true,
      chatLogId,
      transaction: {
        id: transactionId,
        note: parseResult.note,
        amount: parseResult.amount,
        type: parseResult.type,
        typeReasoning: parseResult.typeReasoning,
        categoryId,
        category: finalCategoryName,
        confidenceScore: parseResult.confidence,
        aiReasoning: parseResult.reasoning,
        isConfirmed: false,
        occurredAt: parseResult.occurredAt,
      },
      message: 'AI berhasil mengenali transaksi. Konfirmasi untuk mencatat:',
    });
  } catch (error) {
    console.error('[ChatController] Error parsing chat message:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan pada server saat memproses catatan chat.',
      details: error.message,
    });
  }
}
