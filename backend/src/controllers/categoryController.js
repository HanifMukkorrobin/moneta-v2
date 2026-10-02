import { getDatabase } from '../config/database.js';
import { defaultAiParser } from '../services/aiParserService.js';
import { categorySuggestionService } from '../services/categorySuggestionService.js';
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

    const reqUserId = req.userId || body.userId || query.userId;
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
    const {
      type = 'expense',
      limit = 5,
      days,
      q,
      text,
      sortBy = 'frequency',
      timeOfDay,
      includeUnused = 'true',
    } = req.query;

    const queryText = q || text;
    let suggestions;

    if (queryText && String(queryText).trim() !== '') {
      suggestions = categorySuggestionService.getSuggestionsForText(db, userId, String(queryText).trim(), {
        type: type && type !== 'all' ? type : null,
        limit,
      });
    } else {
      suggestions = categorySuggestionService.getFrequentCategories(db, userId, {
        type: type && type !== 'all' ? type : null,
        limit,
        days: days ? Number(days) : null,
        sortBy,
        includeUnused: includeUnused !== 'false',
      });
    }

    let timeContext = null;
    if (timeOfDay || req.query.includeTimeContext === 'true') {
      timeContext = categorySuggestionService.getSuggestionsByTimeOfDay(db, userId, {
        type: type && type !== 'all' ? type : 'expense',
        timeSlot: timeOfDay,
      });
    }

    return res.status(200).json({
      success: true,
      type,
      total: suggestions.length,
      suggestions,
      timeContext: timeContext || undefined,
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

/**
 * Controller to provide contextual category suggestions for a given input note/sentence.
 *
 * Supported endpoints:
 * - POST /api/categories/suggestions
 * - GET /api/categories/contextual-suggestions
 */
export function getContextualSuggestionsHandler(req, res) {
  try {
    const db = getDatabase();
    const body = req.body || {};
    const userId = getOrCreateDefaultUser(db, req.query?.userId || body.userId);
    const text = body.text || body.note || req.query?.text || req.query?.q || '';
    const type = body.type || req.query?.type || null;
    const limit = body.limit || req.query?.limit || 5;

    const suggestions = categorySuggestionService.getSuggestionsForText(db, userId, text, {
      type: type && type !== 'all' ? type : null,
      limit,
    });

    return res.status(200).json({
      success: true,
      query: text,
      type,
      total: suggestions.length,
      suggestions,
    });
  } catch (error) {
    console.error('[CategoryController] Error generating contextual category suggestions:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menghasilkan saran kategori kontekstual.',
      details: error.message,
    });
  }
}

/**
 * Controller to retrieve overall category usage statistics for a user.
 *
 * Supported endpoints:
 * - GET /api/categories/stats
 */
export function getCategoryStatsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const stats = categorySuggestionService.getCategoryStats(db, userId);

    return res.status(200).json({
      success: true,
      stats,
    });
  } catch (error) {
    console.error('[CategoryController] Error fetching category stats:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat statistik kategori.',
      details: error.message,
    });
  }
}

/**
 * Controller to create a custom expense (or income) category.
 *
 * Supported endpoints:
 * - POST /api/categories/custom
 * - POST /categories/custom
 * - POST /api/categories
 * - POST /categories
 */
export function createCustomCategoryHandler(req, res) {
  try {
    const db = getDatabase();
    const body = req.body || {};
    const {
      name,
      type = 'expense',
      icon = 'bookmark_border_rounded',
      color = 'purple',
      userId: reqUserId,
    } = body;

    // Validate name
    if (!name || typeof name !== 'string' || name.trim() === '') {
      return res.status(400).json({
        success: false,
        error: 'Nama kategori wajib diisi.',
      });
    }

    const trimmedName = name.trim();

    // Validate type
    if (type !== 'expense' && type !== 'income') {
      return res.status(400).json({
        success: false,
        error: 'Jenis kategori harus berupa "expense" (pengeluaran) atau "income" (pemasukan).',
      });
    }

    const userId = getOrCreateDefaultUser(db, reqUserId);

    // Check duplicate name for this user & type
    const existing = db.prepare(`
      SELECT id, name FROM categories
      WHERE (user_id IS NULL OR user_id = ?)
        AND LOWER(name) = LOWER(?)
        AND type = ?
      LIMIT 1
    `).get(userId, trimmedName, type);

    if (existing) {
      return res.status(400).json({
        success: false,
        error: 'Kategori dengan nama ini sudah ada.',
      });
    }

    // Insert custom category
    const result = db.prepare(`
      INSERT INTO categories (user_id, name, type, is_default, icon, color)
      VALUES (?, ?, ?, 0, ?, ?)
    `).run(userId, trimmedName, type, icon, color);

    const insertedId = result.lastInsertRowid;
    const newCategory = db.prepare('SELECT * FROM categories WHERE id = ?').get(insertedId);

    const formattedCategory = {
      id: newCategory.id,
      userId: newCategory.user_id,
      name: newCategory.name,
      type: newCategory.type,
      isDefault: false,
      isCustom: true,
      icon: newCategory.icon,
      color: newCategory.color,
      createdAt: newCategory.created_at,
    };

    return res.status(201).json({
      success: true,
      message: `Kategori ${type === 'expense' ? 'pengeluaran' : 'pemasukan'} kustom "${trimmedName}" berhasil dibuat.`,
      category: formattedCategory,
    });
  } catch (error) {
    console.error('[CategoryController] Error creating custom category:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan pada server saat membuat kategori kustom.',
      details: error.message,
    });
  }
}

/**
 * Controller to list only custom categories for a user.
 *
 * Supported endpoints:
 * - GET /api/categories/custom
 * - GET /categories/custom
 */
export function listCustomCategoriesHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = getOrCreateDefaultUser(db, req.query?.userId);
    const { type } = req.query;

    let query = `
      SELECT id, user_id, name, type, is_default, icon, color, created_at
      FROM categories
      WHERE user_id = ? AND is_default = 0
    `;
    const params = [userId];

    if (type && (type === 'expense' || type === 'income')) {
      query += ' AND type = ?';
      params.push(type);
    }

    query += ' ORDER BY created_at DESC, name ASC';

    const rows = db.prepare(query).all(...params);

    const formatted = rows.map((r) => ({
      id: r.id,
      userId: r.user_id,
      name: r.name,
      type: r.type,
      isDefault: false,
      isCustom: true,
      icon: r.icon,
      color: r.color,
      createdAt: r.created_at,
    }));

    return res.status(200).json({
      success: true,
      total: formatted.length,
      categories: formatted,
    });
  } catch (error) {
    console.error('[CategoryController] Error listing custom categories:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat daftar kategori kustom.',
      details: error.message,
    });
  }
}

/**
 * Controller to get single category by ID.
 *
 * Supported endpoints:
 * - GET /api/categories/:id
 * - GET /categories/:id
 */
export function getCategoryByIdHandler(req, res) {
  try {
    const db = getDatabase();
    const catId = Number(req.params.id);

    const row = db.prepare('SELECT * FROM categories WHERE id = ?').get(catId);
    if (!row) {
      return res.status(404).json({
        success: false,
        error: 'Kategori tidak ditemukan.',
      });
    }

    return res.status(200).json({
      success: true,
      category: {
        id: row.id,
        userId: row.user_id,
        name: row.name,
        type: row.type,
        isDefault: Boolean(row.is_default),
        isCustom: !Boolean(row.is_default),
        icon: row.icon,
        color: row.color,
        createdAt: row.created_at,
      },
    });
  } catch (error) {
    console.error('[CategoryController] Error getting category by ID:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memuat detail kategori.',
      details: error.message,
    });
  }
}

/**
 * Controller to update a custom category.
 *
 * Supported endpoints:
 * - PUT /api/categories/:id
 * - PATCH /api/categories/:id
 * - PUT /api/categories/custom/:id
 */
export function updateCustomCategoryHandler(req, res) {
  try {
    const db = getDatabase();
    const catId = Number(req.params.id);
    const body = req.body || {};
    const userId = getOrCreateDefaultUser(db, body.userId || req.query?.userId);

    const category = db.prepare('SELECT * FROM categories WHERE id = ?').get(catId);
    if (!category) {
      return res.status(404).json({
        success: false,
        error: 'Kategori tidak ditemukan.',
      });
    }

    // Default categories cannot be modified
    if (category.is_default === 1 || category.user_id === null) {
      return res.status(400).json({
        success: false,
        error: 'Kategori bawaan sistem tidak dapat diubah.',
      });
    }

    const newName = body.name !== undefined ? String(body.name).trim() : category.name;
    const newIcon = body.icon !== undefined ? body.icon : category.icon;
    const newColor = body.color !== undefined ? body.color : category.color;
    const newType = body.type !== undefined ? body.type : category.type;

    if (!newName) {
      return res.status(400).json({
        success: false,
        error: 'Nama kategori tidak boleh kosong.',
      });
    }

    if (newType !== 'expense' && newType !== 'income') {
      return res.status(400).json({
        success: false,
        error: 'Jenis kategori harus berupa "expense" atau "income".',
      });
    }

    const targetUserId = category.user_id !== null ? category.user_id : userId;

    // Check collision with another category
    const collision = db.prepare(`
      SELECT id FROM categories
      WHERE id != ? AND (user_id IS NULL OR user_id = ?)
        AND LOWER(name) = LOWER(?) AND type = ?
      LIMIT 1
    `).get(catId, targetUserId, newName, newType);

    if (collision) {
      return res.status(400).json({
        success: false,
        error: 'Nama kategori sudah digunakan.',
      });
    }

    try {
      db.transaction(() => {
        // Update category
        db.prepare(`
          UPDATE categories
          SET name = ?, type = ?, icon = ?, color = ?
          WHERE id = ?
        `).run(newName, newType, newIcon, newColor, catId);

        // Keep transaction category_name in sync
        db.prepare(`
          UPDATE transactions
          SET category_name = ?
          WHERE category_id = ?
        `).run(newName, catId);
      })();
    } catch (err) {
      if (err.code === 'SQLITE_CONSTRAINT_UNIQUE' || String(err.message).includes('UNIQUE')) {
        return res.status(400).json({
          success: false,
          error: 'Nama kategori sudah digunakan.',
        });
      }
      throw err;
    }

    const updated = db.prepare('SELECT * FROM categories WHERE id = ?').get(catId);

    return res.status(200).json({
      success: true,
      message: `Kategori berhasil diubah menjadi "${newName}".`,
      category: {
        id: updated.id,
        userId: updated.user_id,
        name: updated.name,
        type: updated.type,
        isDefault: false,
        isCustom: true,
        icon: updated.icon,
        color: updated.color,
        createdAt: updated.created_at,
      },
    });
  } catch (error) {
    console.error('[CategoryController] Error updating custom category:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat memperbarui kategori.',
      details: error.message,
    });
  }
}

/**
 * Controller to delete a custom category.
 * Reassigns linked transactions to 'Lainnya' so transaction history remains intact.
 *
 * Supported endpoints:
 * - DELETE /api/categories/:id
 * - DELETE /api/categories/custom/:id
 */
export function deleteCustomCategoryHandler(req, res) {
  try {
    const db = getDatabase();
    const catId = Number(req.params.id);
    const userId = getOrCreateDefaultUser(db, req.body?.userId || req.query?.userId);

    const category = db.prepare('SELECT * FROM categories WHERE id = ?').get(catId);
    if (!category) {
      return res.status(404).json({
        success: false,
        error: 'Kategori tidak ditemukan.',
      });
    }

    // Default categories cannot be deleted
    if (category.is_default === 1 || category.user_id === null) {
      return res.status(400).json({
        success: false,
        error: 'Kategori bawaan sistem tidak dapat dihapus.',
      });
    }

    // Find fallback 'Lainnya' category
    const fallbackCat = db.prepare(`
      SELECT id, name FROM categories
      WHERE name = 'Lainnya' AND type = ? AND is_default = 1
      LIMIT 1
    `).get(category.type);

    const fallbackId = fallbackCat ? fallbackCat.id : null;

    let reassignedCount = 0;

    db.transaction(() => {
      // Reassign transactions
      const updateRes = db.prepare(`
        UPDATE transactions
        SET category_id = ?, category_name = 'Lainnya'
        WHERE category_id = ?
      `).run(fallbackId, catId);

      reassignedCount = updateRes.changes;

      // Delete the category
      db.prepare('DELETE FROM categories WHERE id = ?').run(catId);
    })();

    return res.status(200).json({
      success: true,
      message: `Kategori "${category.name}" berhasil dihapus.`,
      id: catId,
      reassignedTransactionsCount: reassignedCount,
      fallbackCategory: fallbackCat ? fallbackCat.name : 'Lainnya',
    });
  } catch (error) {
    console.error('[CategoryController] Error deleting custom category:', error);
    return res.status(500).json({
      success: false,
      error: 'Terjadi kesalahan saat menghapus kategori.',
      details: error.message,
    });
  }
}

