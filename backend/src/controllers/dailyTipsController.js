/**
 * Daily Tips Controller (Controller Tips Harian & Rekomendasi Hemat)
 *
 * Menyediakan endpoint HTTP untuk mengelola tips hemat harian dan riwayat tips:
 * - GET  /api/tips (daftar tips harian terfilter per pengguna dengan counter diterapkan)
 * - GET  /api/tips/riwayat (riwayat tips hemat dengan filter pencarian dan status)
 * - POST /api/tips/:id/toggle (toggle status penerapan tip oleh pengguna)
 * - POST /api/tips/generate (generate tips baru via AI / heuristik berdasarkan transaksi)
 * - GET  /api/tips/:id (detail tip)
 * - POST /api/tips (membuat tip kustom baru)
 */

import { getDatabase } from '../config/database.js';
import { getOrCreateDefaultUser } from './chatController.js';
import {
  getAllTips,
  getTipById,
  getUserSavingTips,
  getUserTipsHistory,
  toggleUserSavingTip,
  createDailyTip,
  getTodayDateString,
} from '../services/dailyTipsService.js';
import { defaultAiSavingTipsGenerator } from '../services/aiSavingTipsGeneratorService.js';

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
 * GET /api/tips & GET /api/tips/harian
 * Mengambil daftar tips harian untuk pengguna dengan status diterapkan
 */
export function getDailyTipsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const date = req.query?.date || getTodayDateString();
    const category = req.query?.category || null;

    let isApplied = null;
    if (req.query?.isApplied !== undefined) {
      isApplied = req.query.isApplied === 'true' || req.query.isApplied === '1';
    }

    const tips = getUserSavingTips(db, {
      userId,
      date,
      category,
      isApplied,
    });

    const appliedCount = tips.filter((t) => t.isApplied).length;
    const unappliedCount = tips.filter((t) => !t.isApplied).length;
    const totalCount = tips.length;
    const successRate = totalCount > 0 ? Math.round((appliedCount / totalCount) * 100) : 0;

    return res.status(200).json({
      success: true,
      userId,
      date,
      count: tips.length,
      appliedCount,
      unappliedCount,
      totalCount,
      successRate,
      appliedBadgeText: `${appliedCount}/${totalCount} Diterapkan`,
      tips,
      data: tips,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat memuat tips harian.',
    });
  }
}

/**
 * GET /api/tips/riwayat & GET /api/tips/history
 * Mengambil riwayat tips hemat lengkap dengan pencarian dan filter status
 */
export function getTipsHistoryHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const search = req.query?.search || req.query?.q || '';
    const status = req.query?.status || 'semua';
    const category = req.query?.category || null;
    const referenceDate = req.query?.date || req.query?.referenceDate || new Date();

    const historyData = getUserTipsHistory(db, {
      userId,
      search,
      status,
      category,
      referenceDate,
    });

    return res.status(200).json({
      success: true,
      ...historyData,
      data: historyData.tips,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat memuat riwayat tips hemat.',
    });
  }
}

/**
 * GET /api/tips/riwayat/summary & GET /api/riwayat-tips/summary
 * Mengambil ringkasan metrik statistik riwayat tips hemat pengguna
 */
export function getTipsHistorySummaryHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const referenceDate = req.query?.date || req.query?.referenceDate || new Date();

    const historyData = getUserTipsHistory(db, {
      userId,
      referenceDate,
    });

    return res.status(200).json({
      success: true,
      userId,
      summary: historyData.summary,
      data: historyData.summary,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat memuat ringkasan riwayat tips.',
    });
  }
}

/**
 * POST & PATCH /api/tips/:id/toggle & POST /api/tips/toggle
 * Toggle status penerapan tip untuk user pada tanggal tertentu
 */
export function toggleTipStatusHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const tipId = req.params?.id || req.body?.tipId || req.body?.id;
    const date = req.body?.date || getTodayDateString();

    if (!tipId) {
      return res.status(400).json({
        success: false,
        error: 'Parameter tipId harus disertakan.',
      });
    }

    const tip = getTipById(db, tipId);
    if (!tip) {
      return res.status(404).json({
        success: false,
        error: `Tip dengan ID ${tipId} tidak ditemukan.`,
      });
    }

    // Jika isApplied tidak diberikan secara eksplisit di body, balikkan (toggle) status sekarang
    let isApplied = req.body?.isApplied;
    if (isApplied === undefined || isApplied === null) {
      const currentTips = getUserSavingTips(db, { userId, date });
      const currentTip = currentTips.find((t) => Number(t.id) === Number(tipId));
      isApplied = currentTip ? !currentTip.isApplied : true;
    } else {
      isApplied = Boolean(isApplied);
    }

    const updated = toggleUserSavingTip(db, {
      userId,
      tipId,
      isApplied,
      date,
    });

    const message = isApplied
      ? `Tips "${tip.title}" berhasil ditandai sebagai diterapkan.`
      : `Tanda penerapan tips "${tip.title}" dibatalkan.`;

    return res.status(200).json({
      success: true,
      message,
      userId,
      tipId: Number(tipId),
      date,
      isApplied,
      tip: updated,
      data: updated,
    });
  } catch (error) {
    const isClientError = error.message.includes('userId') || error.message.includes('tipId');
    const statusCode = isClientError ? 400 : 500;
    return res.status(statusCode).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat memperbarui status tips.',
    });
  }
}

/**
 * POST /api/tips/generate
 * Menghasilkan tips hemat baru via AI atau generator heuristik berdasarkan transaksi pengguna
 */
export async function generateTipsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromRequest(db, req);
    const saveToDb = req.body?.saveToDb !== false;

    const tips = await defaultAiSavingTipsGenerator.generateTips(db, {
      userId,
      saveToDb,
    });

    return res.status(200).json({
      success: true,
      message: 'Tips hemat personal berhasil di-generate via AI.',
      userId,
      count: tips.length,
      tips,
      data: tips,
    });
  } catch (error) {
    console.error('[DailyTipsController] Error generating saving tips:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat menghasilkan tips hemat via AI.',
    });
  }
}

/**
 * GET /api/tips/:id - Detail Satu Tip
 */
export function getTipDetailHandler(req, res) {
  try {
    const db = getDatabase();
    const tipId = req.params.id;

    const tip = getTipById(db, tipId);
    if (!tip) {
      return res.status(404).json({
        success: false,
        error: `Tip dengan ID ${tipId} tidak ditemukan.`,
      });
    }

    return res.status(200).json({
      success: true,
      tip,
      data: tip,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat memuat detail tips.',
    });
  }
}

/**
 * POST /api/tips - Membuat Tip Kustom Baru
 */
export function createTipHandler(req, res) {
  try {
    const db = getDatabase();
    const {
      title,
      category,
      description,
      potentialSaving,
      impactLevel,
      icon,
      actionText,
    } = req.body || {};

    if (!title || !description) {
      return res.status(400).json({
        success: false,
        error: 'Field title dan description wajib diisi.',
      });
    }

    const tip = createDailyTip(db, {
      title,
      category,
      description,
      potentialSaving,
      impactLevel,
      icon,
      actionText,
    });

    return res.status(201).json({
      success: true,
      message: 'Tip hemat berhasil ditambahkan.',
      tip,
      data: tip,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: error.message || 'Terjadi kesalahan saat membuat tip baru.',
    });
  }
}
