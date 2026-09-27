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
    type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
    amount REAL NOT NULL CHECK(amount > 0),
    note TEXT NOT NULL,
    occurred_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_confirmed INTEGER NOT NULL DEFAULT 1,
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
CREATE INDEX IF NOT EXISTS idx_chat_logs_user ON chat_logs(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_chat_logs_status ON chat_logs(status);
CREATE INDEX IF NOT EXISTS idx_categories_user ON categories(user_id, type);
