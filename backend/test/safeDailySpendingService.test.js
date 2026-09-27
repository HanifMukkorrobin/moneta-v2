import { test, describe, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import Database from 'better-sqlite3';
import { runMigrations } from '../src/db/migrate.js';
import {
  calculateSafeDailySpending,
  getSafeDailySpendingForUser,
  getDaysRemainingInMonth,
  getMonthDateMetrics,
  simulateSafeDailySpending,
} from '../src/services/safeDailySpendingService.js';
import { getCachedDailyAdvice } from '../src/services/dailyAdviceCacheService.js';

describe('Safe Daily Spending Service (Layanan Batas Aman Belanja Harian) Tests', () => {
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
    const res = userStmt.run('rina@example.com', 'Rina Wulandari', 'IDR');
    testUserId = res.lastInsertRowid;
  });

  afterEach(() => {
    if (db) {
      db.close();
    }
  });

  describe('1. Date Calculations & Remaining Days', () => {
    test('calculates days remaining in September correctly', () => {
      // 27 September 2026 -> 4 days remaining (27, 28, 29, 30)
      const days = getDaysRemainingInMonth('2026-09-27', { includeToday: true });
      assert.strictEqual(days, 4);

      // 30 September 2026 (last day) -> 1 day remaining
      const lastDay = getDaysRemainingInMonth('2026-09-30', { includeToday: true });
      assert.strictEqual(lastDay, 1);
    });

    test('handles leap year in February accurately', () => {
      // 2024 is leap year (29 days in Feb)
      const febDays = getDaysRemainingInMonth('2024-02-27', { includeToday: true });
      assert.strictEqual(febDays, 3); // 27, 28, 29

      // 2025 is not a leap year (28 days in Feb)
      const febNonLeap = getDaysRemainingInMonth('2025-02-27', { includeToday: true });
      assert.strictEqual(febNonLeap, 2); // 27, 28
    });

    test('returns month metrics correctly', () => {
      const metrics = getMonthDateMetrics('2026-09-27');
      assert.strictEqual(metrics.monthString, '2026-09');
      assert.strictEqual(metrics.daysInMonth, 30);
      assert.strictEqual(metrics.currentDay, 27);
    });
  });

  describe('2. calculateSafeDailySpending (Pure Calculation)', () => {
    test('calculates exact safe daily limit matching PRD & mock specifications (Rp 260.000 / 4 days = Rp 65.000)', () => {
      const result = calculateSafeDailySpending({
        remainingBudget: 260000,
        remainingDays: 4,
        todaySpent: 0,
        avgDailySpend: 60000,
        totalMonthlyBudget: 2000000,
        totalSpent: 1740000,
      });

      assert.strictEqual(result.safeDailyLimit, 65000);
      assert.strictEqual(result.formattedSafeDailyLimit, 'Rp 65.000 / hari');
      assert.strictEqual(result.remainingDays, 4);
      assert.strictEqual(result.todaySpent, 0);
      assert.strictEqual(result.todayRemainingAllowance, 65000);
      assert.strictEqual(result.isTodayOverLimit, false);
      assert.strictEqual(result.status, 'safe');
      assert.strictEqual(result.warnLevel, 'normal');

      // Check 50/30/20 bucket allocation
      assert.strictEqual(result.bucketAllocation.needs, 32500); // 50%
      assert.strictEqual(result.bucketAllocation.savings, 19500); // 30%
      assert.strictEqual(result.bucketAllocation.fun, 13000); // 20%
    });

    test('detects when today spending is within limit vs exceeding limit', () => {
      // Within limit: spent 20.000 of 65.000
      const within = calculateSafeDailySpending({
        remainingBudget: 260000,
        remainingDays: 4,
        todaySpent: 20000,
      });
      assert.strictEqual(within.todayRemainingAllowance, 45000);
      assert.strictEqual(within.isTodayOverLimit, false);
      assert.strictEqual(within.todayUsagePercentage, 31);

      // Exceeding limit: spent 85.000 of 65.000
      const over = calculateSafeDailySpending({
        remainingBudget: 260000,
        remainingDays: 4,
        todaySpent: 85000,
      });
      assert.strictEqual(over.todayRemainingAllowance, 0);
      assert.strictEqual(over.isTodayOverLimit, true);
      assert.strictEqual(over.todayOverLimitAmount, 20000);
      assert.strictEqual(over.status, 'warning');
      assert.strictEqual(over.warnLevel, 'warning');
      assert.ok(over.adviceMessage.includes('Batas Belanja Hari Ini Terlampaui') || over.adviceMessage.includes('melampaui batas aman'));
    });

    test('flags warning when 7-day average burn rate exceeds safe daily limit', () => {
      const result = calculateSafeDailySpending({
        remainingBudget: 200000,
        remainingDays: 5, // Safe limit = 40.000
        todaySpent: 10000,
        avgDailySpend: 65000, // Burning 65.000 vs 40.000 limit
      });

      assert.strictEqual(result.safeDailyLimit, 40000);
      assert.strictEqual(result.burnRateComparison.isExceedingSafeLimit, true);
      assert.strictEqual(result.burnRateComparison.difference, 25000);
      assert.strictEqual(result.status, 'warning');
      assert.strictEqual(result.warnLevel, 'warning');
    });

    test('handles exhausted budget and critical threshold', () => {
      // Exhausted budget
      const exhausted = calculateSafeDailySpending({
        remainingBudget: 0,
        remainingDays: 10,
        totalMonthlyBudget: 1500000,
      });
      assert.strictEqual(exhausted.safeDailyLimit, 0);
      assert.strictEqual(exhausted.status, 'exhausted');
      assert.strictEqual(exhausted.warnLevel, 'critical');

      // Critical low balance (< Rp 15.000/day)
      const critical = calculateSafeDailySpending({
        remainingBudget: 30000,
        remainingDays: 4, // 7.500 / day
      });
      assert.strictEqual(critical.safeDailyLimit, 7500);
      assert.strictEqual(critical.status, 'critical');
      assert.strictEqual(critical.warnLevel, 'critical');
    });

    test('handles no budget configured', () => {
      const noBudget = calculateSafeDailySpending({
        remainingBudget: 0,
        remainingDays: 10,
        totalMonthlyBudget: 0,
      });
      assert.strictEqual(noBudget.status, 'no_budget');
    });
  });

  describe('3. Database Integration: getSafeDailySpendingForUser', () => {
    test('reads actual monthly budget, transactions, and auto-caches advice', () => {
      // 1. Create monthly budget for 2026-09
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount, needs_pct, savings_pct, fun_pct)
        VALUES (?, '2026-09', 2000000, 50, 30, 20)
      `).run(testUserId);

      // 2. Add past transactions in September (total 1.700.000)
      const insertTx = db.prepare(`
        INSERT INTO transactions (user_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, 'expense', ?, ?, ?, 1)
      `);

      insertTx.run(testUserId, 1000000, 'Belanja bulanan', '2026-09-05 10:00:00');
      insertTx.run(testUserId, 500000, 'Bayar listrik & internet', '2026-09-12 11:00:00');
      insertTx.run(testUserId, 200000, 'Makan sepekan', '2026-09-20 12:00:00');

      // 3. Add today transaction (2026-09-27) of 40.000
      insertTx.run(testUserId, 40000, 'Makan siang & kopi', '2026-09-27 12:30:00');

      // 4. Run service for user on 2026-09-27
      const result = getSafeDailySpendingForUser(db, {
        userId: testUserId,
        referenceDate: '2026-09-27',
        autoCache: true,
      });

      // Total spent = 1.000.000 + 500.000 + 200.000 + 40.000 = 1.740.000
      // Remaining budget = 2.000.000 - 1.740.000 = 260.000
      // Days left in Sep (from 27 to 30) = 4 days
      // Safe daily limit = 260.000 / 4 = 65.000 / day
      assert.strictEqual(result.totalMonthlyBudget, 2000000);
      assert.strictEqual(result.totalSpent, 1740000);
      assert.strictEqual(result.remainingBudget, 260000);
      assert.strictEqual(result.remainingDays, 4);
      assert.strictEqual(result.safeDailyLimit, 65000);
      assert.strictEqual(result.todaySpent, 40000);
      assert.strictEqual(result.todayRemainingAllowance, 25000); // 65.000 - 40.000
      assert.strictEqual(result.isTodayOverLimit, false);

      // Verify autoCache saved to daily_advice_cache
      const cached = getCachedDailyAdvice(db, { userId: testUserId, date: '2026-09-27' });
      assert.ok(cached);
      assert.strictEqual(cached.recommendedDailyBudget, 65000);
      assert.strictEqual(cached.estimatedDaysLeft, 4);
      assert.strictEqual(cached.totalMonthlyBudget, 2000000);
      assert.strictEqual(cached.totalSpent, 1740000);
    });

    test('falls back to income balance when user has no explicit monthly budget', () => {
      // Add income transaction of 3.000.000 in 2026-09
      db.prepare(`
        INSERT INTO transactions (user_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, 'income', 3000000, 'Gaji Pokok', '2026-09-01 08:00:00', 1)
      `).run(testUserId);

      // Add expense transaction of 1.000.000
      db.prepare(`
        INSERT INTO transactions (user_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, 'expense', 1000000, 'Belanja Awal Bulan', '2026-09-05 10:00:00', 1)
      `).run(testUserId);

      const result = getSafeDailySpendingForUser(db, {
        userId: testUserId,
        referenceDate: '2026-09-20',
      });

      // Remaining = 3.000.000 - 1.000.000 = 2.000.000
      // Days left in Sep (from 20 to 30) = 11 days
      // Safe daily limit = 2.000.000 / 11 = 181.818
      assert.strictEqual(result.totalIncome, 3000000);
      assert.strictEqual(result.totalSpent, 1000000);
      assert.strictEqual(result.remainingBudget, 2000000);
      assert.strictEqual(result.remainingDays, 11);
      assert.strictEqual(result.safeDailyLimit, Math.floor(2000000 / 11));
    });
  });

  describe('4. Simulation (simulateSafeDailySpending)', () => {
    test('simulates survival days under different spending paces', () => {
      const sim = simulateSafeDailySpending({
        remainingBudget: 500000,
        remainingDays: 10,
        simulatedDailySpend: 50000,
      });

      assert.strictEqual(sim.safeDailyLimit, 50000);
      assert.strictEqual(sim.simulatedDaysSurvival, 10);
      assert.strictEqual(sim.survivesUntilMonthEnd, true);

      // Slower spending: survives longer
      const slowSim = simulateSafeDailySpending({
        remainingBudget: 500000,
        remainingDays: 10,
        simulatedDailySpend: 25000,
      });
      assert.strictEqual(slowSim.simulatedDaysSurvival, 20);
      assert.strictEqual(slowSim.survivesUntilMonthEnd, true);

      // Faster spending: runs out early
      const fastSim = simulateSafeDailySpending({
        remainingBudget: 500000,
        remainingDays: 10,
        simulatedDailySpend: 100000,
      });
      assert.strictEqual(fastSim.simulatedDaysSurvival, 5);
      assert.strictEqual(fastSim.survivesUntilMonthEnd, false);
    });
  });
});
