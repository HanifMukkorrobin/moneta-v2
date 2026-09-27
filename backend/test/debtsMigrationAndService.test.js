import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import Database from 'better-sqlite3';
import { runMigrations, ensureDebtsSchema } from '../src/db/migrate.js';
import {
  createDebt,
  getDebtsByUserId,
  getDebtById,
  updateDebt,
  markDebtAsPaid,
  reopenDebt,
  deleteDebt,
  getDebtSummary,
  calculateDaysUntilDue,
  getDueStatusLabel,
  normalizeDebtType,
  normalizeDebtStatus,
} from '../src/services/debtService.js';

describe('Tabel Debts, Migrasi SQLite & Service Layer Tests', () => {
  let db;
  let testUserId;
  let testUser2Id;

  beforeEach(() => {
    db = new Database(':memory:');
    db.pragma('foreign_keys = ON');
    runMigrations(db);

    const userStmt = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, ?, ?)
    `);

    const u1 = userStmt.run('debt.tester1@example.com', 'Debtor One', 'IDR');
    testUserId = u1.lastInsertRowid;

    const u2 = userStmt.run('debt.tester2@example.com', 'Debtor Two', 'IDR');
    testUser2Id = u2.lastInsertRowid;
  });

  afterEach(() => {
    if (db) {
      db.close();
    }
  });

  describe('1. Skema Tabel Debts & Kolom', () => {
    it('creates debts table with all required columns and constraints', () => {
      const tableInfo = db.prepare('PRAGMA table_info(debts)').all();
      const colNames = tableInfo.map((c) => c.name);

      assert.ok(colNames.includes('id'));
      assert.ok(colNames.includes('user_id'));
      assert.ok(colNames.includes('name'));
      assert.ok(colNames.includes('total_amount'));
      assert.ok(colNames.includes('remaining_amount'));
      assert.ok(colNames.includes('paid_amount'));
      assert.ok(colNames.includes('due_date'));
      assert.ok(colNames.includes('status'));
      assert.ok(colNames.includes('type'));
      assert.ok(colNames.includes('notes'));
      assert.ok(colNames.includes('paid_at'));
      assert.ok(colNames.includes('created_at'));
      assert.ok(colNames.includes('updated_at'));
    });

    it('creates performance indices on debts table', () => {
      const indices = db.prepare("PRAGMA index_list('debts')").all();
      const indexNames = indices.map((idx) => idx.name);

      assert.ok(indexNames.includes('idx_debts_user_status'));
      assert.ok(indexNames.includes('idx_debts_due_date'));
      assert.ok(indexNames.includes('idx_debts_user_due'));
      assert.ok(indexNames.includes('idx_debts_type'));
    });

    it('creates views catatan_hutang and hutang', () => {
      const v1 = db.prepare("SELECT name FROM sqlite_master WHERE type='view' AND name='catatan_hutang'").get();
      assert.ok(v1);

      const v2 = db.prepare("SELECT name FROM sqlite_master WHERE type='view' AND name='hutang'").get();
      assert.ok(v2);

      // Insert and query via views
      createDebt(db, {
        userId: testUserId,
        name: 'Shopee Paylater',
        totalAmount: 500000,
        dueDate: '2026-10-05',
        type: 'paylater',
      });

      const fromView1 = db.prepare('SELECT * FROM catatan_hutang WHERE user_id = ?').all(testUserId);
      assert.strictEqual(fromView1.length, 1);
      assert.strictEqual(fromView1[0].name, 'Shopee Paylater');

      const fromView2 = db.prepare('SELECT * FROM hutang WHERE user_id = ?').all(testUserId);
      assert.strictEqual(fromView2.length, 1);
      assert.strictEqual(fromView2[0].total_amount, 500000);
    });

    it('cascades delete when user is deleted', () => {
      createDebt(db, {
        userId: testUserId,
        name: 'Cicilan Laptop',
        totalAmount: 12000000,
        dueDate: '2026-11-20',
      });

      assert.strictEqual(getDebtsByUserId(db, testUserId).length, 1);

      db.prepare('DELETE FROM users WHERE id = ?').run(testUserId);
      const afterDel = db.prepare('SELECT * FROM debts WHERE user_id = ?').all(testUserId);
      assert.strictEqual(afterDel.length, 0);
    });

    it('enforces total_amount and remaining_amount >= 0 constraints', () => {
      assert.throws(() => {
        db.prepare(`
          INSERT INTO debts (user_id, name, total_amount, due_date)
          VALUES (?, 'Invalid Debt', -50000, '2026-10-01')
        `).run(testUserId);
      });
    });

    it('runs migrations repeatedly without error or duplicate objects', () => {
      assert.doesNotThrow(() => {
        runMigrations(db);
        runMigrations(db);
        ensureDebtsSchema(db);
      });
    });
  });

  describe('2. SQL Triggers for Paid Status Synchronization', () => {
    it('sets status to paid automatically on insert when remaining_amount <= 0', () => {
      const res = db.prepare(`
        INSERT INTO debts (user_id, name, total_amount, remaining_amount, due_date, status)
        VALUES (?, 'Lunas Direct', 200000, 0, '2026-09-30', 'active')
      `).run(testUserId);

      const row = db.prepare('SELECT * FROM debts WHERE id = ?').get(res.lastInsertRowid);
      assert.strictEqual(row.status, 'paid');
      assert.ok(row.paid_at);
    });

    it('updates status to paid automatically when remaining_amount is updated to 0', () => {
      const debt = createDebt(db, {
        userId: testUserId,
        name: 'Kredivo Gadget',
        totalAmount: 1500000,
        remainingAmount: 500000,
        dueDate: '2026-10-15',
      });
      assert.strictEqual(debt.status, 'active');

      db.prepare('UPDATE debts SET remaining_amount = 0 WHERE id = ?').run(debt.id);
      const updated = db.prepare('SELECT * FROM debts WHERE id = ?').get(debt.id);
      assert.strictEqual(updated.status, 'paid');
      assert.ok(updated.paid_at);
    });
  });

  describe('3. Debt Service Functions & Helpers', () => {
    it('creates debt with calculated paidAmount and formatted strings', () => {
      const debt = createDebt(db, {
        userId: testUserId,
        name: 'Kartu Kredit Mandiri',
        totalAmount: 2500000,
        remainingAmount: 1500000,
        dueDate: '2026-10-25',
        type: 'kartuKredit',
        notes: 'Tagihan bulanan tiket pesawat',
      });

      assert.strictEqual(debt.name, 'Kartu Kredit Mandiri');
      assert.strictEqual(debt.totalAmount, 2500000);
      assert.strictEqual(debt.remainingAmount, 1500000);
      assert.strictEqual(debt.paidAmount, 1000000);
      assert.strictEqual(debt.type, 'kartu_kredit');
      assert.strictEqual(debt.status, 'active');
      assert.strictEqual(debt.isPaid, false);
      assert.strictEqual(debt.progressPercent, 40);
      assert.ok(debt.formattedTotalAmount.includes('2.500.000'));
      assert.ok(debt.formattedRemainingAmount.includes('1.500.000'));
    });

    it('filters debts by user, status, and type with sorting', () => {
      createDebt(db, {
        userId: testUserId,
        name: 'GoPay Later',
        totalAmount: 300000,
        remainingAmount: 300000,
        dueDate: '2026-10-01',
        type: 'paylater',
      });

      createDebt(db, {
        userId: testUserId,
        name: 'Pinjaman Teman',
        totalAmount: 1000000,
        remainingAmount: 0,
        dueDate: '2026-09-15',
        type: 'pinjaman_pribadi',
      });

      createDebt(db, {
        userId: testUser2Id,
        name: 'User 2 Debt',
        totalAmount: 500000,
        dueDate: '2026-10-10',
      });

      // User 1 debts isolation
      const user1Debts = getDebtsByUserId(db, testUserId);
      assert.strictEqual(user1Debts.length, 2);

      // Filter by status active
      const activeDebts = getDebtsByUserId(db, testUserId, { status: 'active' });
      assert.strictEqual(activeDebts.length, 1);
      assert.strictEqual(activeDebts[0].name, 'GoPay Later');

      // Filter by status paid
      const paidDebts = getDebtsByUserId(db, testUserId, { status: 'paid' });
      assert.strictEqual(paidDebts.length, 1);
      assert.strictEqual(paidDebts[0].name, 'Pinjaman Teman');

      // Filter by type
      const paylaterDebts = getDebtsByUserId(db, testUserId, { type: 'paylater' });
      assert.strictEqual(paylaterDebts.length, 1);
    });

    it('updates debt fields and recalculates amounts', () => {
      const debt = createDebt(db, {
        userId: testUserId,
        name: 'Cicilan HP',
        totalAmount: 6000000,
        remainingAmount: 6000000,
        dueDate: '2026-10-10',
      });

      const updated = updateDebt(db, debt.id, testUserId, {
        remainingAmount: 4000000,
        notes: 'Sudah bayar DP 2 juta',
      });

      assert.strictEqual(updated.remainingAmount, 4000000);
      assert.strictEqual(updated.paidAmount, 2000000);
      assert.strictEqual(updated.progressPercent, 33);
      assert.strictEqual(updated.notes, 'Sudah bayar DP 2 juta');
    });

    it('marks debt as paid and reopens debt', () => {
      const debt = createDebt(db, {
        userId: testUserId,
        name: 'Akulaku Belanja',
        totalAmount: 850000,
        remainingAmount: 850000,
        dueDate: '2026-10-05',
      });

      // Mark paid
      const paid = markDebtAsPaid(db, debt.id, testUserId);
      assert.strictEqual(paid.status, 'paid');
      assert.strictEqual(paid.remainingAmount, 0);
      assert.strictEqual(paid.paidAmount, 850000);
      assert.strictEqual(paid.isPaid, true);
      assert.ok(paid.paidAt);

      // Reopen
      const reopened = reopenDebt(db, debt.id, testUserId, 400000);
      assert.strictEqual(reopened.status, 'active');
      assert.strictEqual(reopened.remainingAmount, 400000);
      assert.strictEqual(reopened.isPaid, false);
      assert.strictEqual(reopened.paidAt, null);
    });

    it('deletes debt by id with user isolation', () => {
      const debt = createDebt(db, {
        userId: testUserId,
        name: 'Temporary Debt',
        totalAmount: 100000,
        dueDate: '2026-10-01',
      });

      // Cannot delete with wrong user
      const failed = deleteDebt(db, debt.id, testUser2Id);
      assert.strictEqual(failed, false);
      assert.ok(getDebtById(db, debt.id, testUserId));

      // Successful delete
      const deleted = deleteDebt(db, debt.id, testUserId);
      assert.strictEqual(deleted, true);
      assert.strictEqual(getDebtById(db, debt.id, testUserId), null);
    });
  });

  describe('4. Due Date Calculation & Summary Aggregation', () => {
    it('calculates days until due and formats labels', () => {
      const ref = new Date('2026-09-27T10:00:00Z');

      assert.strictEqual(calculateDaysUntilDue('2026-09-27', ref), 0);
      assert.strictEqual(calculateDaysUntilDue('2026-09-28', ref), 1);
      assert.strictEqual(calculateDaysUntilDue('2026-09-30', ref), 3);
      assert.strictEqual(calculateDaysUntilDue('2026-09-25', ref), -2);

      assert.strictEqual(getDueStatusLabel(0, false), 'Jatuh Tempo Hari Ini');
      assert.strictEqual(getDueStatusLabel(1, false), 'Jatuh Tempo Besok');
      assert.strictEqual(getDueStatusLabel(3, false), '3 hari lagi');
      assert.strictEqual(getDueStatusLabel(-2, false), 'Lewat Jatuh Tempo (2 hari)');
      assert.strictEqual(getDueStatusLabel(0, true), 'Lunas');
    });

    it('aggregates debt summary with due soon and clearance rates', () => {
      const ref = new Date('2026-09-27T00:00:00Z');

      // Debt 1: Overdue
      createDebt(db, {
        userId: testUserId,
        name: 'Overdue Loan',
        totalAmount: 1000000,
        remainingAmount: 1000000,
        dueDate: '2026-09-25',
      });

      // Debt 2: Due Soon (besok)
      createDebt(db, {
        userId: testUserId,
        name: 'Due Soon Bill',
        totalAmount: 500000,
        remainingAmount: 300000,
        dueDate: '2026-09-28',
      });

      // Debt 3: Future
      createDebt(db, {
        userId: testUserId,
        name: 'Future Debt',
        totalAmount: 2000000,
        remainingAmount: 2000000,
        dueDate: '2026-10-20',
      });

      // Debt 4: Paid
      createDebt(db, {
        userId: testUserId,
        name: 'Paid Off Debt',
        totalAmount: 1500000,
        remainingAmount: 0,
        dueDate: '2026-09-20',
      });

      const summary = getDebtSummary(db, testUserId, ref);

      assert.strictEqual(summary.totalDebtsCount, 4);
      assert.strictEqual(summary.activeDebtsCount, 3);
      assert.strictEqual(summary.paidDebtsCount, 1);
      assert.strictEqual(summary.totalDebtAmount, 5000000);
      assert.strictEqual(summary.totalRemainingAmount, 3300000);
      assert.strictEqual(summary.totalPaidAmount, 1700000);
      assert.strictEqual(summary.clearancePercent, 34); // 1.7m / 5m = 34%
      assert.strictEqual(summary.overdueCount, 1);
      assert.strictEqual(summary.dueSoonCount, 1);
      assert.strictEqual(summary.dueSoonList.length, 1);
      assert.strictEqual(summary.dueSoonList[0].name, 'Due Soon Bill');
    });

    it('normalizes debt types and statuses', () => {
      assert.strictEqual(normalizeDebtType('kartuKredit'), 'kartu_kredit');
      assert.strictEqual(normalizeDebtType('pinjamanPribadi'), 'pinjaman_pribadi');
      assert.strictEqual(normalizeDebtType('cicilan'), 'cicilan');
      assert.strictEqual(normalizeDebtStatus('lunas'), 'paid');
      assert.strictEqual(normalizeDebtStatus('aktif'), 'active');
    });
  });
});
