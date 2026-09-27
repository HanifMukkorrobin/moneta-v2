import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { runMigrations } from '../src/db/migrate.js';
import { createDebt } from '../src/services/debtService.js';

describe('Endpoint GET Daftar Hutang Urut Jatuh Tempo Tests', () => {
  let server;
  let baseUrl;
  let db;
  let user1Id;
  let user2Id;

  before(async () => {
    db = getDatabase();
    runMigrations(db);

    const u1 = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, 'Debtor List User 1', 'IDR')
    `).run(`debt_list1_${Date.now()}@example.com`);
    user1Id = Number(u1.lastInsertRowid);

    const u2 = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, 'Debtor List User 2', 'IDR')
    `).run(`debt_list2_${Date.now()}@example.com`);
    user2Id = Number(u2.lastInsertRowid);

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  beforeEach(() => {
    db.prepare('DELETE FROM debts WHERE user_id IN (?, ?)').run(user1Id, user2Id);

    // Seed multiple debts for user 1 with different due dates and statuses
    // Debt A: Jatuh tempo paling dekat (2026-10-02)
    createDebt(db, {
      userId: user1Id,
      name: 'Shopee Paylater Sepatu',
      totalAmount: 400000,
      remainingAmount: 400000,
      dueDate: '2026-10-02',
      type: 'paylater',
      notes: 'Beli sneakers diskon',
    });

    // Debt B: Jatuh tempo pertengahan (2026-10-15)
    createDebt(db, {
      userId: user1Id,
      name: 'Cicilan Mesin Cuci',
      totalAmount: 3600000,
      remainingAmount: 1200000,
      dueDate: '2026-10-15',
      type: 'cicilan',
      notes: 'Cicilan 3 dari 12',
    });

    // Debt C: Jatuh tempo paling lama (2026-11-20)
    createDebt(db, {
      userId: user1Id,
      name: 'Kartu Kredit Mandiri',
      totalAmount: 5000000,
      remainingAmount: 5000000,
      dueDate: '2026-11-20',
      type: 'kartu_kredit',
    });

    // Debt D: Sudah lunas
    createDebt(db, {
      userId: user1Id,
      name: 'GoPay Later Pulsa',
      totalAmount: 150000,
      remainingAmount: 0,
      dueDate: '2026-09-25',
      type: 'paylater',
    });

    // Debt E: Milik User 2
    createDebt(db, {
      userId: user2Id,
      name: 'Hutang User 2',
      totalAmount: 900000,
      remainingAmount: 900000,
      dueDate: '2026-10-01',
    });
  });

  after(async () => {
    if (db) {
      db.prepare('DELETE FROM debts WHERE user_id IN (?, ?)').run(user1Id, user2Id);
      db.prepare('DELETE FROM users WHERE id IN (?, ?)').run(user1Id, user2Id);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. Default Pengurutan Jatuh Tempo (due_date ASC)', () => {
    it('returns debts sorted by due_date ASC by default', async () => {
      const res = await fetch(`${baseUrl}/api/debts?userId=${user1Id}`);
      assert.strictEqual(res.status, 200);

      const data = await res.json();
      assert.strictEqual(data.success, true);
      assert.strictEqual(data.userId, user1Id);
      assert.strictEqual(data.total, 4);
      assert.strictEqual(data.activeCount, 3);
      assert.strictEqual(data.paidCount, 1);
      assert.strictEqual(data.totalRemainingAmount, 6600000);
      assert.ok(data.formattedTotalRemainingAmount.includes('6.600.000'));

      // Verify default sorting: 2026-09-25, 2026-10-02, 2026-10-15, 2026-11-20
      const dates = data.debts.map((d) => d.dueDate);
      assert.deepStrictEqual(dates, [
        '2026-09-25',
        '2026-10-02',
        '2026-10-15',
        '2026-11-20',
      ]);

      // Check fields for each debt
      const first = data.debts[1]; // Shopee Paylater
      assert.strictEqual(first.name, 'Shopee Paylater Sepatu');
      assert.ok(first.formattedDueDate);
      assert.ok(first.dueStatusLabel);
      assert.strictEqual(typeof first.daysUntilDue, 'number');
    });

    it('returns debts using route alias /api/hutang', async () => {
      const res = await fetch(`${baseUrl}/api/hutang?userId=${user1Id}`);
      assert.strictEqual(res.status, 200);

      const data = await res.json();
      assert.strictEqual(data.success, true);
      assert.strictEqual(data.debts.length, 4);
    });

    it('supports sortOrder=DESC to sort by newest due date first', async () => {
      const res = await fetch(`${baseUrl}/api/debts?userId=${user1Id}&sortOrder=DESC`);
      assert.strictEqual(res.status, 200);

      const data = await res.json();
      const dates = data.debts.map((d) => d.dueDate);
      assert.deepStrictEqual(dates, [
        '2026-11-20',
        '2026-10-15',
        '2026-10-02',
        '2026-09-25',
      ]);
    });
  });

  describe('2. Filter Status & Jenis Hutang', () => {
    it('filters active debts only using status=active or filter=active', async () => {
      const res = await fetch(`${baseUrl}/api/debts?userId=${user1Id}&status=active`);
      assert.strictEqual(res.status, 200);

      const data = await res.json();
      assert.strictEqual(data.debts.length, 3);
      assert.ok(data.debts.every((d) => d.status === 'active' && !d.isPaid));
    });

    it('filters paid debts only using status=paid or filter=paid', async () => {
      const res = await fetch(`${baseUrl}/api/debts?userId=${user1Id}&filter=paid`);
      assert.strictEqual(res.status, 200);

      const data = await res.json();
      assert.strictEqual(data.debts.length, 1);
      assert.strictEqual(data.debts[0].name, 'GoPay Later Pulsa');
      assert.strictEqual(data.debts[0].isPaid, true);
    });

    it('filters by debt type (e.g. type=cicilan)', async () => {
      const res = await fetch(`${baseUrl}/api/debts?userId=${user1Id}&type=cicilan`);
      assert.strictEqual(res.status, 200);

      const data = await res.json();
      assert.strictEqual(data.debts.length, 1);
      assert.strictEqual(data.debts[0].name, 'Cicilan Mesin Cuci');
      assert.strictEqual(data.debts[0].type, 'cicilan');
    });
  });

  describe('3. Pencarian (Search) & Pagination', () => {
    it('searches debts by keyword in name or notes', async () => {
      const res = await fetch(`${baseUrl}/api/debts?userId=${user1Id}&search=sneakers`);
      assert.strictEqual(res.status, 200);

      const data = await res.json();
      assert.strictEqual(data.debts.length, 1);
      assert.strictEqual(data.debts[0].name, 'Shopee Paylater Sepatu');
    });

    it('supports pagination with limit and offset', async () => {
      const res = await fetch(`${baseUrl}/api/debts?userId=${user1Id}&limit=2&offset=0`);
      assert.strictEqual(res.status, 200);

      const data = await res.json();
      assert.strictEqual(data.debts.length, 2);

      const res2 = await fetch(`${baseUrl}/api/debts?userId=${user1Id}&limit=2&offset=2`);
      const data2 = await res2.json();
      assert.strictEqual(data2.debts.length, 2);

      // Verify no duplicate IDs between pages
      const page1Ids = data.debts.map((d) => d.id);
      const page2Ids = data2.debts.map((d) => d.id);
      assert.strictEqual(page1Ids.some((id) => page2Ids.includes(id)), false);
    });
  });

  describe('4. User Isolation & Error Handling', () => {
    it('isolates debts between user 1 and user 2', async () => {
      const resUser2 = await fetch(`${baseUrl}/api/debts?userId=${user2Id}`);
      assert.strictEqual(resUser2.status, 200);

      const data2 = await resUser2.json();
      assert.strictEqual(data2.total, 1);
      assert.strictEqual(data2.debts[0].name, 'Hutang User 2');
    });

    it('returns 400 when userId is invalid', async () => {
      const res = await fetch(`${baseUrl}/api/debts?userId=abc`);
      assert.strictEqual(res.status, 400);

      const data = await res.json();
      assert.strictEqual(data.success, false);
      assert.ok(data.error.includes('userId'));
    });
  });
});
