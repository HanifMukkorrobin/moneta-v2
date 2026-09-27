/**
 * Auth & User Account Routes (Rute Endpoint Autentikasi, Akun & Pengaturan)
 *
 * Menyediakan endpoint:
 * - POST /register (registrasi akun pengguna baru)
 * - POST /daftar (alias registrasi akun pengguna baru)
 * - POST /signup (alias registrasi akun pengguna baru)
 */

import { Router } from 'express';
import { registerUserHandler } from '../controllers/authController.js';

const router = Router();

// Registrasi akun baru
router.post('/register', registerUserHandler);
router.post('/daftar', registerUserHandler);
router.post('/signup', registerUserHandler);
router.post('/', registerUserHandler);

export default router;
