/**
 * Daily Advice Routes (Rute Endpoint Saran Belanja Hari Ini)
 *
 * Mendefinisikan routing untuk saran harian AI:
 * - GET  / (saran belanja hari ini)
 * - GET  /hari-ini, /today
 * - POST /terapkan, /apply (menandai saran diterapkan)
 * - POST /refresh, /recalculate (refresh kalkulasi saran)
 * - GET & POST /simulasi, /simulate (simulasi what-if)
 */

import { Router } from 'express';
import {
  getTodayAdviceHandler,
  applyTodayAdviceHandler,
  refreshTodayAdviceHandler,
  simulateDailyAdviceHandler,
} from '../controllers/dailyAdviceController.js';

const router = Router();

// Endpoint Utama Saran Belanja Hari Ini
router.get('/', getTodayAdviceHandler);
router.get('/hari-ini', getTodayAdviceHandler);
router.get('/today', getTodayAdviceHandler);

// Endpoint Terapkan Saran Hari Ini
router.post('/terapkan', applyTodayAdviceHandler);
router.post('/apply', applyTodayAdviceHandler);
router.post('/hari-ini/terapkan', applyTodayAdviceHandler);

// Endpoint Segarkan / Rekalkulasi Saran
router.post('/refresh', refreshTodayAdviceHandler);
router.post('/recalculate', refreshTodayAdviceHandler);

// Endpoint Simulasi What-If Batas Belanja
router.get('/simulasi', simulateDailyAdviceHandler);
router.post('/simulasi', simulateDailyAdviceHandler);
router.get('/simulate', simulateDailyAdviceHandler);
router.post('/simulate', simulateDailyAdviceHandler);

export default router;
