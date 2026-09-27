import Database from 'better-sqlite3';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export function createDatabaseConnection(options = {}) {
  const dbPath = options.path || process.env.DB_PATH || path.resolve(__dirname, '../../data/moneta.sqlite');
  const isMemory = dbPath === ':memory:';

  if (!isMemory) {
    const dir = path.dirname(dbPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  const db = new Database(dbPath, {
    verbose: options.verbose ? console.log : undefined,
  });

  // Enable foreign keys and WAL mode for reliability and performance
  db.pragma('foreign_keys = ON');
  if (!isMemory) {
    db.pragma('journal_mode = WAL');
  }

  return db;
}

// Singleton connection for application runtime
let globalDb = null;

export function getDatabase() {
  if (!globalDb) {
    globalDb = createDatabaseConnection();
  }
  return globalDb;
}

export function closeDatabase() {
  if (globalDb) {
    globalDb.close();
    globalDb = null;
  }
}
