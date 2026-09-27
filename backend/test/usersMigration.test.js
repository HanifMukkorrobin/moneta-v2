import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import Database from 'better-sqlite3';
import { runMigrations, ensureUsersSchema } from '../src/db/migrate.js';

describe('Users Table Schema & Migration Tests (Akun & Pengaturan)', () => {
  let db;

  beforeEach(() => {
    db = new Database(':memory:');
    db.pragma('foreign_keys = ON');
    runMigrations(db);
  });

  afterEach(() => {
    if (db) {
      db.close();
    }
  });

  describe('1. Skema Tabel Users & Kolom Default', () => {
    it('creates users table with all required Akun & Pengaturan columns', () => {
      const tableInfo = db.prepare('PRAGMA table_info(users)').all();
      const colNames = tableInfo.map((c) => c.name);

      const expectedColumns = [
        'id',
        'email',
        'password_hash',
        'display_name',
        'currency',
        'currency_symbol',
        'pin_hash',
        'pin_enabled',
        'biometric_enabled',
        'notifications_enabled',
        'ai_advice_tone',
        'monthly_budget_limit',
        'account_tier',
        'date_format',
        'first_day_of_week',
        'theme_mode',
        'hide_balance',
        'auto_confirm_chat',
        'haptic_feedback',
        'budget_alert_threshold',
        'phone',
        'avatar_url',
        'last_login_at',
        'created_at',
        'updated_at',
      ];

      for (const col of expectedColumns) {
        assert.ok(colNames.includes(col), `Column ${col} should exist in users table`);
      }
    });

    it('applies expected default values when inserting a minimal user', () => {
      const res = db
        .prepare("INSERT INTO users (email, display_name) VALUES ('budi@moneta.ai', 'Budi Santoso')")
        .run();

      const user = db.prepare('SELECT * FROM users WHERE id = ?').get(res.lastInsertRowid);
      assert.strictEqual(user.email, 'budi@moneta.ai');
      assert.strictEqual(user.display_name, 'Budi Santoso');
      assert.strictEqual(user.currency, 'IDR');
      assert.strictEqual(user.currency_symbol, 'Rp');
      assert.strictEqual(user.pin_enabled, 0);
      assert.strictEqual(user.biometric_enabled, 0);
      assert.strictEqual(user.notifications_enabled, 1);
      assert.strictEqual(user.ai_advice_tone, 'Standar');
      assert.strictEqual(user.monthly_budget_limit, 6000000);
      assert.strictEqual(user.account_tier, 'Personal AI');
      assert.strictEqual(user.date_format, 'DD/MM/YYYY');
      assert.strictEqual(user.first_day_of_week, 'Senin');
      assert.strictEqual(user.theme_mode, 'Terang');
      assert.strictEqual(user.hide_balance, 0);
      assert.strictEqual(user.auto_confirm_chat, 0);
      assert.strictEqual(user.haptic_feedback, 1);
      assert.strictEqual(user.budget_alert_threshold, 80);
      assert.ok(user.created_at);
      assert.ok(user.updated_at);
    });

    it('creates performance indices and Indonesian view aliases (pengguna, akun_pengguna, sesi_pengguna)', () => {
      const userIndices = db.prepare("PRAGMA index_list('users')").all().map((idx) => idx.name);
      assert.ok(userIndices.includes('idx_users_email'));
      assert.ok(userIndices.includes('idx_users_currency'));
      assert.ok(userIndices.includes('idx_users_theme_mode'));

      const sessionIndices = db.prepare("PRAGMA index_list('user_sessions')").all().map((idx) => idx.name);
      assert.ok(sessionIndices.includes('idx_user_sessions_user'));
      assert.ok(sessionIndices.includes('idx_user_sessions_token'));

      const views = db
        .prepare("SELECT name FROM sqlite_master WHERE type = 'view'")
        .all()
        .map((v) => v.name);
      assert.ok(views.includes('pengguna'));
      assert.ok(views.includes('akun_pengguna'));
      assert.ok(views.includes('sesi_pengguna'));

      db.prepare("INSERT INTO users (email, display_name) VALUES ('viewtest@moneta.ai', 'View Tester')").run();
      const fromPengguna = db.prepare("SELECT * FROM pengguna WHERE email = 'viewtest@moneta.ai'").get();
      assert.ok(fromPengguna);
      assert.strictEqual(fromPengguna.display_name, 'View Tester');

      const fromAkun = db.prepare("SELECT * FROM akun_pengguna WHERE email = 'viewtest@moneta.ai'").get();
      assert.ok(fromAkun);
      assert.strictEqual(fromAkun.currency, 'IDR');
    });
  });

  describe('2. Constraints, Triggers & Tabel Sesi (user_sessions)', () => {
    it('enforces UNIQUE email and CHECK constraints on preference fields', () => {
      db.prepare("INSERT INTO users (email) VALUES ('dup@moneta.ai')").run();
      assert.throws(() => {
        db.prepare("INSERT INTO users (email) VALUES ('dup@moneta.ai')").run();
      }, /UNIQUE constraint failed: users.email/);

      assert.throws(() => {
        db.prepare("INSERT INTO users (email, ai_advice_tone) VALUES ('bad_tone@moneta.ai', 'Marah')").run();
      }, /CHECK constraint failed/);

      assert.throws(() => {
        db.prepare("INSERT INTO users (email, budget_alert_threshold) VALUES ('bad_thresh@moneta.ai', 150)").run();
      }, /CHECK constraint failed/);

      assert.throws(() => {
        db.prepare("INSERT INTO users (email, monthly_budget_limit) VALUES ('bad_limit@moneta.ai', -1000)").run();
      }, /CHECK constraint failed/);
    });

    it('updates updated_at automatically on row modification via trigger', () => {
      const res = db
        .prepare("INSERT INTO users (email, display_name, updated_at) VALUES ('trig@moneta.ai', 'Old Name', '2025-01-01 00:00:00')")
        .run();

      db.prepare('UPDATE users SET display_name = ? WHERE id = ?').run('New Name', res.lastInsertRowid);
      const updated = db.prepare('SELECT display_name, updated_at FROM users WHERE id = ?').get(res.lastInsertRowid);
      assert.strictEqual(updated.display_name, 'New Name');
      assert.notStrictEqual(updated.updated_at, '2025-01-01 00:00:00');
    });

    it('supports user_sessions creation and cascades delete when user is deleted', () => {
      const userRes = db
        .prepare("INSERT INTO users (email, display_name) VALUES ('session_user@moneta.ai', 'Session User')")
        .run();
      const userId = userRes.lastInsertRowid;

      db.prepare(`
        INSERT INTO user_sessions (user_id, token, device_name, expires_at)
        VALUES (?, 'tok_abc_123', 'Flutter iOS', '2026-12-31 23:59:59')
      `).run(userId);

      const sessionsBefore = db.prepare('SELECT * FROM sesi_pengguna WHERE user_id = ?').all(userId);
      assert.strictEqual(sessionsBefore.length, 1);
      assert.strictEqual(sessionsBefore[0].token, 'tok_abc_123');

      db.prepare('DELETE FROM users WHERE id = ?').run(userId);

      const sessionsAfter = db.prepare('SELECT * FROM user_sessions WHERE user_id = ?').all(userId);
      assert.strictEqual(sessionsAfter.length, 0);
    });
  });

  describe('3. Migrasi dari Skema Lama & Idempotensi', () => {
    it('upgrades a legacy minimal users table while preserving existing user rows', () => {
      const legacyDb = new Database(':memory:');
      legacyDb.pragma('foreign_keys = ON');

      // Simulate minimal old users table
      legacyDb.exec(`
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT UNIQUE NOT NULL,
          password_hash TEXT,
          display_name TEXT,
          currency TEXT DEFAULT 'IDR',
          pin_hash TEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        INSERT INTO users (email, display_name, currency)
        VALUES ('legacy@moneta.ai', 'Legacy User', 'USD');
      `);

      // Run full migrations on legacy DB
      assert.doesNotThrow(() => {
        runMigrations(legacyDb);
      });

      const upgradedUser = legacyDb.prepare("SELECT * FROM users WHERE email = 'legacy@moneta.ai'").get();
      assert.ok(upgradedUser);
      assert.strictEqual(upgradedUser.display_name, 'Legacy User');
      assert.strictEqual(upgradedUser.currency, 'USD');
      assert.strictEqual(upgradedUser.theme_mode, 'Terang');
      assert.strictEqual(upgradedUser.ai_advice_tone, 'Standar');
      assert.strictEqual(upgradedUser.budget_alert_threshold, 80);
      assert.ok(upgradedUser.updated_at);

      legacyDb.close();
    });

    it('is idempotent when runMigrations and ensureUsersSchema are executed repeatedly', () => {
      assert.doesNotThrow(() => {
        runMigrations(db);
        ensureUsersSchema(db);
        runMigrations(db);
      });
    });
  });
});
