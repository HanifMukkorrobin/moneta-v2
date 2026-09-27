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
  reopenDebtHandler,
  deleteDebtHandler,
} from '../controllers/debtController.js';

const router = Router();

// Tambah hutang baru dengan validasi
router.post('/', createDebtHandler);
router.post('/add', createDebtHandler);
router.post('/create', createDebtHandler);
router.post('/new', createDebtHandler);

// Ringkasan hutang & total sisa hutang aktif
router.get('/summary', getDebtSummaryHandler);
router.get('/ringkasan', getDebtSummaryHandler);
router.get('/total-sisa', getDebtSummaryHandler);
router.get('/total-sisa-aktif', getDebtSummaryHandler);
router.get('/ringkasan-total', getDebtSummaryHandler);
router.get('/stats', getDebtSummaryHandler);
router.get('/statistik', getDebtSummaryHandler);

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
router.patch('/:id/pay', markDebtAsPaidHandler);
router.post('/:id/lunas', markDebtAsPaidHandler);
router.put('/:id/lunas', markDebtAsPaidHandler);
router.patch('/:id/lunas', markDebtAsPaidHandler);

// Aktifkan kembali / batalkan lunas
router.post('/:id/reopen', reopenDebtHandler);
router.put('/:id/reopen', reopenDebtHandler);
router.patch('/:id/reopen', reopenDebtHandler);
router.post('/:id/aktifkan', reopenDebtHandler);
router.put('/:id/aktifkan', reopenDebtHandler);
router.patch('/:id/aktifkan', reopenDebtHandler);

// Hapus catatan hutang
router.delete('/:id', deleteDebtHandler);

export default router;
