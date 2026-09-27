-- ============================================================================
-- Moneta v2 (Catat Uang AI) - Database Schema
-- SQLite schema for Users, Categories, Transactions, and Chat Logs
-- ============================================================================

PRAGMA foreign_keys = ON;

-- 1. Users Table
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT,
    display_name TEXT,
    currency TEXT DEFAULT 'IDR',
    pin_hash TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. Categories Table
CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
    is_default INTEGER NOT NULL DEFAULT 0,
    icon TEXT,
    color TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_user_category_type UNIQUE (user_id, name, type)
);

-- 3. Transactions Table
CREATE TABLE IF NOT EXISTS transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    category_name TEXT,
    type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
    amount REAL NOT NULL CHECK(amount > 0),
    note TEXT NOT NULL,
    occurred_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_confirmed INTEGER NOT NULL DEFAULT 1,
    is_guessed INTEGER NOT NULL DEFAULT 1,
    confidence_score REAL,
    ai_reasoning TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 4. Chat Logs Table
CREATE TABLE IF NOT EXISTS chat_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    parsed_json TEXT,
    transaction_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'confirmed', 'deleted', 'failed')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indices for performance
CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON transactions(user_id, occurred_at);
CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_cat_type ON transactions(category_id, type);
CREATE INDEX IF NOT EXISTS idx_chat_logs_user ON chat_logs(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_chat_logs_status ON chat_logs(status);
CREATE INDEX IF NOT EXISTS idx_categories_user ON categories(user_id, type);

-- 5. Budgets Table (Supports both Monthly Root Budget & Category-level Budgets)
CREATE TABLE IF NOT EXISTS budgets (
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

-- 6. Monthly Budgets Table (Dedicated Monthly Budget Config & 50/30/20 Allocation)
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

CREATE INDEX IF NOT EXISTS idx_budgets_user_month ON budgets(user_id, month);
CREATE INDEX IF NOT EXISTS idx_budgets_category ON budgets(category_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_budgets_user_monthly_root ON budgets(user_id, month) WHERE category_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_monthly_budgets_user_month ON monthly_budgets(user_id, month);

-- Triggers to keep amount_limit and total_amount synchronized in budgets table
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

-- 7. AI Insights / Financial Analysis Cache Table
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

CREATE INDEX IF NOT EXISTS idx_ai_insights_user_date ON ai_insights(user_id, date);
CREATE INDEX IF NOT EXISTS idx_ai_insights_warn_level ON ai_insights(warn_level);
CREATE INDEX IF NOT EXISTS idx_ai_insights_user_stale ON ai_insights(user_id, is_stale);
CREATE INDEX IF NOT EXISTS idx_ai_insights_expires_at ON ai_insights(expires_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_ai_insights_unique_user_date ON ai_insights(user_id, date);

CREATE VIEW IF NOT EXISTS financial_analysis_cache AS SELECT * FROM ai_insights;

-- 8. Daily Saving Tips Table (Tips Harian AI & Rekomendasi Finansial)
CREATE TABLE IF NOT EXISTS daily_tips (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Umum',
    description TEXT NOT NULL,
    potential_saving REAL NOT NULL DEFAULT 0 CHECK(potential_saving >= 0),
    impact_level TEXT NOT NULL DEFAULT 'Sedang' CHECK(impact_level IN ('Tinggi', 'Sedang', 'Ringan', 'tinggi', 'sedang', 'ringan')),
    icon TEXT DEFAULT 'lightbulb_outline_rounded',
    action_text TEXT NOT NULL DEFAULT 'Terapkan Hari Ini',
    is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0, 1)),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_saving_tips (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tip_id INTEGER NOT NULL REFERENCES daily_tips(id) ON DELETE CASCADE,
    is_applied INTEGER NOT NULL DEFAULT 0 CHECK(is_applied IN (0, 1)),
    applied_at DATETIME,
    date TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d', 'now')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_user_tip_date UNIQUE (user_id, tip_id, date)
);

CREATE INDEX IF NOT EXISTS idx_daily_tips_category ON daily_tips(category);
CREATE INDEX IF NOT EXISTS idx_daily_tips_active ON daily_tips(is_active);
CREATE INDEX IF NOT EXISTS idx_user_saving_tips_user ON user_saving_tips(user_id, date);
CREATE INDEX IF NOT EXISTS idx_user_saving_tips_applied ON user_saving_tips(user_id, is_applied);

CREATE VIEW IF NOT EXISTS tips_harian AS SELECT * FROM daily_tips;

-- 9. Reminder Settings Table (Pengaturan Pengingat Harian & Notifikasi AI)
CREATE TABLE IF NOT EXISTS reminder_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_enabled INTEGER NOT NULL DEFAULT 1 CHECK(is_enabled IN (0, 1)),
    morning_reminder_time TEXT NOT NULL DEFAULT '08:00',
    is_morning_reminder_enabled INTEGER NOT NULL DEFAULT 1 CHECK(is_morning_reminder_enabled IN (0, 1)),
    evening_reminder_time TEXT NOT NULL DEFAULT '20:00',
    is_evening_reminder_enabled INTEGER NOT NULL DEFAULT 1 CHECK(is_evening_reminder_enabled IN (0, 1)),
    active_days TEXT NOT NULL DEFAULT '[1,2,3,4,5,6,7]',
    notify_on_overbudget INTEGER NOT NULL DEFAULT 1 CHECK(notify_on_overbudget IN (0, 1)),
    notify_saving_tips INTEGER NOT NULL DEFAULT 1 CHECK(notify_saving_tips IN (0, 1)),
    notify_debt_due INTEGER NOT NULL DEFAULT 1 CHECK(notify_debt_due IN (0, 1)),
    sound_enabled INTEGER NOT NULL DEFAULT 1 CHECK(sound_enabled IN (0, 1)),
    vibration_enabled INTEGER NOT NULL DEFAULT 1 CHECK(vibration_enabled IN (0, 1)),
    fcm_token TEXT,
    timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_user_reminder_settings UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_reminder_settings_user ON reminder_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_reminder_settings_enabled ON reminder_settings(is_enabled);

CREATE VIEW IF NOT EXISTS pengaturan_pengingat AS SELECT * FROM reminder_settings;

-- 10. Daily Advice Cache Table (Cache Saran Pengeluaran Harian)
CREATE TABLE IF NOT EXISTS daily_advice_cache (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date TEXT NOT NULL,
    recommended_daily_budget REAL NOT NULL DEFAULT 0 CHECK(recommended_daily_budget >= 0),
    estimated_days_left INTEGER NOT NULL DEFAULT 0 CHECK(estimated_days_left >= 0),
    daily_advice TEXT NOT NULL,
    warn_level TEXT NOT NULL DEFAULT 'normal' CHECK(warn_level IN ('normal', 'warning', 'critical')),
    avg_daily_spend REAL NOT NULL DEFAULT 0 CHECK(avg_daily_spend >= 0),
    total_monthly_budget REAL NOT NULL DEFAULT 0,
    total_spent REAL NOT NULL DEFAULT 0,
    remaining_balance REAL NOT NULL DEFAULT 0,
    source TEXT NOT NULL DEFAULT 'rule_based' CHECK(source IN ('rule_based', 'ai_generated', 'hybrid', 'fallback')),
    advice_json TEXT,
    is_applied INTEGER NOT NULL DEFAULT 0 CHECK(is_applied IN (0, 1)),
    is_stale INTEGER NOT NULL DEFAULT 0 CHECK(is_stale IN (0, 1)),
    expires_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_user_daily_advice UNIQUE (user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_daily_advice_user_date ON daily_advice_cache(user_id, date);
CREATE INDEX IF NOT EXISTS idx_daily_advice_warn_level ON daily_advice_cache(warn_level);
CREATE INDEX IF NOT EXISTS idx_daily_advice_stale ON daily_advice_cache(user_id, is_stale);
CREATE INDEX IF NOT EXISTS idx_daily_advice_expires ON daily_advice_cache(expires_at);

CREATE VIEW IF NOT EXISTS cache_saran AS SELECT * FROM daily_advice_cache;
CREATE VIEW IF NOT EXISTS saran_cache AS SELECT * FROM daily_advice_cache;

