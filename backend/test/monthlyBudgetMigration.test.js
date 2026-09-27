import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { createDatabaseConnection } from '../src/config/database.js';
import { runMigrations, ensureMonthlyBudgetSchema } from '../src/db/migrate.js';

describe('Monthly Budget Schema & Migration Tests', () => {
  let db;

  beforeEach(() => {
    db = createDatabaseConnection({ path: ':memory:' });
    runMigrations(db);
  });

  afterEach(() => {
    if (db) {
      db.close();
    }
  });

  it('creates budgets and monthly_budgets tables with all required columns and indices', () => {
    const tables = db
      .prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
      .all()
      .map((r) => r.name);

    assert.ok(tables.includes('budgets'), 'Table budgets should exist');
    assert.ok(tables.includes('monthly_budgets'), 'Table monthly_budgets should exist');

    const budgetCols = db
      .prepare('PRAGMA table_info(budgets)')
      .all()
      .map((c) => c.name);

    for (const col of [
      'id',
      'user_id',
      'category_id',
      'name',
      'amount_limit',
      'total_amount',
      'needs_pct',
      'savings_pct',
      'fun_pct',
      'bucket_type',
      'period',
      'month',
      'alert_enabled',
      'alert_threshold',
      'over_budget_alert_enabled',
      'push_notification_enabled',
      'created_at',
      'updated_at',
    ]) {
      assert.ok(budgetCols.includes(col), `budgets should have column ${col}`);
    }

    const monthlyBudgetCols = db
      .prepare('PRAGMA table_info(monthly_budgets)')
      .all()
      .map((c) => c.name);

    for (const col of [
      'id',
      'user_id',
      'month',
      'total_amount',
      'needs_pct',
      'savings_pct',
      'fun_pct',
      'alert_enabled',
      'alert_threshold',
      'over_budget_alert_enabled',
      'push_notification_enabled',
      'created_at',
      'updated_at',
    ]) {
      assert.ok(monthlyBudgetCols.includes(col), `monthly_budgets should have column ${col}`);
    }

    const indices = db
      .prepare("SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'")
      .all()
      .map((r) => r.name);

    assert.ok(indices.includes('idx_budgets_user_month'));
    assert.ok(indices.includes('idx_budgets_category'));
    assert.ok(indices.includes('idx_budgets_user_monthly_root'));
    assert.ok(indices.includes('idx_monthly_budgets_user_month'));
  });

  it('applies default 50/30/20 allocation percentages and syncs total_amount <-> amount_limit', () => {
    const userRes = db.prepare("INSERT INTO users (email) VALUES ('budget_user@example.com')").run();
    const userId = userRes.lastInsertRowid;

    // 1. Insert using PRD monthly budget columns (total_amount without amount_limit or name)
    const rootRes = db
      .prepare(`
        INSERT INTO budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 6000000)
      `)
      .run(userId);

    const rootBudget = db.prepare('SELECT * FROM budgets WHERE id = ?').get(rootRes.lastInsertRowid);
    assert.equal(rootBudget.name, 'Budget Bulanan');
    assert.equal(rootBudget.total_amount, 6000000);
    assert.equal(rootBudget.amount_limit, 6000000);
    assert.equal(rootBudget.needs_pct, 50);
    assert.equal(rootBudget.savings_pct, 30);
    assert.equal(rootBudget.fun_pct, 20);
    assert.equal(rootBudget.alert_enabled, 1);
    assert.equal(rootBudget.alert_threshold, 80);

    // 2. Insert category budget using amount_limit (syncs total_amount)
    const cat = db.prepare("SELECT id FROM categories WHERE name = 'Makan & Minuman' AND type = 'expense'").get();
    const catRes = db
      .prepare(`
        INSERT INTO budgets (user_id, category_id, name, amount_limit, bucket_type, month)
        VALUES (?, ?, 'Makan & Minuman', 1500000, 'needs', '2026-09')
      `)
      .run(userId, cat.id);

    const catBudget = db.prepare('SELECT * FROM budgets WHERE id = ?').get(catRes.lastInsertRowid);
    assert.equal(catBudget.amount_limit, 1500000);
    assert.equal(catBudget.total_amount, 1500000);
    assert.equal(catBudget.bucket_type, 'needs');

    // 3. Updating total_amount updates amount_limit automatically
    db.prepare('UPDATE budgets SET total_amount = 7500000 WHERE id = ?').run(rootRes.lastInsertRowid);
    const updatedRoot = db.prepare('SELECT * FROM budgets WHERE id = ?').get(rootRes.lastInsertRowid);
    assert.equal(updatedRoot.total_amount, 7500000);
    assert.equal(updatedRoot.amount_limit, 7500000);
  });

  it('enforces constraints on monthly_budgets (unique user+month and 100% allocation sum)', () => {
    const userRes = db.prepare("INSERT INTO users (email) VALUES ('mb_user@example.com')").run();
    const userId = userRes.lastInsertRowid;

    const insertRes = db
      .prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount, needs_pct, savings_pct, fun_pct)
        VALUES (?, '2026-09', 6000000, 50, 30, 20)
      `)
      .run(userId);
    assert.equal(insertRes.changes, 1);

    // Duplicate (user_id, month) should fail
    assert.throws(() => {
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-09', 8000000)
      `).run(userId);
    }, /UNIQUE constraint failed/);

    // Invalid allocation sum (e.g., 60 + 30 + 20 = 110 != 100) should fail CHECK constraint
    assert.throws(() => {
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount, needs_pct, savings_pct, fun_pct)
        VALUES (?, '2026-10', 6000000, 60, 30, 20)
      `).run(userId);
    }, /CHECK constraint failed/);

    // Negative total_amount should fail CHECK constraint
    assert.throws(() => {
      db.prepare(`
        INSERT INTO monthly_budgets (user_id, month, total_amount)
        VALUES (?, '2026-11', -100000)
      `).run(userId);
    }, /CHECK constraint failed/);
  });

  it('migrates legacy budgets table while preserving existing data and backfilling defaults', () => {
    const legacyDb = createDatabaseConnection({ path: ':memory:' });

    try {
      // Simulate legacy schema before monthly budget migration
      legacyDb.exec(`
        CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE NOT NULL
        );
        CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            type TEXT NOT NULL
        );
        CREATE TABLE budgets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            amount_limit REAL NOT NULL CHECK(amount_limit > 0),
            period TEXT NOT NULL DEFAULT 'monthly',
            month TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT unique_user_category_month UNIQUE (user_id, category_id, month)
        );
      `);

      const u = legacyDb.prepare("INSERT INTO users (email) VALUES ('legacy@example.com')").run();
      const c = legacyDb.prepare("INSERT INTO categories (name, type) VALUES ('Makan', 'expense')").run();

      legacyDb
        .prepare(`
          INSERT INTO budgets (user_id, category_id, name, amount_limit, period, month)
          VALUES (?, ?, 'Budget Makan Lama', 2000000, 'monthly', '2026-08')
        `)
        .run(u.lastInsertRowid, c.lastInsertRowid);

      // Run migration on legacy database
      ensureMonthlyBudgetSchema(legacyDb);

      const migrated = legacyDb.prepare('SELECT * FROM budgets WHERE user_id = ?').get(u.lastInsertRowid);
      assert.ok(migrated);
      assert.equal(migrated.name, 'Budget Makan Lama');
      assert.equal(migrated.amount_limit, 2000000);
      assert.equal(migrated.total_amount, 2000000);
      assert.equal(migrated.needs_pct, 50);
      assert.equal(migrated.savings_pct, 30);
      assert.equal(migrated.fun_pct, 20);
      assert.equal(migrated.bucket_type, 'needs');
      assert.equal(migrated.alert_enabled, 1);
      assert.equal(migrated.alert_threshold, 80);
    } finally {
      legacyDb.close();
    }
  });
});
