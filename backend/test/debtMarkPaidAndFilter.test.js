import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { runMigrations } from '../src/db/migrate.js';
import { createDebt } from '../src/services/debtService.js';

describe('Endpoint Tandai Lunas dan Filter Status Hutang Tests', () => {
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
      VALUES (?, 'Paid Tester 1', 'IDR')
    `).run(`debt_paid1_${Date.now()}@example.com`);
    user1Id = Number(u1.lastInsertRowid);

    const u2 = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, 'Paid Tester 2', 'IDR')
    `).run(`debt_paid2_${Date.now()}@example.com`);
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

  describe('1. Menandai Lunas Penuh (POST & PUT /api/debts/:id/pay & /lunas)', () => {
    it('marks active debt as paid via POST /api/debts/:id/pay', async () => {
      const debt = createDebt(db, {
        userId: user1Id,
        name: 'Shopee Paylater Laptop',
        totalAmount: 1200000,
        remainingAmount: 1200000,
        dueDate: '2026-10-15',
      });

      const res = await fetch(`${baseUrl}/api/debts/${debt.id}/pay?userId=${user1Id}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      });

      assert.strictEqual(res.status, 200);
      const data = await res.json();
      assert.strictEqual(data.success, true);
      assert.strictEqual(data.data.status, 'paid');
      assert.strictEqual(data.data.remainingAmount, 0);
      assert.strictEqual(data.data.paidAmount, 1200000);
      assert.strictEqual(data.data.isPaid, true);
      assert.ok(data.data.paidAt);

      // Verify in DB directly
      const dbRow = db.prepare('SELECT * FROM debts WHERE id = ?').get(debt.id);
      assert.strictEqual(dbRow.status, 'paid');
      assert.strictEqual(dbRow.remaining_amount, 0);
      assert.strictEqual(dbRow.paid_amount, 1200000);
    });

    it('marks debt as paid using route alias /api/hutang/:id/lunas', async () => {
      const debt = createDebt(db, {
        userId: user1Id,
        name: 'Cicilan Kulkas',
        totalAmount: 2500000,
        remainingAmount: 2500000,
        dueDate: '2026-10-20',
      });

      const res = await fetch(`${baseUrl}/api/hutang/${debt.id}/lunas?userId=${user1Id}`, {
        method: 'POST',
      });

      assert.strictEqual(res.status, 200);
      const data = await res.json();
      assert.strictEqual(data.data.status, 'paid');
      assert.strictEqual(data.data.isPaid, true);
    });

    it('returns 404 when debt ID does not exist', async () => {
      const res = await fetch(`${baseUrl}/api/debts/999999/pay?userId=${user1Id}`, {
        method: 'POST',
      });
      assert.strictEqual(res.status, 404);
      const data = await res.json();
      assert.strictEqual(data.success, false);
    });

    it('returns 404 when attempting to mark debt belonging to another user', async () => {
      const debt = createDebt(db, {
        userId: user1Id,
        name: 'User 1 Debt',
        totalAmount: 100000,
        dueDate: '2026-10-01',
      });

      const res = await fetch(`${baseUrl}/api/debts/${debt.id}/pay?userId=${user2Id}`, {
        method: 'POST',
      });
      assert.strictEqual(res.status, 404);
    });
  });

  describe('2. Pembayaran Parsial / Cicilan (Partial Payments)', () => {
    it('records partial payment and updates remainingAmount and paidAmount', async () => {
      const debt = createDebt(db, {
        userId: user1Id,
        name: 'Kartu Kredit Mandiri',
        totalAmount: 5000000,
        remainingAmount: 5000000,
        dueDate: '2026-10-25',
      });

      // Bayar 2 juta
      const payRes = await fetch(`${baseUrl}/api/debts/${debt.id}/pay?userId=${user1Id}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount: 2000000, notes: 'Bayar via transfer BCA' }),
      });

      assert.strictEqual(payRes.status, 200);
      const data = await payRes.json();
      assert.strictEqual(data.data.status, 'active');
      assert.strictEqual(data.data.remainingAmount, 3000000);
      assert.strictEqual(data.data.paidAmount, 2000000);
      assert.strictEqual(data.data.progressPercent, 40);
      assert.strictEqual(data.data.notes, 'Bayar via transfer BCA');
      assert.strictEqual(data.data.isPaid, false);
    });

    it('marks as paid when partial payment covers all remaining amount', async () => {
      const debt = createDebt(db, {
        userId: user1Id,
        name: 'Pinjaman KTA',
        totalAmount: 3000000,
        remainingAmount: 1000000,
        dueDate: '2026-10-10',
      });

      // Bayar 1 juta sisa
      const payRes = await fetch(`${baseUrl}/api/debts/${debt.id}/pay?userId=${user1Id}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount: 1000000 }),
      });

      assert.strictEqual(payRes.status, 200);
      const data = await payRes.json();
      assert.strictEqual(data.data.status, 'paid');
      assert.strictEqual(data.data.remainingAmount, 0);
      assert.strictEqual(data.data.paidAmount, 3000000);
      assert.strictEqual(data.data.isPaid, true);
    });

    it('returns 400 for negative or invalid payment amounts', async () => {
      const debt = createDebt(db, {
        userId: user1Id,
        name: 'Cicilan Gadget',
        totalAmount: 1000000,
        dueDate: '2026-10-10',
      });

      const res = await fetch(`${baseUrl}/api/debts/${debt.id}/pay?userId=${user1Id}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount: -50000 }),
      });

      assert.strictEqual(res.status, 400);
      const data = await res.json();
      assert.strictEqual(data.success, false);
      assert.ok(data.error.includes('lebih besar dari 0'));
    });
  });

  describe('3. Mengaktifkan Kembali Hutang (POST /api/debts/:id/reopen & /aktifkan)', () => {
    it('reopens a paid debt and resets status to active', async () => {
      const debt = createDebt(db, {
        userId: user1Id,
        name: 'Paylater Telur',
        totalAmount: 200000,
        remainingAmount: 0,
        dueDate: '2026-09-20',
      });
      assert.strictEqual(debt.status, 'paid');

      const reopenRes = await fetch(`${baseUrl}/api/debts/${debt.id}/reopen?userId=${user1Id}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ remainingAmount: 200000 }),
      });

      assert.strictEqual(reopenRes.status, 200);
      const data = await reopenRes.json();
      assert.strictEqual(data.data.status, 'active');
      assert.strictEqual(data.data.remainingAmount, 200000);
      assert.strictEqual(data.data.isPaid, false);
      assert.strictEqual(data.data.paidAt, null);
    });
  });

  describe('4. Filter Status pada Endpoint GET /api/debts', () => {
    it('accurately filters active vs paid debts and updates immediately upon marking paid', async () => {
      const debt1 = createDebt(db, {
        userId: user1Id,
        name: 'Debt Active 1',
        totalAmount: 500000,
        remainingAmount: 500000,
        dueDate: '2026-10-05',
      });

      createDebt(db, {
        userId: user1Id,
        name: 'Debt Active 2',
        totalAmount: 300000,
        remainingAmount: 300000,
        dueDate: '2026-10-10',
      });

      // Initial active count: 2, paid count: 0
      const initActive = await (await fetch(`${baseUrl}/api/debts?userId=${user1Id}&status=active`)).json();
      assert.strictEqual(initActive.total, 2);

      const initPaid = await (await fetch(`${baseUrl}/api/debts?userId=${user1Id}&status=paid`)).json();
      assert.strictEqual(initPaid.total, 0);

      // Tandai debt1 lunas
      await fetch(`${baseUrl}/api/debts/${debt1.id}/pay?userId=${user1Id}`, { method: 'POST' });

      // After pay: active count: 1, paid count: 1
      const afterActive = await (await fetch(`${baseUrl}/api/debts?userId=${user1Id}&status=active`)).json();
      assert.strictEqual(afterActive.total, 1);
      assert.strictEqual(afterActive.debts[0].name, 'Debt Active 2');

      const afterPaid = await (await fetch(`${baseUrl}/api/debts?userId=${user1Id}&status=paid`)).json();
      assert.strictEqual(afterPaid.total, 1);
      assert.strictEqual(afterPaid.debts[0].name, 'Debt Active 1');

      // Reopen debt1
      await fetch(`${baseUrl}/api/debts/${debt1.id}/reopen?userId=${user1Id}`, { method: 'POST' });

      // After reopen: active count back to 2, paid count 0
      const restoredActive = await (await fetch(`${baseUrl}/api/debts?userId=${user1Id}&status=active`)).json();
      assert.strictEqual(restoredActive.total, 2);
    });
  });
});
