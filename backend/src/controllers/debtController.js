/**
 * Debt Controller (Controller Catatan Hutang / Paylater & Cicilan)
 *
 * Mengelola endpoint HTTP untuk pencatatan hutang:
 * - POST   /api/debts (menambah hutang baru dengan validasi)
 * - GET    /api/debts (mengambil daftar hutang)
 * - GET    /api/debts/summary (ringkasan total hutang & jatuh tempo)
 * - GET    /api/debts/:id (mengambil detail satu hutang)
 * - PUT & PATCH /api/debts/:id (memperbarui catatan hutang)
 * - POST & PUT   /api/debts/:id/pay (menandai hutang lunas)
 * - DELETE /api/debts/:id (menghapus catatan hutang)
 */

import { getDatabase } from '../config/database.js';
import { getOrCreateDefaultUser } from './chatController.js';
import {
  createDebt,
  getDebtsByUserId,
  getDebtById,
  updateDebt,
  markDebtAsPaid,
  reopenDebt,
  deleteDebt,
  getDebtSummary,
  VALID_DEBT_TYPES,
  normalizeDebtType,
} from '../services/debtService.js';
import { formatRupiah } from '../services/dailyAverageSpendingService.js';

/**
 * Helper untuk memvalidasi dan mengekstrak userId dari request
 */
export function resolveUserIdFromRequest(db, req) {
  const rawId = req.query?.userId || req.headers?.['x-user-id'] || req.body?.userId;
  if (rawId !== undefined && rawId !== null && rawId !== '') {
    const num = Number(rawId);
    if (isNaN(num) || num <= 0 || !Number.isInteger(num)) {
      throw new Error('Parameter userId harus berupa bilangan bulat positif.');
    }
    return num;
  }
  return getOrCreateDefaultUser(db);
}

/**
 * POST /api/debts & POST /api/hutang
 * Menambahkan catatan hutang baru dengan validasi lengkap
 */
export async function createDebtHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const body = req.body || {};

    // 1. Validasi Nama Hutang
    const name = body.name ? String(body.name).trim() : '';
    if (!name) {
      return res.status(400).json({
        success: false,
        error: 'Nama hutang/paylater wajib diisi.',
      });
    }

    // 2. Validasi Total Nominal (totalAmount / total_amount / amount)
    const rawTotal = body.totalAmount !== undefined
      ? body.totalAmount
      : (body.total_amount !== undefined ? body.total_amount : body.amount);

    if (rawTotal === undefined || rawTotal === null || rawTotal === '') {
      return res.status(400).json({
        success: false,
        error: 'Total nominal hutang wajib diisi.',
      });
    }

    const totalAmount = Number(rawTotal);
    if (isNaN(totalAmount) || totalAmount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Total nominal hutang harus berupa angka lebih besar dari 0.',
      });
    }

    // 3. Validasi Sisa Nominal (remainingAmount / remaining_amount / paidAmount / paid_amount)
    let remainingAmount;
    if (body.remainingAmount !== undefined || body.remaining_amount !== undefined) {
      const rawRemaining = body.remainingAmount !== undefined ? body.remainingAmount : body.remaining_amount;
      remainingAmount = Number(rawRemaining);
      if (isNaN(remainingAmount) || remainingAmount < 0) {
        return res.status(400).json({
          success: false,
          error: 'Sisa nominal hutang tidak boleh negatif atau tidak valid.',
        });
      }
      if (remainingAmount > totalAmount) {
        return res.status(400).json({
          success: false,
          error: 'Sisa nominal hutang tidak boleh melebihi total nominal hutang.',
        });
      }
    } else if (body.paidAmount !== undefined || body.paid_amount !== undefined) {
      const rawPaid = body.paidAmount !== undefined ? body.paidAmount : body.paid_amount;
      const paidAmount = Number(rawPaid);
      if (isNaN(paidAmount) || paidAmount < 0) {
        return res.status(400).json({
          success: false,
          error: 'Nominal yang sudah dibayar tidak boleh negatif.',
        });
      }
      if (paidAmount > totalAmount) {
        return res.status(400).json({
          success: false,
          error: 'Nominal yang sudah dibayar tidak boleh melebihi total nominal hutang.',
        });
      }
      remainingAmount = Math.max(0, totalAmount - paidAmount);
    } else {
      remainingAmount = totalAmount; // Default belum dibayar sama sekali
    }

    // 4. Validasi Tanggal Jatuh Tempo (dueDate / due_date)
    const rawDueDate = body.dueDate || body.due_date;
    if (!rawDueDate) {
      return res.status(400).json({
        success: false,
        error: 'Tanggal jatuh tempo (dueDate) wajib diisi.',
      });
    }

    const dueDateStr = String(rawDueDate).slice(0, 10);
    const parsedDate = new Date(dueDateStr);
    if (isNaN(parsedDate.getTime())) {
      return res.status(400).json({
        success: false,
        error: 'Format tanggal jatuh tempo (dueDate) tidak valid. Gunakan format YYYY-MM-DD.',
      });
    }

    // 5. Validasi Tipe Hutang (type)
    let type = 'paylater';
    if (body.type) {
      const cleanType = String(body.type).trim();
      const validLower = VALID_DEBT_TYPES.map((t) => t.toLowerCase());
      if (!validLower.includes(cleanType.toLowerCase())) {
        return res.status(400).json({
          success: false,
          error: `Jenis hutang tidak valid. Pilihan yang tersedia: ${VALID_DEBT_TYPES.join(', ')}.`,
        });
      }
      type = normalizeDebtType(cleanType);
    }

    const notes = body.notes ? String(body.notes).trim() : null;
    const status = body.status ? String(body.status).trim() : null;

    // Buat hutang baru
    const newDebt = createDebt(db, {
      userId,
      name,
      totalAmount,
      remainingAmount,
      dueDate: dueDateStr,
      type,
      notes,
      status,
    });

    return res.status(201).json({
      success: true,
      message: 'Catatan hutang berhasil ditambahkan.',
      data: newDebt,
      debt: newDebt,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId') || error.message.includes('wajib') || error.message.includes('tidak boleh');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat menambahkan catatan hutang.',
    });
  }
}

/**
 * GET /api/debts & GET /api/hutang
 * Mengambil daftar catatan hutang dengan filter status, tipe, dan pengurutan
 */
export function listDebtsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);

    const status = req.query?.status;
    const type = req.query?.type;
    const isDueSoon = req.query?.isDueSoon;
    const isOverdue = req.query?.isOverdue;
    const filter = req.query?.filter;
    const search = req.query?.search || req.query?.q;
    const sortBy = req.query?.sortBy || req.query?.sort_by || 'due_date';
    const sortOrder = req.query?.sortOrder || req.query?.sort_order || 'ASC';
    const limit = Number(req.query?.limit) || 100;
    const offset = Number(req.query?.offset) || 0;

    const debts = getDebtsByUserId(db, userId, {
      status,
      type,
      isDueSoon,
      isOverdue,
      filter,
      search,
      sortBy,
      sortOrder,
      limit,
      offset,
    });

    // Hitung ringkasan cepat untuk header UI
    let activeCount = 0;
    let paidCount = 0;
    let dueSoonCount = 0;
    let overdueCount = 0;
    let totalRemainingAmount = 0;

    for (const d of debts) {
      if (d.isPaid) {
        paidCount += 1;
      } else {
        activeCount += 1;
        totalRemainingAmount += d.remainingAmount;
        if (d.isDueSoon) dueSoonCount += 1;
        if (d.isOverdue) overdueCount += 1;
      }
    }

    return res.status(200).json({
      success: true,
      userId,
      total: debts.length,
      activeCount,
      paidCount,
      dueSoonCount,
      overdueCount,
      totalRemainingAmount,
      formattedTotalRemainingAmount: formatRupiah(totalRemainingAmount),
      debts,
      data: debts,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Gagal memuat daftar catatan hutang.',
    });
  }
}

/**
 * GET /api/debts/summary & GET /api/hutang/summary
 * Mengambil ringkasan hutang (total sisa, jatuh tempo terdekat, persentase terbayar)
 */
export function getDebtSummaryHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const summary = getDebtSummary(db, userId);

    return res.status(200).json({
      success: true,
      userId,
      summary,
      data: summary,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Gagal memuat ringkasan hutang.',
    });
  }
}

/**
 * GET /api/debts/:id & GET /api/hutang/:id
 * Mengambil detail satu catatan hutang
 */
export function getDebtByIdHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const id = Number(req.params.id);

    if (isNaN(id) || id <= 0) {
      return res.status(400).json({
        success: false,
        error: 'ID hutang harus berupa bilangan bulat positif.',
      });
    }

    const debt = getDebtById(db, id, userId);
    if (!debt) {
      return res.status(404).json({
        success: false,
        error: 'Catatan hutang tidak ditemukan.',
      });
    }

    return res.status(200).json({
      success: true,
      data: debt,
      debt,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message || 'Gagal memuat detail hutang.',
    });
  }
}

/**
 * PUT & PATCH /api/debts/:id & /api/hutang/:id
 * Memperbarui catatan hutang
 */
export function updateDebtHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const id = Number(req.params.id);

    if (isNaN(id) || id <= 0) {
      return res.status(400).json({
        success: false,
        error: 'ID hutang harus berupa bilangan bulat positif.',
      });
    }

    const body = req.body || {};
    const updated = updateDebt(db, id, userId, body);

    return res.status(200).json({
      success: true,
      message: 'Catatan hutang berhasil diperbarui.',
      data: updated,
      debt: updated,
    });
  } catch (error) {
    const notFound = error.message.includes('tidak ditemukan');
    const statusCode = notFound ? 404 : 400;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Gagal memperbarui catatan hutang.',
    });
  }
}

/**
 * POST, PUT, PATCH /api/debts/:id/pay & /api/hutang/:id/lunas
 * Menandai hutang sebagai lunas atau mencatat cicilan/pelunasan parsial
 */
export function markDebtAsPaidHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const id = Number(req.params.id);

    if (isNaN(id) || id <= 0) {
      return res.status(400).json({
        success: false,
        error: 'ID hutang harus berupa bilangan bulat positif.',
      });
    }

    const existing = getDebtById(db, id, userId);
    if (!existing) {
      return res.status(404).json({
        success: false,
        error: 'Catatan hutang tidak ditemukan.',
      });
    }

    const body = req.body || {};
    const hasAmount = body.amount !== undefined && body.amount !== null && body.amount !== '';
    const isFull = Boolean(body.isFull || !hasAmount);

    let resultDebt;
    if (isFull) {
      // Pelunasan penuh langsung
      resultDebt = markDebtAsPaid(db, id, userId);
    } else {
      // Pembayaran parsial
      const paymentAmount = Number(body.amount);
      if (isNaN(paymentAmount) || paymentAmount <= 0) {
        return res.status(400).json({
          success: false,
          error: 'Nominal pembayaran harus berupa angka lebih besar dari 0.',
        });
      }

      const newRemaining = Math.max(0, existing.remainingAmount - paymentAmount);
      const isNowPaid = newRemaining <= 0;
      const newNotes = body.notes ? String(body.notes).trim() : existing.notes;

      resultDebt = updateDebt(db, id, userId, {
        remainingAmount: newRemaining,
        status: isNowPaid ? 'paid' : 'active',
        notes: newNotes,
      });
    }

    return res.status(200).json({
      success: true,
      message: resultDebt.isPaid
        ? 'Catatan hutang berhasil ditandai sebagai lunas.'
        : `Pembayaran ${formatRupiah(Number(body.amount))} berhasil dicatat.`,
      data: resultDebt,
      debt: resultDebt,
    });
  } catch (error) {
    const notFound = error.message.includes('tidak ditemukan');
    const statusCode = notFound ? 404 : 400;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Gagal memproses pelunasan hutang.',
    });
  }
}

/**
 * POST, PUT, PATCH /api/debts/:id/reopen & /api/hutang/:id/aktifkan
 * Mengaktifkan kembali catatan hutang yang sebelumnya sudah lunas
 */
export function reopenDebtHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const id = Number(req.params.id);

    if (isNaN(id) || id <= 0) {
      return res.status(400).json({
        success: false,
        error: 'ID hutang harus berupa bilangan bulat positif.',
      });
    }

    const body = req.body || {};
    const newRemainingAmount = body.remainingAmount !== undefined
      ? body.remainingAmount
      : (body.remaining_amount !== undefined ? body.remaining_amount : null);

    const reopened = reopenDebt(db, id, userId, newRemainingAmount);

    return res.status(200).json({
      success: true,
      message: 'Catatan hutang berhasil diaktifkan kembali.',
      data: reopened,
      debt: reopened,
    });
  } catch (error) {
    const notFound = error.message.includes('tidak ditemukan');
    const statusCode = notFound ? 404 : 400;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Gagal mengaktifkan kembali hutang.',
    });
  }
}

/**
 * DELETE /api/debts/:id & /api/hutang/:id
 * Menghapus catatan hutang
 */
export function deleteDebtHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const id = Number(req.params.id);

    if (isNaN(id) || id <= 0) {
      return res.status(400).json({
        success: false,
        error: 'ID hutang harus berupa bilangan bulat positif.',
      });
    }

    const deleted = deleteDebt(db, id, userId);
    if (!deleted) {
      return res.status(404).json({
        success: false,
        error: 'Catatan hutang tidak ditemukan atau tidak dapat dihapus.',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Catatan hutang berhasil dihapus.',
      deleted: true,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message || 'Gagal menghapus catatan hutang.',
    });
  }
}
