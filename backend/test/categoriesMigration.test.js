import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createDatabaseConnection } from '../src/config/database.js';
import {
  runMigrations,
  seedDefaultCategories,
  defaultExpenseCategories,
  defaultIncomeCategories,
} from '../src/db/migrate.js';

describe('Categories Table & Default Migration Tests', () => {
  it('creates categories table and seeds exactly 15 default categories', () => {
    // In-memory database for clean, isolated migration testing
    const memDb = createDatabaseConnection({ path: ':memory:' });
    runMigrations(memDb);

    // Verify categories table exists
    const tableCheck = memDb
      .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'categories'")
      .get();
    assert.ok(tableCheck, 'categories table must exist');

    // Verify default expense categories count
    const expenseCount = memDb
      .prepare("SELECT COUNT(*) as count FROM categories WHERE is_default = 1 AND type = 'expense' AND user_id IS NULL")
      .get().count;
    assert.equal(expenseCount, 9, 'Should have 9 default expense categories');

    // Verify default income categories count
    const incomeCount = memDb
      .prepare("SELECT COUNT(*) as count FROM categories WHERE is_default = 1 AND type = 'income' AND user_id IS NULL")
      .get().count;
    assert.equal(incomeCount, 6, 'Should have 6 default income categories');

    // Total default categories
    const totalCount = memDb
      .prepare('SELECT COUNT(*) as count FROM categories WHERE is_default = 1 AND user_id IS NULL')
      .get().count;
    assert.equal(totalCount, 15, 'Total default categories must be 15');

    memDb.close();
  });

  it('contains all required default expense category names and metadata', () => {
    const memDb = createDatabaseConnection({ path: ':memory:' });
    runMigrations(memDb);

    const rows = memDb
      .prepare("SELECT name, icon, color, is_default FROM categories WHERE type = 'expense' AND user_id IS NULL")
      .all();

    const expectedNames = defaultExpenseCategories.map((c) => c.name);
    const actualNames = rows.map((r) => r.name);

    for (const name of expectedNames) {
      assert.ok(actualNames.includes(name), `Missing default expense category: ${name}`);
    }

    // Verify metadata (icon, color, is_default)
    const makanCat = rows.find((r) => r.name === 'Makan & Minuman');
    assert.ok(makanCat);
    assert.equal(makanCat.icon, 'restaurant_rounded');
    assert.equal(makanCat.color, 'orange');
    assert.equal(makanCat.is_default, 1);

    memDb.close();
  });

  it('contains all required default income category names and metadata', () => {
    const memDb = createDatabaseConnection({ path: ':memory:' });
    runMigrations(memDb);

    const rows = memDb
      .prepare("SELECT name, icon, color, is_default FROM categories WHERE type = 'income' AND user_id IS NULL")
      .all();

    const expectedNames = defaultIncomeCategories.map((c) => c.name);
    const actualNames = rows.map((r) => r.name);

    for (const name of expectedNames) {
      assert.ok(actualNames.includes(name), `Missing default income category: ${name}`);
    }

    const gajiCat = rows.find((r) => r.name === 'Gaji');
    assert.ok(gajiCat);
    assert.equal(gajiCat.icon, 'account_balance_wallet_rounded');
    assert.equal(gajiCat.color, 'green');
    assert.equal(gajiCat.is_default, 1);

    memDb.close();
  });

  it('is completely idempotent when run multiple times', () => {
    const memDb = createDatabaseConnection({ path: ':memory:' });
    runMigrations(memDb);
    runMigrations(memDb);
    seedDefaultCategories(memDb);

    const count = memDb
      .prepare('SELECT COUNT(*) as count FROM categories WHERE is_default = 1')
      .get().count;
    assert.equal(count, 15, 'Categories count should not increase upon re-running migrations');

    memDb.close();
  });

  it('allows user custom categories while keeping default categories intact', () => {
    const memDb = createDatabaseConnection({ path: ':memory:' });
    runMigrations(memDb);

    // Create a user
    const userRes = memDb
      .prepare("INSERT INTO users (email, display_name) VALUES ('test@moneta.id', 'Test User')")
      .run();
    const userId = userRes.lastInsertRowid;

    // Add custom category
    memDb
      .prepare(`
        INSERT INTO categories (user_id, name, type, is_default, icon, color)
        VALUES (?, 'Koleksi Hobi & Action Figure', 'expense', 0, 'toys_rounded', 'purple')
      `)
      .run(userId);

    const userCategories = memDb
      .prepare('SELECT * FROM categories WHERE user_id IS NULL OR user_id = ?')
      .all(userId);

    assert.equal(userCategories.length, 16); // 15 default + 1 custom
    assert.ok(userCategories.some((c) => c.name === 'Koleksi Hobi & Action Figure' && c.is_default === 0));

    memDb.close();
  });
});
