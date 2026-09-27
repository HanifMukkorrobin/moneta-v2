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

/**
 * Helper to parse JSON safely.
 */
function safeJsonParse(str) {
  if (!str) return null;
  try {
    return JSON.parse(str);
  } catch {
    return null;
  }
}

/**
 * Helper to format a chat log row into a clean response object.
 */
function formatChatLogRow(r) {
  const parsed = safeJsonParse(r.parsed_json);
  return {
    id: r.id,
    userId: r.user_id,
    message: r.message,
    status: r.status,
    parsedJson: parsed,
    transaction: r.tx_id ? {
      id: r.tx_id,
      amount: r.tx_amount,
      type: r.tx_type,
      note: r.tx_note,
      occurredAt: r.tx_occurred_at,
      isConfirmed: Boolean(r.tx_is_confirmed),
      categoryId: r.category_id,
      category: r.category_name || (parsed?.category || 'Lainnya'),
      categoryIcon: r.category_icon,
      categoryColor: r.category_color,
    } : null,
    createdAt: r.created_at,
  };
}

/**
 * Controller to fetch chat history list with search, filtering, and pagination.
 */
export function getChatHistoryHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const { status, search, limit = 50, offset = 0 } = req.query;

    let baseQuery = `
      FROM chat_logs cl
      LEFT JOIN transactions t ON cl.transaction_id = t.id
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE cl.user_id = ?
    `;
    const params = [userId];

    if (status && ['pending', 'confirmed', 'deleted', 'failed'].includes(status.toLowerCase())) {
      baseQuery += ' AND cl.status = ?';
      params.push(status.toLowerCase());
    }

    if (search && typeof search === 'string' && search.trim() !== '') {
      baseQuery += ' AND (cl.message LIKE ? OR t.note LIKE ?)';
      const searchParam = `%${search.trim()}%`;
      params.push(searchParam, searchParam);
    }

    // Get total count
    const countRow = db.prepare(`SELECT COUNT(*) AS total ${baseQuery}`).get(...params);
    const total = countRow ? countRow.total : 0;

    // Get paginated rows
    const numLimit = Math.max(1, Math.min(200, Number(limit) || 50));
    const numOffset = Math.max(0, Number(offset) || 0);

    const selectQuery = `
      SELECT 
        cl.id,
        cl.user_id,
        cl.message,
        cl.parsed_json,
        cl.transaction_id,
        cl.status,
        cl.created_at,
        t.id AS tx_id,
        t.amount AS tx_amount,
        t.type AS tx_type,
        t.note AS tx_note,
        t.occurred_at AS tx_occurred_at,
        t.is_confirmed AS tx_is_confirmed,
        c.id AS category_id,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color
      ${baseQuery}
      ORDER BY cl.created_at DESC, cl.id DESC
      LIMIT ? OFFSET ?
    `;

    const rows = db.prepare(selectQuery).all(...params, numLimit, numOffset);

    return res.status(200).json({
      success: true,
      total,
      limit: numLimit,
      offset: numOffset,
      chatLogs: rows.map(formatChatLogRow),
    });
  } catch (error) {
    console.error('[ChatController] Error fetching chat history:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat riwayat percakapan chat.',
      details: error.message,
    });
  }
}

/**
 * Controller to fetch single chat log by ID.
 */
export function getChatLogByIdHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const logId = Number(req.params.id);

    const query = `
      SELECT 
        cl.id,
        cl.user_id,
        cl.message,
        cl.parsed_json,
        cl.transaction_id,
        cl.status,
        cl.created_at,
        t.id AS tx_id,
        t.amount AS tx_amount,
        t.type AS tx_type,
        t.note AS tx_note,
        t.occurred_at AS tx_occurred_at,
        t.is_confirmed AS tx_is_confirmed,
        c.id AS category_id,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color
      FROM chat_logs cl
      LEFT JOIN transactions t ON cl.transaction_id = t.id
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE cl.id = ? AND cl.user_id = ?
    `;

    const row = db.prepare(query).get(logId, userId);

    if (!row) {
      return res.status(404).json({
        success: false,
        error: 'Riwayat percakapan tidak ditemukan.',
      });
    }

    return res.status(200).json({
      success: true,
      chatLog: formatChatLogRow(row),
    });
  } catch (error) {
    console.error('[ChatController] Error fetching chat log by ID:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat detail riwayat percakapan.',
      details: error.message,
    });
  }
}

