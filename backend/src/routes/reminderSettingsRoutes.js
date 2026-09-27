/**
 * Reminder Settings Routes (Rute Endpoint Pengaturan Pengingat Harian)
 *
 * Routing untuk preferensi pengingat harian:
 * - GET  / (mengambil pengaturan)
 * - PUT, PATCH, POST / (memperbarui pengaturan)
 * - POST /reset (mereset ke default)
 * - POST /test (simulasi notifikasi uji coba)
 */

import { Router } from 'express';
import {
  getReminderSettingsHandler,
  updateReminderSettingsHandler,
  resetReminderSettingsHandler,
  testReminderNotificationHandler,
  triggerReminderSchedulerHandler,
  getReminderSchedulerStatusHandler,
  startReminderSchedulerHandler,
  stopReminderSchedulerHandler,
  getNotificationHistoryHandler,
  deleteNotificationHistoryHandler,
} from '../controllers/reminderSettingsController.js';

const router = Router();

// Endpoint Mengambil Pengaturan Pengingat
router.get('/', getReminderSettingsHandler);
router.get('/settings', getReminderSettingsHandler);

// Endpoint Memperbarui Pengaturan Pengingat
router.put('/', updateReminderSettingsHandler);
router.patch('/', updateReminderSettingsHandler);
router.post('/', updateReminderSettingsHandler);
router.put('/settings', updateReminderSettingsHandler);
router.patch('/settings', updateReminderSettingsHandler);

// Endpoint Reset Pengaturan
router.post('/reset', resetReminderSettingsHandler);

// Endpoint Simulasi Notifikasi Pengingat
router.post('/test', testReminderNotificationHandler);
router.get('/test', testReminderNotificationHandler);

// Endpoint Scheduler Pengingat Harian
router.get('/scheduler/status', getReminderSchedulerStatusHandler);
router.post('/scheduler/trigger', triggerReminderSchedulerHandler);
router.post('/scheduler/run', triggerReminderSchedulerHandler);
router.post('/scheduler/start', startReminderSchedulerHandler);
router.post('/scheduler/stop', stopReminderSchedulerHandler);

// Endpoint Riwayat Notifikasi Pengguna
router.get('/notifikasi', getNotificationHistoryHandler);
router.get('/notifications', getNotificationHistoryHandler);
router.get('/history', getNotificationHistoryHandler);
router.delete('/notifikasi/:id', deleteNotificationHistoryHandler);
router.delete('/notifications/:id', deleteNotificationHistoryHandler);
router.delete('/notifikasi', deleteNotificationHistoryHandler);
router.delete('/notifications', deleteNotificationHistoryHandler);

// Router khusus untuk root mount /notifikasi dan /api/notifikasi
export const notifikasiRouter = Router();
notifikasiRouter.get('/', getNotificationHistoryHandler);
notifikasiRouter.get('/history', getNotificationHistoryHandler);
notifikasiRouter.delete('/:id', deleteNotificationHistoryHandler);
notifikasiRouter.delete('/', deleteNotificationHistoryHandler);

export default router;
