import { Router } from 'express';
import { parseChatHandler } from '../controllers/chatController.js';

const router = Router();

// Endpoint parsing kalimat jadi catatan
router.post('/parse', parseChatHandler);

// Also expose /chat directly on router for flexible routing
router.post('/', parseChatHandler);

export default router;
