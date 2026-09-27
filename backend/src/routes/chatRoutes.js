import { Router } from 'express';
import {
  parseChatHandler,
  getChatHistoryHandler,
  getChatLogByIdHandler,
} from '../controllers/chatController.js';
import { confirmTransactionHandler } from '../controllers/transactionController.js';

const router = Router();

// Endpoint parsing kalimat jadi catatan
router.post('/parse', parseChatHandler);

// Endpoint konfirmasi transaksi via chat route
router.post('/confirm', confirmTransactionHandler);

// Endpoint riwayat percakapan chat
router.get('/history', getChatHistoryHandler);
router.get('/history/:id', getChatLogByIdHandler);
router.get('/logs', getChatHistoryHandler);
router.get('/logs/:id', getChatLogByIdHandler);

// Root endpoints on chat router
router.get('/', getChatHistoryHandler);
router.get('/:id', getChatLogByIdHandler);
router.post('/', parseChatHandler);

export default router;
