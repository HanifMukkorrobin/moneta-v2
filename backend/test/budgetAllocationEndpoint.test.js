import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Budget Allocation Percentages CRUD & Validation Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  const testMonth = '2026-09';

  before(async () => {
    db = getDatabase();
    const userRes = db
      .prepare("INSERT INTO users (email, display_name) VALUES (?, 'Allocation Tester')")
      .run(`alloc_tester_${Date.now()}@example.com`);
    testUserId = Number(userRes.lastInsertRowid);

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });

    // Seed a 6,000,000 monthly budget for testUserId
    await fetch(`${baseUrl}/api/budgets/monthly`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        totalAmount: 6000000,
      }),
    });
  });

  after(async () => {
    if (testUserId && db) {
      db.prepare('DELETE FROM users WHERE id = ?').run(testUserId);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('retrieves default 50/30/20 allocation percentages and popular presets', async () => {
    const res = await fetch(`${baseUrl}/api/budgets/allocation?userId=${testUserId}&month=${testMonth}`);
    assert.equal(res.status, 200);
    const data = await res.json();

    assert.equal(data.success, true);
    assert.equal(data.needsPercentage, 50);
    assert.equal(data.savingsPercentage, 30);
    assert.equal(data.funPercentage, 20);
    assert.equal(data.totalPercentage, 100);
    assert.equal(data.isValid, true);
    assert.equal(data.activePreset, '50_30_20');
    assert.equal(data.presets.length, 4);
    assert.equal(data.allocation.needsAmount, 3000000);
    assert.equal(data.allocation.savingsAmount, 1800000);
    assert.equal(data.allocation.funAmount, 1200000);
  });

  it('rejects allocation percentages when total is less than 100%', async () => {
    const res = await fetch(`${baseUrl}/api/budgets/allocation`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        needsPct: 40,
        savingsPct: 30,
        funPct: 20, // Total = 90% (shortage 10%)
      }),
    });

    assert.equal(res.status, 400);
    const data = await res.json();
    assert.equal(data.success, false);
    assert.equal(data.isValid, false);
    assert.equal(data.totalPercentage, 90);
    assert.equal(data.shortage, 10);
    assert.match(data.error, /Masih kurang 10%/);
    assert.match(data.validationMessage, /Kurang 10% lagi/);
  });

  it('rejects allocation percentages when total exceeds 100%', async () => {
    const res = await fetch(`${baseUrl}/api/budgets/allocation`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        needsPct: 60,
        savingsPct: 30,
        funPct: 25, // Total = 115% (excess 15%)
      }),
    });

    assert.equal(res.status, 400);
    const data = await res.json();
    assert.equal(data.success, false);
    assert.equal(data.isValid, false);
    assert.equal(data.totalPercentage, 115);
    assert.equal(data.excess, 15);
    assert.match(data.error, /Melebihi batas sebesar 15%/);
    assert.match(data.validationMessage, /Kelebihan 15%/);
  });

  it('rejects negative or out-of-range individual percentages', async () => {
    const res = await fetch(`${baseUrl}/api/budgets/allocation`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        needsPct: -10,
        savingsPct: 90,
        funPct: 20,
      }),
    });

    assert.equal(res.status, 400);
    const data = await res.json();
    assert.equal(data.success, false);
    assert.equal(data.isValid, false);
  });

  it('updates allocation percentages to 40/40/20 and recalculates bucket limits', async () => {
    const res = await fetch(`${baseUrl}/api/budgets/allocation`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        needsPct: 40,
        savingsPct: 40,
        funPct: 20,
      }),
    });

    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.success, true);
    assert.equal(data.needsPercentage, 40);
    assert.equal(data.savingsPercentage, 40);
    assert.equal(data.funPercentage, 20);
    assert.equal(data.activePreset, '40_40_20');
    assert.match(data.message, /40% \/ 40% \/ 20%/);

    // 40% of 6M = 2.4M, 40% of 6M = 2.4M, 20% of 6M = 1.2M
    assert.equal(data.buckets[0].amountLimit, 2400000);
    assert.equal(data.buckets[1].amountLimit, 2400000);
    assert.equal(data.buckets[2].amountLimit, 1200000);
  });

  it('supports updating via preset template (e.g. 35_50_15) and resetting to 50/30/20', async () => {
    // 1. Apply preset 35_50_15
    const presetRes = await fetch(`${baseUrl}/api/budgets/allocation`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        preset: '35_50_15',
      }),
    });

    assert.equal(presetRes.status, 200);
    const presetData = await presetRes.json();
    assert.equal(presetData.needsPercentage, 35);
    assert.equal(presetData.savingsPercentage, 50);
    assert.equal(presetData.funPercentage, 15);
    assert.equal(presetData.buckets[0].amountLimit, 2100000); // 35% of 6M
    assert.equal(presetData.buckets[1].amountLimit, 3000000); // 50% of 6M
    assert.equal(presetData.buckets[2].amountLimit, 900000); // 15% of 6M

    // 2. Reset via DELETE /api/budgets/allocation
    const resetRes = await fetch(
      `${baseUrl}/api/budgets/allocation?userId=${testUserId}&month=${testMonth}`,
      { method: 'DELETE' }
    );
    assert.equal(resetRes.status, 200);
    const resetData = await resetRes.json();
    assert.equal(resetData.needsPercentage, 50);
    assert.equal(resetData.savingsPercentage, 30);
    assert.equal(resetData.funPercentage, 20);
    assert.equal(resetData.buckets[0].amountLimit, 3000000);
    assert.equal(resetData.buckets[1].amountLimit, 1800000);
    assert.equal(resetData.buckets[2].amountLimit, 1200000);
  });
});
