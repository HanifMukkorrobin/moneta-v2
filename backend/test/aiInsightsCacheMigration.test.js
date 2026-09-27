import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { createDatabaseConnection } from '../src/config/database.js';
import { runMigrations, ensureAiInsightsSchema } from '../src/db/migrate.js';
import {
  getCachedAnalysis,
  saveCachedAnalysis,
  invalidateAnalysisCache,
  deleteCachedAnalysis,
  hasValidCachedAnalysis,
  getTodayDateString,
} from '../src/services/analysisCacheService.js';

describe('AI Insights & Financial Analysis Cache Schema & Migration Tests', () => {
  let db;

  beforeEach(() => {
    db = createDatabaseConnection({ path: ':memory:' });
    runMigrations(db);
  });

  afterEach(() => {
    if (db) {
      db.close();
    }
  });

  describe('1. Schema Definition & Table Structure', () => {
    it('creates ai_insights table and financial_analysis_cache view', () => {
      const tables = db
        .prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
        .all()
        .map((r) => r.name);

      assert.ok(tables.includes('ai_insights'), 'Table ai_insights must exist');

      const views = db
        .prepare("SELECT name FROM sqlite_master WHERE type='view'")
        .all()
        .map((r) => r.name);

      assert.ok(views.includes('financial_analysis_cache'), 'View financial_analysis_cache must exist');
    });

    it('has all required columns with correct default values and types', () => {
      const columns = db.prepare('PRAGMA table_info(ai_insights)').all();
      const colMap = new Map(columns.map((c) => [c.name, c]));

      const expectedColumns = [
        'id',
        'user_id',
        'date',
        'avg_daily_spend',
        'estimated_days_left',
        'daily_advice',
        'warn_level',
        'recommended_daily_budget',
        'total_monthly_budget',
        'total_spent',
        'remaining_balance',
        'analysis_json',
        'is_stale',
        'expires_at',
        'created_at',
        'updated_at',
      ];

      for (const col of expectedColumns) {
        assert.ok(colMap.has(col), `Column ${col} must exist in ai_insights`);
      }

      // Check specific column configurations
      const warnLevelCol = colMap.get('warn_level');
      assert.equal(warnLevelCol.dflt_value, "'normal'");

      const isStaleCol = colMap.get('is_stale');
      assert.equal(isStaleCol.dflt_value, '0');

      const avgDailyCol = colMap.get('avg_daily_spend');
      assert.equal(avgDailyCol.dflt_value, '0');
    });

    it('creates performance and uniqueness indices', () => {
      const indices = db
        .prepare("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name = 'ai_insights'")
        .all()
        .map((r) => r.name);

      assert.ok(indices.includes('idx_ai_insights_user_date'), 'idx_ai_insights_user_date must exist');
      assert.ok(indices.includes('idx_ai_insights_warn_level'), 'idx_ai_insights_warn_level must exist');
      assert.ok(indices.includes('idx_ai_insights_user_stale'), 'idx_ai_insights_user_stale must exist');
      assert.ok(indices.includes('idx_ai_insights_expires_at'), 'idx_ai_insights_expires_at must exist');
      assert.ok(indices.includes('idx_ai_insights_unique_user_date'), 'idx_ai_insights_unique_user_date must exist');
    });
  });

  describe('2. Constraints & Integrity', () => {
    it('enforces UNIQUE constraint on (user_id, date)', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('insight_uniq@example.com')").run();
      const userId = userRes.lastInsertRowid;

      db.prepare(`
        INSERT INTO ai_insights (user_id, date, avg_daily_spend, daily_advice)
        VALUES (?, '2026-09-27', 75000, 'Saran hari ini')
      `).run(userId);

      assert.throws(() => {
        db.prepare(`
          INSERT INTO ai_insights (user_id, date, avg_daily_spend, daily_advice)
          VALUES (?, '2026-09-27', 80000, 'Saran duplikat')
        `).run(userId);
      }, /UNIQUE constraint failed/);
    });

    it('validates warn_level check constraint (normal, warning, critical)', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('insight_warn@example.com')").run();
      const userId = userRes.lastInsertRowid;

      // Valid levels
      for (const level of ['normal', 'warning', 'critical']) {
        const res = db.prepare(`
          INSERT INTO ai_insights (user_id, date, warn_level)
          VALUES (?, ?, ?)
        `).run(userId, `2026-09-0${userId + level.length}`, level);
        assert.ok(res.changes === 1);
      }

      // Invalid level should throw
      assert.throws(() => {
        db.prepare(`
          INSERT INTO ai_insights (user_id, date, warn_level)
          VALUES (?, '2026-09-30', 'danger')
        `).run(userId);
      }, /CHECK constraint failed/);
    });

    it('validates non-negative constraints on avg_daily_spend and estimated_days_left', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('insight_nonneg@example.com')").run();
      const userId = userRes.lastInsertRowid;

      assert.throws(() => {
        db.prepare(`
          INSERT INTO ai_insights (user_id, date, avg_daily_spend)
          VALUES (?, '2026-09-27', -100)
        `).run(userId);
      }, /CHECK constraint failed/);

      assert.throws(() => {
        db.prepare(`
          INSERT INTO ai_insights (user_id, date, estimated_days_left)
          VALUES (?, '2026-09-27', -5)
        `).run(userId);
      }, /CHECK constraint failed/);
    });

    it('cascades delete when user is deleted', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('insight_cascade@example.com')").run();
      const userId = userRes.lastInsertRowid;

      db.prepare(`
        INSERT INTO ai_insights (user_id, date, avg_daily_spend)
        VALUES (?, '2026-09-27', 50000)
      `).run(userId);

      assert.equal(db.prepare('SELECT COUNT(*) as c FROM ai_insights WHERE user_id = ?').get(userId).c, 1);

      db.prepare('DELETE FROM users WHERE id = ?').run(userId);

      assert.equal(db.prepare('SELECT COUNT(*) as c FROM ai_insights WHERE user_id = ?').get(userId).c, 0);
    });
  });

  describe('3. Migration on Pre-Existing / Legacy Tables', () => {
    it('upgrades legacy ai_insights table missing newer cache columns', () => {
      const legacyDb = createDatabaseConnection({ path: ':memory:' });

      try {
        // Create legacy table with only initial PRD fields
        legacyDb.exec(`
          CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              email TEXT UNIQUE NOT NULL
          );
          CREATE TABLE ai_insights (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              date TEXT NOT NULL,
              avg_daily_spend REAL NOT NULL DEFAULT 0,
              estimated_days_left INTEGER NOT NULL DEFAULT 0,
              daily_advice TEXT,
              warn_level TEXT NOT NULL DEFAULT 'normal'
          );
        `);

        const u = legacyDb.prepare("INSERT INTO users (email) VALUES ('legacy_cache@example.com')").run();
        legacyDb.prepare(`
          INSERT INTO ai_insights (user_id, date, avg_daily_spend, estimated_days_left, daily_advice, warn_level)
          VALUES (?, '2026-09-25', 65000, 15, 'Saran lama', 'normal')
        `).run(u.lastInsertRowid);

        // Run migration on legacy database
        ensureAiInsightsSchema(legacyDb);

        // Verify columns were added
        const cols = legacyDb.prepare('PRAGMA table_info(ai_insights)').all().map((c) => c.name);
        assert.ok(cols.includes('recommended_daily_budget'));
        assert.ok(cols.includes('total_monthly_budget'));
        assert.ok(cols.includes('total_spent'));
        assert.ok(cols.includes('remaining_balance'));
        assert.ok(cols.includes('analysis_json'));
        assert.ok(cols.includes('is_stale'));
        assert.ok(cols.includes('expires_at'));

        // Verify existing record is intact with default values backfilled
        const record = legacyDb.prepare('SELECT * FROM ai_insights WHERE user_id = ?').get(u.lastInsertRowid);
        assert.equal(record.avg_daily_spend, 65000);
        assert.equal(record.daily_advice, 'Saran lama');
        assert.equal(record.recommended_daily_budget, 0);
        assert.equal(record.is_stale, 0);

        // Verify view is created and returns the legacy row
        const viewRow = legacyDb.prepare('SELECT * FROM financial_analysis_cache WHERE user_id = ?').get(u.lastInsertRowid);
        assert.equal(viewRow.avg_daily_spend, 65000);
      } finally {
        legacyDb.close();
      }
    });
  });

  describe('4. Analysis Cache Service Operations', () => {
    let testUserId;

    beforeEach(() => {
      const res = db.prepare("INSERT INTO users (email) VALUES ('service_tester@example.com')").run();
      testUserId = res.lastInsertRowid;
    });

    it('saves and retrieves cached analysis with JSON breakdown and formatted fields', () => {
      const today = getTodayDateString();
      const mockPayload = {
        spendingPace: 'normal',
        topCategories: [{ name: 'Makan & Minuman', amount: 120000 }],
        aiRecommendation: 'Pertahankan batas harian.',
      };

      const saved = saveCachedAnalysis(db, {
        userId: testUserId,
        date: today,
        avgDailySpend: 78500,
        estimatedDaysLeft: 18,
        dailyAdvice: 'Pertahankan ritme belanja Anda.',
        warnLevel: 'normal',
        recommendedDailyBudget: 65000,
        totalMonthlyBudget: 6000000,
        totalSpent: 2850000,
        remainingBalance: 3150000,
        analysis: mockPayload,
        ttlHours: 12,
      });

      assert.ok(saved);
      assert.equal(saved.userId, testUserId);
      assert.equal(saved.date, today);
      assert.equal(saved.avgDailySpend, 78500);
      assert.equal(saved.estimatedDaysLeft, 18);
      assert.equal(saved.warnLevel, 'normal');
      assert.equal(saved.recommendedDailyBudget, 65000);
      assert.equal(saved.isStale, false);
      assert.deepEqual(saved.analysis, mockPayload);

      // Query through getCachedAnalysis
      const retrieved = getCachedAnalysis(db, { userId: testUserId, date: today });
      assert.ok(retrieved);
      assert.equal(retrieved.avgDailySpend, 78500);
      assert.equal(retrieved.totalSpent, 2850000);

      // Verify hasValidCachedAnalysis returns true
      assert.equal(hasValidCachedAnalysis(db, testUserId, today), true);
    });

    it('updates cache on conflict (upsert) for the same user and date', () => {
      const today = getTodayDateString();

      saveCachedAnalysis(db, {
        userId: testUserId,
        date: today,
        avgDailySpend: 50000,
        warnLevel: 'normal',
      });

      const updated = saveCachedAnalysis(db, {
        userId: testUserId,
        date: today,
        avgDailySpend: 95000,
        warnLevel: 'warning',
        dailyAdvice: 'Pengeluaran naik.',
      });

      assert.equal(updated.avgDailySpend, 95000);
      assert.equal(updated.warnLevel, 'warning');
      assert.equal(updated.dailyAdvice, 'Pengeluaran naik.');

      const count = db.prepare('SELECT COUNT(*) as c FROM ai_insights WHERE user_id = ?').get(testUserId).c;
      assert.equal(count, 1);
    });

    it('invalidates cache by marking is_stale = 1', () => {
      const today = getTodayDateString();

      saveCachedAnalysis(db, {
        userId: testUserId,
        date: today,
        avgDailySpend: 50000,
      });

      assert.equal(hasValidCachedAnalysis(db, testUserId, today), true);

      // Invalidate cache
      const changes = invalidateAnalysisCache(db, testUserId);
      assert.equal(changes, 1);

      // getCachedAnalysis without allowStale returns null
      assert.equal(getCachedAnalysis(db, { userId: testUserId, date: today, allowStale: false }), null);

      // getCachedAnalysis with allowStale returns data with isStale = true
      const staleData = getCachedAnalysis(db, { userId: testUserId, date: today, allowStale: true });
      assert.ok(staleData);
      assert.equal(staleData.isStale, true);

      assert.equal(hasValidCachedAnalysis(db, testUserId, today), false);
    });

    it('deletes cached analysis cleanly', () => {
      const today = getTodayDateString();

      saveCachedAnalysis(db, {
        userId: testUserId,
        date: today,
        avgDailySpend: 60000,
      });

      const deleted = deleteCachedAnalysis(db, testUserId, today);
      assert.equal(deleted, 1);
      assert.equal(getCachedAnalysis(db, { userId: testUserId, date: today, allowStale: true }), null);
    });
  });
});
