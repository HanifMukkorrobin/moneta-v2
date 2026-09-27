/**
 * Auth & User Account Routes (Rute Endpoint Autentikasi, Akun & Pengaturan)
 *
 * Menyediakan endpoint:
 * - POST /register, /daftar, /signup (registrasi akun pengguna baru)
 * - POST /login, /masuk, /signin (login akun & pembuatan token sesi)
 * - GET & POST /verify, /me, /session (verifikasi token sesi aktif)
 * - POST /refresh, /token/refresh (perbarui / rotasi token sesi)
 * - POST & DELETE /logout, /keluar, /session (keluar & cabut token sesi)
 * - GET /sessions, /tokens (daftar sesi aktif pengguna)
 */

import { Router } from 'express';
import {
  registerUserHandler,
  loginUserHandler,
  verifyTokenHandler,
  refreshTokenHandler,
  logoutUserHandler,
  listSessionsHandler,
} from '../controllers/authController.js';

const router = Router();

// Registrasi akun baru
router.post('/register', registerUserHandler);
router.post('/daftar', registerUserHandler);
router.post('/signup', registerUserHandler);
router.post('/', registerUserHandler);

// Login & kelola token sesi
router.post('/login', loginUserHandler);
router.post('/masuk', loginUserHandler);
router.post('/signin', loginUserHandler);

// Verifikasi token sesi aktif
router.get('/verify', verifyTokenHandler);
router.post('/verify', verifyTokenHandler);
router.get('/me', verifyTokenHandler);
router.get('/session', verifyTokenHandler);

// Perbarui / rotasi token sesi
router.post('/refresh', refreshTokenHandler);
router.post('/token/refresh', refreshTokenHandler);

// Keluar / cabut token sesi
router.post('/logout', logoutUserHandler);
router.post('/keluar', logoutUserHandler);
router.delete('/session', logoutUserHandler);

// Daftar sesi aktif pengguna
router.get('/sessions', listSessionsHandler);
router.get('/tokens', listSessionsHandler);

export default router;
