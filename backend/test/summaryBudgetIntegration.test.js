import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { getCurrentMonthString } from '../src/controllers/summaryBudgetController.js';

describe('Integrate Chat Transactions to Rekap and Budget Tests', () => {
  let server;
  let baseUrl;
  let db;
  const currentMonth = getCurrentMonthString();

  before(async () => {
    db = getDatabase();
    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  it('reflects confirmed chat transactions in monthly rekap and updates pending counts', async () => {
    // 1. Initial rekap
    const initialRes = await fetch(`${baseUrl}/api/rekap?month=${currentMonth}`);
    const initialData = await initialRes.json();
    assert.equal(initialRes.status, 200);
    const initialExpense = initialData.summary.totalExpense;
    const initialConfirmedCount = initialData.summary.confirmedTransactionsCount;

    // 2. Parse a new chat expense (creates pending transaction)
    const parseRes = await fetch(`${baseUrl}/api/chat/parse`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Beli makan siang bebek goreng 45rb' }),
    });
    const parseData = await parseRes.json();
    assert.equal(parseData.success, true);
    const txId = parseData.transaction.id;
    const chatLogId = parseData.chatLogId;

    // Verify pending count increased in rekap
    const pendingRekapRes = await fetch(`${baseUrl}/api/rekap?month=${currentMonth}`);
    const pendingRekapData = await pendingRekapRes.json();
    assert.ok(pendingRekapData.summary.pendingTransactionsCount >= 1);

    // 3. Confirm the chat transaction
    const confirmRes = await fetch(`${baseUrl}/api/transactions/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transactionId: txId, chatLogId }),
    });
    assert.equal(confirmRes.status, 200);

    // 4. Verify monthly rekap reflects confirmed expense
    const afterRekapRes = await fetch(`${baseUrl}/api/rekap?month=${currentMonth}`);
    const afterRekapData = await afterRekapRes.json();
    assert.equal(afterRekapData.summary.totalExpense, initialExpense + 45000);
    assert.equal(afterRekapData.summary.confirmedTransactionsCount, initialConfirmedCount + 1);

    // Verify category breakdown includes Makan & Minuman
    const foodCategory = afterRekapData.categoryBreakdown.find((c) => c.categoryName === 'Makan & Minuman');
    assert.ok(foodCategory, 'Makan & Minuman category must exist in breakdown');
    assert.ok(foodCategory.total >= 45000);
    assert.ok(foodCategory.percentage > 0);
  });

  it('tracks budget limit, spent, and remaining from chat transactions', async () => {
    // Find category ID for Makan & Minuman
    const cat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get();
    assert.ok(cat, 'Category Makan & Minuman should exist');

    // 1. Create a budget for Makan & Minuman with limit 200,000
    const createBudgetRes = await fetch(`${baseUrl}/api/budgets`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        categoryId: cat.id,
        name: 'Budget Makan Bulanan',
        amountLimit: 200000,
        month: currentMonth,
      }),
    });

    assert.equal(createBudgetRes.status, 201);
    const budgetData = await createBudgetRes.json();
    assert.equal(budgetData.success, true);
    assert.equal(budgetData.budget.amountLimit, 200000);

    // 2. Fetch budgets and verify calculated spent
    const listRes = await fetch(`${baseUrl}/api/budgets?month=${currentMonth}`);
    assert.equal(listRes.status, 200);
    const listData = await listRes.json();
    assert.equal(listData.success, true);

    const budgetItem = listData.budgets.find((b) => b.categoryId === cat.id);
    assert.ok(budgetItem, 'Budget item for category must be present');
    assert.equal(budgetItem.amountLimit, 200000);
    assert.ok(budgetItem.totalSpent >= 45000, 'Total spent should include confirmed transaction');
    assert.equal(budgetItem.remaining, 200000 - budgetItem.totalSpent);
    assert.equal(budgetItem.isOverBudget, false);

    // 3. Verify budgetStatus section in /api/rekap
    const rekapRes = await fetch(`${baseUrl}/api/rekap?month=${currentMonth}`);
    const rekapData = await rekapRes.json();
    const budgetStatusItem = rekapData.budgetStatus.find((b) => b.categoryId === cat.id);
    assert.ok(budgetStatusItem);
    assert.equal(budgetStatusItem.limit, 200000);
    assert.equal(budgetStatusItem.spent, budgetItem.totalSpent);
  });

  it('calculates net savings and savings rate when income is recorded', async () => {
    // Record income transaction
    const incomeRes = await fetch(`${baseUrl}/api/transactions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount: 5000000,
        type: 'income',
        category: 'Gaji',
        note: 'Gaji bulanan',
      }),
    });
    assert.equal(incomeRes.status, 201);

    // Check rekap
    const rekapRes = await fetch(`${baseUrl}/api/rekap?month=${currentMonth}`);
    const rekapData = await rekapRes.json();
    assert.ok(rekapData.summary.totalIncome >= 5000000);
    assert.equal(rekapData.summary.netSavings, rekapData.summary.totalIncome - rekapData.summary.totalExpense);
    assert.ok(rekapData.summary.savingsRate > 0);
  });

  it('detects when an expense exceeds budget (isOverBudget = true)', async () => {
    const cat = db.prepare("SELECT id FROM categories WHERE name = 'Hiburan' AND type = 'expense'").get();

    // Create small budget of 50,000
    await fetch(`${baseUrl}/api/budgets`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        categoryId: cat.id,
        name: 'Budget Hiburan Kecil',
        amountLimit: 50000,
        month: currentMonth,
      }),
    });

    // Record expense of 80,000
    await fetch(`${baseUrl}/api/transactions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amount: 80000,
        type: 'expense',
        categoryId: cat.id,
        note: 'Nonton bioskop IMAX',
      }),
    });

    // Check budget status
    const listRes = await fetch(`${baseUrl}/api/budgets?month=${currentMonth}`);
    const listData = await listRes.json();
    const entertainmentBudget = listData.budgets.find((b) => b.categoryId === cat.id);

    assert.ok(entertainmentBudget);
    assert.ok(entertainmentBudget.totalSpent >= 80000);
    assert.equal(entertainmentBudget.isOverBudget, true);
    assert.ok(entertainmentBudget.remaining < 0);
    assert.ok(entertainmentBudget.percentageUsed >= 160.0);
  });

  it('deletes budget cleanly via DELETE /api/budgets/:id', async () => {
    const listRes = await fetch(`${baseUrl}/api/budgets?month=${currentMonth}`);
    const listData = await listRes.json();
    const targetId = listData.budgets[0].id;

    const delRes = await fetch(`${baseUrl}/api/budgets/${targetId}`, {
      method: 'DELETE',
    });
    assert.equal(delRes.status, 200);

    const delCheck = db.prepare('SELECT id FROM budgets WHERE id = ?').get(targetId);
    assert.equal(delCheck, undefined);
  });
});
