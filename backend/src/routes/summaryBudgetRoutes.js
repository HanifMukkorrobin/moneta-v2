import { Router } from 'express';
import {
  getMonthlyRekapHandler,
  getSummaryAggregationHandler,
  getComparisonHandler,
  getCategoryBreakdownHandler,
  getDailyAggregationHandler,
  listBudgetsHandler,
  createOrUpdateBudgetHandler,
  deleteBudgetHandler,
} from '../controllers/summaryBudgetController.js';

export const rekapRouter = Router();
rekapRouter.get('/', getMonthlyRekapHandler);
rekapRouter.get('/summary', getSummaryAggregationHandler);
rekapRouter.get('/comparison', getComparisonHandler);
rekapRouter.get('/breakdown', getCategoryBreakdownHandler);
rekapRouter.get('/categories', getCategoryBreakdownHandler);
rekapRouter.get('/daily', getDailyAggregationHandler);

export const budgetRouter = Router();
budgetRouter.get('/', listBudgetsHandler);
budgetRouter.post('/', createOrUpdateBudgetHandler);
budgetRouter.delete('/:id', deleteBudgetHandler);

const combinedRouter = Router();
// Subpaths on /api
combinedRouter.get('/rekap', getMonthlyRekapHandler);
combinedRouter.get('/rekap/summary', getSummaryAggregationHandler);
combinedRouter.get('/rekap/comparison', getComparisonHandler);
combinedRouter.get('/rekap/breakdown', getCategoryBreakdownHandler);
combinedRouter.get('/rekap/categories', getCategoryBreakdownHandler);
combinedRouter.get('/rekap/daily', getDailyAggregationHandler);
combinedRouter.get('/summary', getSummaryAggregationHandler);
combinedRouter.get('/budgets', listBudgetsHandler);
combinedRouter.post('/budgets', createOrUpdateBudgetHandler);
combinedRouter.delete('/budgets/:id', deleteBudgetHandler);

export default combinedRouter;
