import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { runMigrations } from '../src/db/migrate.js';

describe('Endpoint POST Tambah Hutang dengan Validasi Tests', () => {
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
      VALUES (?, 'Debtor Tester 1', 'IDR')
    `).run(`debt_user1_${Date.now()}@example.com`);
    user1Id = Number(u1.lastInsertRowid);

    const u2 = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, 'Debtor Tester 2', 'IDR')
    `).run(`debt_user2_${Date.now()}@example.com`);
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

  describe('1. Sukses Menambah Hutang (POST /api/debts & /api/hutang)', () => {
    it('creates a new paylater debt successfully with HTTP 201', async () => {
      const payload = {
        userId: user1Id,
        name: 'Shopee Paylater',
        totalAmount: 750000,
        dueDate: '2026-10-15',
        type: 'paylater',
        notes: 'Belanja perlengkapan kantor',
      };

      const res = await fetch(`${baseUrl}/api/debts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      assert.strictEqual(res.status, 201);
      const data = await res.json();
      assert.strictEqual(data.success, true);
      assert.strictEqual(data.data.name, 'Shopee Paylater');
      assert.strictEqual(data.data.totalAmount, 750000);
      assert.strictEqual(data.data.remainingAmount, 750000);
      assert.strictEqual(data.data.paidAmount, 0);
      assert.strictEqual(data.data.dueDate, '2026-10-15');
      assert.strictEqual(data.data.status, 'active');
      assert.strictEqual(data.data.type, 'paylater');
      assert.strictEqual(data.data.notes, 'Belanja perlengkapan kantor');
      assert.strictEqual(data.data.isPaid, false);
      assert.ok(data.data.formattedTotalAmount.includes('750.000'));
      assert.ok(data.data.dueStatusLabel);

      // Verify stored in DB
      const row = db.prepare('SELECT * FROM debts WHERE id = ?').get(data.data.id);
      assert.ok(row);
      assert.strictEqual(row.name, 'Shopee Paylater');
      assert.strictEqual(row.user_id, user1Id);
    });

    it('creates debt using /api/hutang route alias', async () => {
      const payload = {
        userId: user1Id,
        name: 'GoPay Later',
        totalAmount: 250000,
        dueDate: '2026-10-01',
      };

      const res = await fetch(`${baseUrl}/api/hutang`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      assert.strictEqual(res.status, 201);
      const data = await res.json();
      assert.strictEqual(data.success, true);
      assert.strictEqual(data.data.name, 'GoPay Later');
    });

    it('supports debt types including camelCase (kartuKredit, pinjamanPribadi)', async () => {
      const payload = {
        userId: user1Id,
        name: 'Kartu Kredit BCA',
        totalAmount: 3000000,
        dueDate: '2026-10-20',
        type: 'kartuKredit',
      };

      const res = await fetch(`${baseUrl}/api/debts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      assert.strictEqual(res.status, 201);
      const data = await res.json();
      assert.strictEqual(data.data.type, 'kartu_kredit');
    });

    it('calculates remainingAmount when partial paidAmount is provided', async () => {
      const payload = {
        userId: user1Id,
        name: 'Cicilan HP Samsung',
        totalAmount: 10000000,
        paidAmount: 4000000,
        dueDate: '2026-11-10',
        type: 'cicilan',
      };

      const res = await fetch(`${baseUrl}/api/debts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      assert.strictEqual(res.status, 201);
      const data = await res.json();
      assert.strictEqual(data.data.totalAmount, 10000000);
      assert.strictEqual(data.data.paidAmount, 4000000);
      assert.strictEqual(data.data.remainingAmount, 6000000);
      assert.strictEqual(data.data.progressPercent, 40);
      assert.strictEqual(data.data.status, 'active');
    });

    it('marks as paid immediately when remainingAmount is 0', async () => {
      const payload = {
        userId: user1Id,
        name: 'Pinjaman Sudah Lunas',
        totalAmount: 500000,
        remainingAmount: 0,
        dueDate: '2026-09-30',
      };

      const res = await fetch(`${baseUrl}/api/debts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      assert.strictEqual(res.status, 201);
      const data = await res.json();
      assert.strictEqual(data.data.status, 'paid');
      assert.strictEqual(data.data.isPaid, true);
      assert.ok(data.data.paidAt);
    });
  });

  describe('2. Validasi Input Error Handling (HTTP 400)', () => {
    it('returns 400 when name is missing or empty', async () => {
      const res = await fetch(`${baseUrl}/api/debts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          name: '   ',
          totalAmount: 500000,
          dueDate: '2026-10-10',
        }),
      });

      assert.strictEqual(res.status, 400);
      const data = await res.json();
      assert.strictEqual(data.success, false);
      assert.ok(data.error.includes('Nama hutang'));
    });

    it('returns 400 when totalAmount is missing or <= 0', async () => {
      const res = await fetch(`${baseUrl}/api/debts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          name: 'Cicilan Motor',
          totalAmount: 0,
          dueDate: '2026-10-10',
        }),
      });

      assert.strictEqual(res.status, 400);
      const data = await res.json();
      assert.strictEqual(data.success, false);
      assert.ok(data.error.includes('lebih besar dari 0'));
    });

    it('returns 400 when dueDate is missing or invalid', async () => {
      const res = await fetch(`${baseUrl}/api/debts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          name: 'Cicilan Motor',
          totalAmount: 1500000,
          dueDate: 'bukan-tanggal-valid',
        }),
      });

      assert.strictEqual(res.status, 400);
      const data = await res.json();
      assert.strictEqual(data.success, false);
      assert.ok(data.error.includes('dueDate'));
    });

    it('returns 400 when debt type is invalid', async () => {
      const res = await fetch(`${baseUrl}/api/debts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          name: 'Hutang Asing',
          totalAmount: 500000,
          dueDate: '2026-10-10',
          type: 'tipe_ngawur',
        }),
      });

      assert.strictEqual(res.status, 400);
      const data = await res.json();
      assert.strictEqual(data.success, false);
      assert.ok(data.error.includes('Jenis hutang tidak valid'));
    });

    it('returns 400 when remainingAmount > totalAmount', async () => {
      const res = await fetch(`${baseUrl}/api/debts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          name: 'Kredivo',
          totalAmount: 500000,
          remainingAmount: 600000,
          dueDate: '2026-10-10',
        }),
      });

      assert.strictEqual(res.status, 400);
      const data = await res.json();
      assert.strictEqual(data.success, false);
      assert.ok(data.error.includes('tidak boleh melebihi'));
    });

    it('returns 400 when userId is invalid', async () => {
      const res = await fetch(`${baseUrl}/api/debts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: -5,
          name: 'Hutang Invalid',
          totalAmount: 500000,
          dueDate: '2026-10-10',
        }),
      });

      assert.strictEqual(res.status, 400);
      const data = await res.json();
      assert.strictEqual(data.success, false);
      assert.ok(data.error.includes('userId'));
    });
  });

  describe('3. Isolasi Pengguna (User Isolation)', () => {
    it('keeps debts separated between different users', async () => {
      await fetch(`${baseUrl}/api/debts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          name: 'Debt User 1',
          totalAmount: 1000000,
          dueDate: '2026-10-10',
        }),
      });

      await fetch(`${baseUrl}/api/debts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user2Id,
          name: 'Debt User 2',
          totalAmount: 2000000,
          dueDate: '2026-10-12',
        }),
      });

      const list1 = await (await fetch(`${baseUrl}/api/debts?userId=${user1Id}`)).json();
      assert.strictEqual(list1.total, 1);
      assert.strictEqual(list1.debts[0].name, 'Debt User 1');

      const list2 = await (await fetch(`${baseUrl}/api/debts?userId=${user2Id}`)).json();
      assert.strictEqual(list2.total, 1);
      assert.strictEqual(list2.debts[0].name, 'Debt User 2');
    });
  });
});
