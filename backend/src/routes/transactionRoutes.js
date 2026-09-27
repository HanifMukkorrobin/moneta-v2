import { Router } from 'express';
import {
  confirmTransactionHandler,
  listTransactionsHandler,
  getTransactionByIdHandler,
  updateTransactionHandler,
  deleteTransactionHandler,
} from '../controllers/transactionController.js';

const router = Router();

// Endpoint konfirmasi transaksi dari hasil chat atau form konfirmasi
router.post('/confirm', confirmTransactionHandler);
router.post('/:id/confirm', confirmTransactionHandler);
router.put('/:id/confirm', confirmTransactionHandler);

// CRUD / List & Detail transactions
router.get('/', listTransactionsHandler);
router.get('/:id', getTransactionByIdHandler);
router.post('/', confirmTransactionHandler);

// Ubah dan Hapus transaksi
router.put('/:id', updateTransactionHandler);
router.patch('/:id', updateTransactionHandler);
router.delete('/:id', deleteTransactionHandler);

export default router;
