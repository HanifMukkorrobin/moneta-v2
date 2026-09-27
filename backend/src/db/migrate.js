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

export const defaultSavingTips = [
  {
    title: 'Bawa Bekal Makan Siang 2x Sepekan',
    category: 'Makan & Minuman',
    description:
      'Mengganti makan siang luar dengan bekal rumahan 2 kali seminggu dapat menghemat hingga Rp 150.000 per pekan.',
    potential_saving: 150000,
    impact_level: 'Tinggi',
    icon: 'restaurant_rounded',
    action_text: 'Rencanakan Menu Bekal',
  },
  {
    title: 'Aturan Tunda 24 Jam Belanja Online',
    category: 'Belanja',
    description:
      'Masukkan barang non-pokok ke keranjang belanja dan tunggu 24 jam sebelum bayar untuk meredam belanja impulsif.',
    potential_saving: 250000,
    impact_level: 'Tinggi',
    icon: 'shopping_bag_rounded',
    action_text: 'Terapkan Aturan 24 Jam',
  },
  {
    title: 'Audit Langganan Aplikasi Digital',
    category: 'Tagihan & Utilitas',
    description:
      'Cek aplikasi streaming atau cloud yang jarang dipakai bulan ini. Nonaktifkan tagihan otomatis untuk pos yang tidak aktif.',
    potential_saving: 89000,
    impact_level: 'Sedang',
    icon: 'subscriptions_rounded',
    action_text: 'Cek Langganan Aktif',
  },
  {
    title: 'Seduh Kopi Sendiri di Pagi Hari',
    category: 'Makan & Minuman',
    description:
      'Beli bubuk kopi favorit dan seduh sendiri sebelum berangkat kerja. Mengurangi frekuensi jajan kopi susu kekinian.',
    potential_saving: 120000,
    impact_level: 'Sedang',
    icon: 'coffee_rounded',
    action_text: 'Seduh Kopi Rumah',
  },
  {
    title: 'Manfaatkan Promo Transportasi Terpadu',
    category: 'Transportasi',
    description:
      'Gunakan kartu langganan bulanan atau tiket komuter terusan saat jam kerja untuk menghemat biaya ojek harian.',
    potential_saving: 75000,
    impact_level: 'Ringan',
    icon: 'directions_bus_rounded',
    action_text: 'Cek Jalur Transit',
  },
  {
    title: 'Matikan Saklar Colokan Listrik Malam Hari',
    category: 'Tagihan & Utilitas',
    description:
      'Mematikan colokan TV, dispenser, dan charger saat tidur dapat menurunkan tagihan listrik bulanan.',
    potential_saving: 45000,
    impact_level: 'Ringan',
    icon: 'power_rounded',
    action_text: 'Cabut Saklar Malam',
  },
  {
    title: 'Beralih ke Paket Data Bulanan Promo',
    category: 'Tagihan & Utilitas',
    description:
      'Beli paket data kuota besar per 30 hari daripada membeli paket harian atau mingguan yang berulang kali lebih mahal.',
    potential_saving: 60000,
    impact_level: 'Sedang',
    icon: 'wifi_rounded',
    action_text: 'Cek Paket Bulanan',
  },
  {
    title: 'Pilih Berjalan Kaki untuk Jarak < 1 KM',
    category: 'Transportasi',
    description:
      'Mengurangi pesanan ojek online untuk rute dekat selain menyehatkan tubuh juga menghemat pengeluaran transportasi mikro.',
    potential_saving: 50000,
    impact_level: 'Ringan',
    icon: 'directions_walk_rounded',
    action_text: 'Mulai Jalan Kaki',
  },
  {
    title: 'Beli Kebutuhan Dapur Kemasan Grosir',
    category: 'Belanja',
    description:
      'Beli beras, minyak goreng, dan deterjen dalam ukuran isi ulang besar untuk mendapatkan potongan harga per liter/kg.',
    potential_saving: 180000,
    impact_level: 'Tinggi',
    icon: 'storefront_rounded',
    action_text: 'Beli Kemasan Grosir',
  },
];

export function ensureSaranHarianSchema(db) {
  // 1. Tabel Daily Tips
  db.exec(`
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
  `);

  // 2. Tabel User Saving Tips (Relasi Tracking Tips Diterapkan)
  db.exec(`
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
  `);

  // 3. Tabel Reminder Settings (Pengaturan Pengingat Harian & Notifikasi)
  db.exec(`
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
  `);

  // 4. Tabel Daily Advice Cache (Cache Saran Pengeluaran Harian)
  db.exec(`
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
  `);

  // Column safety checks for pre-existing tables:
  const tipsCols = db.prepare("PRAGMA table_info(daily_tips)").all().map((c) => c.name);
  if (!tipsCols.includes('category')) db.exec("ALTER TABLE daily_tips ADD COLUMN category TEXT NOT NULL DEFAULT 'Umum'");
  if (!tipsCols.includes('potential_saving')) db.exec("ALTER TABLE daily_tips ADD COLUMN potential_saving REAL NOT NULL DEFAULT 0");
  if (!tipsCols.includes('impact_level')) db.exec("ALTER TABLE daily_tips ADD COLUMN impact_level TEXT NOT NULL DEFAULT 'Sedang'");
  if (!tipsCols.includes('icon')) db.exec("ALTER TABLE daily_tips ADD COLUMN icon TEXT DEFAULT 'lightbulb_outline_rounded'");
  if (!tipsCols.includes('action_text')) db.exec("ALTER TABLE daily_tips ADD COLUMN action_text TEXT NOT NULL DEFAULT 'Terapkan Hari Ini'");
  if (!tipsCols.includes('is_active')) db.exec("ALTER TABLE daily_tips ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1");
  if (!tipsCols.includes('created_at')) {
    db.exec("ALTER TABLE daily_tips ADD COLUMN created_at DATETIME");
    db.exec("UPDATE daily_tips SET created_at = CURRENT_TIMESTAMP WHERE created_at IS NULL");
  }
  if (!tipsCols.includes('updated_at')) {
    db.exec("ALTER TABLE daily_tips ADD COLUMN updated_at DATETIME");
    db.exec("UPDATE daily_tips SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL");
  }

  const reminderCols = db.prepare("PRAGMA table_info(reminder_settings)").all().map((c) => c.name);
  if (!reminderCols.includes('is_enabled')) db.exec("ALTER TABLE reminder_settings ADD COLUMN is_enabled INTEGER NOT NULL DEFAULT 1");
  if (!reminderCols.includes('morning_reminder_time')) db.exec("ALTER TABLE reminder_settings ADD COLUMN morning_reminder_time TEXT NOT NULL DEFAULT '08:00'");
  if (!reminderCols.includes('is_morning_reminder_enabled')) db.exec("ALTER TABLE reminder_settings ADD COLUMN is_morning_reminder_enabled INTEGER NOT NULL DEFAULT 1");
  if (!reminderCols.includes('evening_reminder_time')) db.exec("ALTER TABLE reminder_settings ADD COLUMN evening_reminder_time TEXT NOT NULL DEFAULT '20:00'");
  if (!reminderCols.includes('is_evening_reminder_enabled')) db.exec("ALTER TABLE reminder_settings ADD COLUMN is_evening_reminder_enabled INTEGER NOT NULL DEFAULT 1");
  if (!reminderCols.includes('active_days')) db.exec("ALTER TABLE reminder_settings ADD COLUMN active_days TEXT NOT NULL DEFAULT '[1,2,3,4,5,6,7]'");
  if (!reminderCols.includes('notify_on_overbudget')) db.exec("ALTER TABLE reminder_settings ADD COLUMN notify_on_overbudget INTEGER NOT NULL DEFAULT 1");
  if (!reminderCols.includes('notify_saving_tips')) db.exec("ALTER TABLE reminder_settings ADD COLUMN notify_saving_tips INTEGER NOT NULL DEFAULT 1");
  if (!reminderCols.includes('notify_debt_due')) db.exec("ALTER TABLE reminder_settings ADD COLUMN notify_debt_due INTEGER NOT NULL DEFAULT 1");
  if (!reminderCols.includes('sound_enabled')) db.exec("ALTER TABLE reminder_settings ADD COLUMN sound_enabled INTEGER NOT NULL DEFAULT 1");
  if (!reminderCols.includes('vibration_enabled')) db.exec("ALTER TABLE reminder_settings ADD COLUMN vibration_enabled INTEGER NOT NULL DEFAULT 1");
  if (!reminderCols.includes('fcm_token')) db.exec("ALTER TABLE reminder_settings ADD COLUMN fcm_token TEXT");
  if (!reminderCols.includes('timezone')) db.exec("ALTER TABLE reminder_settings ADD COLUMN timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta'");
  if (!reminderCols.includes('created_at')) {
    db.exec("ALTER TABLE reminder_settings ADD COLUMN created_at DATETIME");
    db.exec("UPDATE reminder_settings SET created_at = CURRENT_TIMESTAMP WHERE created_at IS NULL");
  }
  if (!reminderCols.includes('updated_at')) {
    db.exec("ALTER TABLE reminder_settings ADD COLUMN updated_at DATETIME");
    db.exec("UPDATE reminder_settings SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL");
  }

  const adviceCols = db.prepare("PRAGMA table_info(daily_advice_cache)").all().map((c) => c.name);
  if (!adviceCols.includes('recommended_daily_budget')) db.exec("ALTER TABLE daily_advice_cache ADD COLUMN recommended_daily_budget REAL NOT NULL DEFAULT 0");
  if (!adviceCols.includes('estimated_days_left')) db.exec("ALTER TABLE daily_advice_cache ADD COLUMN estimated_days_left INTEGER NOT NULL DEFAULT 0");
  if (!adviceCols.includes('daily_advice')) db.exec("ALTER TABLE daily_advice_cache ADD COLUMN daily_advice TEXT NOT NULL DEFAULT ''");
  if (!adviceCols.includes('warn_level')) db.exec("ALTER TABLE daily_advice_cache ADD COLUMN warn_level TEXT NOT NULL DEFAULT 'normal'");
  if (!adviceCols.includes('avg_daily_spend')) db.exec("ALTER TABLE daily_advice_cache ADD COLUMN avg_daily_spend REAL NOT NULL DEFAULT 0");
  if (!adviceCols.includes('total_monthly_budget')) db.exec("ALTER TABLE daily_advice_cache ADD COLUMN total_monthly_budget REAL NOT NULL DEFAULT 0");
  if (!adviceCols.includes('total_spent')) db.exec("ALTER TABLE daily_advice_cache ADD COLUMN total_spent REAL NOT NULL DEFAULT 0");
  if (!adviceCols.includes('remaining_balance')) db.exec("ALTER TABLE daily_advice_cache ADD COLUMN remaining_balance REAL NOT NULL DEFAULT 0");
  if (!adviceCols.includes('source')) db.exec("ALTER TABLE daily_advice_cache ADD COLUMN source TEXT NOT NULL DEFAULT 'rule_based'");
  if (!adviceCols.includes('advice_json')) db.exec("ALTER TABLE daily_advice_cache ADD COLUMN advice_json TEXT");
  if (!adviceCols.includes('is_applied')) db.exec("ALTER TABLE daily_advice_cache ADD COLUMN is_applied INTEGER NOT NULL DEFAULT 0");
  if (!adviceCols.includes('is_stale')) db.exec("ALTER TABLE daily_advice_cache ADD COLUMN is_stale INTEGER NOT NULL DEFAULT 0");
  if (!adviceCols.includes('expires_at')) db.exec("ALTER TABLE daily_advice_cache ADD COLUMN expires_at DATETIME");
  if (!adviceCols.includes('created_at')) {
    db.exec("ALTER TABLE daily_advice_cache ADD COLUMN created_at DATETIME");
    db.exec("UPDATE daily_advice_cache SET created_at = CURRENT_TIMESTAMP WHERE created_at IS NULL");
  }
  if (!adviceCols.includes('updated_at')) {
    db.exec("ALTER TABLE daily_advice_cache ADD COLUMN updated_at DATETIME");
    db.exec("UPDATE daily_advice_cache SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL");
  }

  // Create performance indices
  db.exec("CREATE INDEX IF NOT EXISTS idx_daily_tips_category ON daily_tips(category)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_daily_tips_active ON daily_tips(is_active)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_user_saving_tips_user ON user_saving_tips(user_id, date)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_user_saving_tips_applied ON user_saving_tips(user_id, is_applied)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_reminder_settings_user ON reminder_settings(user_id)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_reminder_settings_enabled ON reminder_settings(is_enabled)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_daily_advice_user_date ON daily_advice_cache(user_id, date)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_daily_advice_warn_level ON daily_advice_cache(warn_level)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_daily_advice_stale ON daily_advice_cache(user_id, is_stale)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_daily_advice_expires ON daily_advice_cache(expires_at)");

  // Ensure notification_logs table exists
  db.exec(`
    CREATE TABLE IF NOT EXISTS notification_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        payload_json TEXT,
        scheduled_time TEXT,
        date TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d', 'now')),
        status TEXT NOT NULL DEFAULT 'sent' CHECK(status IN ('sent', 'failed', 'delivered', 'pending')),
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  `);

  const notifCols = db.prepare("PRAGMA table_info(notification_logs)").all().map((c) => c.name);
  if (!notifCols.includes('payload_json')) db.exec("ALTER TABLE notification_logs ADD COLUMN payload_json TEXT");
  if (!notifCols.includes('scheduled_time')) db.exec("ALTER TABLE notification_logs ADD COLUMN scheduled_time TEXT");
  if (!notifCols.includes('date')) db.exec("ALTER TABLE notification_logs ADD COLUMN date TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d', 'now'))");
  if (!notifCols.includes('status')) db.exec("ALTER TABLE notification_logs ADD COLUMN status TEXT NOT NULL DEFAULT 'sent'");
  if (!notifCols.includes('created_at')) {
    db.exec("ALTER TABLE notification_logs ADD COLUMN created_at DATETIME");
    db.exec("UPDATE notification_logs SET created_at = CURRENT_TIMESTAMP WHERE created_at IS NULL");
  }

  db.exec("CREATE INDEX IF NOT EXISTS idx_notification_logs_user_date ON notification_logs(user_id, date)");
  db.exec("CREATE INDEX IF NOT EXISTS idx_notification_logs_type ON notification_logs(type)");

  // Create Views
  db.exec("CREATE VIEW IF NOT EXISTS tips_harian AS SELECT * FROM daily_tips;");
  db.exec("CREATE VIEW IF NOT EXISTS pengaturan_pengingat AS SELECT * FROM reminder_settings;");
  db.exec("CREATE VIEW IF NOT EXISTS cache_saran AS SELECT * FROM daily_advice_cache;");
  db.exec("CREATE VIEW IF NOT EXISTS saran_cache AS SELECT * FROM daily_advice_cache;");
  db.exec("CREATE VIEW IF NOT EXISTS log_notifikasi AS SELECT * FROM notification_logs;");
  db.exec("CREATE VIEW IF NOT EXISTS riwayat_notifikasi AS SELECT * FROM notification_logs;");
}

export function seedDefaultSavingTips(db) {
  const countRow = db.prepare("SELECT COUNT(*) as count FROM daily_tips").get();
  if (countRow && countRow.count > 0) {
    return; // Already seeded
  }

  const insertStmt = db.prepare(`
    INSERT INTO daily_tips (title, category, description, potential_saving, impact_level, icon, action_text, is_active)
    VALUES (@title, @category, @description, @potential_saving, @impact_level, @icon, @action_text, 1)
  `);

  const tx = db.transaction(() => {
    for (const tip of defaultSavingTips) {
      insertStmt.run(tip);
    }
  });

  tx();
}

export function ensureDebtsSchema(db) {
  // 1. Ensure debts table exists
  db.exec(`
    CREATE TABLE IF NOT EXISTS debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        total_amount REAL NOT NULL CHECK(total_amount >= 0),
        remaining_amount REAL NOT NULL DEFAULT 0 CHECK(remaining_amount >= 0),
        paid_amount REAL NOT NULL DEFAULT 0 CHECK(paid_amount >= 0),
        due_date DATE NOT NULL,
        status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'paid', 'lunas', 'aktif')),
        type TEXT NOT NULL DEFAULT 'paylater' CHECK(type IN ('paylater', 'cicilan', 'kartu_kredit', 'kartuKredit', 'pinjaman_pribadi', 'pinjamanPribadi', 'lainnya')),
        notes TEXT,
        paid_at DATETIME,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  `);

  // 2. Check and add any missing columns for pre-existing tables
  const debtCols = db.prepare("PRAGMA table_info(debts)").all().map((c) => c.name);
  if (!debtCols.includes('total_amount')) db.exec("ALTER TABLE debts ADD COLUMN total_amount REAL NOT NULL DEFAULT 0");
  if (!debtCols.includes('remaining_amount')) db.exec("ALTER TABLE debts ADD COLUMN remaining_amount REAL NOT NULL DEFAULT 0");
  if (!debtCols.includes('paid_amount')) db.exec("ALTER TABLE debts ADD COLUMN paid_amount REAL NOT NULL DEFAULT 0");
  if (!debtCols.includes('due_date')) db.exec("ALTER TABLE debts ADD COLUMN due_date DATE");
  if (!debtCols.includes('status')) db.exec("ALTER TABLE debts ADD COLUMN status TEXT NOT NULL DEFAULT 'active'");
  if (!debtCols.includes('type')) db.exec("ALTER TABLE debts ADD COLUMN type TEXT NOT NULL DEFAULT 'paylater'");
  if (!debtCols.includes('notes')) db.exec("ALTER TABLE debts ADD COLUMN notes TEXT");
  if (!debtCols.includes('paid_at')) db.exec("ALTER TABLE debts ADD COLUMN paid_at DATETIME");
  if (!debtCols.includes('created_at')) {
    db.exec("ALTER TABLE debts ADD COLUMN created_at DATETIME");
    db.exec("UPDATE debts SET created_at = CURRENT_TIMESTAMP WHERE created_at IS NULL");
  }
  if (!debtCols.includes('updated_at')) {
    db.exec("ALTER TABLE debts ADD COLUMN updated_at DATETIME");
    db.exec("UPDATE debts SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL");
  }

  // 3. Performance indices
  db.exec("CREATE INDEX IF NOT EXISTS idx_debts_user_status ON debts(user_id, status);");
  db.exec("CREATE INDEX IF NOT EXISTS idx_debts_due_date ON debts(due_date);");
  db.exec("CREATE INDEX IF NOT EXISTS idx_debts_user_due ON debts(user_id, due_date);");
  db.exec("CREATE INDEX IF NOT EXISTS idx_debts_type ON debts(type);");

  // 4. Triggers to keep status consistent when remaining_amount <= 0
  db.exec(`
    CREATE TRIGGER IF NOT EXISTS trg_debts_paid_status_insert
    AFTER INSERT ON debts
    WHEN NEW.remaining_amount <= 0 AND NEW.status != 'paid'
    BEGIN
        UPDATE debts
        SET status = 'paid', paid_at = COALESCE(NEW.paid_at, CURRENT_TIMESTAMP)
        WHERE id = NEW.id;
    END;

    CREATE TRIGGER IF NOT EXISTS trg_debts_paid_status_update
    AFTER UPDATE OF remaining_amount ON debts
    WHEN NEW.remaining_amount <= 0 AND NEW.status != 'paid'
    BEGIN
        UPDATE debts
        SET status = 'paid', paid_at = COALESCE(NEW.paid_at, CURRENT_TIMESTAMP), updated_at = CURRENT_TIMESTAMP
        WHERE id = NEW.id;
    END;
  `);

  // 5. Views for Indonesian aliases
  db.exec("CREATE VIEW IF NOT EXISTS catatan_hutang AS SELECT * FROM debts;");
  db.exec("CREATE VIEW IF NOT EXISTS hutang AS SELECT * FROM debts;");
}

export function ensureUsersSchema(db) {
  // 1. Ensure users table exists with full Akun & Pengaturan schema
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT,
        display_name TEXT,
        currency TEXT NOT NULL DEFAULT 'IDR',
        currency_symbol TEXT NOT NULL DEFAULT 'Rp',
        pin_hash TEXT,
        pin_enabled INTEGER NOT NULL DEFAULT 0 CHECK(pin_enabled IN (0, 1)),
        biometric_enabled INTEGER NOT NULL DEFAULT 0 CHECK(biometric_enabled IN (0, 1)),
        notifications_enabled INTEGER NOT NULL DEFAULT 1 CHECK(notifications_enabled IN (0, 1)),
        ai_advice_tone TEXT NOT NULL DEFAULT 'Standar' CHECK(ai_advice_tone IN ('Santai', 'Standar', 'Tegas', 'santai', 'standar', 'tegas')),
        monthly_budget_limit REAL NOT NULL DEFAULT 6000000 CHECK(monthly_budget_limit >= 0),
        account_tier TEXT NOT NULL DEFAULT 'Personal AI',
        date_format TEXT NOT NULL DEFAULT 'DD/MM/YYYY',
        first_day_of_week TEXT NOT NULL DEFAULT 'Senin',
        theme_mode TEXT NOT NULL DEFAULT 'Terang' CHECK(theme_mode IN ('Terang', 'Gelap', 'Ikuti Sistem', 'Sistem', 'terang', 'gelap', 'ikuti_sistem', 'sistem', 'light', 'dark', 'system')),
        hide_balance INTEGER NOT NULL DEFAULT 0 CHECK(hide_balance IN (0, 1)),
        auto_confirm_chat INTEGER NOT NULL DEFAULT 0 CHECK(auto_confirm_chat IN (0, 1)),
        haptic_feedback INTEGER NOT NULL DEFAULT 1 CHECK(haptic_feedback IN (0, 1)),
        budget_alert_threshold INTEGER NOT NULL DEFAULT 80 CHECK(budget_alert_threshold >= 0 AND budget_alert_threshold <= 100),
        phone TEXT,
        avatar_url TEXT,
        last_login_at DATETIME,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  `);

  // 2. Ensure all columns exist on pre-existing/legacy users tables
  const userCols = db.prepare('PRAGMA table_info(users)').all().map((c) => c.name);

  if (!userCols.includes('password_hash')) {
    db.exec('ALTER TABLE users ADD COLUMN password_hash TEXT');
  }
  if (!userCols.includes('display_name')) {
    db.exec('ALTER TABLE users ADD COLUMN display_name TEXT');
  }
  if (!userCols.includes('currency')) {
    db.exec("ALTER TABLE users ADD COLUMN currency TEXT NOT NULL DEFAULT 'IDR'");
  }
  if (!userCols.includes('currency_symbol')) {
    db.exec("ALTER TABLE users ADD COLUMN currency_symbol TEXT NOT NULL DEFAULT 'Rp'");
  }
  if (!userCols.includes('pin_hash')) {
    db.exec('ALTER TABLE users ADD COLUMN pin_hash TEXT');
  }
  if (!userCols.includes('pin_enabled')) {
    db.exec('ALTER TABLE users ADD COLUMN pin_enabled INTEGER NOT NULL DEFAULT 0');
  }
  if (!userCols.includes('biometric_enabled')) {
    db.exec('ALTER TABLE users ADD COLUMN biometric_enabled INTEGER NOT NULL DEFAULT 0');
  }
  if (!userCols.includes('notifications_enabled')) {
    db.exec('ALTER TABLE users ADD COLUMN notifications_enabled INTEGER NOT NULL DEFAULT 1');
  }
  if (!userCols.includes('ai_advice_tone')) {
    db.exec("ALTER TABLE users ADD COLUMN ai_advice_tone TEXT NOT NULL DEFAULT 'Standar'");
  }
  if (!userCols.includes('monthly_budget_limit')) {
    db.exec('ALTER TABLE users ADD COLUMN monthly_budget_limit REAL NOT NULL DEFAULT 6000000');
  }
  if (!userCols.includes('account_tier')) {
    db.exec("ALTER TABLE users ADD COLUMN account_tier TEXT NOT NULL DEFAULT 'Personal AI'");
  }
  if (!userCols.includes('date_format')) {
    db.exec("ALTER TABLE users ADD COLUMN date_format TEXT NOT NULL DEFAULT 'DD/MM/YYYY'");
  }
  if (!userCols.includes('first_day_of_week')) {
    db.exec("ALTER TABLE users ADD COLUMN first_day_of_week TEXT NOT NULL DEFAULT 'Senin'");
  }
  if (!userCols.includes('theme_mode')) {
    db.exec("ALTER TABLE users ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'Terang'");
  }
  if (!userCols.includes('hide_balance')) {
    db.exec('ALTER TABLE users ADD COLUMN hide_balance INTEGER NOT NULL DEFAULT 0');
  }
  if (!userCols.includes('auto_confirm_chat')) {
    db.exec('ALTER TABLE users ADD COLUMN auto_confirm_chat INTEGER NOT NULL DEFAULT 0');
  }
  if (!userCols.includes('haptic_feedback')) {
    db.exec('ALTER TABLE users ADD COLUMN haptic_feedback INTEGER NOT NULL DEFAULT 1');
  }
  if (!userCols.includes('budget_alert_threshold')) {
    db.exec('ALTER TABLE users ADD COLUMN budget_alert_threshold INTEGER NOT NULL DEFAULT 80');
  }
  if (!userCols.includes('phone')) {
    db.exec('ALTER TABLE users ADD COLUMN phone TEXT');
  }
  if (!userCols.includes('avatar_url')) {
    db.exec('ALTER TABLE users ADD COLUMN avatar_url TEXT');
  }
  if (!userCols.includes('last_login_at')) {
    db.exec('ALTER TABLE users ADD COLUMN last_login_at DATETIME');
  }
  if (!userCols.includes('created_at')) {
    db.exec('ALTER TABLE users ADD COLUMN created_at DATETIME');
    db.exec('UPDATE users SET created_at = CURRENT_TIMESTAMP WHERE created_at IS NULL');
  }
  if (!userCols.includes('updated_at')) {
    db.exec('ALTER TABLE users ADD COLUMN updated_at DATETIME');
    db.exec('UPDATE users SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL');
  }

  // 3. Ensure user_sessions table exists
  db.exec(`
    CREATE TABLE IF NOT EXISTS user_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token TEXT UNIQUE NOT NULL,
        device_name TEXT,
        ip_address TEXT,
        expires_at DATETIME NOT NULL,
        is_revoked INTEGER NOT NULL DEFAULT 0 CHECK(is_revoked IN (0, 1)),
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  `);

  const sessionCols = db.prepare('PRAGMA table_info(user_sessions)').all().map((c) => c.name);
  if (!sessionCols.includes('device_name')) {
    db.exec('ALTER TABLE user_sessions ADD COLUMN device_name TEXT');
  }
  if (!sessionCols.includes('ip_address')) {
    db.exec('ALTER TABLE user_sessions ADD COLUMN ip_address TEXT');
  }
  if (!sessionCols.includes('expires_at')) {
    db.exec("ALTER TABLE user_sessions ADD COLUMN expires_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP");
  }
  if (!sessionCols.includes('is_revoked')) {
    db.exec('ALTER TABLE user_sessions ADD COLUMN is_revoked INTEGER NOT NULL DEFAULT 0');
  }
  if (!sessionCols.includes('created_at')) {
    db.exec('ALTER TABLE user_sessions ADD COLUMN created_at DATETIME');
    db.exec('UPDATE user_sessions SET created_at = CURRENT_TIMESTAMP WHERE created_at IS NULL');
  }

  // 4. Performance indices
  db.exec('CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);');
  db.exec('CREATE INDEX IF NOT EXISTS idx_users_currency ON users(currency);');
  db.exec('CREATE INDEX IF NOT EXISTS idx_users_theme_mode ON users(theme_mode);');
  db.exec('CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(user_id);');
  db.exec('CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON user_sessions(token);');

  // 5. Trigger for automatic updated_at timestamp on users
  db.exec(`
    CREATE TRIGGER IF NOT EXISTS trg_users_updated_at
    AFTER UPDATE ON users
    FOR EACH ROW
    WHEN NEW.updated_at = OLD.updated_at
    BEGIN
        UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
    END;
  `);

  // 6. Views for Indonesian aliases
  db.exec('CREATE VIEW IF NOT EXISTS pengguna AS SELECT * FROM users;');
  db.exec('CREATE VIEW IF NOT EXISTS akun_pengguna AS SELECT * FROM users;');
  db.exec('CREATE VIEW IF NOT EXISTS sesi_pengguna AS SELECT * FROM user_sessions;');
}

export function runMigrations(db) {
  // Ensure users schema & columns exist first so indices in schema.sql succeed on legacy DBs
  ensureUsersSchema(db);

  const schemaPath = path.resolve(__dirname, 'schema.sql');
  const schemaSql = fs.readFileSync(schemaPath, 'utf8');

  // Execute schema creation
  db.exec(schemaPath.endsWith('.sql') ? schemaSql : schemaSql);

  // Ensure users schema, columns, indices, triggers, and views exist
  ensureUsersSchema(db);

  // Ensure transaction columns (category, type, guessed flags) exist on pre-existing tables
  ensureTransactionCategoryAndTypeColumns(db);

  // Ensure monthly budget schema, columns, indices, and triggers exist on pre-existing tables
  ensureMonthlyBudgetSchema(db);

  // Ensure ai_insights and financial analysis cache schema exists
  ensureAiInsightsSchema(db);

  // Ensure daily tips, reminder settings, and daily advice cache schema exists
  ensureSaranHarianSchema(db);

  // Ensure debts table schema exists
  ensureDebtsSchema(db);

  // Seed default categories (with user_id = NULL)
  seedDefaultCategories(db);

  // Seed default saving tips
  seedDefaultSavingTips(db);
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
  console.log('[Migrate] Running migrations and seeding default categories and tips...');
  runMigrations(db);
  const count = db.prepare('SELECT COUNT(*) as count FROM categories WHERE is_default = 1').get().count;
  const tipCount = db.prepare('SELECT COUNT(*) as count FROM daily_tips').get().count;
  console.log(`[Migrate] Migration complete. Total ${count} default categories and ${tipCount} saving tips seeded.`);
  closeDatabase();
}


