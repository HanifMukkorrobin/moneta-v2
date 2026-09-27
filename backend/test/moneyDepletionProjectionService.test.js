import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { createDatabaseConnection } from '../src/config/database.js';
import { runMigrations } from '../src/db/migrate.js';
import {
  calculateMoneyDepletionProjection,
  calculateDaysUntilEndOfMonth,
  simulateDepletion,
  formatIndonesianDate,
  formatShortIndonesianDate,
  getOrUpdateCachedDepletionProjection,
} from '../src/services/moneyDepletionProjectionService.js';

describe('Money Depletion Projection Service (Perkiraan Uang Bertahan & Tanggal Habis) Tests', () => {
  let db;
  let testUserId;
  let makanCatId;
  let gajiCatId;

  beforeEach(() => {
    db = createDatabaseConnection({ path: ':memory:' });
    runMigrations(db);

    const user = db.prepare("INSERT INTO users (email) VALUES ('depletion_user@example.com')").run();
    testUserId = user.lastInsertRowid;

    makanCatId = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get().id;
    gajiCatId = db.prepare("SELECT id FROM categories WHERE name = 'Gaji' AND type = 'income'").get().id;
  });

  afterEach(() => {
    if (db) {
      db.close();
    }
  });

  describe('1. Date Formatting & Days in Month Helpers', () => {
    it('formats date in full Indonesian format and short Indonesian format', () => {
      const date = new Date('2026-10-18T12:00:00');
      assert.equal(formatIndonesianDate(date), '18 Oktober 2026');
      assert.equal(formatShortIndonesianDate(date), '18 Okt 2026');

      const dateJan = new Date('2027-01-05T12:00:00');
      assert.equal(formatIndonesianDate(dateJan), '5 Januari 2027');
      assert.equal(formatShortIndonesianDate(dateJan), '5 Jan 2027');
    });

    it('calculates days until end of month accurately', () => {
      // September has 30 days. On Sept 12, remaining days = 30 - 12 = 18 days
      const sept12 = new Date('2026-09-12T12:00:00');
      assert.equal(calculateDaysUntilEndOfMonth(sept12), 18);

      // On Sept 30 (last day of month), minimum is 1
      const sept30 = new Date('2026-09-30T12:00:00');
      assert.equal(calculateDaysUntilEndOfMonth(sept30), 1);
    });
  });

  describe('2. Normal / Safe Financial Condition', () => {
    it('projects safe depletion date beyond month-end when remaining balance exceeds spending pace', () => {
      // Monthly Budget: Rp 6.000.000 for 2026-09
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount, needs_pct, savings_pct, fun_pct)
        VALUES (?, '2026-09', 6000000, 50, 30, 20)
      `).run(testUserId);

      // Spent: Rp 2.850.000 -> Remaining: Rp 3.150.000
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 2850000, 'Belanja bulanan', '2026-09-10 12:00:00', 1)
      `).run(testUserId, makanCatId);

      // Reference date: 2026-09-12 (18 days left in month)
      // avgDailySpend: Rp 78.500
      // estimatedDaysLeft: floor(3.150.000 / 78.500) = 40 days
      const projection = calculateMoneyDepletionProjection(db, {
        userId: testUserId,
        referenceDate: '2026-09-12',
        avgDailySpend: 78500,
      });

      assert.equal(projection.remainingBalance, 3150000);
      assert.equal(projection.avgDailySpend, 78500);
      assert.equal(projection.estimatedDaysLeft, 40);
      assert.equal(projection.runsOutBeforeEndOfMonth, false);
      assert.equal(projection.warnLevel, 'normal');
      assert.equal(projection.isNormal, true);
      assert.equal(projection.isWarning, false);
      assert.equal(projection.isCritical, false);

      // Depletion date: 2026-09-12 + 40 days = 2026-10-22
      assert.equal(projection.depletionDate, '2026-10-22');
      assert.equal(projection.formattedDepletionDate, '22 Oktober 2026');
      assert.ok(projection.depletionStatusMessage.includes('Aman melampaui akhir bulan'));
      assert.ok(projection.depletionStatusMessage.includes('+22 hari'));
    });
  });

  describe('3. Warning Condition (Runs Out Early)', () => {
    it('detects early depletion when remaining budget runs out before end of month', () => {
      // Monthly Budget: Rp 6.000.000 for 2026-09
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount, needs_pct, savings_pct, fun_pct)
        VALUES (?, '2026-09', 6000000, 50, 30, 20)
      `).run(testUserId);

      // Spent: Rp 4.800.000 -> Remaining: Rp 1.200.000
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 4800000, 'Belanja tinggi', '2026-09-10 12:00:00', 1)
      `).run(testUserId, makanCatId);

      // Reference date: 2026-09-12 (18 days left in month)
      // avgDailySpend: Rp 135.000
      // estimatedDaysLeft: floor(1.200.000 / 135.000) = 8 days
      // 8 < 18 -> runsOutBeforeEndOfMonth = true, difference = 10 days
      const projection = calculateMoneyDepletionProjection(db, {
        userId: testUserId,
        referenceDate: '2026-09-12',
        avgDailySpend: 135000,
      });

      assert.equal(projection.remainingBalance, 1200000);
      assert.equal(projection.estimatedDaysLeft, 8);
      assert.equal(projection.runsOutBeforeEndOfMonth, true);
      assert.equal(projection.warnLevel, 'warning');
      assert.equal(projection.isWarning, true);

      // Depletion date: 2026-09-12 + 8 days = 2026-09-20
      assert.equal(projection.depletionDate, '2026-09-20');
      assert.equal(projection.formattedDepletionDate, '20 September 2026');
      assert.equal(projection.depletionStatusMessage, 'Habis 10 hari sebelum akhir bulan');
    });
  });

  describe('4. Critical Condition (Depletes in <= 3 Days or Deficit)', () => {
    it('marks critical condition when money depletes within 3 days', () => {
      // Monthly Budget: Rp 6.000.000
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount, needs_pct, savings_pct, fun_pct)
        VALUES (?, '2026-09', 6000000, 50, 30, 20)
      `).run(testUserId);

      // Spent: Rp 5.650.000 -> Remaining: Rp 350.000
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 5650000, 'Pengeluaran kritis', '2026-09-10 12:00:00', 1)
      `).run(testUserId, makanCatId);

      // Daily spend: Rp 215.000 -> floor(350.000 / 215.000) = 1 day
      const projection = calculateMoneyDepletionProjection(db, {
        userId: testUserId,
        referenceDate: '2026-09-12',
        avgDailySpend: 215000,
      });

      assert.equal(projection.remainingBalance, 350000);
      assert.equal(projection.estimatedDaysLeft, 1);
      assert.equal(projection.warnLevel, 'critical');
      assert.equal(projection.isCritical, true);
    });

    it('handles zero or negative balance as critical with 0 days left', () => {
      // Spent Rp 7.000.000 against Rp 6.000.000 budget -> Over budget by Rp 1.000.000
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 6000000)
      `).run(testUserId);

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 7000000, 'Over budget', '2026-09-10 12:00:00', 1)
      `).run(testUserId, makanCatId);

      const projection = calculateMoneyDepletionProjection(db, {
        userId: testUserId,
        referenceDate: '2026-09-12',
        avgDailySpend: 100000,
      });

      assert.equal(projection.remainingBalance, -1000000);
      assert.equal(projection.estimatedDaysLeft, 0);
      assert.equal(projection.warnLevel, 'critical');
      assert.equal(projection.isCritical, true);
      assert.ok(projection.depletionStatusMessage.includes('habis'));
    });
  });

  describe('5. Fallback When No Monthly Budget Set', () => {
    it('calculates remaining balance from net income - expense when no budget is defined', () => {
      // Income: Rp 8.000.000, Expense: Rp 3.000.000 -> Net Balance: Rp 5.000.000
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES
          (?, ?, 'income', 8000000, 'Gaji', '2026-09-01 09:00:00', 1),
          (?, ?, 'expense', 3000000, 'Makan & Belanja', '2026-09-10 12:00:00', 1)
      `).run(testUserId, gajiCatId, testUserId, makanCatId);

      // Daily spend Rp 100.000 -> floor(5.000.000 / 100.000) = 50 days
      const projection = calculateMoneyDepletionProjection(db, {
        userId: testUserId,
        referenceDate: '2026-09-15',
        avgDailySpend: 100000,
      });

      assert.equal(projection.hasBudget, false);
      assert.equal(projection.remainingBalance, 5000000);
      assert.equal(projection.estimatedDaysLeft, 50);
      assert.equal(projection.warnLevel, 'normal');
    });
  });

  describe('6. What-If Simulation', () => {
    it('simulates days left and depletion date with altered daily spend', () => {
      const sim = simulateDepletion({
        dailySpend: 50000,
        remainingBalance: 1500000,
        referenceDate: '2026-09-10',
      });

      assert.equal(sim.simulatedDailySpend, 50000);
      assert.equal(sim.formattedSimulatedDailySpend, 'Rp 50.000');
      assert.equal(sim.simulatedDaysLeft, 30); // 1.500.000 / 50.000 = 30 days
      assert.equal(sim.simulatedDate, '2026-10-10');
      assert.equal(sim.formattedSimulatedDate, '10 Oktober 2026');
      assert.equal(sim.runsOutBeforeEndOfMonth, false);
    });
  });

  describe('7. Cache Synchronization with ai_insights', () => {
    it('persists depletion projection to ai_insights cache and serves from cache', () => {
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 5000000)
      `).run(testUserId);

      db.prepare(`
        INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'expense', 2000000, 'Pengeluaran', '2026-09-15 12:00:00', 1)
      `).run(testUserId, makanCatId);

      // Call 1: uncached, saves to ai_insights
      const res1 = getOrUpdateCachedDepletionProjection(db, {
        userId: testUserId,
        referenceDate: '2026-09-15',
      });
      assert.equal(res1.fromCache, false);
      assert.ok(res1.depletionDate);

      // Verify row in ai_insights
      const cacheRow = db.prepare("SELECT * FROM ai_insights WHERE user_id = ? AND date = '2026-09-15'").get(testUserId);
      assert.ok(cacheRow);
      assert.equal(cacheRow.estimated_days_left, res1.estimatedDaysLeft);
      assert.equal(cacheRow.warn_level, res1.warnLevel);

      // Call 2: served from cache
      const res2 = getOrUpdateCachedDepletionProjection(db, {
        userId: testUserId,
        referenceDate: '2026-09-15',
      });
      assert.equal(res2.fromCache, true);
      assert.equal(res2.estimatedDaysLeft, res1.estimatedDaysLeft);
    });
  });
});
