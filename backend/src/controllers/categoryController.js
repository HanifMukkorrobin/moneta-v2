import { getDatabase } from '../config/database.js';
import { defaultAiParser } from '../services/aiParserService.js';
import { getOrCreateDefaultUser } from './chatController.js';

/**
 * Controller to handle classification of category and transaction type (income vs expense).
 *
 * Supported endpoints:
 * - POST /api/categories/classify
 * - GET /api/categories/classify?text=...
 * - POST /categories/classify
 * - POST /api/classify
 * - POST /api/transactions/classify
 */
export async function classifyCategoryAndTypeHandler(req, res, customParser) {
  try {
    const parser = (customParser && typeof customParser.classify === 'function')
      ? customParser
      : defaultAiParser;

    const db = getDatabase();
    const body = req.body || {};
    const query = req.query || {};

    const reqUserId = body.userId || query.userId;
    const userId = getOrCreateDefaultUser(db, reqUserId);

    // Support batch classification if `items` or `texts` is an array
    const batchItems = Array.isArray(body.items) ? body.items : (Array.isArray(body.texts) ? body.texts : null);
    if (batchItems) {
      if (batchItems.length === 0) {
        return res.status(400).json({
          success: false,
          error: 'Daftar teks transaksi tidak boleh kosong.',
        });
      }

      // Fetch user categories once for batch
      const userCategories = db.prepare(`
        SELECT id, name, type, icon, color, is_default
        FROM categories
        WHERE user_id IS NULL OR user_id = ?
      `).all(userId);

      const results = [];
      for (const item of batchItems) {
        const itemText = (typeof item === 'string' ? item : (item.text || item.message || item.note || '')).trim();
        if (!itemText) continue;

        const forcedType = typeof item === 'object' ? item.type : null;
        const result = await parser.classify(itemText, {
          forcedType,
          availableCategories: userCategories,
        });

        // Match with DB category
        const catRow = userCategories.find(
          (c) => c.name.toLowerCase() === (result.category || '').toLowerCase() && (c.type === result.type || !c.type)
        ) || userCategories.find((c) => c.name === 'Lainnya' && c.type === result.type);

        results.push({
          rawSentence: itemText,
          type: result.type,
          typeReasoning: result.typeReasoning,
          category: catRow ? catRow.name : (result.category || 'Lainnya'),
          categoryId: catRow ? catRow.id : null,
          categoryIcon: catRow ? catRow.icon : null,
          categoryColor: catRow ? catRow.color : null,
          confidenceScore: result.confidenceScore,
          confidenceLevel: result.confidenceLevel,
          aiReasoning: result.aiReasoning,
          isGuessedCategory: true,
          isCustomCategory: catRow ? Boolean(!catRow.is_default) : Boolean(result.isCustomCategory),
          alternativeCategories: result.alternativeCategories,
          amount: result.amount || (typeof item === 'object' ? item.amount : null),
        });
      }

      return res.status(200).json({
        success: true,
        total: results.length,
        classifications: results,
      });
    }

    // Support classifying existing transaction by ID
    const transactionId = body.transactionId || query.transactionId;
    let existingTx = null;
    if (transactionId) {
      existingTx = db.prepare(`
        SELECT t.*, c.name AS current_category_name
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        WHERE t.id = ? AND t.user_id = ?
      `).get(transactionId, userId);

      if (!existingTx) {
        return res.status(404).json({
          success: false,
          error: 'Catatan transaksi tidak ditemukan.',
        });
      }
    }

    // Extract text from request body or query or existing transaction note
    const rawText = body.text || body.message || body.sentence || body.note || query.text || query.message || query.q || (existingTx ? existingTx.note : '');
    const forcedType = body.type || query.type || (existingTx ? existingTx.type : null);
    const reqAmount = body.amount !== undefined ? Number(body.amount) : (query.amount !== undefined ? Number(query.amount) : (existingTx ? existingTx.amount : null));

    if (!rawText || typeof rawText !== 'string' || rawText.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'Teks atau kalimat transaksi wajib diisi.',
      });
    }

    const trimmed = rawText.trim();

    // 1. Fetch available categories for user
    const userCategories = db.prepare(`
      SELECT id, name, type, icon, color, is_default
      FROM categories
      WHERE user_id IS NULL OR user_id = ?
    `).all(userId);

    // 2. Perform AI / heuristic classification
    const result = await parser.classify(trimmed, {
      forcedType,
      availableCategories: userCategories,
    });

    if (!result.success) {
      return res.status(200).json({
        success: false,
        error: result.error || 'Kalimat bukan merupakan catatan transaksi keuangan.',
        fallbackManual: true,
        rawSentence: trimmed,
      });
    }

    // 3. Match category in database
    let categoryRecord = null;
    if (result.category && result.category !== 'Belum Dikategorikan') {
      categoryRecord = userCategories.find(
        (c) => c.name.toLowerCase() === result.category.toLowerCase() && (c.type === result.type || !c.type)
      );

      if (!categoryRecord) {
        categoryRecord = userCategories.find((c) => c.name === 'Lainnya' && c.type === result.type);
      }
    }

    const isBelumKategori = result.category === 'Belum Dikategorikan';
    const categoryId = categoryRecord ? categoryRecord.id : null;
    const finalCategoryName = isBelumKategori
      ? 'Belum Dikategorikan'
      : (categoryRecord ? categoryRecord.name : (result.category || 'Lainnya'));
    const categoryIcon = categoryRecord ? categoryRecord.icon : (isBelumKategori ? 'help_outline_rounded' : null);
    const categoryColor = categoryRecord ? categoryRecord.color : (isBelumKategori ? 'grey' : null);
    const isCustomCategory = categoryRecord ? Boolean(!categoryRecord.is_default && categoryRecord.user_id !== null) : Boolean(result.isCustomCategory);

    // 4. If transactionId provided and update/apply requested, update database record
    const shouldApply = Boolean(body.apply === true || body.update === true);
    if (existingTx && shouldApply) {
      db.prepare(`
        UPDATE transactions
        SET category_id = ?, category_name = ?, type = ?, confidence_score = ?, ai_reasoning = ?, is_guessed = 1
        WHERE id = ?
      `).run(categoryId, finalCategoryName, result.type, result.confidenceScore, result.aiReasoning, existingTx.id);
    }

    const payload = {
      rawSentence: trimmed,
      type: result.type,
      typeReasoning: result.typeReasoning,
      category: finalCategoryName,
      categoryId,
      categoryIcon,
      categoryColor,
      confidenceScore: result.confidenceScore,
      confidenceLevel: result.confidenceLevel,
      aiReasoning: result.aiReasoning,
      isGuessedCategory: true,
      isCustomCategory,
      alternativeCategories: result.alternativeCategories,
      amount: reqAmount !== null && !isNaN(reqAmount) ? reqAmount : (result.amount || null),
      occurredAt: new Date().toISOString(),
      transactionId: existingTx ? existingTx.id : undefined,
      applied: shouldApply,
    };

    return res.status(200).json({
      success: true,
      ...payload,
      data: payload,
    });
  } catch (error) {
    console.error('[CategoryController] Error classifying category & type:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan pada server saat mengklasifikasikan kategori.',
      details: error.message,
    });
  }
}

/**
 * Controller to list all categories (default and custom) with filtering by type.
 *
 * Supported endpoints:
 * - GET /api/categories
 * - GET /categories
 */
export function listCategoriesHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const { type } = req.query;

    let query = `
      SELECT id, user_id, name, type, is_default, icon, color, created_at
      FROM categories
      WHERE (user_id IS NULL OR user_id = ?)
    `;
    const params = [userId];

    if (type && (type === 'expense' || type === 'income')) {
      query += ' AND type = ?';
      params.push(type);
    }

    query += ' ORDER BY is_default DESC, name ASC';

    const rows = db.prepare(query).all(...params);

    const formatted = rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
      name: r.name,
      type: r.type,
      isDefault: Boolean(r.is_default),
      isCustom: !Boolean(r.is_default),
      icon: r.icon,
      color: r.color,
      createdAt: r.created_at,
    }));

    return res.status(200).json({
      success: true,
      total: formatted.length,
      categories: formatted,
      defaultCategories: formatted.filter((c) => c.isDefault),
      customCategories: formatted.filter((c) => c.isCustom),
    });
  } catch (error) {
    console.error('[CategoryController] Error listing categories:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat daftar kategori.',
      details: error.message,
    });
  }
}

/**
 * Controller to retrieve suggested/frequently used categories based on history.
 *
 * Supported endpoints:
 * - GET /api/categories/frequent
 * - GET /api/categories/suggestions
 */
export function getCategorySuggestionsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const { type = 'expense', limit = 5 } = req.query;

    const numLimit = Math.max(1, Math.min(20, Number(limit) || 5));

    // Get categories with transaction usage count
    const rows = db.prepare(`
      SELECT 
        c.id, c.name, c.type, c.icon, c.color, c.is_default,
        COUNT(t.id) AS usage_count
      FROM categories c
      LEFT JOIN transactions t ON (t.category_id = c.id OR LOWER(t.category_name) = LOWER(c.name)) AND t.user_id = ?
      WHERE (c.user_id IS NULL OR c.user_id = ?) AND (c.type = ? OR ? IS NULL)
      GROUP BY c.id
      ORDER BY usage_count DESC, c.is_default DESC, c.name ASC
      LIMIT ?
    `).all(userId, userId, type, type, numLimit);

    const suggestions = rows.map((r) => ({
      id: r.id,
      name: r.name,
      type: r.type,
      icon: r.icon,
      color: r.color,
      isDefault: Boolean(r.is_default),
      isCustom: !Boolean(r.is_default),
      usageCount: r.usage_count,
    }));

    return res.status(200).json({
      success: true,
      type,
      suggestions,
    });
  } catch (error) {
    console.error('[CategoryController] Error fetching category suggestions:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat saran kategori.',
      details: error.message,
    });
  }
}
