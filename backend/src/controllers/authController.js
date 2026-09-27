/**
 * Auth & User Account Controller (Controller Autentikasi, Akun & Pengaturan)
 *
 * Mengelola endpoint HTTP untuk:
 * - POST /api/auth/register (registrasi akun pengguna baru)
 */

import { getDatabase } from '../config/database.js';
import { registerUser } from '../services/userService.js';

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
