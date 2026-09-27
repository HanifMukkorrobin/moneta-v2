import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { createDatabaseConnection } from '../src/config/database.js';
import { runMigrations } from '../src/db/migrate.js';
import {
  evaluateEarlyWarningStatus,
  getWarningDiagnostics,
  getOrUpdateCachedEarlyWarning,
} from '../src/services/earlyWarningService.js';

describe('Early Warning Service (Status Peringatan Dini 3 Tingkat) Tests', () => {
  let db;
  let testUserId;
  let makanCatId;
  let hiburanCatId;
  let gajiCatId;

  beforeEach(() => {
    db = createDatabaseConnection({ path: ':memory:' });
    runMigrations(db);

    const user = db.prepare("INSERT INTO users (email) VALUES ('early_warning_user@example.com')").run();
    testUserId = user.lastInsertRowid;

    makanCatId = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get().id;
    hiburanCatId = db.prepare("SELECT id FROM categories WHERE name = 'Hiburan' AND type = 'expense'").get().id;
    gajiCatId = db.prepare("SELECT id FROM categories WHERE name = 'Gaji' AND type = 'income'").get().id;
  });

  afterEach(() => {
    if (db) {
      db.close();
    }
  });

  describe('1. Warning Diagnostics Metadata', () => {
    it('returns structured metadata for all 3 levels', () => {
      const normal = getWarningDiagnostics('normal');
      assert.equal(normal.level, 'normal');
      assert.equal(normal.levelNumber, 1);
      assert.equal(normal.label, 'Keuangan Aman');
      assert.equal(normal.title, 'Tingkat 1: Finansial Terkendali');
      assert.ok(normal.actionRecommendation);

      const warning = getWarningDiagnostics('warning');
      assert.equal(warning.level, 'warning');
      assert.equal(warning.levelNumber, 2);
      assert.equal(warning.label, 'Perlu Waspada');
      assert.equal(warning.title, 'Tingkat 2: Peringatan Belanja Meningkat');
      assert.ok(warning.actionRecommendation);

      const critical = getWarningDiagnostics('critical');
      assert.equal(critical.level, 'critical');
      assert.equal(critical.levelNumber, 3);
      assert.equal(critical.label, 'Kondisi Kritis');
      assert.equal(critical.title, 'Tingkat 3: Kondisi Kritis / Darurat');
      assert.ok(critical.actionRecommendation);

      // Fallback for invalid value
      assert.equal(getWarningDiagnostics('unknown').level, 'normal');
    });
  });

  describe('2. Tingkat 1: Normal (Keuangan Aman)', () => {
    it('evaluates to Level 1 (Normal) when spending is stable and well within budget', () => {
      // Monthly Budget Rp 6.000.000 for September 2026 (target = Rp 200.000 / hari)
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount, needs_pct, savings_pct, fun_pct)
        VALUES (?, '2026-09', 6000000, 50, 30, 20)
      `).run(testUserId);

      // Spend Rp 500.000 across 7 days -> avg = ~Rp 71.428 / hari (well below Rp 200.000)
      // Remaining balance = 6.000.000 - 500.000 = 5.500.000
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES
          (?, ?, 'expense', 250000, 'Makan', '2026-09-08 12:00:00', 1),
          (?, ?, 'expense', 250000, 'Makan', '2026-09-12 12:00:00', 1)
      `).run(testUserId, makanCatId, testUserId, makanCatId);

      const result = evaluateEarlyWarningStatus(db, {
        userId: testUserId,
        referenceDate: '2026-09-12',
      });

      assert.equal(result.level, 'normal');
      assert.equal(result.levelNumber, 1);
      assert.equal(result.label, 'Keuangan Aman');
      assert.equal(result.isNormal, true);
      assert.equal(result.isWarning, false);
      assert.equal(result.isCritical, false);
      assert.ok(result.reasons.length > 0);
      assert.ok(result.actionRecommendation.includes('Pertahankan'));
    });
  });

  describe('3. Tingkat 2: Warning (Perlu Waspada)', () => {
    it('evaluates to Level 2 (Warning) when spending pace exceeds daily budget target', () => {
      // Monthly Budget: Rp 3.000.000 for 2026-09 (30 days -> target = Rp 100.000 / hari)
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 3000000)
      `).run(testUserId);

      // Spend Rp 1.050.000 across 7 days -> avg = Rp 150.000 / hari (> Rp 100.000)
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 1050000, 'Belanja boros', '2026-09-11 12:00:00', 1)
      `).run(testUserId, hiburanCatId);

      const result = evaluateEarlyWarningStatus(db, {
        userId: testUserId,
        referenceDate: '2026-09-12',
      });

      assert.equal(result.level, 'warning');
      assert.equal(result.levelNumber, 2);
      assert.equal(result.label, 'Perlu Waspada');
      assert.equal(result.isWarning, true);
      assert.ok(result.reasons.some((r) => r.includes('melebihi target')));
      assert.ok(result.actionRecommendation.includes('hiburan'));
    });

    it('evaluates to Level 2 (Warning) when money will run out before end of month', () => {
      // Budget: Rp 6.000.000, already spent Rp 4.800.000 -> Remaining: Rp 1.200.000
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 6000000)
      `).run(testUserId);

      // Reference date: 2026-09-12 (18 days left in month)
      // Spend Rp 1.050.000 in last 7 days -> avg = Rp 150.000 / hari
      // Days left = 1.200.000 / 150.000 = 8 days (< 18 days)
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES
          (?, ?, 'expense', 3750000, 'Belanja awal', '2026-09-02 12:00:00', 1),
          (?, ?, 'expense', 1050000, 'Belanja pekan ini', '2026-09-10 12:00:00', 1)
      `).run(testUserId, makanCatId, testUserId, makanCatId);

      const result = evaluateEarlyWarningStatus(db, {
        userId: testUserId,
        referenceDate: '2026-09-12',
      });

      assert.equal(result.level, 'warning');
      assert.equal(result.levelNumber, 2);
      assert.equal(result.isWarning, true);
      assert.ok(result.reasons.some((r) => r.includes('sebelum akhir bulan') || r.includes('bertahan')));
    });

    it('evaluates to Level 2 (Warning) on weekly spending spike (WoW >= 25%)', () => {
      // Prev week: Rp 300.000 -> Curr week: Rp 450.000 (+50% increase)
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 10000000)
      `).run(testUserId);

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES
          (?, ?, 'expense', 300000, 'Minggu lalu', '2026-09-05 12:00:00', 1),
          (?, ?, 'expense', 450000, 'Minggu ini', '2026-09-12 12:00:00', 1)
      `).run(testUserId, makanCatId, testUserId, makanCatId);

      const result = evaluateEarlyWarningStatus(db, {
        userId: testUserId,
        referenceDate: '2026-09-12',
      });

      assert.equal(result.level, 'warning');
      assert.equal(result.levelNumber, 2);
      assert.ok(result.reasons.some((r) => r.includes('meningkat')));
    });
  });

  describe('4. Tingkat 3: Critical (Kondisi Kritis / Darurat)', () => {
    it('evaluates to Level 3 (Critical) when balance is exhausted (overbudget/deficit)', () => {
      // Budget: Rp 5.000.000 -> Spent: Rp 5.500.000
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 5000000)
      `).run(testUserId);

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 5500000, 'Overbudget', '2026-09-10 12:00:00', 1)
      `).run(testUserId, makanCatId);

      const result = evaluateEarlyWarningStatus(db, {
        userId: testUserId,
        referenceDate: '2026-09-12',
      });

      assert.equal(result.level, 'critical');
      assert.equal(result.levelNumber, 3);
      assert.equal(result.label, 'Kondisi Kritis');
      assert.equal(result.isCritical, true);
      assert.ok(result.reasons.some((r) => r.includes('habis')));
      assert.ok(result.actionRecommendation.includes('primer'));
    });

    it('evaluates to Level 3 (Critical) when money is projected to run out in <= 3 days', () => {
      // Budget: Rp 6.000.000 -> Remaining: Rp 350.000
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 6000000)
      `).run(testUserId);

      // In last 7 days, spent Rp 1.050.000 (avg = Rp 150.000 / hari)
      // Days left = 350.000 / 150.000 = 2 days (<= 3 days)
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES
          (?, ?, 'expense', 4600000, 'Pengeluaran awal', '2026-09-02 12:00:00', 1),
          (?, ?, 'expense', 1050000, 'Pengeluaran pekan', '2026-09-11 12:00:00', 1)
      `).run(testUserId, makanCatId, testUserId, makanCatId);

      const result = evaluateEarlyWarningStatus(db, {
        userId: testUserId,
        referenceDate: '2026-09-12',
      });

      assert.equal(result.level, 'critical');
      assert.equal(result.levelNumber, 3);
      assert.equal(result.isCritical, true);
      assert.ok(result.reasons.some((r) => r.includes('sangat singkat')));
    });
  });

  describe('5. Cache Integration with ai_insights', () => {
    it('caches early warning evaluation in ai_insights and serves from cache', () => {
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 5000000)
      `).run(testUserId);

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 1000000, 'Belanja', '2026-09-12 12:00:00', 1)
      `).run(testUserId, makanCatId);

      // Call 1: uncached
      const eval1 = getOrUpdateCachedEarlyWarning(db, {
        userId: testUserId,
        referenceDate: '2026-09-12',
      });
      assert.equal(eval1.fromCache, false);
      assert.equal(eval1.level, 'normal');

      // Verify row in ai_insights
      const cacheRow = db.prepare("SELECT * FROM ai_insights WHERE user_id = ? AND date = '2026-09-12'").get(testUserId);
      assert.ok(cacheRow);
      assert.equal(cacheRow.warn_level, 'normal');

      // Call 2: served from cache
      const eval2 = getOrUpdateCachedEarlyWarning(db, {
        userId: testUserId,
        referenceDate: '2026-09-12',
      });
      assert.equal(eval2.fromCache, true);
      assert.equal(eval2.level, 'normal');
    });
  });
});
