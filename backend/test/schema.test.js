import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { createDatabaseConnection } from '../src/config/database.js';
import { runMigrations, defaultExpenseCategories, defaultIncomeCategories } from '../src/db/migrate.js';

describe('Database Schema & Table Tests', () => {
  let db;

  beforeEach(() => {
    // Use fresh in-memory database for each test to ensure isolation
    db = createDatabaseConnection({ path: ':memory:' });
    runMigrations(db);
  });

  afterEach(() => {
    if (db) {
      db.close();
    }
  });

  describe('1. Schema Initialization & Seeding', () => {
    it('creates all required tables', () => {
      const tables = db
        .prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
        .all()
        .map((row) => row.name);

      assert.ok(tables.includes('users'), 'Table users should exist');
      assert.ok(tables.includes('categories'), 'Table categories should exist');
      assert.ok(tables.includes('transactions'), 'Table transactions should exist');
      assert.ok(tables.includes('chat_logs'), 'Table chat_logs should exist');
    });

    it('creates all required performance indices', () => {
      const indices = db
        .prepare("SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'")
        .all()
        .map((row) => row.name);

      assert.ok(indices.includes('idx_transactions_user_date'), 'idx_transactions_user_date index should exist');
      assert.ok(indices.includes('idx_transactions_category'), 'idx_transactions_category index should exist');
      assert.ok(indices.includes('idx_chat_logs_user'), 'idx_chat_logs_user index should exist');
      assert.ok(indices.includes('idx_chat_logs_status'), 'idx_chat_logs_status index should exist');
    });

    it('seeds default expense and income categories with user_id NULL', () => {
      const categories = db.prepare('SELECT * FROM categories WHERE is_default = 1').all();

      const expectedTotal = defaultExpenseCategories.length + defaultIncomeCategories.length;
      assert.equal(categories.length, expectedTotal, `Expected ${expectedTotal} default categories`);

      const expenses = categories.filter((c) => c.type === 'expense');
      const incomes = categories.filter((c) => c.type === 'income');

      assert.equal(expenses.length, defaultExpenseCategories.length);
      assert.equal(incomes.length, defaultIncomeCategories.length);

      // Verify specific expected default category names
      const expenseNames = expenses.map((c) => c.name);
      assert.ok(expenseNames.includes('Makan & Minuman'));
      assert.ok(expenseNames.includes('Transportasi'));
      assert.ok(expenseNames.includes('Lainnya'));

      const incomeNames = incomes.map((c) => c.name);
      assert.ok(incomeNames.includes('Gaji'));
      assert.ok(incomeNames.includes('Freelance'));
    });
  });

  describe('2. Users Table Constraints', () => {
    it('inserts a new user and retrieves it', () => {
      const result = db
        .prepare(`
          INSERT INTO users (email, password_hash, display_name, currency, pin_hash)
          VALUES (?, ?, ?, ?, ?)
        `)
        .run('user@example.com', 'hashed_pass_123', 'Ahmad User', 'IDR', '123456');

      assert.equal(result.changes, 1);
      const user = db.prepare('SELECT * FROM users WHERE id = ?').get(result.lastInsertRowid);
      assert.equal(user.email, 'user@example.com');
      assert.equal(user.display_name, 'Ahmad User');
      assert.equal(user.currency, 'IDR');
      assert.ok(user.created_at);
    });

    it('enforces UNIQUE constraint on user email', () => {
      db.prepare("INSERT INTO users (email, display_name) VALUES ('unique@example.com', 'User 1')").run();

      assert.throws(() => {
        db.prepare("INSERT INTO users (email, display_name) VALUES ('unique@example.com', 'User 2')").run();
      }, /UNIQUE constraint failed: users.email/);
    });
  });

  describe('3. Categories Table Constraints', () => {
    it('creates custom category tied to user and allows retrieval', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('cat_user@example.com')").run();
      const userId = userRes.lastInsertRowid;

      const catRes = db
        .prepare(`
          INSERT INTO categories (user_id, name, type, is_default, icon, color)
          VALUES (?, ?, ?, 0, ?, ?)
        `)
        .run(userId, 'Gym & Fitness', 'expense', 'fitness_center', 'amber');

      const customCat = db.prepare('SELECT * FROM categories WHERE id = ?').get(catRes.lastInsertRowid);
      assert.equal(customCat.name, 'Gym & Fitness');
      assert.equal(customCat.user_id, userId);
      assert.equal(customCat.is_default, 0);
    });

    it('rejects invalid category type', () => {
      assert.throws(() => {
        db.prepare("INSERT INTO categories (name, type) VALUES ('Invalid Type', 'investing')").run();
      }, /CHECK constraint failed: type IN \('income', 'expense'\)/);
    });

    it('cascades delete on categories when user is deleted', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('cascade_cat@example.com')").run();
      const userId = userRes.lastInsertRowid;

      db.prepare("INSERT INTO categories (user_id, name, type) VALUES (?, 'Hobi & Game', 'expense')").run(userId);

      // Verify custom category exists
      let customCats = db.prepare('SELECT * FROM categories WHERE user_id = ?').all(userId);
      assert.equal(customCats.length, 1);

      // Delete user
      db.prepare('DELETE FROM users WHERE id = ?').run(userId);

      // Category should be deleted by foreign key cascade
      customCats = db.prepare('SELECT * FROM categories WHERE user_id = ?').all(userId);
      assert.equal(customCats.length, 0);
    });
  });

  describe('4. Transactions Table Constraints & Queries', () => {
    it('inserts expense and income transactions and queries them', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('tx_user@example.com')").run();
      const userId = userRes.lastInsertRowid;

      const makanCat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get();
      const gajiCat = db.prepare("SELECT id FROM categories WHERE name = 'Gaji' AND type = 'income'").get();

      // Insert expense
      const expRes = db
        .prepare(`
          INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
          VALUES (?, ?, 'expense', ?, ?, '2026-09-27 12:00:00', 1)
        `)
        .run(userId, makanCat.id, 25000, 'Makan siang nasi padang');

      // Insert income
      const incRes = db
        .prepare(`
          INSERT INTO transactions (user_id, category_id, type, amount, note, occurred_at, is_confirmed)
          VALUES (?, ?, 'income', ?, ?, '2026-09-27 09:00:00', 1)
        `)
        .run(userId, gajiCat.id, 5000000, 'Gajian bulanan');

      assert.equal(expRes.changes, 1);
      assert.equal(incRes.changes, 1);

      // Query user transactions ordered by date descending
      const transactions = db
        .prepare('SELECT * FROM transactions WHERE user_id = ? ORDER BY occurred_at DESC')
        .all(userId);

      assert.equal(transactions.length, 2);
      assert.equal(transactions[0].type, 'expense');
      assert.equal(transactions[0].amount, 25000);
      assert.equal(transactions[1].type, 'income');
      assert.equal(transactions[1].amount, 5000000);
    });

    it('rejects transaction with amount <= 0', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('zero_tx@example.com')").run();
      const userId = userRes.lastInsertRowid;

      assert.throws(() => {
        db.prepare("INSERT INTO transactions (user_id, type, amount, note) VALUES (?, 'expense', 0, 'Zero amount')").run(userId);
      }, /CHECK constraint failed: amount > 0/);

      assert.throws(() => {
        db.prepare("INSERT INTO transactions (user_id, type, amount, note) VALUES (?, 'expense', -5000, 'Negative amount')").run(userId);
      }, /CHECK constraint failed: amount > 0/);
    });

    it('sets category_id to NULL on transaction when category is deleted', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('del_cat_user@example.com')").run();
      const userId = userRes.lastInsertRowid;

      const catRes = db.prepare("INSERT INTO categories (user_id, name, type) VALUES (?, 'Uji Hapus', 'expense')").run(userId);
      const catId = catRes.lastInsertRowid;

      const txRes = db
        .prepare("INSERT INTO transactions (user_id, category_id, type, amount, note) VALUES (?, ?, 'expense', 15000, 'Test')")
        .run(userId, catId);
      const txId = txRes.lastInsertRowid;

      // Delete the category
      db.prepare('DELETE FROM categories WHERE id = ?').run(catId);

      // Transaction should still exist, but category_id should be NULL (SET NULL)
      const tx = db.prepare('SELECT * FROM transactions WHERE id = ?').get(txId);
      assert.ok(tx, 'Transaction should still exist');
      assert.equal(tx.category_id, null, 'category_id should be NULL');
    });

    it('cascades delete on transactions when user is deleted', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('cascade_tx@example.com')").run();
      const userId = userRes.lastInsertRowid;

      db.prepare("INSERT INTO transactions (user_id, type, amount, note) VALUES (?, 'expense', 30000, 'Belanja')").run(userId);

      // Verify transaction exists
      let txs = db.prepare('SELECT * FROM transactions WHERE user_id = ?').all(userId);
      assert.equal(txs.length, 1);

      // Delete user
      db.prepare('DELETE FROM users WHERE id = ?').run(userId);

      // Transactions must be gone
      txs = db.prepare('SELECT * FROM transactions WHERE user_id = ?').all(userId);
      assert.equal(txs.length, 0);
    });
  });

  describe('5. Chat Logs Table Constraints & Workflow', () => {
    it('creates chat logs with pending, confirmed, and deleted statuses', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('chat_user@example.com')").run();
      const userId = userRes.lastInsertRowid;

      const parsedPayload = JSON.stringify({
        nominal: 25000,
        jenis: 'expense',
        kategori: 'Makan & Minuman',
        confidence: 0.95,
      });

      // 1. Insert initial pending chat log
      const logRes = db
        .prepare(`
          INSERT INTO chat_logs (user_id, message, parsed_json, status)
          VALUES (?, ?, ?, 'pending')
        `)
        .run(userId, 'Makan siang ayam geprek 25rb', parsedPayload);

      const logId = logRes.lastInsertRowid;
      let log = db.prepare('SELECT * FROM chat_logs WHERE id = ?').get(logId);
      assert.equal(log.status, 'pending');
      assert.equal(JSON.parse(log.parsed_json).nominal, 25000);

      // 2. Simulate confirmation: create transaction and link to chat log
      const txRes = db
        .prepare(`
          INSERT INTO transactions (user_id, type, amount, note, is_confirmed)
          VALUES (?, 'expense', 25000, 'Makan siang ayam geprek', 1)
        `)
        .run(userId);

      db.prepare('UPDATE chat_logs SET status = ?, transaction_id = ? WHERE id = ?').run(
        'confirmed',
        txRes.lastInsertRowid,
        logId
      );

      log = db.prepare('SELECT * FROM chat_logs WHERE id = ?').get(logId);
      assert.equal(log.status, 'confirmed');
      assert.equal(log.transaction_id, txRes.lastInsertRowid);

      // 3. Update to deleted status
      db.prepare('UPDATE chat_logs SET status = ? WHERE id = ?').run('deleted', logId);
      log = db.prepare('SELECT * FROM chat_logs WHERE id = ?').get(logId);
      assert.equal(log.status, 'deleted');
    });

    it('rejects invalid chat log status', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('invalid_chat@example.com')").run();
      const userId = userRes.lastInsertRowid;

      assert.throws(() => {
        db.prepare("INSERT INTO chat_logs (user_id, message, status) VALUES (?, 'Halo', 'unknown_status')").run(userId);
      }, /CHECK constraint failed: status IN \('pending', 'confirmed', 'deleted', 'failed'\)/);
    });

    it('sets transaction_id to NULL when associated transaction is deleted', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('link_tx@example.com')").run();
      const userId = userRes.lastInsertRowid;

      const txRes = db.prepare("INSERT INTO transactions (user_id, type, amount, note) VALUES (?, 'expense', 20000, 'Kopi')").run(userId);
      const txId = txRes.lastInsertRowid;

      const logRes = db
        .prepare("INSERT INTO chat_logs (user_id, message, transaction_id, status) VALUES (?, 'Kopi 20rb', ?, 'confirmed')")
        .run(userId, txId);
      const logId = logRes.lastInsertRowid;

      // Delete transaction
      db.prepare('DELETE FROM transactions WHERE id = ?').run(txId);

      // Chat log must remain, with transaction_id set to NULL
      const log = db.prepare('SELECT * FROM chat_logs WHERE id = ?').get(logId);
      assert.ok(log, 'Chat log should remain');
      assert.equal(log.transaction_id, null, 'transaction_id should be NULL');
    });

    it('cascades delete on chat logs when user is deleted', () => {
      const userRes = db.prepare("INSERT INTO users (email) VALUES ('cascade_chat@example.com')").run();
      const userId = userRes.lastInsertRowid;

      db.prepare("INSERT INTO chat_logs (user_id, message) VALUES (?, 'Beli bensin 50rb')").run(userId);

      // Delete user
      db.prepare('DELETE FROM users WHERE id = ?').run(userId);

      // Chat logs must be gone
      const logs = db.prepare('SELECT * FROM chat_logs WHERE user_id = ?').all(userId);
      assert.equal(logs.length, 0);
    });
  });
});
