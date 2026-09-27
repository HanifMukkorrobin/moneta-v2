import { Router } from 'express';
import {
  getMonthlyRekapHandler,
  refreshMonthlyRekapHandler,
  getAvailableMonthsHandler,
  getSummaryAggregationHandler,
  getIncomeExpenseSummaryHandler,
  getComparisonHandler,
  getCategoryBreakdownHandler,
  getExpensesByCategoryHandler,
  getMonthlyTransactionsHandler,
  getDailyAggregationHandler,
  listBudgetsHandler,
  getMonthlyBudgetHandler,
  upsertMonthlyBudgetHandler,
  createOrUpdateBudgetHandler,
  updateBudgetByIdHandler,
  deleteMonthlyBudgetHandler,
  deleteBudgetHandler,
  getAllocationPercentagesHandler,
  upsertAllocationPercentagesHandler,
  resetAllocationPercentagesHandler,
  validateAllocationPercentagesHandler,
  getRemainingAndBucketNominalsHandler,
  getBudgetWarningStatusHandler,
  updateBudgetAlertSettingsHandler,
  toggleBudgetAlertHandler,
  getBudgetDailyAdviceHandler,
} from '../controllers/summaryBudgetController.js';
import { getTransactionByIdHandler } from '../controllers/transactionController.js';

export const rekapRouter = Router();
rekapRouter.get('/', getMonthlyRekapHandler);
rekapRouter.get('/refresh', refreshMonthlyRekapHandler);
rekapRouter.post('/refresh', refreshMonthlyRekapHandler);
rekapRouter.get('/months', getAvailableMonthsHandler);
rekapRouter.get('/available-months', getAvailableMonthsHandler);
rekapRouter.get('/summary', getSummaryAggregationHandler);
rekapRouter.get('/income-expense', getIncomeExpenseSummaryHandler);
rekapRouter.get('/comparison', getComparisonHandler);
rekapRouter.get('/compare', getComparisonHandler);
rekapRouter.get('/month-comparison', getComparisonHandler);
rekapRouter.get('/breakdown', getCategoryBreakdownHandler);
rekapRouter.get('/categories', getCategoryBreakdownHandler);
rekapRouter.get('/expenses-by-category', getExpensesByCategoryHandler);
rekapRouter.get('/expense-categories', getExpensesByCategoryHandler);
rekapRouter.get('/category-expenses', getExpensesByCategoryHandler);
rekapRouter.get('/by-category', getExpensesByCategoryHandler);
rekapRouter.get('/transactions', getMonthlyTransactionsHandler);
rekapRouter.get('/transactions/:id', getTransactionByIdHandler);
rekapRouter.get('/daily', getDailyAggregationHandler);
rekapRouter.get('/daily-advice', getBudgetDailyAdviceHandler);
rekapRouter.post('/daily-advice', getBudgetDailyAdviceHandler);
rekapRouter.get('/saran-harian', getBudgetDailyAdviceHandler);
rekapRouter.post('/saran-harian', getBudgetDailyAdviceHandler);

export const budgetRouter = Router();
budgetRouter.get('/', listBudgetsHandler);
budgetRouter.get('/monthly', getMonthlyBudgetHandler);
budgetRouter.get('/limit', getMonthlyBudgetHandler);
budgetRouter.get('/month/:month', getMonthlyBudgetHandler);
budgetRouter.get('/remaining', getRemainingAndBucketNominalsHandler);
budgetRouter.get('/sisa-batas', getRemainingAndBucketNominalsHandler);
budgetRouter.get('/buckets', getRemainingAndBucketNominalsHandler);
budgetRouter.get('/pos', getRemainingAndBucketNominalsHandler);
budgetRouter.get('/calculation', getRemainingAndBucketNominalsHandler);
budgetRouter.post('/calculation', getRemainingAndBucketNominalsHandler);
budgetRouter.get('/daily-advice', getBudgetDailyAdviceHandler);
budgetRouter.post('/daily-advice', getBudgetDailyAdviceHandler);
budgetRouter.get('/saran-harian', getBudgetDailyAdviceHandler);
budgetRouter.post('/saran-harian', getBudgetDailyAdviceHandler);
budgetRouter.get('/warnings', getBudgetWarningStatusHandler);
budgetRouter.get('/alerts', getBudgetWarningStatusHandler);
budgetRouter.get('/alert-settings', getBudgetWarningStatusHandler);
budgetRouter.get('/notification-settings', getBudgetWarningStatusHandler);
budgetRouter.post('/warnings/toggle', toggleBudgetAlertHandler);
budgetRouter.put('/warnings/toggle', toggleBudgetAlertHandler);
budgetRouter.patch('/warnings/toggle', toggleBudgetAlertHandler);
budgetRouter.post('/alerts/toggle', toggleBudgetAlertHandler);
budgetRouter.put('/alerts/toggle', toggleBudgetAlertHandler);
budgetRouter.patch('/alerts/toggle', toggleBudgetAlertHandler);
budgetRouter.post('/alert-settings/toggle', toggleBudgetAlertHandler);
budgetRouter.put('/alert-settings/toggle', toggleBudgetAlertHandler);
budgetRouter.patch('/alert-settings/toggle', toggleBudgetAlertHandler);
budgetRouter.post('/notification-settings/toggle', toggleBudgetAlertHandler);
budgetRouter.put('/notification-settings/toggle', toggleBudgetAlertHandler);
budgetRouter.patch('/notification-settings/toggle', toggleBudgetAlertHandler);
budgetRouter.post('/warnings', updateBudgetAlertSettingsHandler);
budgetRouter.put('/warnings', updateBudgetAlertSettingsHandler);
budgetRouter.patch('/warnings', updateBudgetAlertSettingsHandler);
budgetRouter.post('/alerts', updateBudgetAlertSettingsHandler);
budgetRouter.put('/alerts', updateBudgetAlertSettingsHandler);
budgetRouter.patch('/alerts', updateBudgetAlertSettingsHandler);
budgetRouter.post('/alert-settings', updateBudgetAlertSettingsHandler);
budgetRouter.put('/alert-settings', updateBudgetAlertSettingsHandler);
budgetRouter.patch('/alert-settings', updateBudgetAlertSettingsHandler);
budgetRouter.post('/notification-settings', updateBudgetAlertSettingsHandler);
budgetRouter.put('/notification-settings', updateBudgetAlertSettingsHandler);
budgetRouter.patch('/notification-settings', updateBudgetAlertSettingsHandler);
budgetRouter.get('/allocation', getAllocationPercentagesHandler);
budgetRouter.get('/allocations', getAllocationPercentagesHandler);
budgetRouter.get('/percentages', getAllocationPercentagesHandler);
budgetRouter.get('/allocation/validate', validateAllocationPercentagesHandler);
budgetRouter.post('/allocation/validate', validateAllocationPercentagesHandler);
budgetRouter.post('/allocation/reset', resetAllocationPercentagesHandler);
budgetRouter.put('/allocation/reset', resetAllocationPercentagesHandler);
budgetRouter.post('/allocation', upsertAllocationPercentagesHandler);
budgetRouter.put('/allocation', upsertAllocationPercentagesHandler);
budgetRouter.patch('/allocation', upsertAllocationPercentagesHandler);
budgetRouter.delete('/allocation', resetAllocationPercentagesHandler);
budgetRouter.post('/allocations', upsertAllocationPercentagesHandler);
budgetRouter.put('/allocations', upsertAllocationPercentagesHandler);
budgetRouter.patch('/allocations', upsertAllocationPercentagesHandler);
budgetRouter.delete('/allocations', resetAllocationPercentagesHandler);
budgetRouter.post('/percentages', upsertAllocationPercentagesHandler);
budgetRouter.put('/percentages', upsertAllocationPercentagesHandler);
budgetRouter.patch('/percentages', upsertAllocationPercentagesHandler);
budgetRouter.delete('/percentages', resetAllocationPercentagesHandler);
budgetRouter.post('/', createOrUpdateBudgetHandler);
budgetRouter.put('/', createOrUpdateBudgetHandler);
budgetRouter.patch('/', createOrUpdateBudgetHandler);
budgetRouter.post('/monthly', upsertMonthlyBudgetHandler);
budgetRouter.put('/monthly', upsertMonthlyBudgetHandler);
budgetRouter.patch('/monthly', upsertMonthlyBudgetHandler);
budgetRouter.post('/limit', upsertMonthlyBudgetHandler);
budgetRouter.put('/limit', upsertMonthlyBudgetHandler);
budgetRouter.patch('/limit', upsertMonthlyBudgetHandler);
budgetRouter.put('/:id', updateBudgetByIdHandler);
budgetRouter.patch('/:id', updateBudgetByIdHandler);
budgetRouter.delete('/monthly', deleteMonthlyBudgetHandler);
budgetRouter.delete('/limit', deleteMonthlyBudgetHandler);
budgetRouter.delete('/month/:month', deleteMonthlyBudgetHandler);
budgetRouter.delete('/', deleteMonthlyBudgetHandler);
budgetRouter.delete('/:id', deleteBudgetHandler);

const combinedRouter = Router();
// Subpaths on /api
combinedRouter.get('/rekap', getMonthlyRekapHandler);
combinedRouter.get('/rekap/refresh', refreshMonthlyRekapHandler);
combinedRouter.post('/rekap/refresh', refreshMonthlyRekapHandler);
combinedRouter.get('/rekap/months', getAvailableMonthsHandler);
combinedRouter.get('/rekap/available-months', getAvailableMonthsHandler);
combinedRouter.get('/rekap/summary', getSummaryAggregationHandler);
combinedRouter.get('/rekap/income-expense', getIncomeExpenseSummaryHandler);
combinedRouter.get('/rekap/comparison', getComparisonHandler);
combinedRouter.get('/rekap/compare', getComparisonHandler);
combinedRouter.get('/rekap/month-comparison', getComparisonHandler);
combinedRouter.get('/rekap/breakdown', getCategoryBreakdownHandler);
combinedRouter.get('/rekap/categories', getCategoryBreakdownHandler);
combinedRouter.get('/rekap/expenses-by-category', getExpensesByCategoryHandler);
combinedRouter.get('/rekap/expense-categories', getExpensesByCategoryHandler);
combinedRouter.get('/rekap/category-expenses', getExpensesByCategoryHandler);
combinedRouter.get('/rekap/by-category', getExpensesByCategoryHandler);
combinedRouter.get('/rekap/transactions', getMonthlyTransactionsHandler);
combinedRouter.get('/rekap/transactions/:id', getTransactionByIdHandler);
combinedRouter.get('/rekap/daily', getDailyAggregationHandler);
combinedRouter.get('/rekap/daily-advice', getBudgetDailyAdviceHandler);
combinedRouter.post('/rekap/daily-advice', getBudgetDailyAdviceHandler);
combinedRouter.get('/rekap/saran-harian', getBudgetDailyAdviceHandler);
combinedRouter.post('/rekap/saran-harian', getBudgetDailyAdviceHandler);
combinedRouter.get('/summary', getSummaryAggregationHandler);
combinedRouter.get('/summary/refresh', refreshMonthlyRekapHandler);
combinedRouter.post('/summary/refresh', refreshMonthlyRekapHandler);
combinedRouter.get('/summary/months', getAvailableMonthsHandler);
combinedRouter.get('/summary/income-expense', getIncomeExpenseSummaryHandler);
combinedRouter.get('/summary/comparison', getComparisonHandler);
combinedRouter.get('/summary/expenses-by-category', getExpensesByCategoryHandler);
combinedRouter.get('/summary/transactions', getMonthlyTransactionsHandler);
combinedRouter.get('/summary/transactions/:id', getTransactionByIdHandler);
combinedRouter.get('/summary/daily-advice', getBudgetDailyAdviceHandler);
combinedRouter.get('/summary/saran-harian', getBudgetDailyAdviceHandler);
combinedRouter.get('/daily-advice', getBudgetDailyAdviceHandler);
combinedRouter.post('/daily-advice', getBudgetDailyAdviceHandler);
combinedRouter.get('/saran-harian', getBudgetDailyAdviceHandler);
combinedRouter.post('/saran-harian', getBudgetDailyAdviceHandler);
combinedRouter.get('/income-expense', getIncomeExpenseSummaryHandler);
combinedRouter.get('/comparison', getComparisonHandler);
combinedRouter.get('/expenses-by-category', getExpensesByCategoryHandler);
combinedRouter.get('/budgets', listBudgetsHandler);
combinedRouter.get('/budgets/monthly', getMonthlyBudgetHandler);
combinedRouter.get('/budgets/limit', getMonthlyBudgetHandler);
combinedRouter.get('/budgets/month/:month', getMonthlyBudgetHandler);
combinedRouter.get('/budgets/remaining', getRemainingAndBucketNominalsHandler);
combinedRouter.get('/budgets/sisa-batas', getRemainingAndBucketNominalsHandler);
combinedRouter.get('/budgets/buckets', getRemainingAndBucketNominalsHandler);
combinedRouter.get('/budgets/pos', getRemainingAndBucketNominalsHandler);
combinedRouter.get('/budgets/calculation', getRemainingAndBucketNominalsHandler);
combinedRouter.post('/budgets/calculation', getRemainingAndBucketNominalsHandler);
combinedRouter.get('/budgets/daily-advice', getBudgetDailyAdviceHandler);
combinedRouter.post('/budgets/daily-advice', getBudgetDailyAdviceHandler);
combinedRouter.get('/budgets/saran-harian', getBudgetDailyAdviceHandler);
combinedRouter.post('/budgets/saran-harian', getBudgetDailyAdviceHandler);
combinedRouter.get('/budgets/warnings', getBudgetWarningStatusHandler);
combinedRouter.get('/budgets/alerts', getBudgetWarningStatusHandler);
combinedRouter.get('/budgets/alert-settings', getBudgetWarningStatusHandler);
combinedRouter.get('/budgets/notification-settings', getBudgetWarningStatusHandler);
combinedRouter.post('/budgets/warnings/toggle', toggleBudgetAlertHandler);
combinedRouter.put('/budgets/warnings/toggle', toggleBudgetAlertHandler);
combinedRouter.patch('/budgets/warnings/toggle', toggleBudgetAlertHandler);
combinedRouter.post('/budgets/alerts/toggle', toggleBudgetAlertHandler);
combinedRouter.put('/budgets/alerts/toggle', toggleBudgetAlertHandler);
combinedRouter.patch('/budgets/alerts/toggle', toggleBudgetAlertHandler);
combinedRouter.post('/budgets/alert-settings/toggle', toggleBudgetAlertHandler);
combinedRouter.put('/budgets/alert-settings/toggle', toggleBudgetAlertHandler);
combinedRouter.patch('/budgets/alert-settings/toggle', toggleBudgetAlertHandler);
combinedRouter.post('/budgets/notification-settings/toggle', toggleBudgetAlertHandler);
combinedRouter.put('/budgets/notification-settings/toggle', toggleBudgetAlertHandler);
combinedRouter.patch('/budgets/notification-settings/toggle', toggleBudgetAlertHandler);
combinedRouter.post('/budgets/warnings', updateBudgetAlertSettingsHandler);
combinedRouter.put('/budgets/warnings', updateBudgetAlertSettingsHandler);
combinedRouter.patch('/budgets/warnings', updateBudgetAlertSettingsHandler);
combinedRouter.post('/budgets/alerts', updateBudgetAlertSettingsHandler);
combinedRouter.put('/budgets/alerts', updateBudgetAlertSettingsHandler);
combinedRouter.patch('/budgets/alerts', updateBudgetAlertSettingsHandler);
combinedRouter.post('/budgets/alert-settings', updateBudgetAlertSettingsHandler);
combinedRouter.put('/budgets/alert-settings', updateBudgetAlertSettingsHandler);
combinedRouter.patch('/budgets/alert-settings', updateBudgetAlertSettingsHandler);
combinedRouter.post('/budgets/notification-settings', updateBudgetAlertSettingsHandler);
combinedRouter.put('/budgets/notification-settings', updateBudgetAlertSettingsHandler);
combinedRouter.patch('/budgets/notification-settings', updateBudgetAlertSettingsHandler);
combinedRouter.get('/budgets/allocation', getAllocationPercentagesHandler);
combinedRouter.get('/budgets/allocations', getAllocationPercentagesHandler);
combinedRouter.get('/budgets/percentages', getAllocationPercentagesHandler);
combinedRouter.get('/budgets/allocation/validate', validateAllocationPercentagesHandler);
combinedRouter.post('/budgets/allocation/validate', validateAllocationPercentagesHandler);
combinedRouter.post('/budgets/allocation/reset', resetAllocationPercentagesHandler);
combinedRouter.put('/budgets/allocation/reset', resetAllocationPercentagesHandler);
combinedRouter.post('/budgets/allocation', upsertAllocationPercentagesHandler);
combinedRouter.put('/budgets/allocation', upsertAllocationPercentagesHandler);
combinedRouter.patch('/budgets/allocation', upsertAllocationPercentagesHandler);
combinedRouter.delete('/budgets/allocation', resetAllocationPercentagesHandler);
combinedRouter.post('/budgets/allocations', upsertAllocationPercentagesHandler);
combinedRouter.put('/budgets/allocations', upsertAllocationPercentagesHandler);
combinedRouter.patch('/budgets/allocations', upsertAllocationPercentagesHandler);
combinedRouter.delete('/budgets/allocations', resetAllocationPercentagesHandler);
combinedRouter.post('/budgets/percentages', upsertAllocationPercentagesHandler);
combinedRouter.put('/budgets/percentages', upsertAllocationPercentagesHandler);
combinedRouter.patch('/budgets/percentages', upsertAllocationPercentagesHandler);
combinedRouter.delete('/budgets/percentages', resetAllocationPercentagesHandler);
combinedRouter.post('/budgets', createOrUpdateBudgetHandler);
combinedRouter.put('/budgets', createOrUpdateBudgetHandler);
combinedRouter.patch('/budgets', createOrUpdateBudgetHandler);
combinedRouter.post('/budgets/monthly', upsertMonthlyBudgetHandler);
combinedRouter.put('/budgets/monthly', upsertMonthlyBudgetHandler);
combinedRouter.patch('/budgets/monthly', upsertMonthlyBudgetHandler);
combinedRouter.post('/budgets/limit', upsertMonthlyBudgetHandler);
combinedRouter.put('/budgets/limit', upsertMonthlyBudgetHandler);
combinedRouter.patch('/budgets/limit', upsertMonthlyBudgetHandler);
combinedRouter.put('/budgets/:id', updateBudgetByIdHandler);
combinedRouter.patch('/budgets/:id', updateBudgetByIdHandler);
combinedRouter.delete('/budgets/monthly', deleteMonthlyBudgetHandler);
combinedRouter.delete('/budgets/limit', deleteMonthlyBudgetHandler);
combinedRouter.delete('/budgets/month/:month', deleteMonthlyBudgetHandler);
combinedRouter.delete('/budgets', deleteMonthlyBudgetHandler);
combinedRouter.delete('/:id', deleteBudgetHandler);
combinedRouter.delete('/budgets/:id', deleteBudgetHandler);

export default combinedRouter;



