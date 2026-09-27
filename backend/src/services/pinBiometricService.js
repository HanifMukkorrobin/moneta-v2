/**
 * PIN & Biometric Security Service (Layanan Keamanan Kunci PIN & Biometrik)
 *
 * Mengelola:
 * - Pembuatan / pengaturan PIN baru (setupPin)
 * - Verifikasi PIN untuk membuka kunci aplikasi (verifyPin)
 * - Perubahan PIN lama ke PIN baru (changePin)
 * - Aktivasi / penonaktifan kunci PIN (togglePinLock)
 * - Aktivasi / penonaktifan autentikasi biometrik (toggleBiometric)
 * - Verifikasi autentikasi biometrik perangkat (verifyBiometric)
 * - Status pengaturan keamanan pengguna (getSecurityStatus)
 */

import { hashSecret, verifySecret, getUserById } from './userService.js';

export function isValidPinFormat(pin) {
  if (pin === undefined || pin === null) return false;
  const str = String(pin).trim();
  return /^\d{4,6}$/.test(str);
}

function getRawUserOrThrow(db, userId) {
  const numId = Number(userId);
  if (!numId || isNaN(numId) || numId <= 0) {
    const err = new Error('ID pengguna tidak valid.');
    err.statusCode = 400;
    err.code = 'INVALID_USER_ID';
    throw err;
  }

  const row = db.prepare('SELECT * FROM users WHERE id = ?').get(numId);
  if (!row) {
    const err = new Error('Pengguna tidak ditemukan.');
    err.statusCode = 404;
    err.code = 'USER_NOT_FOUND';
    throw err;
  }

  return row;
}

export function getSecurityStatus(db, userId) {
  const row = getRawUserOrThrow(db, userId);
  const user = getUserById(db, row.id);

  return {
    userId: row.id,
    pinEnabled: Boolean(row.pin_enabled),
    hasPin: Boolean(row.pin_hash),
    biometricEnabled: Boolean(row.biometric_enabled),
    user,
  };
}

export function setupPin(db, userId, payload = {}) {
  const row = getRawUserOrThrow(db, userId);
  const rawPin = payload.pin ?? payload.newPin ?? payload.pinCode ?? payload.pin_code;

  if (rawPin === undefined || rawPin === null || String(rawPin).trim() === '') {
    const err = new Error('PIN wajib diisi.');
    err.statusCode = 400;
    err.code = 'PIN_REQUIRED';
    throw err;
  }

  const pinStr = String(rawPin).trim();
  if (!isValidPinFormat(pinStr)) {
    const err = new Error('PIN harus berupa 4 hingga 6 digit angka.');
    err.statusCode = 400;
    err.code = 'INVALID_PIN_FORMAT';
    throw err;
  }

  const rawConfirm = payload.confirmPin ?? payload.confirm_pin ?? payload.konfirmasiPin;
  if (rawConfirm !== undefined && rawConfirm !== null && String(rawConfirm).trim() !== pinStr) {
    const err = new Error('Konfirmasi PIN tidak cocok.');
    err.statusCode = 400;
    err.code = 'PIN_MISMATCH';
    throw err;
  }

  const pinHash = hashSecret(pinStr);
  const enabled = payload.enabled === undefined ? 1 : (payload.enabled ? 1 : 0);

  db.prepare(`
    UPDATE users
    SET pin_hash = ?, pin_enabled = ?, updated_at = CURRENT_TIMESTAMP
    WHERE id = ?
  `).run(pinHash, enabled, row.id);

  const user = getUserById(db, row.id);
  return {
    success: true,
    pinEnabled: Boolean(enabled),
    hasPin: true,
    user,
  };
}

export function verifyPin(db, userId, pinInput) {
  const row = getRawUserOrThrow(db, userId);
  const rawPin =
    typeof pinInput === 'object' && pinInput !== null
      ? (pinInput.pin ?? pinInput.pinCode ?? pinInput.pin_code)
      : pinInput;

  if (rawPin === undefined || rawPin === null || String(rawPin).trim() === '') {
    const err = new Error('PIN wajib dimasukkan untuk verifikasi.');
    err.statusCode = 400;
    err.code = 'PIN_REQUIRED';
    throw err;
  }

  const pinStr = String(rawPin).trim();
  if (!isValidPinFormat(pinStr)) {
    const err = new Error('Format PIN tidak valid (harus 4-6 digit angka).');
    err.statusCode = 400;
    err.code = 'INVALID_PIN_FORMAT';
    throw err;
  }

  if (!row.pin_hash) {
    const err = new Error('PIN keamanan belum diatur untuk akun ini.');
    err.statusCode = 400;
    err.code = 'PIN_NOT_SET';
    throw err;
  }

  const matched = verifySecret(pinStr, row.pin_hash);
  if (!matched) {
    const err = new Error('PIN salah. Silakan coba lagi.');
    err.statusCode = 401;
    err.code = 'INVALID_PIN';
    throw err;
  }

  const user = getUserById(db, row.id);
  return {
    valid: true,
    unlocked: true,
    method: 'pin',
    user,
  };
}

export function changePin(db, userId, payload = {}) {
  const row = getRawUserOrThrow(db, userId);

  const oldPin = payload.oldPin ?? payload.old_pin ?? payload.currentPin ?? payload.pinLama;
  const newPin = payload.newPin ?? payload.new_pin ?? payload.pinBaru ?? payload.pin;
  const confirmNewPin =
    payload.confirmNewPin ??
    payload.confirm_new_pin ??
    payload.confirmPin ??
    payload.konfirmasiPinBaru;

  if (row.pin_hash) {
    if (oldPin === undefined || oldPin === null || String(oldPin).trim() === '') {
      const err = new Error('PIN lama wajib diisi.');
      err.statusCode = 400;
      err.code = 'OLD_PIN_REQUIRED';
      throw err;
    }

    const oldMatched = verifySecret(String(oldPin).trim(), row.pin_hash);
    if (!oldMatched) {
      const err = new Error('PIN lama salah.');
      err.statusCode = 401;
      err.code = 'INVALID_OLD_PIN';
      throw err;
    }
  }

  if (newPin === undefined || newPin === null || String(newPin).trim() === '') {
    const err = new Error('PIN baru wajib diisi.');
    err.statusCode = 400;
    err.code = 'NEW_PIN_REQUIRED';
    throw err;
  }

  const newPinStr = String(newPin).trim();
  if (!isValidPinFormat(newPinStr)) {
    const err = new Error('PIN baru harus berupa 4 hingga 6 digit angka.');
    err.statusCode = 400;
    err.code = 'INVALID_PIN_FORMAT';
    throw err;
  }

  if (
    confirmNewPin !== undefined &&
    confirmNewPin !== null &&
    String(confirmNewPin).trim() !== newPinStr
  ) {
    const err = new Error('Konfirmasi PIN baru tidak cocok.');
    err.statusCode = 400;
    err.code = 'PIN_MISMATCH';
    throw err;
  }

  const newHash = hashSecret(newPinStr);
  db.prepare(`
    UPDATE users
    SET pin_hash = ?, pin_enabled = 1, updated_at = CURRENT_TIMESTAMP
    WHERE id = ?
  `).run(newHash, row.id);

  const user = getUserById(db, row.id);
  return {
    success: true,
    pinChanged: true,
    pinEnabled: true,
    user,
  };
}

export function togglePinLock(db, userId, payload = {}) {
  const row = getRawUserOrThrow(db, userId);

  const rawEnabled =
    payload.enabled !== undefined
      ? payload.enabled
      : (payload.pinEnabled !== undefined ? payload.pinEnabled : payload.pin_enabled);

  if (rawEnabled === undefined || rawEnabled === null) {
    const err = new Error('Status enabled (true/false) wajib disertakan.');
    err.statusCode = 400;
    err.code = 'ENABLED_REQUIRED';
    throw err;
  }

  const enabled = Boolean(rawEnabled);
  const rawPin = payload.pin ?? payload.pinCode ?? payload.pin_code;

  let nextPinHash = row.pin_hash;
  if (rawPin !== undefined && rawPin !== null && String(rawPin).trim() !== '') {
    const pinStr = String(rawPin).trim();
    if (!isValidPinFormat(pinStr)) {
      const err = new Error('PIN harus berupa 4 hingga 6 digit angka.');
      err.statusCode = 400;
      err.code = 'INVALID_PIN_FORMAT';
      throw err;
    }
    nextPinHash = hashSecret(pinStr);
  } else if (enabled && !nextPinHash) {
    // Default fallback PIN '1234' when enabling without prior PIN (matches Flutter AppState.togglePin)
    nextPinHash = hashSecret('1234');
  }

  if (!enabled && payload.clearPin) {
    nextPinHash = null;
  }

  db.prepare(`
    UPDATE users
    SET pin_enabled = ?, pin_hash = ?, updated_at = CURRENT_TIMESTAMP
    WHERE id = ?
  `).run(enabled ? 1 : 0, nextPinHash, row.id);

  const user = getUserById(db, row.id);
  return {
    success: true,
    pinEnabled: enabled,
    hasPin: Boolean(nextPinHash),
    user,
  };
}

export function toggleBiometric(db, userId, payload = {}) {
  const row = getRawUserOrThrow(db, userId);

  const rawEnabled =
    payload.enabled !== undefined
      ? payload.enabled
      : (payload.biometricEnabled !== undefined
          ? payload.biometricEnabled
          : payload.biometric_enabled);

  if (rawEnabled === undefined || rawEnabled === null) {
    const err = new Error('Status biometrik enabled (true/false) wajib disertakan.');
    err.statusCode = 400;
    err.code = 'ENABLED_REQUIRED';
    throw err;
  }

  const enabled = Boolean(rawEnabled);
  db.prepare(`
    UPDATE users
    SET biometric_enabled = ?, updated_at = CURRENT_TIMESTAMP
    WHERE id = ?
  `).run(enabled ? 1 : 0, row.id);

  const user = getUserById(db, row.id);
  return {
    success: true,
    biometricEnabled: enabled,
    user,
  };
}

export function verifyBiometric(db, userId, payload = {}) {
  const row = getRawUserOrThrow(db, userId);

  if (!row.biometric_enabled && payload.strict !== false) {
    const err = new Error('Autentikasi biometrik belum diaktifkan pada akun ini.');
    err.statusCode = 403;
    err.code = 'BIOMETRIC_DISABLED';
    throw err;
  }

  if (payload.verified === false || payload.biometricToken === 'invalid') {
    const err = new Error('Verifikasi sensor biometrik gagal atau ditolak perangkat.');
    err.statusCode = 401;
    err.code = 'BIOMETRIC_VERIFICATION_FAILED';
    throw err;
  }

  const sensorType = payload.sensorType || payload.sensor_type || 'fingerprint';
  const user = getUserById(db, row.id);

  return {
    valid: true,
    unlocked: true,
    method: 'biometric',
    sensorType,
    biometricEnabled: Boolean(row.biometric_enabled),
    user,
  };
}
