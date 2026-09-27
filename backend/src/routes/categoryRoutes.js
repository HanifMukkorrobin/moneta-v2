import { Router } from 'express';
import {
  classifyCategoryAndTypeHandler,
  listCategoriesHandler,
  getCategorySuggestionsHandler,
} from '../controllers/categoryController.js';

const router = Router();

// Endpoint klasifikasi kategori dan jenis transaksi
router.post('/classify', classifyCategoryAndTypeHandler);
router.get('/classify', classifyCategoryAndTypeHandler);

// Endpoint daftar kategori
router.get('/', listCategoriesHandler);

// Endpoint saran kategori paling sering digunakan
router.get('/frequent', getCategorySuggestionsHandler);
router.get('/suggestions', getCategorySuggestionsHandler);

export default router;
