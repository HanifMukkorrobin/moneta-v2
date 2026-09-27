import { Router } from 'express';
import {
  classifyCategoryAndTypeHandler,
  listCategoriesHandler,
  getCategorySuggestionsHandler,
  getContextualSuggestionsHandler,
  getCategoryStatsHandler,
  createCustomCategoryHandler,
  listCustomCategoriesHandler,
  getCategoryByIdHandler,
  updateCustomCategoryHandler,
  deleteCustomCategoryHandler,
} from '../controllers/categoryController.js';
import { updateTransactionCategoryAndTypeHandler } from '../controllers/transactionController.js';

const router = Router();

// Endpoint ubah kategori & jenis transaksi via /categories/transactions/:id
router.put('/transactions/:id', updateTransactionCategoryAndTypeHandler);
router.patch('/transactions/:id', updateTransactionCategoryAndTypeHandler);

// Endpoint klasifikasi kategori dan jenis transaksi
router.post('/classify', classifyCategoryAndTypeHandler);
router.get('/classify', classifyCategoryAndTypeHandler);

// Endpoint kategori pengeluaran/pemasukan kustom
router.post('/custom', createCustomCategoryHandler);
router.get('/custom', listCustomCategoriesHandler);
router.get('/custom/:id', getCategoryByIdHandler);
router.put('/custom/:id', updateCustomCategoryHandler);
router.patch('/custom/:id', updateCustomCategoryHandler);
router.delete('/custom/:id', deleteCustomCategoryHandler);

// Endpoint statistik kategori
router.get('/stats', getCategoryStatsHandler);

// Endpoint saran kategori berbasis frekuensi & kontekstual
router.get('/frequent', getCategorySuggestionsHandler);
router.get('/suggestions', getCategorySuggestionsHandler);
router.post('/suggestions', getContextualSuggestionsHandler);
router.get('/contextual-suggestions', getContextualSuggestionsHandler);

// General category endpoints (CRUD + List)
router.get('/', listCategoriesHandler);
router.post('/', createCustomCategoryHandler);
router.get('/:id', getCategoryByIdHandler);
router.put('/:id', updateCustomCategoryHandler);
router.patch('/:id', updateCustomCategoryHandler);
router.delete('/:id', deleteCustomCategoryHandler);

export default router;
