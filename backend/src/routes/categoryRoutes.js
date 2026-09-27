import { Router } from 'express';
import {
  classifyCategoryAndTypeHandler,
  listCategoriesHandler,
  getCategorySuggestionsHandler,
  createCustomCategoryHandler,
  listCustomCategoriesHandler,
  getCategoryByIdHandler,
  updateCustomCategoryHandler,
  deleteCustomCategoryHandler,
} from '../controllers/categoryController.js';

const router = Router();

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

// Endpoint saran kategori paling sering digunakan
router.get('/frequent', getCategorySuggestionsHandler);
router.get('/suggestions', getCategorySuggestionsHandler);

// General category endpoints (CRUD + List)
router.get('/', listCategoriesHandler);
router.post('/', createCustomCategoryHandler);
router.get('/:id', getCategoryByIdHandler);
router.put('/:id', updateCustomCategoryHandler);
router.patch('/:id', updateCustomCategoryHandler);
router.delete('/:id', deleteCustomCategoryHandler);

export default router;
