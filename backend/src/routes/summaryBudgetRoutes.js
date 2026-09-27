import { Router } from 'express';
import {
  getMonthlyRekapHandler,
  listBudgetsHandler,
  createOrUpdateBudgetHandler,
  deleteBudgetHandler,
} from '../controllers/summaryBudgetController.js';

export const rekapRouter = Router();
rekapRouter.get('/', getMonthlyRekapHandler);
rekapRouter.get('/summary', getMonthlyRekapHandler);

export const budgetRouter = Router();
budgetRouter.get('/', listBudgetsHandler);
budgetRouter.post('/', createOrUpdateBudgetHandler);
budgetRouter.delete('/:id', deleteBudgetHandler);

const combinedRouter = Router();
// Subpaths on /api
combinedRouter.get('/rekap', getMonthlyRekapHandler);
combinedRouter.get('/summary', getMonthlyRekapHandler);
combinedRouter.get('/budgets', listBudgetsHandler);
combinedRouter.post('/budgets', createOrUpdateBudgetHandler);
combinedRouter.delete('/budgets/:id', deleteBudgetHandler);

export default combinedRouter;
