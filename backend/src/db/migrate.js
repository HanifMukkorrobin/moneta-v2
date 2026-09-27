import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const defaultExpenseCategories = [
  { name: 'Makan & Minuman', icon: 'restaurant_rounded', color: 'orange' },
  { name: 'Transportasi', icon: 'directions_car_rounded', color: 'blue' },
  { name: 'Belanja', icon: 'shopping_bag_rounded', color: 'pink' },
  { name: 'Hiburan', icon: 'sports_esports_rounded', color: 'purple' },
  { name: 'Tagihan & Utilitas', icon: 'receipt_long_rounded', color: 'amber' },
  { name: 'Hutang & Paylater', icon: 'credit_card_rounded', color: 'red' },
  { name: 'Kebutuhan Rumah', icon: 'home_rounded', color: 'teal' },
  { name: 'Kesehatan', icon: 'local_hospital_rounded', color: 'green' },
  { name: 'Lainnya', icon: 'more_horiz_rounded', color: 'grey' },
];

export const defaultIncomeCategories = [
  { name: 'Gaji', icon: 'account_balance_wallet_rounded', color: 'green' },
  { name: 'Freelance', icon: 'laptop_chromebook_rounded', color: 'teal' },
  { name: 'Bonus', icon: 'card_giftcard_rounded', color: 'amber' },
  { name: 'Investasi', icon: 'trending_up_rounded', color: 'blue' },
  { name: 'Transfer Masuk', icon: 'move_to_inbox_rounded', color: 'cyan' },
  { name: 'Lainnya', icon: 'attach_money_rounded', color: 'grey' },
];

export function ensureTransactionCategoryAndTypeColumns(db) {
  const columns = db.prepare("PRAGMA table_info(transactions)").all().map((c) => c.name);

  if (!columns.includes('category_name')) {
    db.exec("ALTER TABLE transactions ADD COLUMN category_name TEXT");
  }
  if (!columns.includes('type')) {
    db.exec("ALTER TABLE transactions ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'");
  }
  if (!columns.includes('is_guessed')) {
    db.exec("ALTER TABLE transactions ADD COLUMN is_guessed INTEGER NOT NULL DEFAULT 1");
  }
  if (!columns.includes('confidence_score')) {
    db.exec("ALTER TABLE transactions ADD COLUMN confidence_score REAL");
  }
  if (!columns.includes('ai_reasoning')) {
    db.exec("ALTER TABLE transactions ADD COLUMN ai_reasoning TEXT");
  }

  // Create composite indices for performance
  db.exec("CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_transactions_cat_type ON transactions(category_id, type)");
}

export function ensureMonthlyBudgetSchema(db) {
  const tableInfo = db.prepare("PRAGMA table_info(budgets)").all();
  const columns = tableInfo.map((c) => c.name);
  const nameCol = tableInfo.find((c) => c.name === 'name');

  // If budgets table existed from an older schema without total_amount or without default on name,
  // upgrade the table structure while preserving all existing rows.
  const needsTableUpgrade =
    tableInfo.length > 0 &&
    (!columns.includes('total_amount') || !nameCol || nameCol.dflt_value === null);

  if (needsTableUpgrade) {
    const hasTotalAmount = columns.includes('total_amount');
    const hasNeedsPct = columns.includes('needs_pct');
    const hasSavingsPct = columns.includes('savings_pct');
    const hasFunPct = columns.includes('fun_pct');
    const hasBucketType = columns.includes('bucket_type');
    const hasAlertEnabled = columns.includes('alert_enabled');
    const hasAlertThreshold = columns.includes('alert_threshold');
    const hasOverBudgetAlert = columns.includes('over_budget_alert_enabled');
    const hasPushNotification = columns.includes('push_notification_enabled');
    const hasUpdatedAt = columns.includes('updated_at');

    const upgradeTx = db.transaction(() => {
      db.exec(`
        DROP TRIGGER IF EXISTS trg_budgets_sync_amounts_insert;
        DROP TRIGGER IF EXISTS trg_budgets_sync_amounts_update;

        CREATE TABLE budgets_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
            name TEXT NOT NULL DEFAULT 'Budget Bulanan',
            amount_limit REAL NOT NULL DEFAULT 0 CHECK(amount_limit >= 0),
            total_amount REAL NOT NULL DEFAULT 0 CHECK(total_amount >= 0),
            needs_pct REAL NOT NULL DEFAULT 50 CHECK(needs_pct >= 0 AND needs_pct <= 100),
            savings_pct REAL NOT NULL DEFAULT 30 CHECK(savings_pct >= 0 AND savings_pct <= 100),
            fun_pct REAL NOT NULL DEFAULT 20 CHECK(fun_pct >= 0 AND fun_pct <= 100),
            bucket_type TEXT NOT NULL DEFAULT 'needs' CHECK(bucket_type IN ('needs', 'savings', 'fun')),
            period TEXT NOT NULL DEFAULT 'monthly' CHECK(period IN ('monthly', 'weekly', 'custom')),
            month TEXT NOT NULL DEFAULT (strftime('%Y-%m', 'now')),
            alert_enabled INTEGER NOT NULL DEFAULT 1,
            alert_threshold REAL NOT NULL DEFAULT 80 CHECK(alert_threshold > 0 AND alert_threshold <= 100),
            over_budget_alert_enabled INTEGER NOT NULL DEFAULT 1,
            push_notification_enabled INTEGER NOT NULL DEFAULT 1,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT unique_user_category_month UNIQUE (user_id, category_id, month)
        );

        INSERT INTO budgets_new (
            id, user_id, category_id, name, amount_limit, total_amount,
            needs_pct, savings_pct, fun_pct, bucket_type, period, month,
            alert_enabled, alert_threshold, over_budget_alert_enabled, push_notification_enabled,
            created_at, updated_at
        )
        SELECT
            id,
            user_id,
            category_id,
            COALESCE(name, 'Budget Bulanan'),
            COALESCE(amount_limit, 0),
            ${hasTotalAmount ? 'COALESCE(total_amount, amount_limit, 0)' : 'COALESCE(amount_limit, 0)'},
            ${hasNeedsPct ? 'COALESCE(needs_pct, 50)' : '50'},
            ${hasSavingsPct ? 'COALESCE(savings_pct, 30)' : '30'},
            ${hasFunPct ? 'COALESCE(fun_pct, 20)' : '20'},
            ${hasBucketType ? "COALESCE(bucket_type, 'needs')" : "'needs'"},
            COALESCE(period, 'monthly'),
            COALESCE(month, strftime('%Y-%m', 'now')),
            ${hasAlertEnabled ? 'COALESCE(alert_enabled, 1)' : '1'},
            ${hasAlertThreshold ? 'COALESCE(alert_threshold, 80)' : '80'},
            ${hasOverBudgetAlert ? 'COALESCE(over_budget_alert_enabled, 1)' : '1'},
            ${hasPushNotification ? 'COALESCE(push_notification_enabled, 1)' : '1'},
            COALESCE(created_at, CURRENT_TIMESTAMP),
            ${hasUpdatedAt ? 'COALESCE(updated_at, created_at, CURRENT_TIMESTAMP)' : 'COALESCE(created_at, CURRENT_TIMESTAMP)'}
        FROM budgets;

        DROP TABLE budgets;
        ALTER TABLE budgets_new RENAME TO budgets;
      `);
    });

    upgradeTx();
  } else if (tableInfo.length > 0) {
    // Ensure any individual columns exist if added incrementally
    if (!columns.includes('total_amount')) {
      db.exec("ALTER TABLE budgets ADD COLUMN total_amount REAL NOT NULL DEFAULT 0");
      db.exec("UPDATE budgets SET total_amount = amount_limit WHERE total_amount = 0 AND amount_limit > 0");
    }
    if (!columns.includes('needs_pct')) {
      db.exec("ALTER TABLE budgets ADD COLUMN needs_pct REAL NOT NULL DEFAULT 50");
    }
    if (!columns.includes('savings_pct')) {
      db.exec("ALTER TABLE budgets ADD COLUMN savings_pct REAL NOT NULL DEFAULT 30");
    }
    if (!columns.includes('fun_pct')) {
      db.exec("ALTER TABLE budgets ADD COLUMN fun_pct REAL NOT NULL DEFAULT 20");
    }
    if (!columns.includes('bucket_type')) {
      db.exec("ALTER TABLE budgets ADD COLUMN bucket_type TEXT NOT NULL DEFAULT 'needs'");
    }
    if (!columns.includes('alert_enabled')) {
      db.exec("ALTER TABLE budgets ADD COLUMN alert_enabled INTEGER NOT NULL DEFAULT 1");
    }
    if (!columns.includes('alert_threshold')) {
      db.exec("ALTER TABLE budgets ADD COLUMN alert_threshold REAL NOT NULL DEFAULT 80");
    }
    if (!columns.includes('over_budget_alert_enabled')) {
      db.exec("ALTER TABLE budgets ADD COLUMN over_budget_alert_enabled INTEGER NOT NULL DEFAULT 1");
    }
    if (!columns.includes('push_notification_enabled')) {
      db.exec("ALTER TABLE budgets ADD COLUMN push_notification_enabled INTEGER NOT NULL DEFAULT 1");
    }
    if (!columns.includes('updated_at')) {
      db.exec("ALTER TABLE budgets ADD COLUMN updated_at DATETIME DEFAULT CURRENT_TIMESTAMP");
    }
  }

  // Ensure monthly_budgets table exists
  db.exec(`
    CREATE TABLE IF NOT EXISTS monthly_budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        month TEXT NOT NULL,
        total_amount REAL NOT NULL DEFAULT 0 CHECK(total_amount >= 0),
        needs_pct REAL NOT NULL DEFAULT 50 CHECK(needs_pct >= 0 AND needs_pct <= 100),
        savings_pct REAL NOT NULL DEFAULT 30 CHECK(savings_pct >= 0 AND savings_pct <= 100),
        fun_pct REAL NOT NULL DEFAULT 20 CHECK(fun_pct >= 0 AND fun_pct <= 100),
        alert_enabled INTEGER NOT NULL DEFAULT 1,
        alert_threshold REAL NOT NULL DEFAULT 80 CHECK(alert_threshold > 0 AND alert_threshold <= 100),
        over_budget_alert_enabled INTEGER NOT NULL DEFAULT 1,
        push_notification_enabled INTEGER NOT NULL DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT unique_user_monthly_budget UNIQUE (user_id, month),
        CONSTRAINT check_monthly_allocation_sum CHECK (ABS((needs_pct + savings_pct + fun_pct) - 100) < 0.01)
    );
  `);

  // Ensure indices and sync triggers exist
  db.exec("CREATE INDEX IF NOT EXISTS idx_budgets_user_month ON budgets(user_id, month)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_budgets_category ON budgets(category_id)");
  db.exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_budgets_user_monthly_root ON budgets(user_id, month) WHERE category_id IS NULL");
  db.exec("CREATE INDEX IF NOT EXISTS idx_monthly_budgets_user_month ON monthly_budgets(user_id, month)");

  db.exec(`
    CREATE TRIGGER IF NOT EXISTS trg_budgets_sync_amounts_insert
    AFTER INSERT ON budgets
    WHEN (NEW.total_amount > 0 AND NEW.amount_limit = 0) OR (NEW.amount_limit > 0 AND NEW.total_amount = 0)
    BEGIN
        UPDATE budgets
        SET
            amount_limit = CASE WHEN NEW.amount_limit = 0 THEN NEW.total_amount ELSE NEW.amount_limit END,
            total_amount = CASE WHEN NEW.total_amount = 0 THEN NEW.amount_limit ELSE NEW.total_amount END
        WHERE id = NEW.id;
    END;

    CREATE TRIGGER IF NOT EXISTS trg_budgets_sync_amounts_update
    AFTER UPDATE OF amount_limit, total_amount ON budgets
    WHEN NEW.amount_limit != NEW.total_amount
    BEGIN
        UPDATE budgets
        SET
            amount_limit = CASE WHEN NEW.amount_limit != OLD.amount_limit THEN NEW.amount_limit ELSE NEW.total_amount END,
            total_amount = CASE WHEN NEW.total_amount != OLD.total_amount THEN NEW.total_amount ELSE NEW.amount_limit END,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.id;
    END;
  `);
}

export function ensureAiInsightsSchema(db) {
  // 1. Ensure ai_insights table exists
  db.exec(`
    CREATE TABLE IF NOT EXISTS ai_insights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        date TEXT NOT NULL,
        avg_daily_spend REAL NOT NULL DEFAULT 0 CHECK(avg_daily_spend >= 0),
        estimated_days_left INTEGER NOT NULL DEFAULT 0 CHECK(estimated_days_left >= 0),
        daily_advice TEXT,
        warn_level TEXT NOT NULL DEFAULT 'normal' CHECK(warn_level IN ('normal', 'warning', 'critical')),
        recommended_daily_budget REAL NOT NULL DEFAULT 0,
        total_monthly_budget REAL NOT NULL DEFAULT 0,
        total_spent REAL NOT NULL DEFAULT 0,
        remaining_balance REAL NOT NULL DEFAULT 0,
        analysis_json TEXT,
        is_stale INTEGER NOT NULL DEFAULT 0 CHECK(is_stale IN (0, 1)),
        expires_at DATETIME,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT unique_user_insight_date UNIQUE (user_id, date)
    );
  `);

  // 2. Ensure all columns exist for existing/migrated databases
  const columns = db.prepare("PRAGMA table_info(ai_insights)").all().map((c) => c.name);

  if (!columns.includes('recommended_daily_budget')) {
    db.exec("ALTER TABLE ai_insights ADD COLUMN recommended_daily_budget REAL NOT NULL DEFAULT 0");
  }
  if (!columns.includes('total_monthly_budget')) {
    db.exec("ALTER TABLE ai_insights ADD COLUMN total_monthly_budget REAL NOT NULL DEFAULT 0");
  }
  if (!columns.includes('total_spent')) {
    db.exec("ALTER TABLE ai_insights ADD COLUMN total_spent REAL NOT NULL DEFAULT 0");
  }
  if (!columns.includes('remaining_balance')) {
    db.exec("ALTER TABLE ai_insights ADD COLUMN remaining_balance REAL NOT NULL DEFAULT 0");
  }
  if (!columns.includes('analysis_json')) {
    db.exec("ALTER TABLE ai_insights ADD COLUMN analysis_json TEXT");
  }
  if (!columns.includes('is_stale')) {
    db.exec("ALTER TABLE ai_insights ADD COLUMN is_stale INTEGER NOT NULL DEFAULT 0");
  }
  if (!columns.includes('expires_at')) {
    db.exec("ALTER TABLE ai_insights ADD COLUMN expires_at DATETIME");
  }
  if (!columns.includes('created_at')) {
    db.exec("ALTER TABLE ai_insights ADD COLUMN created_at DATETIME");
    db.exec("UPDATE ai_insights SET created_at = CURRENT_TIMESTAMP WHERE created_at IS NULL");
  }
  if (!columns.includes('updated_at')) {
    db.exec("ALTER TABLE ai_insights ADD COLUMN updated_at DATETIME");
    db.exec("UPDATE ai_insights SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL");
  }

  // 3. Ensure indices exist
  db.exec("CREATE INDEX IF NOT EXISTS idx_ai_insights_user_date ON ai_insights(user_id, date)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_ai_insights_warn_level ON ai_insights(warn_level)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_ai_insights_user_stale ON ai_insights(user_id, is_stale)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_ai_insights_expires_at ON ai_insights(expires_at)");
  db.exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_ai_insights_unique_user_date ON ai_insights(user_id, date)");

  // 4. Ensure view financial_analysis_cache exists
  db.exec("CREATE VIEW IF NOT EXISTS financial_analysis_cache AS SELECT * FROM ai_insights;");
}

export function runMigrations(db) {
  const schemaPath = path.resolve(__dirname, 'schema.sql');
  const schemaSql = fs.readFileSync(schemaPath, 'utf8');

  // Execute schema creation
  db.exec(schemaPath.endsWith('.sql') ? schemaSql : schemaSql);

  // Ensure transaction columns (category, type, guessed flags) exist on pre-existing tables
  ensureTransactionCategoryAndTypeColumns(db);

  // Ensure monthly budget schema, columns, indices, and triggers exist on pre-existing tables
  ensureMonthlyBudgetSchema(db);

  // Ensure ai_insights and financial analysis cache schema exists
  ensureAiInsightsSchema(db);

  // Seed default categories (with user_id = NULL)
  seedDefaultCategories(db);
}


export function seedDefaultCategories(db) {
  const insertStmt = db.prepare(`
    INSERT OR IGNORE INTO categories (user_id, name, type, is_default, icon, color)
    VALUES (?, ?, ?, ?, ?, ?)
  `);

  const checkStmt = db.prepare(`
    SELECT COUNT(*) as count FROM categories WHERE user_id IS NULL AND is_default = 1
  `);

  const { count } = checkStmt.get();
  if (count > 0) {
    return; // Already seeded
  }

  const transaction = db.transaction(() => {
    for (const cat of defaultExpenseCategories) {
      insertStmt.run(null, cat.name, 'expense', 1, cat.icon, cat.color);
    }
    for (const cat of defaultIncomeCategories) {
      insertStmt.run(null, cat.name, 'income', 1, cat.icon, cat.color);
    }
  });

  transaction();
}

// Support running directly via `node src/db/migrate.js` or `npm run migrate`
const isMain = process.argv[1] && import.meta.url.endsWith(process.argv[1]);
if (isMain) {
  const { getDatabase, closeDatabase } = await import('../config/database.js');
  const db = getDatabase();
  console.log('[Migrate] Running migrations and seeding default categories...');
  runMigrations(db);
  const count = db.prepare('SELECT COUNT(*) as count FROM categories WHERE is_default = 1').get().count;
  console.log(`[Migrate] Migration complete. Total ${count} default categories seeded.`);
  closeDatabase();
}

