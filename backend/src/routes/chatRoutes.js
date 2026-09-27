import { Router } from 'express';
import {
  parseChatHandler,
  getChatHistoryHandler,
  getChatLogByIdHandler,
  deleteChatLogHandler,
  restoreChatLogHandler,
} from '../controllers/chatController.js';
import {
  confirmTransactionHandler,
  updateTransactionHandler,
  deleteTransactionHandler,
} from '../controllers/transactionController.js';

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

// Ubah & Hapus transaksi / chat log via chat routes
router.put('/history/:id', updateTransactionHandler);
router.delete('/history/:id', deleteChatLogHandler);
router.post('/history/:id/restore', restoreChatLogHandler);

router.put('/logs/:id', updateTransactionHandler);
router.delete('/logs/:id', deleteChatLogHandler);
router.post('/logs/:id/restore', restoreChatLogHandler);

// Root endpoints on chat router
router.get('/', getChatHistoryHandler);
router.post('/', parseChatHandler);
router.get('/:id', getChatLogByIdHandler);
router.put('/:id', updateTransactionHandler);
router.delete('/:id', deleteChatLogHandler);
router.post('/:id/restore', restoreChatLogHandler);

export default router;
