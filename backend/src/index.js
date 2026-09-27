import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { getDatabase, closeDatabase } from './config/database.js';
import { runMigrations } from './db/migrate.js';

import chatRoutes from './routes/chatRoutes.js';
import transactionRoutes from './routes/transactionRoutes.js';
import summaryBudgetRoutes, { rekapRouter, budgetRouter } from './routes/summaryBudgetRoutes.js';
import categoryRoutes from './routes/categoryRoutes.js';
import analysisRoutes from './routes/analysisRoutes.js';
import dailyAdviceRoutes from './routes/dailyAdviceRoutes.js';
import dailyTipsRoutes, { riwayatTipsRouter } from './routes/dailyTipsRoutes.js';
import reminderSettingsRoutes, { notifikasiRouter } from './routes/reminderSettingsRoutes.js';
import debtRoutes from './routes/debtRoutes.js';
import { globalReminderScheduler } from './services/reminderSchedulerService.js';
import { classifyCategoryAndTypeHandler } from './controllers/categoryController.js';

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

// Mount Transaction endpoints
app.use('/transactions', transactionRoutes);
app.use('/api/transactions', transactionRoutes);

// Mount Rekap & Budget endpoints
app.use('/rekap', rekapRouter);
app.use('/api/rekap', rekapRouter);
app.use('/summary', rekapRouter);
app.use('/api/summary', rekapRouter);
app.use('/budgets', budgetRouter);
app.use('/api/budgets', budgetRouter);
app.use('/api', summaryBudgetRoutes);

// Mount Category & Classification endpoints
app.use('/categories', categoryRoutes);
app.use('/api/categories', categoryRoutes);

// Mount Analisa Keuangan AI endpoints
app.use('/analisa', analysisRoutes);
app.use('/api/analisa', analysisRoutes);
app.use('/analysis', analysisRoutes);
app.use('/api/analysis', analysisRoutes);

// Mount Saran Harian AI endpoints
app.use('/saran', dailyAdviceRoutes);
app.use('/api/saran', dailyAdviceRoutes);
app.use('/saran-harian', dailyAdviceRoutes);
app.use('/api/saran-harian', dailyAdviceRoutes);
app.use('/daily-advice', dailyAdviceRoutes);
app.use('/api/daily-advice', dailyAdviceRoutes);

// Mount Tips Hemat Harian endpoints
app.use('/tips', dailyTipsRoutes);
app.use('/api/tips', dailyTipsRoutes);
app.use('/tips-harian', dailyTipsRoutes);
app.use('/api/tips-harian', dailyTipsRoutes);
app.use('/riwayat-tips', riwayatTipsRouter);
app.use('/api/riwayat-tips', riwayatTipsRouter);

// Mount Pengaturan Pengingat Harian & Scheduler endpoints
app.use('/pengaturan-pengingat', reminderSettingsRoutes);
app.use('/api/pengaturan-pengingat', reminderSettingsRoutes);
app.use('/reminders', reminderSettingsRoutes);
app.use('/api/reminders', reminderSettingsRoutes);

// Mount Notifikasi endpoints
app.use('/notifikasi', notifikasiRouter);
app.use('/api/notifikasi', notifikasiRouter);
app.use('/notifications', notifikasiRouter);
app.use('/api/notifications', notifikasiRouter);

// Mount Catatan Hutang / Paylater endpoints
app.use('/debts', debtRoutes);
app.use('/api/debts', debtRoutes);
app.use('/hutang', debtRoutes);
app.use('/api/hutang', debtRoutes);

// Direct top-level classify endpoint aliases
app.post('/classify', classifyCategoryAndTypeHandler);
app.get('/classify', classifyCategoryAndTypeHandler);
app.post('/api/classify', classifyCategoryAndTypeHandler);
app.get('/api/classify', classifyCategoryAndTypeHandler);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'moneta-backend',
    database: 'connected',
    scheduler: globalReminderScheduler.getStatus(),
    timestamp: new Date().toISOString(),
  });
});

// Start server when executed directly as main module
const isMain = process.argv[1] && import.meta.url.endsWith(process.argv[1]);
if (process.env.NODE_ENV !== 'test' && isMain) {
  // Start daily reminder background scheduler
  if (process.env.ENABLE_REMINDER_SCHEDULER !== 'false') {
    globalReminderScheduler.start({
      intervalMs: Number(process.env.REMINDER_SCHEDULER_INTERVAL_MS) || 60000,
      dbGetter: getDatabase,
    });
    console.log('[Reminder Scheduler] Daily reminder background scheduler started.');
  }

  app.listen(PORT, () => {
    console.log(`[Moneta Backend] Server listening on http://localhost:${PORT}`);
  });
}

process.on('SIGINT', () => {
  globalReminderScheduler.stop();
  closeDatabase();
  process.exit(0);
});

process.on('SIGTERM', () => {
  globalReminderScheduler.stop();
  closeDatabase();
  process.exit(0);
});

export default app;
