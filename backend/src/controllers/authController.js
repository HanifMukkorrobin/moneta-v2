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
 * - PIN & Biometric Security endpoints (/pin/setup, /pin/verify, /pin/change, /pin/toggle, /biometric/toggle, /biometric/verify)
 */

import { getDatabase } from '../config/database.js';
import { getOrCreateDefaultUser } from './chatController.js';
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
  getUserPreferences,
  updateUserPreferences,
  resetUserPreferences,
} from '../services/userService.js';
import {
  getSecurityStatus,
  setupPin,
  verifyPin,
  changePin,
  togglePinLock,
  toggleBiometric,
  verifyBiometric,
} from '../services/pinBiometricService.js';
import {
  getAccountSyncSnapshot,
  syncAccountRecords,
  exportAccountData,
  resetAccountRecords,
} from '../services/accountSyncService.js';

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
 * Helper untuk mendapatkan userId dari token sesi, parameter userId, atau user default
 */
export function resolveUserIdFromAuthOrRequest(db, req) {
  const rawId = req.params?.userId || req.query?.userId || req.headers?.['x-user-id'] || req.body?.userId;
  if (rawId !== undefined && rawId !== null && rawId !== '') {
    const num = Number(rawId);
    if (isNaN(num) || num <= 0 || !Number.isInteger(num)) {
      const err = new Error('Parameter userId harus berupa bilangan bulat positif.');
      err.statusCode = 400;
      err.code = 'INVALID_USER_ID';
      throw err;
    }
    return num;
  }

  const token = extractTokenFromRequest(req);
  if (token) {
    const verified = verifySessionToken(db, token);
    return verified.user.id;
  }

  return getOrCreateDefaultUser(db);
}

/**
 * Middleware opsional untuk mengisolasi dan menyinkronkan userId per akun berdasarkan
 * token sesi aktif atau header x-user-id pada seluruh endpoint aplikasi.
 */
export function attachAuthUserMiddleware(req, res, next) {
  try {
    const explicitUserId = req.query?.userId || req.body?.userId || req.headers?.['x-user-id'];
    if (explicitUserId !== undefined && explicitUserId !== null && explicitUserId !== '') {
      const num = Number(explicitUserId);
      if (!isNaN(num) && num > 0 && Number.isInteger(num)) {
        req.userId = num;
        if (req.query && req.query.userId === undefined) {
          req.query.userId = String(num);
        }
        if (req.body && typeof req.body === 'object' && req.body.userId === undefined) {
          req.body.userId = num;
        }
      }
      return next();
    }

    const headerToken = extractTokenFromRequest({
      headers: req.headers,
      query: {},
      body: {},
    });

    if (headerToken) {
      const db = getDatabase();
      const verified = verifySessionToken(db, headerToken);
      if (verified?.user?.id) {
        const resolvedId = verified.user.id;
        req.userId = resolvedId;
        req.authUser = verified.user;
        req.headers['x-user-id'] = String(resolvedId);
        if (req.query && req.query.userId === undefined) {
          req.query.userId = String(resolvedId);
        }
        if (req.body && typeof req.body === 'object' && req.body.userId === undefined) {
          req.body.userId = resolvedId;
        }
      }
    }
  } catch {
    // Abaikan error token di middleware opsional agar handler spesifik menangani validasi bila diperlukan
  }
  return next();
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

/**
 * GET /api/auth/security & GET /api/security/status
 * Mengambil status keamanan PIN & biometrik pengguna
 */
export async function getSecurityStatusHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const status = getSecurityStatus(db, userId);

    return res.status(200).json({
      success: true,
      data: status,
      ...status,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'SECURITY_STATUS_FAILED',
      error: err.message || 'Gagal mengambil status keamanan.',
    });
  }
}

/**
 * POST & PUT /api/auth/pin/setup, /api/auth/pin
 * Mengatur PIN baru untuk akun pengguna
 */
export async function setupPinHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const result = setupPin(db, userId, req.body || {});

    return res.status(200).json({
      success: true,
      message: 'PIN keamanan berhasil dibuat!',
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'PIN_SETUP_FAILED',
      error: err.message || 'Gagal mengatur PIN keamanan.',
    });
  }
}

/**
 * POST /api/auth/pin/verify
 * Memverifikasi PIN untuk membuka kunci aplikasi
 */
export async function verifyPinHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const result = verifyPin(db, userId, req.body || {});

    return res.status(200).json({
      success: true,
      message: 'Kunci PIN berhasil dibuka!',
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 401;
    return res.status(status).json({
      success: false,
      valid: false,
      unlocked: false,
      code: err.code || 'PIN_VERIFY_FAILED',
      error: err.message || 'Verifikasi PIN gagal.',
    });
  }
}

/**
 * PUT & POST /api/auth/pin/change
 * Mengubah PIN lama menjadi PIN baru
 */
export async function changePinHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const result = changePin(db, userId, req.body || {});

    return res.status(200).json({
      success: true,
      message: 'PIN keamanan berhasil diubah!',
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'PIN_CHANGE_FAILED',
      error: err.message || 'Gagal mengubah PIN keamanan.',
    });
  }
}

/**
 * POST, PUT & PATCH /api/auth/pin/toggle
 * Mengaktifkan atau menonaktifkan kunci PIN aplikasi
 */
export async function togglePinHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const result = togglePinLock(db, userId, req.body || {});

    return res.status(200).json({
      success: true,
      message: result.pinEnabled
        ? 'Kunci PIN aplikasi diaktifkan.'
        : 'Kunci PIN aplikasi dinonaktifkan.',
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'PIN_TOGGLE_FAILED',
      error: err.message || 'Gagal mengubah status kunci PIN.',
    });
  }
}

/**
 * POST, PUT & PATCH /api/auth/biometric/toggle, /api/auth/biometric
 * Mengaktifkan atau menonaktifkan autentikasi biometrik perangkat
 */
export async function toggleBiometricHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const result = toggleBiometric(db, userId, req.body || {});

    return res.status(200).json({
      success: true,
      message: result.biometricEnabled
        ? 'Biometrik diaktifkan.'
        : 'Biometrik dinonaktifkan.',
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'BIOMETRIC_TOGGLE_FAILED',
      error: err.message || 'Gagal mengubah status biometrik.',
    });
  }
}

/**
 * POST /api/auth/biometric/verify
 * Memverifikasi autentikasi biometrik perangkat untuk membuka kunci
 */
export async function verifyBiometricHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const result = verifyBiometric(db, userId, req.body || {});

    return res.status(200).json({
      success: true,
      message: 'Autentikasi biometrik berhasil!',
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 401;
    return res.status(status).json({
      success: false,
      valid: false,
      unlocked: false,
      code: err.code || 'BIOMETRIC_VERIFY_FAILED',
      error: err.message || 'Verifikasi biometrik gagal.',
    });
  }
}

/**
 * GET /api/preferences, /api/preferensi, /api/auth/preferences, /api/users/profile
 * Mengambil preferensi aplikasi & profil pengguna
 */
export async function getUserPreferencesHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const result = getUserPreferences(db, userId);

    return res.status(200).json({
      success: true,
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'PREFERENCES_FETCH_FAILED',
      error: err.message || 'Gagal mengambil preferensi aplikasi pengguna.',
    });
  }
}

/**
 * PUT, PATCH & POST /api/preferences, /api/preferensi, /api/auth/preferences, /api/users/profile
 * Memperbarui preferensi aplikasi & profil pengguna
 */
export async function updateUserPreferencesHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const result = updateUserPreferences(db, userId, req.body || {});

    return res.status(200).json({
      success: true,
      message: 'Preferensi aplikasi berhasil diperbarui.',
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'PREFERENCES_UPDATE_FAILED',
      error: err.message || 'Gagal memperbarui preferensi aplikasi pengguna.',
    });
  }
}

/**
 * POST & DELETE /api/preferences/reset, /api/preferensi/reset
 * Mengembalikan preferensi aplikasi pengguna ke nilai bawaan (default)
 */
export async function resetUserPreferencesHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const result = resetUserPreferences(db, userId);

    return res.status(200).json({
      success: true,
      message: 'Preferensi aplikasi dikembalikan ke pengaturan default.',
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'PREFERENCES_RESET_FAILED',
      error: err.message || 'Gagal mengembalikan preferensi ke pengaturan default.',
    });
  }
}

/**
 * GET /api/sync, /api/sinkronisasi, /api/auth/sync, /api/users/sync
 * Mengambil snapshot sinkronisasi seluruh catatan milik akun pengguna
 */
export async function getAccountSyncHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const snapshot = getAccountSyncSnapshot(db, userId, req.query || {});

    return res.status(200).json({
      success: true,
      message: 'Data catatan akun berhasil disinkronkan.',
      data: snapshot,
      ...snapshot,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'ACCOUNT_SYNC_FETCH_FAILED',
      error: err.message || 'Gagal mengambil data sinkronisasi akun.',
    });
  }
}

/**
 * POST & PUT /api/sync, /api/sinkronisasi, /api/auth/sync, /api/users/sync
 * Menyinkronkan catatan (push/merge/replace) milik akun pengguna
 */
export async function syncAccountRecordsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const result = syncAccountRecords(db, userId, req.body || {});

    return res.status(200).json({
      success: true,
      message: 'Sinkronisasi catatan akun berhasil diproses.',
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'ACCOUNT_SYNC_PUSH_FAILED',
      error: err.message || 'Gagal menyinkronkan catatan akun.',
    });
  }
}

/**
 * GET & POST /api/sync/export, /api/auth/export, /api/users/export, /api/preferences/export
 * Mengekspor seluruh catatan akun pengguna dalam format JSON atau CSV
 */
export async function exportAccountDataHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const format = req.query?.format || req.body?.format || 'json';
    const exported = exportAccountData(db, userId, { format });

    return res.status(200).json({
      success: true,
      message: `Data akun berhasil diekspor dalam format ${exported.format.toUpperCase()}.`,
      data: exported,
      ...exported,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'ACCOUNT_EXPORT_FAILED',
      error: err.message || 'Gagal mengekspor data akun.',
    });
  }
}

/**
 * POST & DELETE /api/sync/reset, /api/auth/reset-data, /api/users/reset-data
 * Menghapus / mereset seluruh catatan keuangan milik satu akun pengguna tanpa memengaruhi akun lain
 */
export async function resetAccountRecordsHandler(req, res) {
  try {
    const db = getDatabase();
    const userId = resolveUserIdFromAuthOrRequest(db, req);
    const result = resetAccountRecords(db, userId, {
      ...(req.query || {}),
      ...(req.body || {}),
    });

    return res.status(200).json({
      success: true,
      message: 'Seluruh catatan keuangan akun berhasil direset.',
      data: result,
      ...result,
    });
  } catch (err) {
    const status = err.statusCode || 400;
    return res.status(status).json({
      success: false,
      code: err.code || 'ACCOUNT_RESET_FAILED',
      error: err.message || 'Gagal mereset catatan keuangan akun.',
    });
  }
}


