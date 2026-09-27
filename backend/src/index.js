import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { getDatabase, closeDatabase } from './config/database.js';
import { runMigrations } from './db/migrate.js';

import chatRoutes from './routes/chatRoutes.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Initialize database & run migrations on startup
const db = getDatabase();
runMigrations(db);

// Mount Chat parsing endpoints
app.use('/chat', chatRoutes);
app.use('/api/chat', chatRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'moneta-backend',
    database: 'connected',
    timestamp: new Date().toISOString(),
  });
});

// Start server when executed directly as main module
const isMain = process.argv[1] && import.meta.url.endsWith(process.argv[1]);
if (process.env.NODE_ENV !== 'test' && isMain) {
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
