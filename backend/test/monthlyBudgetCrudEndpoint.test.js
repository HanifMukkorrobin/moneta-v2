import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Monthly Budget Limit CRUD Endpoints Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;
  const testMonth = '2026-09';

  before(async () => {
    db = getDatabase();
    const userRes = db
      .prepare("INSERT INTO users (email, display_name) VALUES (?, 'Budget CRUD Tester')")
      .run(`budget_crud_${Date.now()}@example.com`);
    testUserId = Number(userRes.lastInsertRowid);

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
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

  it('returns empty monthly budget state when no budget is set yet', async () => {
    const res = await fetch(`${baseUrl}/api/budgets/monthly?userId=${testUserId}&month=${testMonth}`);
    assert.equal(res.status, 200);
    const data = await res.json();

    assert.equal(data.success, true);
    assert.equal(data.month, testMonth);
    assert.equal(data.monthLabel, 'September 2026');
    assert.equal(data.hasMonthlyBudget, false);
    assert.equal(data.totalBudget, 0);
    assert.equal(data.needsPercentage, 50);
    assert.equal(data.savingsPercentage, 30);
    assert.equal(data.funPercentage, 20);
    assert.deepEqual(data.buckets, []);
  });

  it('rejects creating a monthly budget with amount <= 0', async () => {
    const resZero = await fetch(`${baseUrl}/api/budgets/monthly`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        totalAmount: 0,
      }),
    });
    assert.equal(resZero.status, 400);
    const errZero = await resZero.json();
    assert.equal(errZero.success, false);

    const resNeg = await fetch(`${baseUrl}/api/budgets`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        totalBudget: -500000,
      }),
    });
    assert.equal(resNeg.status, 400);
  });

  it('creates a monthly budget limit via POST /api/budgets/monthly and calculates 50/30/20 buckets', async () => {
    const createRes = await fetch(`${baseUrl}/api/budgets/monthly`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        totalAmount: 6000000,
      }),
    });

    assert.equal(createRes.status, 201);
    const data = await createRes.json();
    assert.equal(data.success, true);
    assert.equal(data.hasMonthlyBudget, true);
    assert.equal(data.totalBudget, 6000000);
    assert.equal(data.totalAmount, 6000000);
    assert.equal(data.formattedTotalBudget, 'Rp 6.000.000');
    assert.equal(data.buckets.length, 3);

    // Verify 50/30/20 bucket limits
    const needsBucket = data.buckets.find((b) => b.type === 'needs');
    const savingsBucket = data.buckets.find((b) => b.type === 'savings');
    const funBucket = data.buckets.find((b) => b.type === 'fun');

    assert.equal(needsBucket.amountLimit, 3000000);
    assert.equal(savingsBucket.amountLimit, 1800000);
    assert.equal(funBucket.amountLimit, 1200000);

    // Verify simulation object
    assert.equal(data.simulation503020.needsAmount, 3000000);
    assert.equal(data.simulation503020.savingsAmount, 1800000);
    assert.equal(data.simulation503020.funAmount, 1200000);
  });

  it('updates the monthly budget limit via PUT /api/budgets/monthly and PUT /api/budgets/:id', async () => {
    // 1. Update via PUT /api/budgets/monthly
    const putRes = await fetch(`${baseUrl}/api/budgets/monthly`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        month: testMonth,
        totalBudget: 7500000,
      }),
    });

    assert.equal(putRes.status, 200);
    const putData = await putRes.json();
    assert.equal(putData.totalBudget, 7500000);
    assert.equal(putData.formattedTotalBudget, 'Rp 7.500.000');
    assert.equal(putData.buckets[0].amountLimit, 3750000); // 50% of 7.5M

    // 2. Update via PUT /api/budgets/:id using the returned budgetId
    const budgetId = putData.budgetId || putData.id;
    assert.ok(budgetId);

    const patchRes = await fetch(`${baseUrl}/api/budgets/${budgetId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        amountLimit: 10000000,
      }),
    });

    assert.equal(patchRes.status, 200);
    const patchData = await patchRes.json();
    assert.equal(patchData.totalBudget, 10000000);
    assert.equal(patchData.buckets[0].amountLimit, 5000000); // 50% of 10M
    assert.equal(patchData.buckets[1].amountLimit, 3000000); // 30% of 10M
    assert.equal(patchData.buckets[2].amountLimit, 2000000); // 20% of 10M
  });

  it('supports creating and updating category-level budgets alongside monthly budget', async () => {
    const cat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get();

    const catCreateRes = await fetch(`${baseUrl}/api/budgets`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        categoryId: cat.id,
        name: 'Makan & Minuman',
        amountLimit: 2000000,
        bucketType: 'needs',
        month: testMonth,
      }),
    });

    assert.equal(catCreateRes.status, 201);
    const catCreateData = await catCreateRes.json();
    assert.equal(catCreateData.budget.amountLimit, 2000000);
    const catBudgetId = catCreateData.budget.id;

    // Update category budget via PUT /api/budgets/:id
    const catUpdateRes = await fetch(`${baseUrl}/api/budgets/${catBudgetId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: testUserId,
        amountLimit: 2500000,
      }),
    });
    assert.equal(catUpdateRes.status, 200);
    const catUpdateData = await catUpdateRes.json();
    assert.equal(catUpdateData.budget.amountLimit, 2500000);

    // Verify GET /api/budgets includes both monthlyBudget and categoryBudgets
    const listRes = await fetch(`${baseUrl}/api/budgets?userId=${testUserId}&month=${testMonth}`);
    assert.equal(listRes.status, 200);
    const listData = await listRes.json();
    assert.equal(listData.totalBudget, 10000000);
    assert.equal(listData.categoryBudgets.length, 1);
    assert.equal(listData.categoryBudgets[0].amountLimit, 2500000);
  });

  it('deletes the monthly budget limit via DELETE /api/budgets/monthly and resets totalBudget to 0', async () => {
    const delRes = await fetch(
      `${baseUrl}/api/budgets/monthly?userId=${testUserId}&month=${testMonth}`,
      { method: 'DELETE' }
    );
    assert.equal(delRes.status, 200);
    const delData = await delRes.json();
    assert.equal(delData.success, true);
    assert.equal(delData.hasMonthlyBudget, false);
    assert.equal(delData.totalBudget, 0);
    assert.deepEqual(delData.buckets, []);

    // Subsequent delete for the same month returns 404
    const delAgainRes = await fetch(
      `${baseUrl}/api/budgets/monthly?userId=${testUserId}&month=${testMonth}`,
      { method: 'DELETE' }
    );
    assert.equal(delAgainRes.status, 404);
  });
});
