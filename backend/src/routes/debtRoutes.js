/**
 * Debt Routes (Rute Endpoint Catatan Hutang / Paylater & Cicilan)
 *
 * Menyediakan endpoint:
 * - POST / (tambah hutang baru dengan validasi)
 * - GET / (ambil daftar hutang)
 * - GET /summary (ringkasan total hutang, sisa, jatuh tempo)
 * - GET /:id (detail satu hutang)
 * - PUT & PATCH /:id (ubah data hutang)
 * - POST & PUT /:id/pay (tandai lunas)
 * - DELETE /:id (hapus hutang)
 */

import { Router } from 'express';
import {
  createDebtHandler,
  listDebtsHandler,
  getDebtSummaryHandler,
  getDebtByIdHandler,
  updateDebtHandler,
  markDebtAsPaidHandler,
  deleteDebtHandler,
} from '../controllers/debtController.js';

const router = Router();

// Tambah hutang baru dengan validasi
router.post('/', createDebtHandler);
router.post('/add', createDebtHandler);
router.post('/create', createDebtHandler);
router.post('/new', createDebtHandler);

// Ringkasan hutang & jatuh tempo terdekat
router.get('/summary', getDebtSummaryHandler);
router.get('/ringkasan', getDebtSummaryHandler);

// Daftar catatan hutang
router.get('/', listDebtsHandler);

// Detail satu catatan hutang
router.get('/:id', getDebtByIdHandler);

// Update catatan hutang
router.put('/:id', updateDebtHandler);
router.patch('/:id', updateDebtHandler);

// Tandai lunas
router.post('/:id/pay', markDebtAsPaidHandler);
router.put('/:id/pay', markDebtAsPaidHandler);
router.post('/:id/lunas', markDebtAsPaidHandler);
router.put('/:id/lunas', markDebtAsPaidHandler);

// Hapus catatan hutang
router.delete('/:id', deleteDebtHandler);

export default router;
