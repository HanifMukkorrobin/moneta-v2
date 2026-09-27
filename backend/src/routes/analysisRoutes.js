import { Router } from 'express';
import {
  getFullFinancialAnalysisHandler,
  getAnalysisSummaryHandler,
  getDailyAverageSpendingHandler,
  getMoneyDepletionHandler,
  getEarlyWarningStatusHandler,
  recalculateAnalysisHandler,
} from '../controllers/analysisController.js';

const router = Router();

// Full Financial Analysis
router.get('/', getFullFinancialAnalysisHandler);
router.get('/full', getFullFinancialAnalysisHandler);

// Executive Summary
router.get('/summary', getAnalysisSummaryHandler);
router.get('/ringkasan', getAnalysisSummaryHandler);

// Daily Average Spending
router.get('/daily-average', getDailyAverageSpendingHandler);
router.get('/rata-rata-pengeluaran', getDailyAverageSpendingHandler);
router.get('/avg-daily', getDailyAverageSpendingHandler);

// Money Depletion Projection
router.get('/depletion', getMoneyDepletionHandler);
router.get('/perkiraan-uang-bertahan', getMoneyDepletionHandler);
router.get('/tanggal-habis', getMoneyDepletionHandler);

// 3-Level Early Warning Status
router.get('/warning', getEarlyWarningStatusHandler);
router.get('/peringatan-dini', getEarlyWarningStatusHandler);
router.get('/early-warning', getEarlyWarningStatusHandler);

// Recalculate / Refresh Cache
router.post('/recalculate', recalculateAnalysisHandler);
router.post('/refresh', recalculateAnalysisHandler);

export default router;
