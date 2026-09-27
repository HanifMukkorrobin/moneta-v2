import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { recalculateFinancialAnalysis } from '../src/services/financialAnalysisService.js';
import { getCachedAnalysis } from '../src/services/analysisCacheService.js';

describe('Auto-Recalculate Financial Analysis on Transaction Save/Update/Delete Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  let makanCatId;
  let transportCatId;

  before(async () => {
    db = getDatabase();
    const user = db.prepare("INSERT INTO users (email) VALUES (?)").run(`auto_recalc_${Date.now()}@example.com`);
    testUserId = user.lastInsertRowid;

    makanCatId = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get().id;
    transportCatId = db.prepare("SELECT id FROM categories WHERE name = 'Transportasi' AND type = 'expense'").get().id;

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
    db.prepare('DELETE FROM ai_insights WHERE user_id = ?').run(testUserId);
    db.prepare('DELETE FROM chat_logs WHERE user_id = ?').run(testUserId);
  });

  after(async () => {
    if (testUserId && db) {
      db.prepare('DELETE FROM transactions WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM budgets WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM monthly_budgets WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM ai_insights WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM chat_logs WHERE user_id = ?').run(testUserId);
      db.prepare('DELETE FROM users WHERE id = ?').run(testUserId);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. Direct Service Recalculation', () => {
    it('recalculates daily average, depletion, and early warning, persisting into ai_insights cache', () => {
      // Set monthly budget Rp 3.000.000
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 3000000)
      `).run(testUserId);

      // Insert 2 confirmed transactions on 2026-09-12
      db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES
          (?, ?, 'Makan & Minuman', 'expense', 150000, 'Makan siang & malam', '2026-09-12 12:00:00', 1),
          (?, ?, 'Transportasi', 'expense', 60000, 'Ojek online', '2026-09-12 18:00:00', 1)
      `).run(testUserId, makanCatId, testUserId, transportCatId);

      const result = recalculateFinancialAnalysis(db, {
        userId: testUserId,
        referenceDate: '2026-09-12',
      });

      assert.ok(result.summary);
      assert.equal(result.summary.totalSpent, 210000);
      assert.equal(result.summary.remainingBalance, 2790000);
      assert.ok(result.summary.avgDailySpend > 0);
      assert.ok(result.summary.estimatedDaysLeft > 0);
      assert.ok(result.summary.depletionDate);
      assert.ok(result.summary.warnLevel);

      // Verify row in ai_insights cache
      const cached = getCachedAnalysis(db, { userId: testUserId, date: '2026-09-12' });
      assert.ok(cached);
      assert.equal(cached.totalSpent, 210000);
      assert.equal(cached.remainingBalance, 2790000);
      assert.equal(cached.isStale, false);
    });
  });

  describe('2. Confirming Existing Transaction via HTTP', () => {
    it('automatically recalculates analysis when confirming a pending chat transaction', async () => {
      // Set monthly budget Rp 6.000.000
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 6000000)
      `).run(testUserId);

      // Create a pending unconfirmed transaction
      const txRes = db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Makan & Minuman', 'expense', 700000, 'Belanja bulanan', '2026-09-12 12:00:00', 0)
      `).run(testUserId, makanCatId);
      const pendingTxId = txRes.lastInsertRowid;

      // Confirm via POST /api/transactions/:id/confirm
      const response = await fetch(`${baseUrl}/api/transactions/${pendingTxId}/confirm`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: testUserId }),
      });

      assert.equal(response.status, 200);
      const body = await response.json();
      assert.equal(body.success, true);
      assert.equal(body.transaction.isConfirmed, true);

      // Verify response has analysis summary
      assert.ok(body.analysis);
      assert.equal(body.analysis.totalSpent, 700000);
      assert.equal(body.analysis.remainingBalance, 5300000);
      assert.ok(body.analysis.avgDailySpend > 0);
      assert.ok(body.analysis.depletionDate);

      // Verify cache in ai_insights table is synchronized
      const cacheRow = db.prepare("SELECT * FROM ai_insights WHERE user_id = ? AND date = '2026-09-12'").get(testUserId);
      assert.ok(cacheRow);
      assert.equal(cacheRow.total_spent, 700000);
      assert.equal(cacheRow.remaining_balance, 5300000);
    });
  });

  describe('3. Creating New Confirmed Transaction via HTTP', () => {
    it('automatically recalculates analysis when saving a new manual transaction', async () => {
      // Set monthly budget Rp 5.000.000
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 5000000)
      `).run(testUserId);

      const response = await fetch(`${baseUrl}/api/transactions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: testUserId,
          amount: 350000,
          type: 'expense',
          categoryName: 'Makan & Minuman',
          note: 'Makan bersama keluarga',
          occurredAt: '2026-09-15 13:00:00',
        }),
      });

      assert.equal(response.status, 201);
      const body = await response.json();
      assert.equal(body.success, true);
      assert.ok(body.analysis);
      assert.equal(body.analysis.totalSpent, 350000);
      assert.equal(body.analysis.remainingBalance, 4650000);

      // Verify cache
      const cacheRow = db.prepare("SELECT * FROM ai_insights WHERE user_id = ? AND date = '2026-09-15'").get(testUserId);
      assert.ok(cacheRow);
      assert.equal(cacheRow.total_spent, 350000);
      assert.equal(cacheRow.remaining_balance, 4650000);
    });
  });

  describe('4. Updating Transaction via HTTP', () => {
    it('automatically updates financial analysis when transaction amount is modified', async () => {
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 5000000)
      `).run(testUserId);

      const txRes = db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Makan & Minuman', 'expense', 100000, 'Makan', '2026-09-15 12:00:00', 1)
      `).run(testUserId, makanCatId);
      const txId = txRes.lastInsertRowid;

      // Update amount to Rp 800.000 via PUT /api/transactions/:id
      const response = await fetch(`${baseUrl}/api/transactions/${txId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: testUserId,
          amount: 800000,
        }),
      });

      assert.equal(response.status, 200);
      const body = await response.json();
      assert.equal(body.success, true);
      assert.ok(body.analysis);
      assert.equal(body.analysis.totalSpent, 800000);
      assert.equal(body.analysis.remainingBalance, 4200000);

      // Verify cache
      const cacheRow = db.prepare("SELECT * FROM ai_insights WHERE user_id = ? AND date = '2026-09-15'").get(testUserId);
      assert.ok(cacheRow);
      assert.equal(cacheRow.total_spent, 800000);
    });
  });

  describe('5. Deleting Transaction via HTTP', () => {
    it('automatically recalculates analysis and reduces spent when transaction is deleted', async () => {
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 5000000)
      `).run(testUserId);

      const txRes = db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, ?, 'Makan & Minuman', 'expense', 500000, 'Belanja salah', '2026-09-15 12:00:00', 1)
      `).run(testUserId, makanCatId);
      const txId = txRes.lastInsertRowid;

      // Delete transaction via DELETE /api/transactions/:id
      const response = await fetch(`${baseUrl}/api/transactions/${txId}?userId=${testUserId}`, {
        method: 'DELETE',
      });

      assert.equal(response.status, 200);
      const body = await response.json();
      assert.equal(body.success, true);
      assert.ok(body.analysis);
      assert.equal(body.analysis.totalSpent, 0); // reduced to 0
      assert.equal(body.analysis.remainingBalance, 5000000);

      // Verify cache in ai_insights
      const cacheRow = db.prepare("SELECT * FROM ai_insights WHERE user_id = ? AND date = '2026-09-15'").get(testUserId);
      assert.ok(cacheRow);
      assert.equal(cacheRow.total_spent, 0);
      assert.equal(cacheRow.remaining_balance, 5000000);
    });
  });
});
