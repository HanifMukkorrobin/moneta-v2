import { describe, it, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import {
  CategorySuggestionService,
  categorySuggestionService,
} from '../src/services/categorySuggestionService.js';

describe('CategorySuggestionService & Frequency Endpoints Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  let service;

  before(async () => {
    db = getDatabase();
    db.prepare('DELETE FROM categories WHERE is_default = 0').run();
    const user = db.prepare('SELECT id FROM users ORDER BY id ASC LIMIT 1').get();
    testUserId = user ? user.id : 1;
    service = new CategorySuggestionService();

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    if (db) {
      db.prepare('DELETE FROM categories WHERE is_default = 0').run();
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. Unit Tests: getFrequentCategories', () => {
    beforeEach(() => {
      // Clean transactions for test isolation
      db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM categories WHERE is_default = 0 AND user_id = ?').run(testUserId);
    });

    afterEach(() => {
      db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM categories WHERE is_default = 0 AND user_id = ?').run(testUserId);
    });

    it('returns categories ordered by usage count (highest frequency first)', () => {
      const makanCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense' LIMIT 1").get();
      const transportCat = db.prepare("SELECT id FROM categories WHERE name = 'Transportasi' AND type = 'expense' LIMIT 1").get();
      const belanjaCat = db.prepare("SELECT id FROM categories WHERE name = 'Belanja' AND type = 'expense' LIMIT 1").get();

      // Insert 5 transactions for Makan & Minuman
      for (let i = 0; i < 5; i++) {
        db.prepare(`
          INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
          VALUES (?, ?, 'Makan & Minuman', 'expense', 25000, 'Makan siang', CURRENT_TIMESTAMP, 1)
        `).run(testUserId, makanCat.id);
      }

      // Insert 3 transactions for Transportasi
      for (let i = 0; i < 3; i++) {
        db.prepare(`
          INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
          VALUES (?, ?, 'Transportasi', 'expense', 15000, 'Bensin motor', CURRENT_TIMESTAMP, 1)
        `).run(testUserId, transportCat.id);
      }

      // Insert 1 transaction for Belanja
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Belanja', 'expense', 50000, 'Beli baju', CURRENT_TIMESTAMP, 1)
      `).run(testUserId, belanjaCat.id);

      const result = service.getFrequentCategories(db, testUserId, {
        type: 'expense',
        limit: 5,
        includeUnused: false,
      });

      assert.equal(result.length, 3);
      assert.equal(result[0].name, 'Makan & Minuman');
      assert.equal(result[0].usageCount, 5);
      assert.equal(result[0].totalAmount, 125000);
      assert.equal(result[0].rank, 1);
      assert.ok(result[0].frequencyScore > result[1].frequencyScore);

      assert.equal(result[1].name, 'Transportasi');
      assert.equal(result[1].usageCount, 3);
      assert.equal(result[1].totalAmount, 45000);
      assert.equal(result[1].rank, 2);

      assert.equal(result[2].name, 'Belanja');
      assert.equal(result[2].usageCount, 1);
      assert.equal(result[2].totalAmount, 50000);
      assert.equal(result[2].rank, 3);
    });

    it('calculates percentageOfTransactions accurately', () => {
      const makanCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense' LIMIT 1").get();
      const hiburanCat = db.prepare("SELECT id FROM categories WHERE name = 'Hiburan' AND type = 'expense' LIMIT 1").get();

      // 6 Makan, 4 Hiburan => total 10 transactions
      for (let i = 0; i < 6; i++) {
        db.prepare(`
          INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
          VALUES (?, ?, 'Makan & Minuman', 'expense', 20000, 'Makan', CURRENT_TIMESTAMP, 1)
        `).run(testUserId, makanCat.id);
      }
      for (let i = 0; i < 4; i++) {
        db.prepare(`
          INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
          VALUES (?, ?, 'Hiburan', 'expense', 50000, 'Bioskop', CURRENT_TIMESTAMP, 1)
        `).run(testUserId, hiburanCat.id);
      }

      const result = service.getFrequentCategories(db, testUserId, {
        type: 'expense',
        limit: 5,
        includeUnused: false,
      });

      assert.equal(result[0].name, 'Makan & Minuman');
      assert.equal(result[0].percentageOfTransactions, 60.0);
      assert.equal(result[1].name, 'Hiburan');
      assert.equal(result[1].percentageOfTransactions, 40.0);
    });

    it('filters by transaction type (income vs expense)', () => {
      const gajiCat = db.prepare("SELECT id FROM categories WHERE name = 'Gaji' AND type = 'income' LIMIT 1").get();
      const makanCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense' LIMIT 1").get();

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Gaji', 'income', 8000000, 'Gaji kantor', CURRENT_TIMESTAMP, 1)
      `).run(testUserId, gajiCat.id);

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Makan & Minuman', 'expense', 30000, 'Makan', CURRENT_TIMESTAMP, 1)
      `).run(testUserId, makanCat.id);

      const incomeFrequent = service.getFrequentCategories(db, testUserId, {
        type: 'income',
        includeUnused: false,
      });
      assert.equal(incomeFrequent.length, 1);
      assert.equal(incomeFrequent[0].name, 'Gaji');
      assert.equal(incomeFrequent[0].type, 'income');

      const expenseFrequent = service.getFrequentCategories(db, testUserId, {
        type: 'expense',
        includeUnused: false,
      });
      assert.equal(expenseFrequent.length, 1);
      assert.equal(expenseFrequent[0].name, 'Makan & Minuman');
      assert.equal(expenseFrequent[0].type, 'expense');
    });

    it('pads with system default categories when includeUnused=true', () => {
      const result = service.getFrequentCategories(db, testUserId, {
        type: 'expense',
        limit: 5,
        includeUnused: true,
      });

      assert.equal(result.length, 5);
      // All should have usageCount 0 since no transactions exist
      assert.ok(result.every((r) => r.usageCount === 0));
      assert.ok(result.every((r) => r.isDefault === true));
    });

    it('supports custom user categories seamlessly', () => {
      // Create custom category
      const ins = db.prepare(`
        INSERT INTO categories (user_id, name, type, is_default, icon, color)
        VALUES (?, 'Koleksi Gundam', 'expense', 0, 'toys_rounded', 'red')
      `).run(testUserId);
      const customCatId = ins.lastInsertRowid;

      // Add transaction for custom category
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Koleksi Gundam', 'expense', 750000, 'Beli model kit RG', CURRENT_TIMESTAMP, 1)
      `).run(testUserId, customCatId);

      const result = service.getFrequentCategories(db, testUserId, {
        type: 'expense',
        limit: 5,
        includeUnused: false,
      });

      assert.equal(result.length, 1);
      assert.equal(result[0].name, 'Koleksi Gundam');
      assert.equal(result[0].isCustom, true);
      assert.equal(result[0].isDefault, false);
      assert.equal(result[0].usageCount, 1);
      assert.equal(result[0].totalAmount, 750000);
    });

    it('respects sortBy="amount" and sortBy="recency"', () => {
      const makanCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense' LIMIT 1").get();
      const belanjaCat = db.prepare("SELECT id FROM categories WHERE name = 'Belanja' AND type = 'expense' LIMIT 1").get();

      // Makan: 10 transactions of 10k = 100k total
      for (let i = 0; i < 10; i++) {
        db.prepare(`
          INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
          VALUES (?, ?, 'Makan & Minuman', 'expense', 10000, 'Snack', datetime('now', '-2 days'), 1)
        `).run(testUserId, makanCat.id);
      }

      // Belanja: 1 transaction of 500k = 500k total, occurred today
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Belanja', 'expense', 500000, 'Beli HP', CURRENT_TIMESTAMP, 1)
      `).run(testUserId, belanjaCat.id);

      // By frequency: Makan (10x) ranks above Belanja (1x)
      const byFreq = service.getFrequentCategories(db, testUserId, {
        type: 'expense',
        sortBy: 'frequency',
        includeUnused: false,
      });
      assert.equal(byFreq[0].name, 'Makan & Minuman');

      // By amount: Belanja (500k) ranks above Makan (100k)
      const byAmount = service.getFrequentCategories(db, testUserId, {
        type: 'expense',
        sortBy: 'amount',
        includeUnused: false,
      });
      assert.equal(byAmount[0].name, 'Belanja');

      // By recency: Belanja (today) ranks above Makan (-2 days)
      const byRecency = service.getFrequentCategories(db, testUserId, {
        type: 'expense',
        sortBy: 'recency',
        includeUnused: false,
      });
      assert.equal(byRecency[0].name, 'Belanja');
    });
  });

  describe('2. Unit Tests: getSuggestionsForText', () => {
    beforeEach(() => {
      db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM categories WHERE is_default = 0 AND user_id = ?').run(testUserId);
    });

    afterEach(() => {
      db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM categories WHERE is_default = 0 AND user_id = ?').run(testUserId);
    });

    it('matches past transaction notes and suggests appropriate category', () => {
      const makanCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense' LIMIT 1").get();

      // Record several coffee transactions
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Makan & Minuman', 'expense', 24000, 'Kopi Kenangan mantan', CURRENT_TIMESTAMP, 1)
      `).run(testUserId, makanCat.id);
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Makan & Minuman', 'expense', 28000, 'Kopi susu gula aren', CURRENT_TIMESTAMP, 1)
      `).run(testUserId, makanCat.id);

      const suggestions = service.getSuggestionsForText(db, testUserId, 'Beli kopi sore', {
        type: 'expense',
        limit: 3,
      });

      assert.ok(suggestions.length > 0);
      assert.equal(suggestions[0].category, 'Makan & Minuman');
      assert.equal(suggestions[0].matchType, 'historical_note_match');
      assert.ok(suggestions[0].confidenceScore >= 0.70);
      assert.ok(suggestions[0].samplePastNotes.length > 0);
    });

    it('matches direct category name when text mentions category keyword', () => {
      const suggestions = service.getSuggestionsForText(db, testUserId, 'Biaya langganan internet bulanan', {
        type: 'expense',
        limit: 3,
      });

      assert.ok(suggestions.length > 0);
      const tagihanMatch = suggestions.find((s) => s.category === 'Tagihan & Utilitas');
      assert.ok(tagihanMatch);
    });

    it('falls back to frequent categories when input text is empty or unrecognized', () => {
      const suggestions = service.getSuggestionsForText(db, testUserId, '', {
        type: 'expense',
        limit: 4,
      });

      assert.equal(suggestions.length, 4);
      assert.equal(suggestions[0].matchType, 'frequent_fallback');
    });
  });

  describe('3. Unit Tests: getSuggestionsByTimeOfDay & augmentAlternativeCategories', () => {
    it('returns time-of-day suggestions with timeSlot and hour metadata', () => {
      const morningRes = service.getSuggestionsByTimeOfDay(db, testUserId, {
        hour: 8,
        type: 'expense',
        limit: 3,
      });

      assert.equal(morningRes.timeSlot, 'morning');
      assert.equal(morningRes.currentHour, 8);
      assert.ok(morningRes.suggestions.length > 0);

      const eveningRes = service.getSuggestionsByTimeOfDay(db, testUserId, {
        hour: 17,
        type: 'expense',
        limit: 3,
      });

      assert.equal(eveningRes.timeSlot, 'evening');
      assert.equal(eveningRes.currentHour, 17);
      assert.ok(eveningRes.suggestions.length > 0);
    });

    it('augments alternative categories with frequent categories without duplicates', () => {
      const makanCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense' LIMIT 1").get();
      const hiburanCat = db.prepare("SELECT id FROM categories WHERE name = 'Hiburan' AND type = 'expense' LIMIT 1").get();

      // Add frequent transactions for Makan and Hiburan
      for (let i = 0; i < 3; i++) {
        db.prepare(`
          INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
          VALUES (?, ?, 'Makan & Minuman', 'expense', 20000, 'Makan', CURRENT_TIMESTAMP, 1)
        `).run(testUserId, makanCat.id);
      }
      for (let i = 0; i < 2; i++) {
        db.prepare(`
          INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
          VALUES (?, ?, 'Hiburan', 'expense', 40000, 'Game', CURRENT_TIMESTAMP, 1)
        `).run(testUserId, hiburanCat.id);
      }

      const initialAlternatives = ['Belanja', 'Makan & Minuman', 'Transportasi'];
      const augmented = service.augmentAlternativeCategories(db, testUserId, initialAlternatives, {
        type: 'expense',
        limit: 5,
      });

      assert.ok(Array.isArray(augmented));
      assert.ok(augmented.length <= 5);
      // All items should be unique
      const uniqueNames = new Set(augmented.map((n) => n.toLowerCase()));
      assert.equal(uniqueNames.size, augmented.length);
      // Should include Makan & Minuman, Hiburan, Belanja
      assert.ok(augmented.includes('Makan & Minuman'));
      assert.ok(augmented.includes('Hiburan'));
      assert.ok(augmented.includes('Belanja'));
    });
  });

  describe('4. Unit Tests: getCategoryStats', () => {
    beforeEach(() => {
      db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
    });

    it('computes accurate category stats for user', () => {
      const makanCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense' LIMIT 1").get();
      const gajiCat = db.prepare("SELECT id FROM categories WHERE name = 'Gaji' AND type = 'income' LIMIT 1").get();

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Makan & Minuman', 'expense', 30000, 'Makan', CURRENT_TIMESTAMP, 1)
      `).run(testUserId, makanCat.id);

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Makan & Minuman', 'expense', 45000, 'Makan malam', CURRENT_TIMESTAMP, 1)
      `).run(testUserId, makanCat.id);

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Gaji', 'income', 7500000, 'Gaji bulanan', CURRENT_TIMESTAMP, 1)
      `).run(testUserId, gajiCat.id);

      const stats = service.getCategoryStats(db, testUserId);
      assert.equal(stats.userId, testUserId);
      assert.equal(stats.totalTransactions, 3);
      assert.equal(stats.expenseTransactionsCount, 2);
      assert.equal(stats.incomeTransactionsCount, 1);
      assert.equal(stats.distinctCategoriesUsed, 2);
      assert.ok(stats.mostFrequentCategory);
      assert.equal(stats.mostFrequentCategory.name, 'Makan & Minuman');
      assert.equal(stats.mostFrequentCategory.count, 2);
      assert.equal(stats.mostFrequentCategory.totalSpent, 75000);
    });
  });

  describe('5. HTTP Integration Endpoints Tests', () => {
    beforeEach(() => {
      db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM categories WHERE is_default = 0 AND user_id = ?').run(testUserId);
    });

    afterEach(() => {
      db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM categories WHERE is_default = 0 AND user_id = ?').run(testUserId);
    });

    it('GET /api/categories/frequent returns frequency-ranked categories', async () => {
      const res = await fetch(`${baseUrl}/api/categories/frequent?type=expense&limit=5&userId=${testUserId}`);
      assert.equal(res.status, 200);
      const data = await res.json();

      assert.equal(data.success, true);
      assert.equal(data.type, 'expense');
      assert.equal(data.total, 5);
      assert.ok(Array.isArray(data.suggestions));
      assert.equal(data.suggestions.length, 5);
      assert.ok(data.suggestions[0].name);
      assert.ok(data.suggestions[0].icon);
    });

    it('GET /api/categories/frequent?q=... performs contextual token search', async () => {
      const makanCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense' LIMIT 1").get();
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Makan & Minuman', 'expense', 25000, 'Beli bakso malang enak', CURRENT_TIMESTAMP, 1)
      `).run(testUserId, makanCat.id);

      const res = await fetch(`${baseUrl}/api/categories/frequent?q=bakso&userId=${testUserId}`);
      assert.equal(res.status, 200);
      const data = await res.json();

      assert.equal(data.success, true);
      assert.ok(data.suggestions.length > 0);
      assert.equal(data.suggestions[0].category, 'Makan & Minuman');
    });

    it('POST /api/categories/suggestions provides contextual suggestions via JSON body', async () => {
      const res = await fetch(`${baseUrl}/api/categories/suggestions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          text: 'Bayar tagihan listrik PLN bulanan',
          type: 'expense',
          userId: testUserId,
          limit: 3,
        }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.query, 'Bayar tagihan listrik PLN bulanan');
      assert.ok(data.suggestions.length > 0);
      assert.ok(data.suggestions.some((s) => s.category === 'Tagihan & Utilitas'));
    });

    it('GET /api/categories/stats returns accurate user category statistics', async () => {
      const res = await fetch(`${baseUrl}/api/categories/stats?userId=${testUserId}`);
      assert.equal(res.status, 200);
      const data = await res.json();

      assert.equal(data.success, true);
      assert.ok(data.stats);
      assert.equal(typeof data.stats.totalTransactions, 'number');
      assert.equal(typeof data.stats.distinctCategoriesUsed, 'number');
    });
  });
});
