/**
 * CategorySuggestionService
 *
 * Provides frequency-based and contextual category recommendations for Moneta v2.
 * Calculates usage metrics, historical transaction patterns, token-based note matching,
 * time-of-day contextual suggestions, and personalized alternative category lists.
 */
export const DEFAULT_CATEGORY_KEYWORDS = {
  'Makan & Minuman': ['makan', 'kopi', 'minum', 'sarapan', 'lunch', 'dinner', 'resto', 'ayam', 'nasi', 'jajan', 'martabak', 'roti', 'bakso', 'mie', 'sate', 'snack', 'camilan', 'cemilan', 'cafe', 'kafe', 'warung', 'kuliner', 'boba', 'burger', 'pizza', 'gofood', 'grabfood', 'shopeefood'],
  'Transportasi': ['bensin', 'pertamax', 'pertalite', 'shell', 'ojol', 'grab', 'gojek', 'maxim', 'tol', 'parkir', 'transport', 'kereta', 'krl', 'mrt', 'motor', 'mobil', 'servis'],
  'Belanja': ['belanja', 'baju', 'sepatu', 'tas', 'mall', 'tokopedia', 'shopee', 'lazada', 'minimarket', 'indomaret', 'alfamart', 'buku', 'gramedia', 'jaket', 'celana', 'kaos'],
  'Hiburan': ['nonton', 'bioskop', 'game', 'steam', 'hiburan', 'konser', 'karaoke', 'netflix', 'spotify', 'disney'],
  'Tagihan & Utilitas': ['tagihan', 'utilitas', 'listrik', 'pln', 'air', 'pdam', 'wifi', 'internet', 'indihome', 'pulsa', 'kuota', 'bpjs', 'iuran'],
  'Hutang & Paylater': ['cicilan', 'hutang', 'paylater', 'spaylater', 'kredivo', 'pinjaman', 'angsuran'],
  'Kebutuhan Rumah': ['sabun', 'deterjen', 'perabot', 'galon', 'gas', 'rumah', 'lpg', 'kebersihan'],
  'Kesehatan': ['obat', 'dokter', 'klinik', 'apotek', 'vitamin', 'rumah sakit', 'medis'],
  'Gaji': ['gaji', 'gajian', 'payroll', 'salary'],
  'Freelance': ['freelance', 'proyek', 'klien', 'fee'],
  'Bonus': ['bonus', 'thr', 'insentif', 'komisi', 'hadiah'],
  'Investasi': ['investasi', 'saham', 'dividen', 'reksadana', 'crypto'],
  'Transfer Masuk': ['transfer masuk', 'kiriman', 'ditransfer', 'dapat kiriman'],
};

export class CategorySuggestionService {
  constructor(options = {}) {
    this.defaultLimit = options.defaultLimit || 5;
    this.maxLimit = options.maxLimit || 50;
  }

  /**
   * Retrieves frequently used categories for a user, sorted by frequency score,
   * transaction count, and recency.
   *
   * @param {import('better-sqlite3').Database} db
   * @param {number|string} userId
   * @param {Object} [options]
   * @param {string} [options.type] - 'expense' | 'income' | null (both)
   * @param {number} [options.limit=5] - Number of suggestions to return
   * @param {number} [options.days] - Restrict to transactions in the last N days
   * @param {boolean} [options.includeUnused=true] - Pad with system default categories if fewer than limit
   * @param {string} [options.sortBy='frequency'] - 'frequency' | 'recency' | 'amount'
   * @param {number} [options.minCount=0] - Minimum usage count to be included
   * @returns {Array<Object>} List of category suggestions with frequency metrics
   */
  getFrequentCategories(db, userId, options = {}) {
    if (!db) {
      throw new Error('[CategorySuggestionService] Database connection is required.');
    }

    const {
      type = null,
      limit = this.defaultLimit,
      days = null,
      includeUnused = true,
      sortBy = 'frequency',
      minCount = 0,
    } = options;

    const effectiveLimit = Math.max(1, Math.min(this.maxLimit, Number(limit) || this.defaultLimit));

    // 1. Calculate total transactions for percentage calculation
    let totalTxQuery = `
      SELECT COUNT(*) AS total
      FROM transactions
      WHERE user_id = ?
    `;
    const totalTxParams = [userId];
    if (type && (type === 'expense' || type === 'income')) {
      totalTxQuery += ' AND type = ?';
      totalTxParams.push(type);
    }
    if (days && Number(days) > 0) {
      totalTxQuery += ` AND occurred_at >= datetime('now', '-' || ? || ' days')`;
      totalTxParams.push(Number(days));
    }

    const totalTxRow = db.prepare(totalTxQuery).get(...totalTxParams);
    const totalTransactions = totalTxRow ? totalTxRow.total : 0;

    // 2. Query categories with usage aggregation
    let txDateFilter = '';
    const queryParams = [userId];

    if (days && Number(days) > 0) {
      txDateFilter = `AND t.occurred_at >= datetime('now', '-' || ? || ' days')`;
      queryParams.push(Number(days));
    }

    queryParams.push(userId); // for WHERE (c.user_id IS NULL OR c.user_id = ?)

    let typeFilter = '';
    if (type && (type === 'expense' || type === 'income')) {
      typeFilter = 'AND (c.type = ?)';
      queryParams.push(type);
    }

    let orderClause = 'ORDER BY usage_count DESC, last_used_at DESC, c.is_default DESC, c.name ASC';
    if (sortBy === 'recency') {
      orderClause = 'ORDER BY last_used_at DESC, usage_count DESC, c.name ASC';
    } else if (sortBy === 'amount') {
      orderClause = 'ORDER BY total_amount DESC, usage_count DESC, c.name ASC';
    }

    const sql = `
      SELECT
        c.id,
        c.name,
        c.type,
        c.icon,
        c.color,
        c.is_default,
        c.user_id,
        COUNT(t.id) AS usage_count,
        COALESCE(SUM(t.amount), 0) AS total_amount,
        MAX(t.occurred_at) AS last_used_at,
        MIN(t.occurred_at) AS first_used_at
      FROM categories c
      LEFT JOIN transactions t ON (t.category_id = c.id OR LOWER(t.category_name) = LOWER(c.name))
        AND t.user_id = ?
        ${txDateFilter}
      WHERE (c.user_id IS NULL OR c.user_id = ?)
        ${typeFilter}
      GROUP BY c.id
      HAVING usage_count >= ?
      ${orderClause}
    `;

    queryParams.push(minCount);

    const rows = db.prepare(sql).all(...queryParams);

    // Map to formatted objects and calculate frequency score & recency bonus
    const now = Date.now();
    const formatted = rows.map((r, index) => {
      const usageCount = Number(r.usage_count) || 0;
      const totalAmount = Number(r.total_amount) || 0;
      const lastUsedTimestamp = r.last_used_at ? new Date(r.last_used_at).getTime() : 0;
      
      // Calculate recency decay: transactions used within 7 days get full bonus (1.0),
      // decreasing down to 0.1 for transactions older than 60 days
      let recencyWeight = 0.1;
      if (lastUsedTimestamp > 0) {
        const daysAgo = Math.max(0, (now - lastUsedTimestamp) / (1000 * 60 * 60 * 24));
        recencyWeight = Math.max(0.1, Math.min(1.0, 1.0 - (daysAgo / 60)));
      }

      // Frequency score: baseline usage count multiplied by recency weight
      const frequencyScore = Math.round((usageCount * (1 + recencyWeight)) * 100) / 100;
      const percentage = totalTransactions > 0
        ? Math.round((usageCount / totalTransactions) * 1000) / 10
        : 0;

      return {
        id: r.id,
        name: r.name,
        type: r.type,
        icon: r.icon,
        color: r.color,
        isDefault: Boolean(r.is_default),
        isCustom: !Boolean(r.is_default) && r.user_id !== null,
        usageCount,
        totalAmount,
        lastUsedAt: r.last_used_at || null,
        firstUsedAt: r.first_used_at || null,
        frequencyScore,
        percentageOfTransactions: percentage,
        rank: index + 1,
      };
    });

    // 3. Separate categories that have been used vs unused
    const usedCategories = formatted.filter((c) => c.usageCount > 0);
    const unusedCategories = formatted.filter((c) => c.usageCount === 0);

    let result = usedCategories;

    // If caller wants unused categories to fill up to effectiveLimit
    if (includeUnused && result.length < effectiveLimit) {
      const needed = effectiveLimit - result.length;
      result = [...result, ...unusedCategories.slice(0, needed)];
    } else {
      result = result.slice(0, effectiveLimit);
    }

    // Re-index ranks
    return result.map((item, idx) => ({
      ...item,
      rank: idx + 1,
    }));
  }

  /**
   * Provides contextual category suggestions for a given input note/sentence.
   * Matches note tokens with user's past transaction history and category keywords,
   * weighted by historical frequency.
   *
   * @param {import('better-sqlite3').Database} db
   * @param {number|string} userId
   * @param {string} text - Transaction description or note
   * @param {Object} [options]
   * @param {string} [options.type] - 'expense' | 'income'
   * @param {number} [options.limit=5]
   * @returns {Array<Object>} Ranked suggestions with confidence and reasoning
   */
  getSuggestionsForText(db, userId, text, options = {}) {
    if (!db) {
      throw new Error('[CategorySuggestionService] Database connection is required.');
    }

    const { type = null, limit = this.defaultLimit } = options;
    const effectiveLimit = Math.max(1, Math.min(this.maxLimit, Number(limit) || this.defaultLimit));

    if (!text || typeof text !== 'string' || text.trim() === '') {
      // Fallback to top frequent categories when no text is provided
      const frequent = this.getFrequentCategories(db, userId, { type, limit: effectiveLimit });
      return frequent.map((f) => ({
        categoryId: f.id,
        category: f.name,
        type: f.type,
        icon: f.icon,
        color: f.color,
        isCustom: f.isCustom,
        score: f.usageCount > 0 ? 0.70 : 0.50,
        matchType: 'frequent_fallback',
        matchReason: f.usageCount > 0
          ? `Kategori sering digunakan (${f.usageCount}x)`
          : 'Kategori standar yang disarankan',
        usageCount: f.usageCount,
        samplePastNotes: [],
      }));
    }

    const cleanTokens = this._extractTokens(text);

    // 1. Fetch user's past transactions matching any of the tokens
    let pastTxRows = [];
    if (cleanTokens.length > 0) {
      const tokenConditions = cleanTokens.map(() => `LOWER(note) LIKE ?`).join(' OR ');
      const tokenParams = cleanTokens.map((t) => `%${t}%`);

      let txSql = `
        SELECT
          t.category_id,
          t.category_name,
          t.type,
          t.note,
          t.occurred_at,
          c.icon,
          c.color,
          c.is_default
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        WHERE t.user_id = ?
          AND (${tokenConditions})
      `;
      const queryArgs = [userId, ...tokenParams];
      if (type && (type === 'expense' || type === 'income')) {
        txSql += ' AND t.type = ?';
        queryArgs.push(type);
      }
      txSql += ' ORDER BY t.occurred_at DESC LIMIT 50';

      pastTxRows = db.prepare(txSql).all(...queryArgs);
    }

    // 2. Fetch available categories for user
    let catSql = `
      SELECT id, name, type, icon, color, is_default, user_id
      FROM categories
      WHERE (user_id IS NULL OR user_id = ?)
    `;
    const catArgs = [userId];
    if (type && (type === 'expense' || type === 'income')) {
      catSql += ' AND type = ?';
      catArgs.push(type);
    }
    const allCategories = db.prepare(catSql).all(...catArgs);

    // 3. Score categories based on:
    // a. Past note token matches
    // b. Category name token matches
    // c. General historical frequency
    const categoryScores = new Map();

    // Initialize map
    for (const cat of allCategories) {
      categoryScores.set(cat.id, {
        categoryId: cat.id,
        category: cat.name,
        type: cat.type,
        icon: cat.icon,
        color: cat.color,
        isCustom: !Boolean(cat.is_default) && cat.user_id !== null,
        noteMatchCount: 0,
        sampleNotes: [],
        nameMatched: false,
        score: 0,
        matchType: 'general',
        matchReason: '',
      });
    }

    // Process past transactions matches
    for (const tx of pastTxRows) {
      const catEntry = categoryScores.get(tx.category_id);
      if (catEntry) {
        catEntry.noteMatchCount += 1;
        if (catEntry.sampleNotes.length < 3 && tx.note && !catEntry.sampleNotes.includes(tx.note)) {
          catEntry.sampleNotes.push(tx.note);
        }
      }
    }

    // Check direct category name token match or built-in category keyword match
    const lowerText = text.toLowerCase();
    for (const cat of allCategories) {
      const entry = categoryScores.get(cat.id);
      if (!entry) continue;

      const catLower = cat.name.toLowerCase();
      if (lowerText.includes(catLower)) {
        entry.nameMatched = true;
        entry.score += 0.50;
      } else {
        const catTokens = catLower.split(/[\s&/,]+/).filter((t) => t.length >= 3);
        if (catTokens.some((t) => cleanTokens.includes(t) || lowerText.includes(t))) {
          entry.nameMatched = true;
          entry.score += 0.40;
        }
      }

      // Check category keywords
      const keywords = DEFAULT_CATEGORY_KEYWORDS[cat.name] || [];
      const matchedKeyword = keywords.find((kw) => lowerText.includes(kw) || cleanTokens.includes(kw));
      if (matchedKeyword) {
        entry.keywordMatched = true;
        entry.score += 0.45;
        if (!entry.matchReason) {
          entry.matchReason = `Cocok dengan kata kunci kategori "${cat.name}": "${matchedKeyword}"`;
        }
      }
    }

    // Add note match score
    for (const entry of categoryScores.values()) {
      if (entry.noteMatchCount > 0) {
        const matchWeight = 0.60 + Math.min(0.35, entry.noteMatchCount * 0.10);
        entry.score += matchWeight;
        entry.matchType = 'historical_note_match';
        entry.matchReason = `Sering dicatat pada kategori ini sebelumnya (${entry.noteMatchCount}x)`;
      } else if (entry.nameMatched) {
        entry.matchType = 'category_name_match';
        entry.matchReason = entry.matchReason || `Cocok dengan kata kunci nama kategori: "${entry.category}"`;
      } else if (entry.keywordMatched) {
        entry.matchType = 'category_keyword_match';
      }
    }

    // Sort scored categories
    const sorted = Array.from(categoryScores.values())
      .filter((e) => e.score > 0)
      .sort((a, b) => b.score - a.score);

    // If we have fewer than limit, augment with frequent categories
    const topFrequent = this.getFrequentCategories(db, userId, { type, limit: effectiveLimit });
    const existingIds = new Set(sorted.map((s) => s.categoryId));

    for (const f of topFrequent) {
      if (sorted.length >= effectiveLimit) break;
      if (!existingIds.has(f.id)) {
        sorted.push({
          categoryId: f.id,
          category: f.name,
          type: f.type,
          icon: f.icon,
          color: f.color,
          isCustom: f.isCustom,
          score: f.usageCount > 0 ? 0.30 : 0.15,
          matchType: 'frequent_fallback',
          matchReason: f.usageCount > 0
            ? `Kategori favorit sering digunakan (${f.usageCount}x)`
            : 'Kategori standar pilihan',
          usageCount: f.usageCount,
          sampleNotes: [],
        });
        existingIds.add(f.id);
      }
    }

    return sorted.slice(0, effectiveLimit).map((item) => ({
      categoryId: item.categoryId,
      category: item.category,
      type: item.type,
      icon: item.icon,
      color: item.color,
      isCustom: item.isCustom,
      confidenceScore: Math.min(0.99, Math.round(item.score * 100) / 100),
      matchType: item.matchType,
      matchReason: item.matchReason,
      samplePastNotes: item.sampleNotes || [],
    }));
  }

  /**
   * Provides time-of-day contextual suggestions based on current hour or specified slot.
   *
   * @param {import('better-sqlite3').Database} db
   * @param {number|string} userId
   * @param {Object} [options]
   * @param {string} [options.timeSlot] - 'morning' | 'afternoon' | 'evening' | 'night'
   * @param {number} [options.hour] - 0-23
   * @param {string} [options.type='expense']
   * @param {number} [options.limit=4]
   * @returns {Object} Contextual suggestion with time slot and categories
   */
  getSuggestionsByTimeOfDay(db, userId, options = {}) {
    if (!db) {
      throw new Error('[CategorySuggestionService] Database connection is required.');
    }

    const { type = 'expense', limit = 4 } = options;
    const currentHour = options.hour !== undefined ? Number(options.hour) : new Date().getHours();
    const timeSlot = options.timeSlot || this._determineTimeSlot(currentHour);

    // Map slot to hour ranges for SQLite strftime('%H', occurred_at)
    let startHour = '00';
    let endHour = '23';

    switch (timeSlot) {
      case 'morning':
        startHour = '04';
        endHour = '10';
        break;
      case 'afternoon':
        startHour = '11';
        endHour = '14';
        break;
      case 'evening':
        startHour = '15';
        endHour = '18';
        break;
      case 'night':
        startHour = '19';
        endHour = '23';
        break;
    }

    // Query user's past transactions in this hour window
    const rows = db.prepare(`
      SELECT
        c.id, c.name, c.type, c.icon, c.color, c.is_default,
        COUNT(t.id) AS slot_usage_count
      FROM categories c
      JOIN transactions t ON (t.category_id = c.id OR LOWER(t.category_name) = LOWER(c.name))
      WHERE t.user_id = ?
        AND (c.type = ? OR ? IS NULL)
        AND strftime('%H', t.occurred_at) BETWEEN ? AND ?
      GROUP BY c.id
      ORDER BY slot_usage_count DESC, c.name ASC
      LIMIT ?
    `).all(userId, type, type, startHour, endHour, limit);

    let suggestions = rows.map((r) => ({
      id: r.id,
      name: r.name,
      type: r.type,
      icon: r.icon,
      color: r.color,
      isDefault: Boolean(r.is_default),
      isCustom: !Boolean(r.is_default),
      slotUsageCount: Number(r.slot_usage_count),
    }));

    // If no past transactions in this slot, provide time-of-day default priors
    if (suggestions.length === 0) {
      suggestions = this._getDefaultTimeSlotPriors(db, timeSlot, type, limit);
    }

    return {
      timeSlot,
      currentHour,
      type,
      suggestions,
    };
  }

  /**
   * Augments or personalizes an initial list of alternative categories
   * by combining heuristic alternatives with user's top frequently used categories.
   *
   * @param {import('better-sqlite3').Database} db
   * @param {number|string} userId
   * @param {Array<string>} initialAlternatives - Heuristic alternatives
   * @param {Object} [options]
   * @param {string} [options.type='expense']
   * @param {number} [options.limit=5]
   * @returns {Array<string>} Merged, deduplicated category names
   */
  augmentAlternativeCategories(db, userId, initialAlternatives = [], options = {}) {
    if (!db || !userId) {
      return initialAlternatives || [];
    }

    const { type = 'expense', limit = 5 } = options;
    const seen = new Set();
    const result = [];

    // 1. Add user's top frequent categories first
    const frequent = this.getFrequentCategories(db, userId, {
      type,
      limit,
      includeUnused: false,
    });

    for (const f of frequent) {
      if (f.name && !seen.has(f.name.toLowerCase())) {
        seen.add(f.name.toLowerCase());
        result.push(f.name);
      }
    }

    // 2. Add initial alternatives
    if (Array.isArray(initialAlternatives)) {
      for (const item of initialAlternatives) {
        const name = typeof item === 'string' ? item : item.name;
        if (name && !seen.has(name.toLowerCase())) {
          seen.add(name.toLowerCase());
          result.push(name);
        }
      }
    }

    return result.slice(0, limit);
  }

  /**
   * Calculates overall category statistics for a user.
   *
   * @param {import('better-sqlite3').Database} db
   * @param {number|string} userId
   * @returns {Object} Comprehensive category usage statistics
   */
  getCategoryStats(db, userId) {
    if (!db) {
      throw new Error('[CategorySuggestionService] Database connection is required.');
    }

    const row = db.prepare(`
      SELECT
        COUNT(DISTINCT category_id) AS distinct_categories_used,
        COUNT(id) AS total_transactions,
        SUM(CASE WHEN type = 'expense' THEN 1 ELSE 0 END) AS expense_transactions_count,
        SUM(CASE WHEN type = 'income' THEN 1 ELSE 0 END) AS income_transactions_count
      FROM transactions
      WHERE user_id = ?
    `).get(userId);

    const mostFrequent = db.prepare(`
      SELECT
        category_name,
        type,
        COUNT(id) AS count,
        SUM(amount) AS total_spent
      FROM transactions
      WHERE user_id = ? AND category_name IS NOT NULL
      GROUP BY category_name, type
      ORDER BY count DESC
      LIMIT 1
    `).get(userId);

    return {
      userId,
      distinctCategoriesUsed: row ? Number(row.distinct_categories_used) : 0,
      totalTransactions: row ? Number(row.total_transactions) : 0,
      expenseTransactionsCount: row ? Number(row.expense_transactions_count) : 0,
      incomeTransactionsCount: row ? Number(row.income_transactions_count) : 0,
      mostFrequentCategory: mostFrequent
        ? {
            name: mostFrequent.category_name,
            type: mostFrequent.type,
            count: Number(mostFrequent.count),
            totalSpent: Number(mostFrequent.total_spent),
          }
        : null,
    };
  }

  /**
   * Helper: Extracts meaningful keywords/tokens from text, stripping common Indonesian stop words.
   * @private
   */
  _extractTokens(text) {
    const stopWords = new Set([
      'dan', 'atau', 'di', 'ke', 'dari', 'yang', 'ini', 'itu', 'pada', 'untuk',
      'dengan', 'buat', 'sama', 'ada', 'bisa', 'mau', 'lagi', 'sudah', 'tadi',
      'beli', 'bayar', 'habis', 'keluar', 'masuk', 'transfer', 'kirim', 'dapat',
      'terima', 'sebesar', 'seharga', 'rp', 'idr', 'ribu', 'juta', 'k', 'rb', 'jt'
    ]);

    const words = text
      .toLowerCase()
      .replace(/[^\p{L}\p{N}\s]/gu, ' ')
      .split(/\s+/)
      .filter((w) => w.length >= 3 && !stopWords.has(w) && !/^\d+$/.test(w));

    return Array.from(new Set(words));
  }

  /**
   * Helper: Maps hour of day to contextual time slot.
   * @private
   */
  _determineTimeSlot(hour) {
    if (hour >= 4 && hour <= 10) return 'morning';
    if (hour >= 11 && hour <= 14) return 'afternoon';
    if (hour >= 15 && hour <= 18) return 'evening';
    return 'night';
  }

  /**
   * Helper: Returns default system category suggestions for a given time slot.
   * @private
   */
  _getDefaultTimeSlotPriors(db, timeSlot, type, limit) {
    const priorsBySlot = {
      morning: ['Makan & Minuman', 'Transportasi', 'Kebutuhan Rumah'],
      afternoon: ['Makan & Minuman', 'Belanja', 'Transportasi'],
      evening: ['Makan & Minuman', 'Hiburan', 'Transportasi'],
      night: ['Makan & Minuman', 'Hiburan', 'Belanja'],
    };

    const targetNames = priorsBySlot[timeSlot] || ['Makan & Minuman', 'Belanja'];
    const placeholders = targetNames.map(() => '?').join(',');

    const rows = db.prepare(`
      SELECT id, name, type, icon, color, is_default
      FROM categories
      WHERE name IN (${placeholders}) AND (type = ? OR ? IS NULL)
      LIMIT ?
    `).all(...targetNames, type, type, limit);

    return rows.map((r) => ({
      id: r.id,
      name: r.name,
      type: r.type,
      icon: r.icon,
      color: r.color,
      isDefault: Boolean(r.is_default),
      isCustom: false,
      slotUsageCount: 0,
    }));
  }
}

export const categorySuggestionService = new CategorySuggestionService();
