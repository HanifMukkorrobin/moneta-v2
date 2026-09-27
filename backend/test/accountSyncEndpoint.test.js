import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'moneta-account-sync-test-'));
process.env.DB_PATH = path.join(tmpDir, 'test-account-sync.sqlite');
process.env.NODE_ENV = 'test';

import app from '../src/index.js';
import { getDatabase, closeDatabase } from '../src/config/database.js';
import { runMigrations } from '../src/db/migrate.js';

function sendRequest(server, method, urlPath, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const addr = server.address();
    const options = {
      hostname: '127.0.0.1',
      port: addr.port,
      path: urlPath,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    };

    const req = http.request(options, (res) => {
      let raw = '';
      res.on('data', (chunk) => {
        raw += chunk;
      });
      res.on('end', () => {
        try {
          resolve({
            status: res.statusCode,
            body: raw ? JSON.parse(raw) : {},
          });
        } catch {
          resolve({ status: res.statusCode, body: { raw } });
        }
      });
    });

    req.on('error', reject);
    if (body !== null) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

describe('Sinkronisasi Catatan Per Akun Endpoints & Service', () => {
  let server;
  let userA;
  let tokenA;
  let userB;
  let tokenB;

  before(async () => {
    const db = getDatabase();
    runMigrations(db);
    db.prepare("DELETE FROM users WHERE email LIKE '%@synctest.moneta.id'").run();

    await new Promise((resolve) => {
      server = app.listen(0, '127.0.0.1', resolve);
    });

    const regA = await sendRequest(server, 'POST', '/api/auth/register', {
      email: 'akun-a@synctest.moneta.id',
      password: 'PasswordA123!',
      displayName: 'Akun A',
      currency: 'IDR',
      themeMode: 'dark',
    });
    assert.equal(regA.status, 201);
    userA = regA.body.user;
    tokenA = regA.body.token;

    const regB = await sendRequest(server, 'POST', '/api/auth/register', {
      email: 'akun-b@synctest.moneta.id',
      password: 'PasswordB123!',
      displayName: 'Akun B',
      currency: 'USD',
      themeMode: 'light',
    });
    assert.equal(regB.status, 201);
    userB = regB.body.user;
    tokenB = regB.body.token;
  });

  after(async () => {
    const db = getDatabase();
    db.prepare("DELETE FROM users WHERE email LIKE '%@synctest.moneta.id'").run();
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
    closeDatabase();
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('1. Isolasi otomatis per akun menggunakan Bearer token pada endpoint transaksi & hutang', async () => {
    // Akun A mencatat transaksi lewat Bearer token tanpa menulis userId di body
    const txARes = await sendRequest(
      server,
      'POST',
      '/api/transactions/confirm',
      {
        type: 'expense',
        amount: 45000,
        categoryName: 'Makan & Minum',
        note: 'Nasi Padang Akun A',
        description: 'Nasi Padang Akun A',
        transactionDate: '2026-03-10',
      },
      { Authorization: `Bearer ${tokenA}` }
    );
    assert.ok(txARes.status === 200 || txARes.status === 201);

    // Akun B mencatat transaksi & hutang lewat Bearer token
    const txBRes = await sendRequest(
      server,
      'POST',
      '/api/transactions/confirm',
      {
        type: 'income',
        amount: 2500000,
        categoryName: 'Gaji',
        note: 'Freelance Akun B',
        description: 'Freelance Akun B',
        transactionDate: '2026-03-11',
      },
      { Authorization: `Bearer ${tokenB}` }
    );
    assert.ok(txBRes.status === 200 || txBRes.status === 201);

    const debtBRes = await sendRequest(
      server,
      'POST',
      '/api/debts',
      {
        name: 'Paylater Laptop Akun B',
        amount: 1200000,
        dueDate: '2026-04-15',
        type: 'paylater',
      },
      { Authorization: `Bearer ${tokenB}` }
    );
    assert.equal(debtBRes.status, 201);

    // Cek snapshot Akun A -> hanya berisi transaksi Akun A dan 0 hutang
    const syncA = await sendRequest(
      server,
      'GET',
      '/api/sync',
      null,
      { Authorization: `Bearer ${tokenA}` }
    );
    assert.equal(syncA.status, 200);
    assert.equal(syncA.body.success, true);
    assert.equal(syncA.body.userId, userA.id);
    assert.equal(syncA.body.transactions.length, 1);
    assert.equal(syncA.body.transactions[0].description, 'Nasi Padang Akun A');
    assert.equal(syncA.body.debts.length, 0);

    // Cek snapshot Akun B -> hanya berisi transaksi & hutang Akun B
    const syncB = await sendRequest(
      server,
      'GET',
      '/api/sinkronisasi',
      null,
      { Authorization: `Bearer ${tokenB}` }
    );
    assert.equal(syncB.status, 200);
    assert.equal(syncB.body.userId, userB.id);
    assert.equal(syncB.body.transactions.length, 1);
    assert.equal(syncB.body.transactions[0].description, 'Freelance Akun B');
    assert.equal(syncB.body.debts.length, 1);
    assert.equal(syncB.body.debts[0].name, 'Paylater Laptop Akun B');
  });

  it('2. POST /api/sync (mode merge) menyinkronkan batch transaksi, budget, hutang, kategori kustom, dan preferensi ke akun terkait', async () => {
    const res = await sendRequest(
      server,
      'POST',
      '/api/sync',
      {
        mode: 'merge',
        preferences: {
          themeMode: 'light',
          aiTone: 'friendly',
        },
        categories: [
          { name: 'Langganan Cloud', type: 'expense', icon: '☁️' },
        ],
        transactions: [
          {
            type: 'income',
            amount: 8000000,
            categoryName: 'Gaji',
            description: 'Gaji Bulanan Akun A',
            transactionDate: '2026-03-01',
          },
          {
            type: 'expense',
            amount: 150000,
            categoryName: 'Langganan Cloud',
            description: 'Sewa VPS Akun A',
            transactionDate: '2026-03-12',
          },
        ],
        budgets: [
          {
            month: '2026-03',
            amountLimit: 3500000,
            dailySavingTarget: 50000,
          },
        ],
        debts: [
          {
            name: 'Pinjaman Teman A',
            creditor: 'Budi',
            amount: 300000,
            dueDate: '2026-03-28',
            type: 'personal',
            status: 'unpaid',
          },
        ],
      },
      { Authorization: `Bearer ${tokenA}` }
    );

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(res.body.syncStats.mode, 'merge');
    assert.equal(res.body.syncStats.transactionsInserted, 2);
    assert.equal(res.body.syncStats.budgetsUpserted, 1);
    assert.equal(res.body.syncStats.debtsInserted, 1);
    assert.equal(res.body.syncStats.categoriesInserted, 1);
    assert.equal(res.body.syncStats.preferencesUpdated, true);

    // Pastikan total transaksi Akun A menjadi 3 (1 lama + 2 baru)
    assert.equal(res.body.transactions.length, 3);
    assert.equal(res.body.summary.totalIncome, 8000000);
    assert.equal(res.body.summary.totalExpense, 195000);
    assert.equal(res.body.summary.netBalance, 7805000);
    assert.equal(res.body.preferences.themeMode, 'Terang');
    assert.equal(res.body.preferences.aiAdviceTone, 'Santai');

    // Pastikan Akun B tidak terpengaruh sama sekali
    const checkB = await sendRequest(
      server,
      'GET',
      '/api/auth/sync',
      null,
      { Authorization: `Bearer ${tokenB}` }
    );
    assert.equal(checkB.status, 200);
    assert.equal(checkB.body.transactions.length, 1);
    assert.equal(checkB.body.debts.length, 1);
  });

  it('3. PUT /api/sync (mode replace) mengganti catatan milik akun tanpa menyentuh akun lain', async () => {
    const res = await sendRequest(
      server,
      'PUT',
      '/api/sync',
      {
        mode: 'replace',
        transactions: [
          {
            type: 'expense',
            amount: 75000,
            categoryName: 'Belanja',
            description: 'Belanja Mingguan Baru A',
            transactionDate: '2026-03-15',
          },
        ],
        debts: [],
      },
      { Authorization: `Bearer ${tokenA}` }
    );

    assert.equal(res.status, 200);
    assert.equal(res.body.syncStats.mode, 'replace');
    assert.equal(res.body.transactions.length, 1);
    assert.equal(res.body.transactions[0].description, 'Belanja Mingguan Baru A');
    assert.equal(res.body.debts.length, 0);

    // Pastikan Akun B tetap utuh
    const checkB = await sendRequest(
      server,
      'GET',
      '/api/users/sync',
      null,
      { Authorization: `Bearer ${tokenB}` }
    );
    assert.equal(checkB.status, 200);
    assert.equal(checkB.body.transactions.length, 1);
    assert.equal(checkB.body.debts.length, 1);
  });

  it('4. GET /api/sync/export mengekspor data akun dalam format JSON dan CSV', async () => {
    const jsonExport = await sendRequest(
      server,
      'GET',
      '/api/sync/export?format=json',
      null,
      { Authorization: `Bearer ${tokenA}` }
    );
    assert.equal(jsonExport.status, 200);
    assert.equal(jsonExport.body.success, true);
    assert.equal(jsonExport.body.format, 'json');
    assert.equal(jsonExport.body.userId, userA.id);
    assert.ok(jsonExport.body.filename.endsWith('.json'));
    assert.equal(jsonExport.body.snapshot.transactions.length, 1);

    const csvExport = await sendRequest(
      server,
      'GET',
      '/api/auth/export?format=csv',
      null,
      { Authorization: `Bearer ${tokenA}` }
    );
    assert.equal(csvExport.status, 200);
    assert.equal(csvExport.body.format, 'csv');
    assert.ok(csvExport.body.filename.endsWith('.csv'));
    assert.ok(csvExport.body.csv.includes('Belanja Mingguan Baru A'));
    assert.ok(!csvExport.body.csv.includes('Freelance Akun B'));
  });

  it('5. POST /api/sync/reset menghapus seluruh catatan akun A tanpa menghapus catatan akun B', async () => {
    const resetRes = await sendRequest(
      server,
      'POST',
      '/api/sync/reset',
      { includeCustomCategories: true },
      { Authorization: `Bearer ${tokenA}` }
    );
    assert.equal(resetRes.status, 200);
    assert.equal(resetRes.body.success, true);
    assert.equal(resetRes.body.userId, userA.id);
    assert.equal(resetRes.body.deleted.transactions, 1);

    // Pastikan Akun A sekarang bersih (0 transaksi, 0 budget, 0 hutang)
    const afterA = await sendRequest(
      server,
      'GET',
      '/api/sync',
      null,
      { Authorization: `Bearer ${tokenA}` }
    );
    assert.equal(afterA.status, 200);
    assert.equal(afterA.body.transactions.length, 0);
    assert.equal(afterA.body.budgets.length, 0);
    assert.equal(afterA.body.debts.length, 0);

    // Pastikan Akun B masih memiliki seluruh catatannya
    const afterB = await sendRequest(
      server,
      'GET',
      '/api/sync',
      null,
      { Authorization: `Bearer ${tokenB}` }
    );
    assert.equal(afterB.status, 200);
    assert.equal(afterB.body.transactions.length, 1);
    assert.equal(afterB.body.debts.length, 1);
  });
});
