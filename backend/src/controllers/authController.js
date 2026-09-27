/**
 * Auth & User Account Controller (Controller Autentikasi, Akun & Pengaturan)
 *
 * Mengelola endpoint HTTP untuk:
 * - POST /api/auth/register (registrasi akun pengguna baru)
 * - POST /api/auth/login (masuk ke akun & buat token sesi)
 * - GET & POST /api/auth/verify / /api/auth/me (verifikasi token sesi aktif)
 * - POST /api/auth/refresh (rotasi / perbarui token sesi)
 * - POST & DELETE /api/auth/logout / /api/auth/session (keluar & hapus/cabut sesi)
 * - DELETE /api/auth/sessions/:id (hapus satu sesi berdasarkan ID)
 * - DELETE /api/auth/sessions & POST /api/auth/sessions/clear (hapus seluruh sesi pengguna)
 * - GET /api/auth/sessions (daftar sesi aktif pengguna)
 */

import { getDatabase } from '../config/database.js';
import {
  registerUser,
  loginUser,
  verifySessionToken,
  refreshUserSession,
  revokeUserSession,
  revokeAllUserSessions,
  deleteUserSessionById,
  deleteAllUserSessions,
  cleanupExpiredSessions,
  getUserActiveSessions,
} from '../services/userService.js';

/**
 * Helper untuk mengekstrak token dari Authorization header, custom header, body, atau query
 */
export function extractTokenFromRequest(req) {
  const authHeader = req.headers?.authorization || req.headers?.Authorization;
  if (authHeader && typeof authHeader === 'string') {
    if (authHeader.toLowerCase().startsWith('bearer ')) {
      return authHeader.slice(7).trim();
    }
    return authHeader.trim();
  }

  const headerToken = req.headers?.['x-auth-token'] || req.headers?.['x-access-token'];
  if (headerToken && typeof headerToken === 'string') {
    return headerToken.trim();
  }

  if (req.body?.token && typeof req.body.token === 'string') {
    return req.body.token.trim();
  }

  if (req.query?.token && typeof req.query.token === 'string') {
    return req.query.token.trim();
  }

  return '';
}

/**
 * POST /api/auth/register & POST /api/users/register
 * Registrasi akun pengguna baru dengan validasi email, kata sandi, dan mata uang
 */
export async function registerUserHandler(req, res) {
  try {
    const db = getDatabase();
    const body = req.body || {};

    const { user, session } = registerUser(db, {
      ...body,
      ipAddress: req.ip || null,
    });

    return res.status(201).json({
      success: true,
      message: `Akun ${user.displayName} berhasil didaftarkan.`,
      data: {
        user,
        token: session.token,
        session,
      },
      user,
      token: session.token,
      session,
    });
  } catch (err) {
    const status = err.statusCode || 500;
    return res.status(status).json({
      success: false,
      code: err.code || 'REGISTRATION_FAILED',
      error: err.message || 'Gagal melakukan registrasi akun.',
    });
  }
}

/**
 * POST /api/auth/login & POST /api/auth/masuk
 * Autentikasi email & kata sandi pengguna serta pembuatan token sesi baru
 */
export async function loginUserHandler(req, res) {
  try {
    const db = getDatabase();
    const body = req.body || {};

    const { user, session } = loginUser(db, {
      ...body,
      ipAddress: req.ip || null,
    });

    return res.status(200).json({
      success: true,
      message: `Selamat datang kembali, ${user.displayName}!`,
      data: {
        user,
        token: session.token,
        session,
      },
      user,
      token: session.token,
      session,
    });
  } catch (err) {
    const status = err.statusCode || 500;
    return res.status(status).json({
      success: false,
      code: err.code || 'LOGIN_FAILED',
      error: err.message || 'Gagal masuk ke akun.',
    });
  }
}

/**
 * GET & POST /api/auth/verify, /api/auth/me, /api/auth/session
 * Memverifikasi token sesi aktif dan mengembalikan profil pengguna
 */
export async function verifyTokenHandler(req, res) {
  try {
    const db = getDatabase();
    const token = extractTokenFromRequest(req);
    const { user, session } = verifySessionToken(db, token);

    return res.status(200).json({
      success: true,
      valid: true,
      message: 'Token sesi valid dan aktif.',
      data: {
        user,
        session,
        token: session.token,
      },
      user,
      session,
      token: session.token,
    });
  } catch (err) {
    const status = err.statusCode || 401;
    return res.status(status).json({
      success: false,
      valid: false,
      code: err.code || 'INVALID_TOKEN',
      error: err.message || 'Token sesi tidak valid.',
    });
  }
}

/**
 * POST /api/auth/refresh & POST /api/auth/token/refresh
 * Memperbarui (rotasi) token sesi aktif dan mencabut token lama
 */
export async function refreshTokenHandler(req, res) {
  try {
    const db = getDatabase();
    const token = extractTokenFromRequest(req);
    const body = req.body || {};

    const { user, session, revokedToken } = refreshUserSession(db, token, {
      deviceName: body.deviceName || body.device_name,
      ipAddress: req.ip || null,
      ttlDays: body.ttlDays,
    });

    return res.status(200).json({
      success: true,
      message: 'Token sesi berhasil diperbarui.',
      data: {
        user,
        token: session.token,
        session,
        revokedToken,
      },
      user,
      token: session.token,
      session,
      revokedToken,
    });
  } catch (err) {
    const status = err.statusCode || 401;
    return res.status(status).json({
      success: false,
      code: err.code || 'REFRESH_FAILED',
      error: err.message || 'Gagal memperbarui token sesi.',
    });
  }
}

/**
 * POST & DELETE /api/auth/logout, /api/auth/keluar, /api/auth/session, /api/auth/hapus-sesi
 * Mencabut atau menghapus sesi saat ini maupun seluruh sesi perangkat pengguna
 */
export async function logoutUserHandler(req, res) {
  try {
    const db = getDatabase();
    const token = extractTokenFromRequest(req);
    const body = req.body || {};
    const query = req.query || {};

    const rawUserId = body.userId ?? query.userId ?? req.headers?.['x-user-id'];
    const allDevices = Boolean(
      body.allDevices ||
      body.semuaPerangkat ||
      query.allDevices === 'true' ||
      (!token && rawUserId)
    );
    const hardDelete = Boolean(
      body.hardDelete ||
      body.deleteSession ||
      body.hapusSesi ||
      query.hardDelete === 'true' ||
      query.deleteSession === 'true' ||
      req.method === 'DELETE'
    );

    if (allDevices && (rawUserId || token)) {
      let targetUserId = rawUserId ? Number(rawUserId) : null;
      if (!targetUserId && token) {
        const verified = verifySessionToken(db, token);
        targetUserId = verified.user.id;
      }
      const result = revokeAllUserSessions(db, targetUserId, { hardDelete });
      return res.status(200).json({
        success: true,
        message: hardDelete
          ? 'Seluruh sesi perangkat berhasil dihapus.'
          : 'Berhasil keluar dari seluruh perangkat.',
        data: result,
        ...result,
      });
    }

    const result = revokeUserSession(db, token, { hardDelete });
    return res.status(200).json({
      success: true,
      message: hardDelete ? 'Sesi berhasil dihapus dan keluar dari akun.' : 'Berhasil keluar dari sesi.',
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'LOGOUT_FAILED',
      error: err.message || 'Gagal keluar dari sesi.',
    });
  }
}

/**
 * DELETE /api/auth/sessions/:id & DELETE /api/auth/sesi/:id
 * Menghapus satu sesi spesifik berdasarkan ID sesi
 */
export async function deleteSessionByIdHandler(req, res) {
  try {
    const db = getDatabase();
    const sessionId = req.params.id;
    const token = extractTokenFromRequest(req);
    let userId = req.query?.userId || req.body?.userId || req.headers?.['x-user-id'] || null;

    if (!userId && token) {
      try {
        const verified = verifySessionToken(db, token);
        userId = verified.user.id;
      } catch {
        // Allow deletion by sessionId if valid
      }
    }

    const result = deleteUserSessionById(db, sessionId, userId);
    return res.status(200).json({
      success: true,
      message: 'Sesi perangkat berhasil dihapus.',
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'DELETE_SESSION_FAILED',
      error: err.message || 'Gagal menghapus sesi perangkat.',
    });
  }
}

/**
 * DELETE /api/auth/sessions & POST /api/auth/sessions/clear
 * Menghapus semua sesi pengguna atau membersihkan sesi kedaluwarsa
 */
export async function clearUserSessionsHandler(req, res) {
  try {
    const db = getDatabase();
    const token = extractTokenFromRequest(req);
    const body = req.body || {};
    const query = req.query || {};

    if (body.expiredOnly || query.expiredOnly === 'true') {
      const cleaned = cleanupExpiredSessions(db);
      return res.status(200).json({
        success: true,
        message: 'Sesi kedaluwarsa dan dicabut berhasil dibersihkan.',
        data: cleaned,
        ...cleaned,
      });
    }

    let userId = body.userId ?? query.userId ?? req.headers?.['x-user-id'];
    if (!userId && token) {
      const verified = verifySessionToken(db, token);
      userId = verified.user.id;
    }

    if (!userId) {
      return res.status(400).json({
        success: false,
        code: 'USER_ID_OR_TOKEN_REQUIRED',
        error: 'Token sesi atau userId wajib disertakan untuk menghapus sesi.',
      });
    }

    const keepCurrent = Boolean(body.keepCurrent || query.keepCurrent === 'true');
    const result = deleteAllUserSessions(db, userId, {
      exceptToken: keepCurrent && token ? token : null,
    });

    return res.status(200).json({
      success: true,
      message: 'Seluruh sesi pengguna berhasil dihapus.',
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'CLEAR_SESSIONS_FAILED',
      error: err.message || 'Gagal menghapus sesi pengguna.',
    });
  }
}

/**
 * GET /api/auth/sessions & GET /api/auth/tokens
 * Mengambil daftar sesi aktif milik pengguna
 */
export async function listSessionsHandler(req, res) {
  try {
    const db = getDatabase();
    const token = extractTokenFromRequest(req);
    let userId = req.query?.userId ? Number(req.query.userId) : null;

    if (!userId && token) {
      const { user } = verifySessionToken(db, token);
      userId = user.id;
    }

    if (!userId || isNaN(userId) || userId <= 0) {
      return res.status(401).json({
        success: false,
        code: 'AUTH_REQUIRED',
        error: 'Token sesi atau userId wajib disertakan.',
      });
    }

    const sessions = getUserActiveSessions(db, userId);
    return res.status(200).json({
      success: true,
      count: sessions.length,
      data: sessions,
      sessions,
    });
  } catch (err) {
    const status = err.statusCode || 401;
    return res.status(status).json({
      success: false,
      code: err.code || 'SESSIONS_FETCH_FAILED',
      error: err.message || 'Gagal mengambil daftar sesi aktif.',
    });
  }
}
