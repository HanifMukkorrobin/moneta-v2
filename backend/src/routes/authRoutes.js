/**
 * Auth & User Account Routes (Rute Endpoint Autentikasi, Akun & Pengaturan)
 *
 * Menyediakan endpoint:
 * - POST /register, /daftar, /signup (registrasi akun pengguna baru)
 * - POST /login, /masuk, /signin (login akun & pembuatan token sesi)
 * - GET & POST /verify, /me, /session (verifikasi token sesi aktif)
 * - POST /refresh, /token/refresh (perbarui / rotasi token sesi)
 * - POST & DELETE /logout, /keluar, /session, /sesi, /hapus-sesi (keluar & cabut/hapus sesi)
 * - DELETE /sessions/:id, /tokens/:id, /sesi/:id (hapus satu sesi perangkat)
 * - DELETE /sessions, /sesi & POST /sessions/clear (hapus seluruh sesi / bersihkan kedaluwarsa)
 * - GET /sessions, /tokens, /sesi (daftar sesi aktif pengguna)
 */

import { Router } from 'express';
import {
  registerUserHandler,
  loginUserHandler,
  verifyTokenHandler,
  refreshTokenHandler,
  logoutUserHandler,
  deleteSessionByIdHandler,
  clearUserSessionsHandler,
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

// Keluar & hapus/cabut token sesi
router.post('/logout', logoutUserHandler);
router.delete('/logout', logoutUserHandler);
router.post('/keluar', logoutUserHandler);
router.delete('/keluar', logoutUserHandler);
router.delete('/session', logoutUserHandler);
router.delete('/sesi', logoutUserHandler);
router.post('/hapus-sesi', logoutUserHandler);

// Hapus satu sesi perangkat berdasarkan ID
router.delete('/sessions/:id', deleteSessionByIdHandler);
router.delete('/tokens/:id', deleteSessionByIdHandler);
router.delete('/sesi/:id', deleteSessionByIdHandler);

// Hapus seluruh sesi pengguna / bersihkan sesi kedaluwarsa
router.delete('/sessions', clearUserSessionsHandler);
router.post('/sessions/clear', clearUserSessionsHandler);
router.post('/sesi/hapus-semua', clearUserSessionsHandler);

// Daftar sesi aktif pengguna
router.get('/sessions', listSessionsHandler);
router.get('/tokens', listSessionsHandler);
router.get('/sesi', listSessionsHandler);

export default router;
