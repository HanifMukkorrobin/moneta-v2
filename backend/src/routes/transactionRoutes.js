import { Router } from 'express';
import {
  confirmTransactionHandler,
  listTransactionsHandler,
  getTransactionByIdHandler,
} from '../controllers/transactionController.js';

const router = Router();

// Endpoint konfirmasi transaksi dari hasil chat atau form konfirmasi
router.post('/confirm', confirmTransactionHandler);
router.post('/:id/confirm', confirmTransactionHandler);
router.put('/:id/confirm', confirmTransactionHandler);

// CRUD / List transactions
router.get('/', listTransactionsHandler);
router.get('/:id', getTransactionByIdHandler);
router.post('/', confirmTransactionHandler);

export default router;
