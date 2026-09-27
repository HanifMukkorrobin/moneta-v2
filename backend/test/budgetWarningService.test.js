import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import {
  detectBudgetWarningThreshold,
  getBudgetWarningStatusQuery,
  updateBudgetAlertSettings,
  upsertMonthlyBudgetLimit,
  deleteMonthlyBudgetLimit,
} from '../src/services/budgetService.js';

describe('Budget Warning Threshold Detection Service & Alert Settings Endpoints', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  const testMonth = '2026-10';

  before(async () => {
    db = getDatabase();
    const userRes = db
      .prepare("INSERT INTO users (email, display_name) VALUES (?, 'Warning Threshold Tester')")
      .run(`warning_tester_${Date.now()}@example.com`);
    testUserId = Number(userRes.lastInsertRowid);

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  beforeEach(() => {
    db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
    db.prepare('DELETE FROM budgets WHERE user_id = ?').run(testUserId);
    db.prepare('DELETE FROM monthly_budgets WHERE user_id = ?').run(testUserId);
  });

  after(async () => {
    if (testUserId && db) {
      db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM budgets WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM monthly_budgets WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM users WHERE id = ?').run(testUserId);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('detectBudgetWarningThreshold pure service handles none, nearLimit, overLimit, and disabled states', () => {
    // 1. Safe usage (< threshold)
    const safe = detectBudgetWarningThreshold({
      totalBudget: 5000000,
      totalSpent: 2500000, // 50%
      alertThreshold: 80,
      isAlertEnabled: true,
      isOverBudgetAlertEnabled: true,
      isPushNotificationEnabled: false,
    });
    assert.equal(safe.warningLevel, 'none');
    assert.equal(safe.shouldShowWarningBanner, false);
    assert.equal(safe.percentageUsed, 50);
    assert.equal(safe.alertThreshold, 80);
    assert.deepEqual(safe.thresholdOptions, [80, 85, 90]);
    assert.match(safe.alertCardStatusText, /Peringatan aktif: Anda akan diberi peringatan saat pengeluaran mencapai 80% dari plafon/);

    // 2. Near limit (>= threshold, <= 100%)
    const near = detectBudgetWarningThreshold({
      totalBudget: 5000000,
      totalSpent: 4250000, // 85%
      alertThreshold: 80,
      isAlertEnabled: true,
      isOverBudgetAlertEnabled: true,
    });
    assert.equal(near.warningLevel, 'nearLimit');
    assert.equal(near.isNearLimit, true);
    assert.equal(near.isOverLimit, false);
    assert.equal(near.shouldShowWarningBanner, true);
    assert.equal(near.bannerTitle, 'Peringatan: Budget Mendekati Batas!');
    assert.match(near.bannerMessage, /mencapai 85\.0% dari plafon/);
    assert.match(near.bannerMessage, /Rp 750\.000/);

    // 3. Over limit (> 100%) with bucket overages
    const over = detectBudgetWarningThreshold({
      totalBudget: 5000000,
      totalSpent: 5400000, // 108%
      alertThreshold: 85,
      isAlertEnabled: true,
      isOverBudgetAlertEnabled: true,
      buckets: [
        { key: 'needs', title: 'Kebutuhan Pokok', allocatedAmount: 2500000, spentAmount: 2900000 },
        { key: 'savings', title: 'Tabungan & Investasi', allocatedAmount: 1500000, spentAmount: 1000000 },
        { key: 'fun', title: 'Hiburan & Gaya Hidup', allocatedAmount: 1000000, spentAmount: 1500000 },
      ],
    });
    assert.equal(over.warningLevel, 'overLimit');
    assert.equal(over.isOverLimit, true);
    assert.equal(over.shouldShowWarningBanner, true);
    assert.equal(over.overBudgetAmount, 400000);
    assert.equal(over.bannerTitle, 'Perhatian: Budget Melewati Batas!');
    assert.match(over.bannerMessage, /Rp 400\.000/);
    assert.deepEqual(over.overLimitBucketTitles, ['Kebutuhan Pokok', 'Hiburan & Gaya Hidup']);
    assert.equal(over.affectedBucketsLabel, 'Pos melebihi limit: Kebutuhan Pokok, Hiburan & Gaya Hidup');

    // 4. Master alert switch disabled suppresses warning banner
    const disabled = detectBudgetWarningThreshold({
      totalBudget: 5000000,
      totalSpent: 4500000, // 90%
      alertThreshold: 80,
      isAlertEnabled: false,
    });
    assert.equal(disabled.warningLevel, 'none');
    assert.equal(disabled.shouldShowWarningBanner, false);
    assert.match(disabled.alertCardStatusText, /Peringatan budget sedang dinonaktifkan/);
  });

  it('getBudgetWarningStatusQuery & updateBudgetAlertSettings persist settings and detect real transaction spend', () => {
    upsertMonthlyBudgetLimit(db, testUserId, {
      month: testMonth,
      totalAmount: 4000000,
      needsPct: 50,
      savingsPct: 30,
      funPct: 20,
      alertThreshold: 80,
      isAlertEnabled: true,
    });

    const makanCat = db
      .prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'")
      .get();
    const hiburanCat = db
      .prepare("SELECT id FROM categories WHERE name = 'Hiburan' AND type = 'expense'")
      .get();

    // Insert expense transactions totaling Rp 3.400.000 (85% of Rp 4.000.000)
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES
        (?, ?, 'Makan & Minuman', 'expense', 2200000, 'Belanja bulanan', '2026-10-05 12:00:00', 1),
        (?, ?, 'Hiburan', 'expense', 1200000, 'Konser & nongkrong', '2026-10-12 19:00:00', 1)
    `).run(testUserId, makanCat.id, testUserId, hiburanCat.id);

    // At 80% threshold, 85% usage triggers nearLimit
    const status80 = getBudgetWarningStatusQuery(db, testUserId, { month: testMonth });
    assert.equal(status80.warningLevel, 'nearLimit');
    assert.equal(status80.shouldShowWarningBanner, true);
    assert.equal(status80.percentageUsed, 85);
    assert.deepEqual(status80.overLimitBucketTitles, ['Kebutuhan Pokok', 'Hiburan & Keinginan']);

    // Update threshold to 90% -> 85% usage is now below 90% threshold ('none')
    const updated90 = updateBudgetAlertSettings(db, testUserId, {
      month: testMonth,
      alertThreshold: 90,
      isPushNotificationEnabled: true,
    });
    assert.equal(updated90.alertThreshold, 90);
    assert.equal(updated90.isPushNotificationEnabled, true);
    assert.equal(updated90.warningLevel, 'none');
    assert.equal(updated90.shouldShowWarningBanner, false);

    // Add another Rp 800.000 expense -> total Rp 4.200.000 (105% of Rp 4.000.000) -> overLimit
    db.prepare(`
      INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
      VALUES (?, ?, 'Makan & Minuman', 'expense', 800000, 'Belanja tambahan', '2026-10-18 15:00:00', 1)
    `).run(testUserId, makanCat.id);

    const statusOver = getBudgetWarningStatusQuery(db, testUserId, { month: testMonth });
    assert.equal(statusOver.warningLevel, 'overLimit');
    assert.equal(statusOver.isOverLimit, true);
    assert.equal(statusOver.overBudgetAmount, 200000);
    assert.equal(statusOver.shouldShowWarningBanner, true);

    deleteMonthlyBudgetLimit(db, testUserId, { month: testMonth });
  });

  it('HTTP endpoints GET & PUT /api/budgets/warnings and /api/budgets/alert-settings work end-to-end', async () => {
    const createRes = await fetch(`${baseUrl}/api/budgets/monthly`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        totalAmount: 5000000,
        alertThreshold: 80,
        isAlertEnabled: true,
      }),
    });
    assert.equal(createRes.status, 201);

    // Preview warning with simulated totalSpent via query param
    const getNearRes = await fetch(
      `${baseUrl}/api/budgets/warnings?userId=${testUserId}&month=${testMonth}&totalSpent=4200000`
    );
    assert.equal(getNearRes.status, 200);
    const getNearBody = await getNearRes.json();

    assert.equal(getNearBody.success, true);
    assert.equal(getNearBody.warningLevel, 'nearLimit');
    assert.equal(getNearBody.shouldShowWarningBanner, true);
    assert.equal(getNearBody.percentageUsed, 84);

    // Update alert threshold to 85% via PUT /api/budgets/alert-settings
    const putSettingsRes = await fetch(`${baseUrl}/api/budgets/alert-settings`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        alertThreshold: 85,
        isOverBudgetAlertEnabled: true,
        isPushNotificationEnabled: true,
      }),
    });
    assert.equal(putSettingsRes.status, 200);
    const putSettingsBody = await putSettingsRes.json();

    assert.equal(putSettingsBody.success, true);
    assert.equal(putSettingsBody.alertThreshold, 85);
    assert.equal(putSettingsBody.isPushNotificationEnabled, true);
    assert.match(putSettingsBody.message, /85%/);

    // Validate invalid threshold returns 400
    const invalidRes = await fetch(`${baseUrl}/api/budgets/alert-settings`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        alertThreshold: 120,
      }),
    });
    assert.equal(invalidRes.status, 400);
    const invalidBody = await invalidRes.json();
    assert.equal(invalidBody.success, false);
  });
});
