import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { createDatabaseConnection } from '../src/config/database.js';
import { runMigrations } from '../src/db/migrate.js';
import {
  calculateDailyAverageSpending,
  calculateMonthToDateDailyAverage,
  getOrUpdateCachedDailyAverage,
  formatRupiah,
  formatCompactRupiah,
  getDayName,
  getDayShortLabel,
} from '../src/services/dailyAverageSpendingService.js';

describe('Daily Average Spending Service (Hitung Rata-rata Pengeluaran Harian) Tests', () => {
  let db;
  let testUserId;
  let otherUserId;
  let makanCatId;
  let transportCatId;
  let gajiCatId;

  beforeEach(() => {
    db = createDatabaseConnection({ path: ':memory:' });
    runMigrations(db);

    const user1 = db.prepare("INSERT INTO users (email) VALUES ('daily_avg_user1@example.com')").run();
    testUserId = user1.lastInsertRowid;

    const user2 = db.prepare("INSERT INTO users (email) VALUES ('daily_avg_user2@example.com')").run();
    otherUserId = user2.lastInsertRowid;

    makanCatId = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get().id;
    transportCatId = db.prepare("SELECT id FROM categories WHERE name = 'Transportasi' AND type = 'expense'").get().id;
    gajiCatId = db.prepare("SELECT id FROM categories WHERE name = 'Gaji' AND type = 'income'").get().id;
  });

  afterEach(() => {
    if (db) {
      db.close();
    }
  });

  describe('1. Currency & Date Formatting Helpers', () => {
    it('formats rupiah correctly for positive, zero, and negative values', () => {
      assert.equal(formatRupiah(78500), 'Rp 78.500');
      assert.equal(formatRupiah(0), 'Rp 0');
      assert.equal(formatRupiah(1500000), 'Rp 1.500.000');
      assert.equal(formatRupiah(-50000), '- Rp 50.000');
    });

    it('formats compact rupiah for bar charts', () => {
      assert.equal(formatCompactRupiah(65000), '65rb');
      assert.equal(formatCompactRupiah(1500000), '1.5jt');
      assert.equal(formatCompactRupiah(2500000000), '2.5M');
      assert.equal(formatCompactRupiah(850), '850');
      assert.equal(formatCompactRupiah(65000, true), 'Rp 65rb');
    });

    it('returns Indonesian day names and short labels', () => {
      // 2026-09-27 is Sunday (Minggu)
      const sunday = new Date('2026-09-27T12:00:00');
      assert.equal(getDayName(sunday), 'Minggu');
      assert.equal(getDayShortLabel(sunday), 'Min');

      // 2026-09-28 is Monday (Senin)
      const monday = new Date('2026-09-28T12:00:00');
      assert.equal(getDayName(monday), 'Senin');
      assert.equal(getDayShortLabel(monday), 'Sen');
    });
  });

  describe('2. Empty State / Zero Spending Handling', () => {
    it('returns structured empty analysis with 0 amounts and 7 daily points when no transactions exist', () => {
      const result = calculateDailyAverageSpending(db, {
        userId: testUserId,
        days: 7,
        referenceDate: '2026-09-27',
      });

      assert.equal(result.userId, testUserId);
      assert.equal(result.days, 7);
      assert.equal(result.totalSpent, 0);
      assert.equal(result.avgDailySpend, 0);
      assert.equal(result.formattedAvgDailySpend, 'Rp 0');
      assert.equal(result.highestSpendAmount, 0);
      assert.equal(result.lowestSpendAmount, 0);
      assert.equal(result.dailyPoints.length, 7);
      assert.equal(result.topCategoryPercentage, 0);
      assert.equal(result.weekOverWeekPercent, 0);
      assert.equal(result.isSpendingIncreasing, false);
      assert.equal(result.isAboveTarget, false);
    });
  });

  describe('3. 7-Day Daily Spending Calculation & Metrics', () => {
    it('accurately calculates 7-day average, daily points, highest, lowest, and top category', () => {
      // Seed 7 days of expenses: 2026-09-21 to 2026-09-27
      // 2026-09-21 (Sen): 60.000 Makan
      // 2026-09-22 (Sel): 35.000 Transport
      // 2026-09-23 (Rab): 90.000 Makan
      // 2026-09-24 (Kam): 70.000 Makan
      // 2026-09-25 (Jum): 100.000 Makan
      // 2026-09-26 (Sab): 145.000 Makan (highest)
      // 2026-09-27 (Min): 50.000 Transport (reference date)
      // Total = 550.000 -> 7-day avg = 550.000 / 7 = 78.571 -> rounded to 78.571
      const insertStmt = db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, ?, 'expense', ?, 'Pengeluaran', ?, 1)
      `);

      insertStmt.run(testUserId, makanCatId, 'Makan & Minuman', 60000, '2026-09-21 12:00:00');
      insertStmt.run(testUserId, transportCatId, 'Transportasi', 35000, '2026-09-22 08:00:00');
      insertStmt.run(testUserId, makanCatId, 'Makan & Minuman', 90000, '2026-09-23 13:00:00');
      insertStmt.run(testUserId, makanCatId, 'Makan & Minuman', 70000, '2026-09-24 19:00:00');
      insertStmt.run(testUserId, makanCatId, 'Makan & Minuman', 100000, '2026-09-25 12:30:00');
      insertStmt.run(testUserId, makanCatId, 'Makan & Minuman', 145000, '2026-09-26 20:00:00');
      insertStmt.run(testUserId, transportCatId, 'Transportasi', 50000, '2026-09-27 10:00:00');

      // Also seed an income transaction (Rp 5.000.000) and an unconfirmed transaction - should be excluded
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES
          (?, ?, 'income', 5000000, 'Gaji', '2026-09-25 09:00:00', 1),
          (?, ?, 'expense', 200000, 'Belum konfirmasi', '2026-09-26 15:00:00', 0)
      `).run(testUserId, gajiCatId, testUserId, makanCatId);

      // Seed another user's transactions - should be isolated
      insertStmt.run(otherUserId, makanCatId, 'Makan & Minuman', 999999, '2026-09-26 12:00:00');

      const result = calculateDailyAverageSpending(db, {
        userId: testUserId,
        days: 7,
        referenceDate: '2026-09-27',
      });

      assert.equal(result.totalSpent, 550000);
      assert.equal(result.avgDailySpend, 78571); // 550000 / 7
      assert.equal(result.formattedAvgDailySpend, 'Rp 78.571');

      // Check highest and lowest spend
      assert.equal(result.highestSpendAmount, 145000);
      assert.equal(result.highestSpendDay, 'Sabtu');
      assert.equal(result.highestSpendDate, '2026-09-26');
      assert.equal(result.formattedHighestSpend, 'Rp 145.000');

      assert.equal(result.lowestSpendAmount, 35000);
      assert.equal(result.lowestSpendDay, 'Selasa');
      assert.equal(result.lowestSpendDate, '2026-09-22');
      assert.equal(result.formattedLowestSpend, 'Rp 35.000');

      // Check top category
      // Makan total = 60 + 90 + 70 + 100 + 145 = 465.000 (84.5% of 550.000)
      assert.equal(result.topCategoryName, 'Makan & Minuman');
      assert.equal(result.topCategoryAmount, 465000);
      assert.equal(result.topCategoryPercentage, 84.5);

      // Check 7 daily points and isAboveAverage flags
      assert.equal(result.dailyPoints.length, 7);
      const sabtuPoint = result.dailyPoints.find((p) => p.dayName === 'Sabtu');
      assert.ok(sabtuPoint);
      assert.equal(sabtuPoint.amount, 145000);
      assert.equal(sabtuPoint.isAboveAverage, true); // 145.000 > 78.571

      const selasaPoint = result.dailyPoints.find((p) => p.dayName === 'Selasa');
      assert.ok(selasaPoint);
      assert.equal(selasaPoint.amount, 35000);
      assert.equal(selasaPoint.isAboveAverage, false); // 35.000 < 78.571
    });
  });

  describe('4. Week-over-Week (WoW) Comparison', () => {
    it('detects spending increase and computes WoW percentage', () => {
      // Previous week: 2026-09-14 to 2026-09-20 -> Total 400.000
      // Current week: 2026-09-21 to 2026-09-27 -> Total 500.000
      // WoW change: ((500.000 - 400.000) / 400.000) * 100 = +25.0%
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES
          (?, ?, 'expense', 400000, 'Minggu lalu', '2026-09-17 12:00:00', 1),
          (?, ?, 'expense', 500000, 'Minggu ini', '2026-09-24 12:00:00', 1)
      `).run(testUserId, makanCatId, testUserId, makanCatId);

      const result = calculateDailyAverageSpending(db, {
        userId: testUserId,
        days: 7,
        referenceDate: '2026-09-27',
      });

      assert.equal(result.weekOverWeekPercent, 25.0);
      assert.equal(result.isSpendingIncreasing, true);
      assert.equal(result.comparisonBadgeLabel, '+25.0% vs pekan lalu');
    });

    it('detects spending decrease when current week is lower than previous week', () => {
      // Previous week: 500.000
      // Current week: 350.000
      // WoW change: ((350.000 - 500.000) / 500.000) * 100 = -30.0%
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES
          (?, ?, 'expense', 500000, 'Minggu lalu', '2026-09-17 12:00:00', 1),
          (?, ?, 'expense', 350000, 'Minggu ini', '2026-09-24 12:00:00', 1)
      `).run(testUserId, makanCatId, testUserId, makanCatId);

      const result = calculateDailyAverageSpending(db, {
        userId: testUserId,
        days: 7,
        referenceDate: '2026-09-27',
      });

      assert.equal(result.weekOverWeekPercent, -30.0);
      assert.equal(result.isSpendingIncreasing, false);
      assert.equal(result.comparisonBadgeLabel, '-30.0% vs pekan lalu');
    });
  });

  describe('5. Monthly Budget Target Integration', () => {
    it('compares daily average against monthly budget targetDailySpend', () => {
      // Set monthly budget Rp 2.100.000 for 2026-09 (30 days) -> target = Rp 70.000 / hari
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount, needs_pct, savings_pct, fun_pct)
        VALUES (?, '2026-09', 2100000, 50, 30, 20)
      `).run(testUserId);

      // Spend Rp 700.000 across 7 days -> avg = 100.000 / hari
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 700000, 'Belanja mingguan', '2026-09-25 12:00:00', 1)
      `).run(testUserId, makanCatId);

      const result = calculateDailyAverageSpending(db, {
        userId: testUserId,
        days: 7,
        referenceDate: '2026-09-27',
      });

      assert.equal(result.targetDailySpend, 70000); // 2.100.000 / 30
      assert.equal(result.formattedTargetDailySpend, 'Rp 70.000');
      assert.equal(result.avgDailySpend, 100000);
      assert.equal(result.isAboveTarget, true); // 100.000 > 70.000
    });
  });

  describe('6. Month-To-Date (MTD) Daily Average', () => {
    it('computes month-to-date daily average and projects month-end total expense', () => {
      // In September 2026 (30 days total), reference date 2026-09-15 (day 15 elapsed)
      // Total spent = Rp 1.500.000
      // Daily avg = 1.500.000 / 15 = 100.000 / hari
      // Projected month-end = 100.000 * 30 = Rp 3.000.000
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 1500000, 'MTD spend', '2026-09-10 12:00:00', 1)
      `).run(testUserId, makanCatId);

      const mtd = calculateMonthToDateDailyAverage(db, {
        userId: testUserId,
        month: '2026-09',
        referenceDate: '2026-09-15',
      });

      assert.equal(mtd.daysInMonth, 30);
      assert.equal(mtd.daysElapsed, 15);
      assert.equal(mtd.remainingDays, 15);
      assert.equal(mtd.totalSpent, 1500000);
      assert.equal(mtd.avgDailySpend, 100000);
      assert.equal(mtd.projectedMonthExpense, 3000000);
      assert.equal(mtd.formattedAvgDailySpend, 'Rp 100.000');
      assert.equal(mtd.formattedProjectedMonthExpense, 'Rp 3.000.000');
    });
  });

  describe('7. Cache Integration with ai_insights & financial_analysis_cache', () => {
    it('caches analysis in ai_insights and serves from cache on repeated calls', () => {
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 140000, 'Kopi dan makan', '2026-09-27 12:00:00', 1)
      `).run(testUserId, makanCatId);

      // First call: calculates and saves to cache
      const call1 = getOrUpdateCachedDailyAverage(db, {
        userId: testUserId,
        days: 7,
        referenceDate: '2026-09-27',
      });
      assert.equal(call1.fromCache, false);
      assert.equal(call1.totalSpent, 140000);
      assert.equal(call1.avgDailySpend, 20000); // 140.000 / 7

      // Verify row in ai_insights table
      const insightRow = db.prepare("SELECT * FROM ai_insights WHERE user_id = ? AND date = '2026-09-27'").get(testUserId);
      assert.ok(insightRow);
      assert.equal(insightRow.avg_daily_spend, 20000);

      // Second call: serves from cache
      const call2 = getOrUpdateCachedDailyAverage(db, {
        userId: testUserId,
        days: 7,
        referenceDate: '2026-09-27',
      });
      assert.equal(call2.fromCache, true);
      assert.equal(call2.avgDailySpend, 20000);

      // Third call with forceRefresh: true -> recalculates
      const call3 = getOrUpdateCachedDailyAverage(db, {
        userId: testUserId,
        days: 7,
        referenceDate: '2026-09-27',
        forceRefresh: true,
      });
      assert.equal(call3.fromCache, false);
      assert.equal(call3.avgDailySpend, 20000);
    });
  });
});
