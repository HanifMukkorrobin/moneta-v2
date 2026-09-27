import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { runMigrations } from '../src/db/migrate.js';
import { createDebt } from '../src/services/debtService.js';

describe('Endpoint Ringkasan Total Sisa Hutang Aktif Tests', () => {
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
      VALUES (?, 'Summary Tester 1', 'IDR')
    `).run(`debt_sum1_${Date.now()}@example.com`);
    user1Id = Number(u1.lastInsertRowid);

    const u2 = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, 'Summary Tester 2', 'IDR')
    `).run(`debt_sum2_${Date.now()}@example.com`);
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

  describe('1. Ringkasan Kosong Saat Pengguna Belum Memiliki Catatan Hutang', () => {
    it('returns zero totals and empty list when no debts exist', async () => {
      const res = await fetch(`${baseUrl}/api/debts/summary?userId=${user1Id}`);
      assert.equal(res.status, 200);

      const json = await res.json();
      assert.equal(json.success, true);
      assert.equal(json.totalRemainingAmount, 0);
      assert.equal(json.totalDebtAmount, 0);
      assert.equal(json.totalPaidAmount, 0);
      assert.equal(json.activeDebtsCount, 0);
      assert.equal(json.paidDebtsCount, 0);
      assert.equal(json.dueSoonCount, 0);
      assert.equal(json.overdueCount, 0);
      assert.equal(json.hasDueSoon, false);
      assert.equal(json.hasOverdue, false);
      assert.equal(json.clearancePercent, 100);
      assert.equal(json.clearanceRatio, 1.0);
      assert.ok(json.formattedTotalRemainingAmount.includes('0'));
    });

    it('works across route aliases: /api/debts/total-sisa & /api/hutang/ringkasan', async () => {
      const res1 = await fetch(`${baseUrl}/api/debts/total-sisa?userId=${user1Id}`);
      assert.equal(res1.status, 200);
      const json1 = await res1.json();
      assert.equal(json1.totalRemainingAmount, 0);

      const res2 = await fetch(`${baseUrl}/api/hutang/ringkasan?userId=${user1Id}`);
      assert.equal(res2.status, 200);
      const json2 = await res2.json();
      assert.equal(json2.totalRemainingAmount, 0);

      const res3 = await fetch(`${baseUrl}/api/hutang/total-sisa?userId=${user1Id}`);
      assert.equal(res3.status, 200);
      const json3 = await res3.json();
      assert.equal(json3.totalRemainingAmount, 0);
    });
  });

  describe('2. Kalkulasi Total Sisa Hutang Aktif & Persentase Pelunasan', () => {
    it('accurately calculates active remaining amounts, paid amounts, and clearance percentage', async () => {
      // 1. Tagihan SPayLater (Aktif, sisa 400.000 dari 1.000.000)
      createDebt(db, {
        userId: user1Id,
        name: 'SPayLater Meja Kerja',
        totalAmount: 1000000,
        remainingAmount: 400000,
        dueDate: '2026-10-15',
        type: 'paylater',
      });

      // 2. Tagihan Cicilan HP (Aktif, sisa 600.000 dari 600.000)
      createDebt(db, {
        userId: user1Id,
        name: 'Cicilan HP',
        totalAmount: 600000,
        remainingAmount: 600000,
        dueDate: '2026-10-25',
        type: 'cicilan',
      });

      // 3. Tagihan Pinjaman Teman (Sudah Lunas)
      createDebt(db, {
        userId: user1Id,
        name: 'Pinjaman Renovasi Teman',
        totalAmount: 400000,
        remainingAmount: 0,
        dueDate: '2026-09-01',
        type: 'pinjaman',
        status: 'paid',
      });

      const res = await fetch(`${baseUrl}/api/debts/summary?userId=${user1Id}`);
      assert.equal(res.status, 200);

      const json = await res.json();
      assert.equal(json.success, true);

      // Total hutang keseluruhan: 1.000.000 + 600.000 + 400.000 = 2.000.000
      assert.equal(json.totalDebtAmount, 2000000);

      // Total sisa hutang AKTIF: 400.000 + 600.000 = 1.000.000
      assert.equal(json.totalRemainingAmount, 1000000);
      assert.equal(json.total_remaining_amount, 1000000);

      // Total terbayar: (1.000.000 - 400.000) + 0 + 400.000 = 1.000.000
      assert.equal(json.totalPaidAmount, 1000000);

      // Jumlah tagihan
      assert.equal(json.totalDebtsCount, 3);
      assert.equal(json.activeDebtsCount, 2);
      assert.equal(json.paidDebtsCount, 1);

      // Rasio pelunasan: 1.000.000 / 2.000.000 = 50%
      assert.equal(json.clearanceRatio, 0.5);
      assert.equal(json.clearancePercent, 50);

      // Format Rupiah
      assert.ok(json.formattedTotalRemainingAmount.includes('1.000.000'));
      assert.ok(json.formattedTotalDebtAmount.includes('2.000.000'));
      assert.ok(json.formattedTotalPaidAmount.includes('1.000.000'));
    });
  });

  describe('3. Deteksi Tagihan Jatuh Tempo Terdekat (Due Soon) & Terlewat (Overdue)', () => {
    it('detects debts due in <= 3 days and overdue debts in summary', async () => {
      const now = new Date();

      // Jatuh tempo besok (+1 hari) -> due soon
      const tomorrow = new Date(now.getTime() + 1 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
      createDebt(db, {
        userId: user1Id,
        name: 'Kredivo Listrik (Besok)',
        totalAmount: 250000,
        remainingAmount: 250000,
        dueDate: tomorrow,
        type: 'paylater',
      });

      // Jatuh tempo 5 hari lagi -> bukan due soon
      const future = new Date(now.getTime() + 5 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
      createDebt(db, {
        userId: user1Id,
        name: 'Kartu Kredit Mandiri',
        totalAmount: 750000,
        remainingAmount: 750000,
        dueDate: future,
        type: 'kartu_kredit',
      });

      // Jatuh tempo 3 hari lalu -> overdue
      const past = new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
      createDebt(db, {
        userId: user1Id,
        name: 'Cicilan Motor Tertunggak',
        totalAmount: 500000,
        remainingAmount: 500000,
        dueDate: past,
        type: 'cicilan',
      });

      const res = await fetch(`${baseUrl}/api/debts/summary?userId=${user1Id}`);
      assert.equal(res.status, 200);

      const json = await res.json();
      assert.equal(json.activeDebtsCount, 3);
      assert.equal(json.dueSoonCount, 1);
      assert.equal(json.hasDueSoon, true);
      assert.equal(json.overdueCount, 1);
      assert.equal(json.hasOverdue, true);

      assert.equal(json.dueSoonList.length, 1);
      assert.equal(json.dueSoonList[0].name, 'Kredivo Listrik (Besok)');
    });
  });

  describe('4. Rincian Sisa Berdasarkan Tipe Hutang (Breakdown per Tipe)', () => {
    it('groups remaining active debt by type for TotalSisaHutangCard breakdown UI', async () => {
      createDebt(db, {
        userId: user1Id,
        name: 'GoPay Later 1',
        totalAmount: 300000,
        remainingAmount: 200000,
        dueDate: '2026-10-10',
        type: 'paylater',
      });
      createDebt(db, {
        userId: user1Id,
        name: 'Shopee PayLater 2',
        totalAmount: 500000,
        remainingAmount: 300000,
        dueDate: '2026-10-12',
        type: 'paylater',
      });
      createDebt(db, {
        userId: user1Id,
        name: 'Cicilan Gadget',
        totalAmount: 1500000,
        remainingAmount: 1000000,
        dueDate: '2026-10-20',
        type: 'cicilan',
      });

      const res = await fetch(`${baseUrl}/api/debts/summary?userId=${user1Id}`);
      assert.equal(res.status, 200);

      const json = await res.json();
      assert.ok(Array.isArray(json.breakdown));

      const paylater = json.breakdown.find((b) => b.type === 'paylater');
      assert.ok(paylater);
      assert.equal(paylater.count, 2);
      assert.equal(paylater.remainingAmount, 500000); // 200.000 + 300.000
      assert.ok(paylater.formattedRemainingAmount.includes('500.000'));

      const cicilan = json.breakdown.find((b) => b.type === 'cicilan');
      assert.ok(cicilan);
      assert.equal(cicilan.count, 1);
      assert.equal(cicilan.remainingAmount, 1000000);

      // Cek juga breakdownByType dictionary
      assert.equal(json.breakdownByType.paylater.remainingAmount, 500000);
      assert.equal(json.breakdownByType.cicilan.remainingAmount, 1000000);
    });
  });

  describe('5. Isolasi Data Pengguna & Validasi Header/Query', () => {
    it('ensures user 1 data is completely isolated from user 2', async () => {
      // User 1 hutang
      createDebt(db, {
        userId: user1Id,
        name: 'Hutang User 1',
        totalAmount: 500000,
        remainingAmount: 500000,
        dueDate: '2026-10-10',
        type: 'paylater',
      });

      // User 2 hutang
      createDebt(db, {
        userId: user2Id,
        name: 'Hutang User 2',
        totalAmount: 1200000,
        remainingAmount: 1200000,
        dueDate: '2026-10-15',
        type: 'pinjaman',
      });

      // Cek User 1 via header x-user-id
      const resUser1 = await fetch(`${baseUrl}/api/debts/summary`, {
        headers: { 'x-user-id': String(user1Id) },
      });
      const dataUser1 = await resUser1.json();
      assert.equal(dataUser1.totalRemainingAmount, 500000);
      assert.equal(dataUser1.activeDebtsCount, 1);

      // Cek User 2 via query param ?userId=
      const resUser2 = await fetch(`${baseUrl}/api/debts/summary?userId=${user2Id}`);
      const dataUser2 = await resUser2.json();
      assert.equal(dataUser2.totalRemainingAmount, 1200000);
      assert.equal(dataUser2.activeDebtsCount, 1);
    });

    it('returns 400 for invalid userId', async () => {
      const res = await fetch(`${baseUrl}/api/debts/summary?userId=invalid_abc`);
      assert.equal(res.status, 400);

      const json = await res.json();
      assert.equal(json.success, false);
      assert.ok(json.error.includes('userId'));
    });
  });
});
