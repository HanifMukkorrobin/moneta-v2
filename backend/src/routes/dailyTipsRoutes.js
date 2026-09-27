/**
 * Daily Tips Routes (Rute Endpoint Tips Hemat Harian)
 *
 * Routing untuk tips hemat harian dan riwayat tips:
 * - GET  / (daftar tips hari ini dengan counter)
 * - GET  /harian
 * - GET  /riwayat, /history (riwayat tips hemat)
 * - POST /generate (generate tips baru via AI)
 * - POST /:id/toggle, /toggle (toggle status penerapan)
 * - GET  /:id (detail tip)
 * - POST / (tambah tip baru)
 */

import { Router } from 'express';
import {
  getDailyTipsHandler,
  getTipsHistoryHandler,
  getTipsHistorySummaryHandler,
  toggleTipStatusHandler,
  generateTipsHandler,
  getTipDetailHandler,
  createTipHandler,
} from '../controllers/dailyTipsController.js';

const router = Router();

// Endpoint Utama Daftar Tips Harian
router.get('/', getDailyTipsHandler);
router.get('/harian', getDailyTipsHandler);

// Endpoint Riwayat Tips Hemat (Pencarian & Filter & Summary)
router.get('/riwayat/summary', getTipsHistorySummaryHandler);
router.get('/history/summary', getTipsHistorySummaryHandler);
router.get('/riwayat', getTipsHistoryHandler);
router.get('/history', getTipsHistoryHandler);

// Endpoint Generator Tips Hemat via AI
router.post('/generate', generateTipsHandler);

// Endpoint Toggle Status Diterapkan
router.post('/toggle', toggleTipStatusHandler);
router.post('/riwayat/toggle', toggleTipStatusHandler);
router.post('/riwayat/:id/toggle', toggleTipStatusHandler);
router.post('/:id/toggle', toggleTipStatusHandler);
router.patch('/:id/toggle', toggleTipStatusHandler);

// Endpoint Detail & Pembuatan Tip
router.get('/:id', getTipDetailHandler);
router.post('/', createTipHandler);

// Dedicated router untuk endpoint /riwayat-tips & /api/riwayat-tips
export const riwayatTipsRouter = Router();
riwayatTipsRouter.get('/summary', getTipsHistorySummaryHandler);
riwayatTipsRouter.get('/', getTipsHistoryHandler);
riwayatTipsRouter.post('/toggle', toggleTipStatusHandler);
riwayatTipsRouter.post('/:id/toggle', toggleTipStatusHandler);
riwayatTipsRouter.patch('/:id/toggle', toggleTipStatusHandler);

export default router;
