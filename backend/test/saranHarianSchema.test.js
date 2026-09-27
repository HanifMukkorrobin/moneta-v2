import { test, describe, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import Database from 'better-sqlite3';
import { runMigrations, defaultSavingTips, ensureSaranHarianSchema } from '../src/db/migrate.js';
import {
  getAllTips,
  getTipById,
  getUserSavingTips,
  toggleUserSavingTip,
  createDailyTip,
} from '../src/services/dailyTipsService.js';
import {
  getReminderSettings,
  updateReminderSettings,
  resetReminderSettings,
  DEFAULT_REMINDER_SETTINGS,
} from '../src/services/reminderSettingsService.js';
import {
  getCachedDailyAdvice,
  saveCachedDailyAdvice,
  markAdviceAsApplied,
  invalidateDailyAdviceCache,
  deleteCachedDailyAdvice,
  hasValidCachedDailyAdvice,
} from '../src/services/dailyAdviceCacheService.js';

describe('Tabel Tips Harian, Pengaturan Pengingat & Cache Saran Tests', () => {
  let db;
  let testUserId;

  beforeEach(() => {
    db = new Database(':memory:');
    db.pragma('foreign_keys = ON');
    runMigrations(db);

    const userStmt = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, ?, ?)
    `);
    const res = userStmt.run('budi@example.com', 'Budi Santoso', 'IDR');
    testUserId = res.lastInsertRowid;
  });

  afterEach(() => {
    if (db) {
      db.close();
    }
  });

  describe('1. Tabel Tips Harian & Seeding (daily_tips)', () => {
    test('creates daily_tips table with proper schema and seeds 9 default saving tips', () => {
      const tableInfo = db.prepare("PRAGMA table_info(daily_tips)").all();
      const colNames = tableInfo.map((c) => c.name);

      assert.ok(colNames.includes('id'));
      assert.ok(colNames.includes('title'));
      assert.ok(colNames.includes('category'));
      assert.ok(colNames.includes('description'));
      assert.ok(colNames.includes('potential_saving'));
      assert.ok(colNames.includes('impact_level'));
      assert.ok(colNames.includes('icon'));
      assert.ok(colNames.includes('action_text'));
      assert.ok(colNames.includes('is_active'));
      assert.ok(colNames.includes('created_at'));
      assert.ok(colNames.includes('updated_at'));

      const tips = getAllTips(db);
      assert.strictEqual(tips.length, defaultSavingTips.length);
      assert.strictEqual(tips[0].title, 'Bawa Bekal Makan Siang 2x Sepekan');
      assert.strictEqual(tips[0].category, 'Makan & Minuman');
      assert.strictEqual(tips[0].potentialSaving, 150000);
      assert.strictEqual(tips[0].impactLevel, 'Tinggi');
    });

    test('supports view tips_harian', () => {
      const rows = db.prepare('SELECT * FROM tips_harian').all();
      assert.strictEqual(rows.length, defaultSavingTips.length);
    });

    test('filters tips by category and creates a new custom tip', () => {
      const makanTips = getAllTips(db, { category: 'Makan & Minuman' });
      assert.ok(makanTips.length >= 2);
      makanTips.forEach((t) => assert.strictEqual(t.category, 'Makan & Minuman'));

      const newTip = createDailyTip(db, {
        title: 'Gunakan Tumbler Air Minum Pribadi',
        category: 'Gaya Hidup',
        description: 'Bawa botol minum sendiri saat bepergian untuk memangkas jajan air kemasan.',
        potentialSaving: 30000,
        impactLevel: 'Ringan',
        icon: 'water_bottle_rounded',
        actionText: 'Siapkan Botol Minum',
      });

      assert.ok(newTip.id);
      assert.strictEqual(newTip.title, 'Gunakan Tumbler Air Minum Pribadi');
      assert.strictEqual(newTip.potentialSaving, 30000);

      const fetched = getTipById(db, newTip.id);
      assert.strictEqual(fetched.title, 'Gunakan Tumbler Air Minum Pribadi');
    });

    test('user_saving_tips tracks applied status per user and cascades delete', () => {
      const tips = getUserSavingTips(db, { userId: testUserId });
      assert.strictEqual(tips.length, defaultSavingTips.length);
      assert.strictEqual(tips[0].isApplied, false);

      // Toggle first tip to applied
      const updated = toggleUserSavingTip(db, {
        userId: testUserId,
        tipId: tips[0].id,
        isApplied: true,
      });

      assert.strictEqual(updated.isApplied, true);
      assert.ok(updated.appliedAt);

      const updatedList = getUserSavingTips(db, { userId: testUserId });
      assert.strictEqual(updatedList[0].isApplied, true);

      // Toggle back to false
      const untoggled = toggleUserSavingTip(db, {
        userId: testUserId,
        tipId: tips[0].id,
        isApplied: false,
      });
      assert.strictEqual(untoggled.isApplied, false);

      // Cascade delete verification
      db.prepare('DELETE FROM users WHERE id = ?').run(testUserId);
      const remainingUserTips = db.prepare('SELECT COUNT(*) as count FROM user_saving_tips WHERE user_id = ?').get(testUserId);
      assert.strictEqual(remainingUserTips.count, 0);
    });
  });

  describe('2. Tabel Pengaturan Pengingat (reminder_settings)', () => {
    test('creates reminder_settings table and provides default settings on demand', () => {
      const tableInfo = db.prepare("PRAGMA table_info(reminder_settings)").all();
      const colNames = tableInfo.map((c) => c.name);

      assert.ok(colNames.includes('id'));
      assert.ok(colNames.includes('user_id'));
      assert.ok(colNames.includes('is_enabled'));
      assert.ok(colNames.includes('morning_reminder_time'));
      assert.ok(colNames.includes('is_morning_reminder_enabled'));
      assert.ok(colNames.includes('evening_reminder_time'));
      assert.ok(colNames.includes('is_evening_reminder_enabled'));
      assert.ok(colNames.includes('active_days'));
      assert.ok(colNames.includes('notify_on_overbudget'));
      assert.ok(colNames.includes('notify_saving_tips'));
      assert.ok(colNames.includes('notify_debt_due'));
      assert.ok(colNames.includes('sound_enabled'));
      assert.ok(colNames.includes('vibration_enabled'));
      assert.ok(colNames.includes('fcm_token'));
      assert.ok(colNames.includes('timezone'));

      const settings = getReminderSettings(db, testUserId);
      assert.strictEqual(settings.userId, testUserId);
      assert.strictEqual(settings.isEnabled, true);
      assert.strictEqual(settings.morningReminderTime, '08:00');
      assert.strictEqual(settings.eveningReminderTime, '20:00');
      assert.deepStrictEqual(settings.activeDays, [1, 2, 3, 4, 5, 6, 7]);
      assert.strictEqual(settings.notifyOnOverbudget, true);
    });

    test('supports view pengaturan_pengingat', () => {
      getReminderSettings(db, testUserId);
      const row = db.prepare('SELECT * FROM pengaturan_pengingat WHERE user_id = ?').get(testUserId);
      assert.ok(row);
      assert.strictEqual(row.morning_reminder_time, '08:00');
    });

    test('updates reminder settings with custom time, active days, and tokens', () => {
      const updated = updateReminderSettings(db, testUserId, {
        morningReminderTime: '07:30',
        eveningReminderTime: '21:15',
        activeDays: [1, 2, 3, 4, 5], // Hari kerja
        notifyDebtDue: false,
        fcmToken: 'fcm-device-token-12345',
      });

      assert.strictEqual(updated.morningReminderTime, '07:30');
      assert.strictEqual(updated.eveningReminderTime, '21:15');
      assert.deepStrictEqual(updated.activeDays, [1, 2, 3, 4, 5]);
      assert.strictEqual(updated.notifyDebtDue, false);
      assert.strictEqual(updated.fcmToken, 'fcm-device-token-12345');

      // Verify persistence on re-query
      const fetched = getReminderSettings(db, testUserId);
      assert.strictEqual(fetched.morningReminderTime, '07:30');
      assert.deepStrictEqual(fetched.activeDays, [1, 2, 3, 4, 5]);
    });

    test('resets reminder settings to default', () => {
      updateReminderSettings(db, testUserId, {
        isEnabled: false,
        morningReminderTime: '06:00',
      });

      const reset = resetReminderSettings(db, testUserId);
      assert.strictEqual(reset.isEnabled, true);
      assert.strictEqual(reset.morningReminderTime, DEFAULT_REMINDER_SETTINGS.morningReminderTime);
    });

    test('cascades delete when user is deleted', () => {
      getReminderSettings(db, testUserId);
      db.prepare('DELETE FROM users WHERE id = ?').run(testUserId);

      const count = db.prepare('SELECT COUNT(*) as count FROM reminder_settings WHERE user_id = ?').get(testUserId);
      assert.strictEqual(count.count, 0);
    });
  });

  describe('3. Tabel Cache Saran (daily_advice_cache)', () => {
    test('creates daily_advice_cache table with indices and view aliases', () => {
      const tableInfo = db.prepare("PRAGMA table_info(daily_advice_cache)").all();
      const colNames = tableInfo.map((c) => c.name);

      assert.ok(colNames.includes('id'));
      assert.ok(colNames.includes('user_id'));
      assert.ok(colNames.includes('date'));
      assert.ok(colNames.includes('recommended_daily_budget'));
      assert.ok(colNames.includes('estimated_days_left'));
      assert.ok(colNames.includes('daily_advice'));
      assert.ok(colNames.includes('warn_level'));
      assert.ok(colNames.includes('avg_daily_spend'));
      assert.ok(colNames.includes('total_monthly_budget'));
      assert.ok(colNames.includes('total_spent'));
      assert.ok(colNames.includes('remaining_balance'));
      assert.ok(colNames.includes('source'));
      assert.ok(colNames.includes('advice_json'));
      assert.ok(colNames.includes('is_applied'));
      assert.ok(colNames.includes('is_stale'));
      assert.ok(colNames.includes('expires_at'));

      // Check views
      const views = db.prepare("SELECT name FROM sqlite_master WHERE type = 'view'").all().map((v) => v.name);
      assert.ok(views.includes('cache_saran'));
      assert.ok(views.includes('saran_cache'));
    });

    test('saves, retrieves, and updates cached daily advice', () => {
      const advice = saveCachedDailyAdvice(db, {
        userId: testUserId,
        date: '2026-09-27',
        recommendedDailyBudget: 65000,
        estimatedDaysLeft: 4,
        dailyAdvice: 'Batas belanja aman hari ini adalah Rp 65.000 agar saldo bertahan sampai akhir bulan.',
        warnLevel: 'normal',
        avgDailySpend: 62500,
        totalMonthlyBudget: 2000000,
        totalSpent: 1740000,
        remainingBalance: 260000,
        source: 'rule_based',
        adviceJson: { focusCategory: 'Makan & Minuman', maxSingleExpense: 35000 },
      });

      assert.strictEqual(advice.userId, testUserId);
      assert.strictEqual(advice.recommendedDailyBudget, 65000);
      assert.strictEqual(advice.estimatedDaysLeft, 4);
      assert.strictEqual(advice.warnLevel, 'normal');
      assert.strictEqual(advice.adviceDetails.focusCategory, 'Makan & Minuman');
      assert.strictEqual(advice.isApplied, false);

      // Verify via getCachedDailyAdvice
      const cached = getCachedDailyAdvice(db, { userId: testUserId, date: '2026-09-27' });
      assert.ok(cached);
      assert.strictEqual(cached.dailyAdvice, advice.dailyAdvice);

      // Mark advice as applied
      const applied = markAdviceAsApplied(db, { userId: testUserId, date: '2026-09-27', isApplied: true });
      assert.strictEqual(applied.isApplied, true);

      // Verify query via view cache_saran
      const viewRow = db.prepare('SELECT * FROM cache_saran WHERE user_id = ? AND date = ?').get(testUserId, '2026-09-27');
      assert.ok(viewRow);
      assert.strictEqual(Number(viewRow.recommended_daily_budget), 65000);
      assert.strictEqual(viewRow.is_applied, 1);
    });

    test('invalidates cache when marked stale', () => {
      saveCachedDailyAdvice(db, {
        userId: testUserId,
        date: '2026-09-27',
        recommendedDailyBudget: 50000,
        dailyAdvice: 'Saran hemat hari ini',
      });

      assert.strictEqual(hasValidCachedDailyAdvice(db, testUserId, '2026-09-27'), true);

      invalidateDailyAdviceCache(db, testUserId, '2026-09-27');

      // Without allowStale, should return null
      assert.strictEqual(getCachedDailyAdvice(db, { userId: testUserId, date: '2026-09-27', allowStale: false }), null);
      assert.strictEqual(hasValidCachedDailyAdvice(db, testUserId, '2026-09-27'), false);

      // With allowStale, returns row marked isStale = true
      const staleRow = getCachedDailyAdvice(db, { userId: testUserId, date: '2026-09-27', allowStale: true });
      assert.ok(staleRow);
      assert.strictEqual(staleRow.isStale, true);
    });

    test('deletes cached daily advice and cascades on user delete', () => {
      saveCachedDailyAdvice(db, {
        userId: testUserId,
        date: '2026-09-27',
        recommendedDailyBudget: 50000,
        dailyAdvice: 'Saran hemat',
      });

      deleteCachedDailyAdvice(db, testUserId, '2026-09-27');
      assert.strictEqual(getCachedDailyAdvice(db, { userId: testUserId, date: '2026-09-27', allowStale: true }), null);

      // Cascade test
      saveCachedDailyAdvice(db, {
        userId: testUserId,
        date: '2026-09-28',
        recommendedDailyBudget: 55000,
        dailyAdvice: 'Saran esok',
      });

      db.prepare('DELETE FROM users WHERE id = ?').run(testUserId);
      const count = db.prepare('SELECT COUNT(*) as count FROM daily_advice_cache WHERE user_id = ?').get(testUserId);
      assert.strictEqual(count.count, 0);
    });
  });

  describe('4. Migration Idempotency & Upgrade Compatibility', () => {
    test('runs migrations repeatedly without error or duplicating tables or columns', () => {
      assert.doesNotThrow(() => {
        runMigrations(db);
        runMigrations(db);
        ensureSaranHarianSchema(db);
      });

      const tipCount = db.prepare('SELECT COUNT(*) as count FROM daily_tips').get().count;
      assert.strictEqual(tipCount, defaultSavingTips.length);
    });
  });
});
