import { Router } from 'express';
import { parseChatHandler } from '../controllers/chatController.js';
import { confirmTransactionHandler } from '../controllers/transactionController.js';

const router = Router();

// Endpoint parsing kalimat jadi catatan
router.post('/parse', parseChatHandler);

// Endpoint konfirmasi transaksi via chat route
router.post('/confirm', confirmTransactionHandler);

// Also expose /chat directly on router for flexible routing
router.post('/', parseChatHandler);

export default router;
