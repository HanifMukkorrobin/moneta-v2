import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase, createDatabaseConnection } from '../src/config/database.js';
import { ensureTransactionCategoryAndTypeColumns, runMigrations } from '../src/db/migrate.js';

describe('Transaction Category & Type Columns Tests', () => {
  let server;
  let baseUrl;
  let db;

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

  it('has category_name, type, is_guessed, confidence_score, and ai_reasoning columns in transactions table', () => {
    const columns = db.prepare('PRAGMA table_info(transactions)').all();
    const colNames = columns.map((c) => c.name);

    assert.ok(colNames.includes('category_name'), 'Should have category_name column');
    assert.ok(colNames.includes('type'), 'Should have type column');
    assert.ok(colNames.includes('is_guessed'), 'Should have is_guessed column');
    assert.ok(colNames.includes('confidence_score'), 'Should have confidence_score column');
    assert.ok(colNames.includes('ai_reasoning'), 'Should have ai_reasoning column');
  });

  it('creates performance indices on type and category_id + type', () => {
    const indices = db.prepare("SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'transactions'").all();
    const indexNames = indices.map((i) => i.name);

    assert.ok(indexNames.includes('idx_transactions_type'), 'Should have index on type');
    assert.ok(indexNames.includes('idx_transactions_cat_type'), 'Should have composite index on category_id and type');
  });

  it('populates category_name, is_guessed=1, confidence_score, and reasoning when parsed by AI', async () => {
    const parseRes = await fetch(`${baseUrl}/api/chat/parse`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: 'Beli bensin 25rb' }),
    });

    assert.equal(parseRes.status, 200);
    const parseData = await parseRes.json();
    const txId = parseData.transaction.id;

    // Check database row
    const row = db.prepare('SELECT * FROM transactions WHERE id = ?').get(txId);
    assert.ok(row);
    assert.equal(row.category_name, 'Transportasi');
    assert.equal(row.type, 'expense');
    assert.equal(row.is_guessed, 1, 'AI guessed category must have is_guessed = 1');
    assert.ok(row.confidence_score >= 0.8);
    assert.ok(row.ai_reasoning);

    // Confirm transaction and verify is_guessed resets to 0
    const confirmRes = await fetch(`${baseUrl}/api/transactions/confirm`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ transactionId: txId }),
    });
    assert.equal(confirmRes.status, 200);

    const confirmedRow = db.prepare('SELECT is_guessed FROM transactions WHERE id = ?').get(txId);
    assert.equal(confirmedRow.is_guessed, 0, 'Confirmed transaction should set is_guessed = 0');
  });

  it('supports migration on existing schema without failing or duplicating columns', () => {
    const memDb = createDatabaseConnection({ path: ':memory:' });
    runMigrations(memDb);
    // Running column check twice should be completely safe
    ensureTransactionCategoryAndTypeColumns(memDb);
    ensureTransactionCategoryAndTypeColumns(memDb);

    const columns = memDb.prepare('PRAGMA table_info(transactions)').all().map((c) => c.name);
    assert.ok(columns.includes('category_name'));
    assert.ok(columns.includes('type'));
    assert.ok(columns.includes('is_guessed'));

    memDb.close();
  });
});
