/**
 * Auth & User Account Routes (Rute Endpoint Autentikasi, Akun, PIN, Biometrik & Preferensi)
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
 * - GET /security, /security/status (status keamanan PIN & biometrik)
 * - POST & PUT /pin/setup, /pin (buat / atur PIN baru)
 * - POST /pin/verify, /pin/unlock (verifikasi PIN untuk membuka kunci)
 * - PUT, POST & PATCH /pin/change, /pin/ubah (ubah PIN lama ke PIN baru)
 * - POST, PUT & PATCH /pin/toggle (aktifkan/nonaktifkan kunci PIN)
 * - POST, PUT & PATCH /biometric/toggle, /biometric (aktifkan/nonaktifkan biometrik)
 * - POST /biometric/verify, /biometric/unlock (verifikasi autentikasi biometrik)
 * - GET, PUT, PATCH & POST /preferences, /preferensi, /profile, /profil, /settings, /pengaturan (preferensi aplikasi & profil pengguna)
 * - POST & DELETE /preferences/reset, /preferensi/reset (reset preferensi ke nilai bawaan)
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
  getSecurityStatusHandler,
  setupPinHandler,
  verifyPinHandler,
  changePinHandler,
  togglePinHandler,
  toggleBiometricHandler,
  verifyBiometricHandler,
  getUserPreferencesHandler,
  updateUserPreferencesHandler,
  resetUserPreferencesHandler,
  getAccountSyncHandler,
  syncAccountRecordsHandler,
  exportAccountDataHandler,
  resetAccountRecordsHandler,
} from '../controllers/authController.js';

const router = Router();
export const preferencesRouter = Router();
export const syncRouter = Router();

// Dedicated Account Sync Router (mounted at /sync, /api/sync, /sinkronisasi, /api/sinkronisasi)
syncRouter.get('/', getAccountSyncHandler);
syncRouter.get('/snapshot', getAccountSyncHandler);
syncRouter.get('/pull', getAccountSyncHandler);
syncRouter.post('/', syncAccountRecordsHandler);
syncRouter.put('/', syncAccountRecordsHandler);
syncRouter.post('/push', syncAccountRecordsHandler);
syncRouter.put('/push', syncAccountRecordsHandler);
syncRouter.get('/export', exportAccountDataHandler);
syncRouter.post('/export', exportAccountDataHandler);
syncRouter.get('/ekspor', exportAccountDataHandler);
syncRouter.post('/ekspor', exportAccountDataHandler);
syncRouter.post('/reset', resetAccountRecordsHandler);
syncRouter.delete('/reset', resetAccountRecordsHandler);
syncRouter.delete('/', resetAccountRecordsHandler);
syncRouter.post('/reset-data', resetAccountRecordsHandler);
syncRouter.delete('/reset-data', resetAccountRecordsHandler);

// Dedicated Preferences Router (mounted at /preferences, /api/preferences, /preferensi, /api/preferensi, /settings, /api/settings, /pengaturan, /api/pengaturan)
preferencesRouter.get('/', getUserPreferencesHandler);
preferencesRouter.put('/', updateUserPreferencesHandler);
preferencesRouter.patch('/', updateUserPreferencesHandler);
preferencesRouter.post('/', updateUserPreferencesHandler);
preferencesRouter.post('/reset', resetUserPreferencesHandler);
preferencesRouter.delete('/reset', resetUserPreferencesHandler);
preferencesRouter.delete('/', resetUserPreferencesHandler);
preferencesRouter.get('/sync', getAccountSyncHandler);
preferencesRouter.post('/sync', syncAccountRecordsHandler);
preferencesRouter.put('/sync', syncAccountRecordsHandler);
preferencesRouter.get('/export', exportAccountDataHandler);
preferencesRouter.post('/export', exportAccountDataHandler);
preferencesRouter.post('/reset-data', resetAccountRecordsHandler);
preferencesRouter.delete('/reset-data', resetAccountRecordsHandler);
preferencesRouter.put('/theme', updateUserPreferencesHandler);
preferencesRouter.patch('/theme', updateUserPreferencesHandler);
preferencesRouter.put('/tema', updateUserPreferencesHandler);
preferencesRouter.patch('/tema', updateUserPreferencesHandler);
preferencesRouter.put('/currency', updateUserPreferencesHandler);
preferencesRouter.patch('/currency', updateUserPreferencesHandler);
preferencesRouter.put('/mata-uang', updateUserPreferencesHandler);
preferencesRouter.patch('/mata-uang', updateUserPreferencesHandler);
preferencesRouter.put('/ai-tone', updateUserPreferencesHandler);
preferencesRouter.patch('/ai-tone', updateUserPreferencesHandler);
preferencesRouter.put('/gaya-bahasa', updateUserPreferencesHandler);
preferencesRouter.patch('/gaya-bahasa', updateUserPreferencesHandler);

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

// Keamanan PIN & Biometrik
router.get('/security', getSecurityStatusHandler);
router.get('/security/status', getSecurityStatusHandler);
router.get('/status', getSecurityStatusHandler);
router.get('/keamanan', getSecurityStatusHandler);

router.post('/pin/setup', setupPinHandler);
router.put('/pin/setup', setupPinHandler);
router.post('/pin', setupPinHandler);
router.put('/pin', setupPinHandler);

router.post('/pin/verify', verifyPinHandler);
router.post('/pin/unlock', verifyPinHandler);
router.post('/pin/verifikasi', verifyPinHandler);

router.put('/pin/change', changePinHandler);
router.post('/pin/change', changePinHandler);
router.patch('/pin/change', changePinHandler);
router.put('/pin/ubah', changePinHandler);
router.post('/pin/ubah', changePinHandler);

router.post('/pin/toggle', togglePinHandler);
router.put('/pin/toggle', togglePinHandler);
router.patch('/pin/toggle', togglePinHandler);

router.post('/biometric/toggle', toggleBiometricHandler);
router.put('/biometric/toggle', toggleBiometricHandler);
router.patch('/biometric/toggle', toggleBiometricHandler);
router.post('/biometric', toggleBiometricHandler);
router.put('/biometric', toggleBiometricHandler);
router.patch('/biometric', toggleBiometricHandler);
router.post('/biometrik/toggle', toggleBiometricHandler);

router.post('/biometric/verify', verifyBiometricHandler);
router.post('/biometric/unlock', verifyBiometricHandler);
router.post('/biometrik/verifikasi', verifyBiometricHandler);

// Preferensi Aplikasi & Profil Pengguna
router.get('/preferences', getUserPreferencesHandler);
router.put('/preferences', updateUserPreferencesHandler);
router.patch('/preferences', updateUserPreferencesHandler);
router.post('/preferences', updateUserPreferencesHandler);
router.post('/preferences/reset', resetUserPreferencesHandler);
router.delete('/preferences/reset', resetUserPreferencesHandler);

router.get('/preferensi', getUserPreferencesHandler);
router.put('/preferensi', updateUserPreferencesHandler);
router.patch('/preferensi', updateUserPreferencesHandler);
router.post('/preferensi', updateUserPreferencesHandler);
router.post('/preferensi/reset', resetUserPreferencesHandler);
router.delete('/preferensi/reset', resetUserPreferencesHandler);

router.get('/profile', getUserPreferencesHandler);
router.put('/profile', updateUserPreferencesHandler);
router.patch('/profile', updateUserPreferencesHandler);
router.post('/profile', updateUserPreferencesHandler);

router.get('/profil', getUserPreferencesHandler);
router.put('/profil', updateUserPreferencesHandler);
router.patch('/profil', updateUserPreferencesHandler);
router.post('/profil', updateUserPreferencesHandler);

router.get('/settings', getUserPreferencesHandler);
router.put('/settings', updateUserPreferencesHandler);
router.patch('/settings', updateUserPreferencesHandler);
router.post('/settings', updateUserPreferencesHandler);

router.get('/pengaturan', getUserPreferencesHandler);
router.put('/pengaturan', updateUserPreferencesHandler);
router.patch('/pengaturan', updateUserPreferencesHandler);
router.post('/pengaturan', updateUserPreferencesHandler);

// Sinkronisasi Catatan, Ekspor Data & Reset Data Per Akun
router.get('/sync', getAccountSyncHandler);
router.post('/sync', syncAccountRecordsHandler);
router.put('/sync', syncAccountRecordsHandler);
router.get('/sinkronisasi', getAccountSyncHandler);
router.post('/sinkronisasi', syncAccountRecordsHandler);
router.put('/sinkronisasi', syncAccountRecordsHandler);

router.get('/export', exportAccountDataHandler);
router.post('/export', exportAccountDataHandler);
router.get('/ekspor', exportAccountDataHandler);
router.post('/ekspor', exportAccountDataHandler);

router.post('/reset-data', resetAccountRecordsHandler);
router.delete('/reset-data', resetAccountRecordsHandler);
router.post('/sync/reset', resetAccountRecordsHandler);
router.delete('/sync/reset', resetAccountRecordsHandler);
router.post('/hapus-data', resetAccountRecordsHandler);
router.delete('/hapus-data', resetAccountRecordsHandler);

export default router;

