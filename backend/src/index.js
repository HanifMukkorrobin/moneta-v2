import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { getDatabase, closeDatabase } from './config/database.js';
import { runMigrations } from './db/migrate.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Initialize database & run migrations on startup
const db = getDatabase();
runMigrations(db);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'moneta-backend',
    database: 'connected',
    timestamp: new Date().toISOString(),
  });
});

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`[Moneta Backend] Server listening on http://localhost:${PORT}`);
  });
}

process.on('SIGINT', () => {
  closeDatabase();
  process.exit(0);
});

process.on('SIGTERM', () => {
  closeDatabase();
  process.exit(0);
});

export default app;
