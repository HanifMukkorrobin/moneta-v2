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

export function runMigrations(db) {
  const schemaPath = path.resolve(__dirname, 'schema.sql');
  const schemaSql = fs.readFileSync(schemaPath, 'utf8');

  // Execute schema creation
  db.exec(schemaSql);

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
