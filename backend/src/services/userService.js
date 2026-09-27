import crypto from 'node:crypto';

export const CURRENCY_SYMBOLS = {
  IDR: 'Rp',
  USD: '$',
  EUR: '€',
  SGD: 'S$',
  MYR: 'RM',
  GBP: '£',
  JPY: '¥',
  AUD: 'A$',
};

export const SUPPORTED_CURRENCIES = Object.keys(CURRENCY_SYMBOLS);

export function getCurrencySymbol(currency = 'IDR', customSymbol) {
  if (customSymbol && String(customSymbol).trim()) {
    return String(customSymbol).trim();
  }
  const code = String(currency || 'IDR').trim().toUpperCase();
  return CURRENCY_SYMBOLS[code] || code;
}

export function hashSecret(secret) {
  const salt = crypto.randomBytes(16).toString('hex');
  const derived = crypto.scryptSync(String(secret), salt, 64).toString('hex');
  return `scrypt$${salt}$${derived}`;
}

export function verifySecret(secret, storedHash) {
  if (!storedHash || typeof storedHash !== 'string') return false;
  if (storedHash.startsWith('scrypt$')) {
    const parts = storedHash.split('$');
    if (parts.length !== 3) return false;
    const [, salt, originalHash] = parts;
    const derived = crypto.scryptSync(String(secret), salt, 64).toString('hex');
    const a = Buffer.from(originalHash, 'hex');
    const b = Buffer.from(derived, 'hex');
    if (a.length !== b.length) return false;
    return crypto.timingSafeEqual(a, b);
  }
  // Fallback for plain/legacy test hashes in fixtures
  return String(secret) === storedHash;
}

export function isValidEmail(email) {
  if (!email || typeof email !== 'string') return false;
  const trimmed = email.trim();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed);
}

export function formatUserRow(row) {
  if (!row) return null;
  const currency = row.currency || 'IDR';
  const currencySymbol = row.currency_symbol || getCurrencySymbol(currency);
  const pinEnabled = Boolean(row.pin_enabled) || Boolean(row.pin_hash);

  return {
    id: row.id,
    email: row.email,
    displayName: row.display_name || 'Pengguna Moneta',
    display_name: row.display_name || 'Pengguna Moneta',
    currency,
    currencySymbol,
    currency_symbol: currencySymbol,
    pinEnabled,
    pin_enabled: pinEnabled ? 1 : 0,
    hasPin: Boolean(row.pin_hash),
    biometricEnabled: Boolean(row.biometric_enabled),
    biometric_enabled: row.biometric_enabled ? 1 : 0,
    notificationsEnabled: row.notifications_enabled === undefined ? true : Boolean(row.notifications_enabled),
    notifications_enabled: row.notifications_enabled === undefined ? 1 : (row.notifications_enabled ? 1 : 0),
    aiAdviceTone: row.ai_advice_tone || 'Standar',
    ai_advice_tone: row.ai_advice_tone || 'Standar',
    monthlyBudgetLimit: Number(row.monthly_budget_limit ?? 6000000),
    monthly_budget_limit: Number(row.monthly_budget_limit ?? 6000000),
    accountTier: row.account_tier || 'Personal AI',
    account_tier: row.account_tier || 'Personal AI',
    dateFormat: row.date_format || 'DD/MM/YYYY',
    date_format: row.date_format || 'DD/MM/YYYY',
    firstDayOfWeek: row.first_day_of_week || 'Senin',
    first_day_of_week: row.first_day_of_week || 'Senin',
    themeMode: row.theme_mode || 'Terang',
    theme_mode: row.theme_mode || 'Terang',
    hideBalance: Boolean(row.hide_balance),
    hide_balance: row.hide_balance ? 1 : 0,
    autoConfirmChat: Boolean(row.auto_confirm_chat),
    auto_confirm_chat: row.auto_confirm_chat ? 1 : 0,
    hapticFeedback: row.haptic_feedback === undefined ? true : Boolean(row.haptic_feedback),
    haptic_feedback: row.haptic_feedback === undefined ? 1 : (row.haptic_feedback ? 1 : 0),
    budgetAlertThreshold: Number(row.budget_alert_threshold ?? 80),
    budget_alert_threshold: Number(row.budget_alert_threshold ?? 80),
    phone: row.phone || null,
    avatarUrl: row.avatar_url || null,
    avatar_url: row.avatar_url || null,
    lastLoginAt: row.last_login_at || null,
    last_login_at: row.last_login_at || null,
    createdAt: row.created_at,
    created_at: row.created_at,
    updatedAt: row.updated_at || row.created_at,
    updated_at: row.updated_at || row.created_at,
  };
}

export function getUserById(db, userId) {
  const row = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
  return formatUserRow(row);
}

export function getUserByEmail(db, email) {
  if (!email) return null;
  const normalized = String(email).trim().toLowerCase();
  const row = db.prepare('SELECT * FROM users WHERE LOWER(email) = ?').get(normalized);
  return row || null;
}

export function createUserSession(db, userId, { deviceName = 'Flutter Mobile App', ipAddress = null, ttlDays = 30 } = {}) {
  const token = `mnt_${crypto.randomBytes(24).toString('hex')}`;
  const expiresAt = new Date(Date.now() + ttlDays * 24 * 60 * 60 * 1000).toISOString();

  const res = db
    .prepare(`
      INSERT INTO user_sessions (user_id, token, device_name, ip_address, expires_at, is_revoked)
      VALUES (?, ?, ?, ?, ?, 0)
    `)
    .run(userId, token, deviceName, ipAddress, expiresAt);

  return {
    id: Number(res.lastInsertRowid),
    userId: Number(userId),
    token,
    deviceName,
    ipAddress,
    expiresAt,
    isRevoked: false,
  };
}

export function registerUser(db, payload = {}) {
  const rawName =
    payload.displayName ??
    payload.display_name ??
    payload.name ??
    payload.nama ??
    payload.fullName ??
    payload.full_name;

  const displayName = rawName !== undefined && rawName !== null ? String(rawName).trim() : '';
  if (!displayName) {
    const err = new Error('Nama lengkap wajib diisi.');
    err.statusCode = 400;
    err.code = 'NAME_REQUIRED';
    throw err;
  }

  const rawEmail = payload.email !== undefined && payload.email !== null ? String(payload.email).trim().toLowerCase() : '';
  if (!rawEmail) {
    const err = new Error('Alamat email wajib diisi.');
    err.statusCode = 400;
    err.code = 'EMAIL_REQUIRED';
    throw err;
  }

  if (!isValidEmail(rawEmail)) {
    const err = new Error('Format alamat email tidak valid.');
    err.statusCode = 400;
    err.code = 'INVALID_EMAIL';
    throw err;
  }

  const rawPassword =
    payload.password ??
    payload.kataSandi ??
    payload.kata_sandi;

  if (rawPassword === undefined || rawPassword === null || String(rawPassword).length === 0) {
    const err = new Error('Kata sandi wajib diisi.');
    err.statusCode = 400;
    err.code = 'PASSWORD_REQUIRED';
    throw err;
  }

  const passwordStr = String(rawPassword);
  if (passwordStr.length < 6) {
    const err = new Error('Kata sandi minimal 6 karakter.');
    err.statusCode = 400;
    err.code = 'PASSWORD_TOO_SHORT';
    throw err;
  }

  const rawConfirm =
    payload.confirmPassword ??
    payload.confirm_password ??
    payload.konfirmasiPassword ??
    payload.konfirmasi_password;

  if (rawConfirm !== undefined && rawConfirm !== null && String(rawConfirm) !== passwordStr) {
    const err = new Error('Konfirmasi kata sandi tidak cocok.');
    err.statusCode = 400;
    err.code = 'PASSWORD_MISMATCH';
    throw err;
  }

  const existingUser = getUserByEmail(db, rawEmail);
  if (existingUser) {
    const err = new Error('Email sudah terdaftar. Silakan gunakan email lain atau masuk ke akun Anda.');
    err.statusCode = 409;
    err.code = 'EMAIL_ALREADY_EXISTS';
    throw err;
  }

  const currency = payload.currency ? String(payload.currency).trim().toUpperCase() : 'IDR';
  const currencySymbol = getCurrencySymbol(currency, payload.currencySymbol ?? payload.currency_symbol);
  const passwordHash = hashSecret(passwordStr);
  const phone = payload.phone ? String(payload.phone).trim() : null;
  const aiAdviceTone = payload.aiAdviceTone || payload.ai_advice_tone || 'Standar';
  const themeMode = payload.themeMode || payload.theme_mode || 'Terang';
  const monthlyBudgetLimit =
    payload.monthlyBudgetLimit !== undefined || payload.monthly_budget_limit !== undefined
      ? Number(payload.monthlyBudgetLimit ?? payload.monthly_budget_limit)
      : 6000000;

  if (isNaN(monthlyBudgetLimit) || monthlyBudgetLimit < 0) {
    const err = new Error('Batas budget bulanan harus berupa angka positif atau nol.');
    err.statusCode = 400;
    err.code = 'INVALID_BUDGET_LIMIT';
    throw err;
  }

  const tx = db.transaction(() => {
    const insertRes = db
      .prepare(`
        INSERT INTO users (
          email,
          password_hash,
          display_name,
          currency,
          currency_symbol,
          ai_advice_tone,
          monthly_budget_limit,
          theme_mode,
          phone,
          last_login_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      `)
      .run(
        rawEmail,
        passwordHash,
        displayName,
        currency,
        currencySymbol,
        aiAdviceTone,
        monthlyBudgetLimit,
        themeMode,
        phone
      );

    const newUserId = Number(insertRes.lastInsertRowid);
    const session = createUserSession(db, newUserId, {
      deviceName: payload.deviceName || payload.device_name || 'Flutter Mobile App',
      ipAddress: payload.ipAddress || null,
    });

    const user = getUserById(db, newUserId);
    return { user, session };
  });

  return tx();
}

export function loginUser(db, payload = {}) {
  const rawEmail =
    payload.email !== undefined && payload.email !== null
      ? String(payload.email).trim().toLowerCase()
      : '';

  if (!rawEmail) {
    const err = new Error('Alamat email wajib diisi.');
    err.statusCode = 400;
    err.code = 'EMAIL_REQUIRED';
    throw err;
  }

  if (!isValidEmail(rawEmail)) {
    const err = new Error('Format alamat email tidak valid.');
    err.statusCode = 400;
    err.code = 'INVALID_EMAIL';
    throw err;
  }

  const rawPassword =
    payload.password ??
    payload.kataSandi ??
    payload.kata_sandi;

  if (rawPassword === undefined || rawPassword === null || String(rawPassword).length === 0) {
    const err = new Error('Kata sandi wajib diisi.');
    err.statusCode = 400;
    err.code = 'PASSWORD_REQUIRED';
    throw err;
  }

  const userRow = getUserByEmail(db, rawEmail);
  if (!userRow || !userRow.password_hash) {
    const err = new Error('Email atau kata sandi salah.');
    err.statusCode = 401;
    err.code = 'INVALID_CREDENTIALS';
    throw err;
  }

  const isPasswordValid = verifySecret(String(rawPassword), userRow.password_hash);
  if (!isPasswordValid) {
    const err = new Error('Email atau kata sandi salah.');
    err.statusCode = 401;
    err.code = 'INVALID_CREDENTIALS';
    throw err;
  }

  const tx = db.transaction(() => {
    db.prepare('UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = ?').run(userRow.id);

    const session = createUserSession(db, userRow.id, {
      deviceName: payload.deviceName || payload.device_name || 'Flutter Mobile App',
      ipAddress: payload.ipAddress || null,
      ttlDays: Number(payload.ttlDays) > 0 ? Number(payload.ttlDays) : 30,
    });

    const user = getUserById(db, userRow.id);
    return { user, session };
  });

  return tx();
}

export function verifySessionToken(db, token) {
  if (!token || typeof token !== 'string' || !token.trim()) {
    const err = new Error('Token autentikasi wajib disertakan.');
    err.statusCode = 401;
    err.code = 'TOKEN_REQUIRED';
    throw err;
  }

  const cleanToken = token.trim();
  const sessionRow = db
    .prepare('SELECT * FROM user_sessions WHERE token = ?')
    .get(cleanToken);

  if (!sessionRow) {
    const err = new Error('Token sesi tidak ditemukan atau tidak valid.');
    err.statusCode = 401;
    err.code = 'INVALID_TOKEN';
    throw err;
  }

  if (sessionRow.is_revoked) {
    const err = new Error('Sesi telah berakhir atau sudah keluar (revoked).');
    err.statusCode = 401;
    err.code = 'TOKEN_REVOKED';
    throw err;
  }

  const expiresDate = new Date(sessionRow.expires_at);
  if (!isNaN(expiresDate.getTime()) && expiresDate.getTime() <= Date.now()) {
    const err = new Error('Token sesi telah kedaluwarsa.');
    err.statusCode = 401;
    err.code = 'TOKEN_EXPIRED';
    throw err;
  }

  const user = getUserById(db, sessionRow.user_id);
  if (!user) {
    const err = new Error('Pengguna pemilik sesi tidak ditemukan.');
    err.statusCode = 401;
    err.code = 'USER_NOT_FOUND';
    throw err;
  }

  return {
    user,
    session: {
      id: sessionRow.id,
      userId: sessionRow.user_id,
      token: sessionRow.token,
      deviceName: sessionRow.device_name,
      ipAddress: sessionRow.ip_address,
      expiresAt: sessionRow.expires_at,
      isRevoked: Boolean(sessionRow.is_revoked),
      createdAt: sessionRow.created_at,
    },
  };
}

export function refreshUserSession(db, token, options = {}) {
  const { user, session: oldSession } = verifySessionToken(db, token);

  const tx = db.transaction(() => {
    db.prepare('UPDATE user_sessions SET is_revoked = 1 WHERE id = ?').run(oldSession.id);

    const newSession = createUserSession(db, user.id, {
      deviceName: options.deviceName || oldSession.deviceName || 'Flutter Mobile App',
      ipAddress: options.ipAddress || oldSession.ipAddress || null,
      ttlDays: Number(options.ttlDays) > 0 ? Number(options.ttlDays) : 30,
    });

    return { user, session: newSession, revokedToken: oldSession.token };
  });

  return tx();
}

export function revokeUserSession(db, token) {
  if (!token || typeof token !== 'string' || !token.trim()) {
    const err = new Error('Token sesi wajib disertakan untuk logout.');
    err.statusCode = 400;
    err.code = 'TOKEN_REQUIRED';
    throw err;
  }

  const cleanToken = token.trim();
  const res = db
    .prepare('UPDATE user_sessions SET is_revoked = 1 WHERE token = ?')
    .run(cleanToken);

  return {
    revoked: res.changes > 0,
    token: cleanToken,
  };
}

export function revokeAllUserSessions(db, userId) {
  const res = db
    .prepare('UPDATE user_sessions SET is_revoked = 1 WHERE user_id = ? AND is_revoked = 0')
    .run(userId);

  return {
    revokedCount: res.changes,
    userId: Number(userId),
  };
}

export function getUserActiveSessions(db, userId) {
  const rows = db
    .prepare(`
      SELECT id, user_id, token, device_name, ip_address, expires_at, is_revoked, created_at
      FROM user_sessions
      WHERE user_id = ? AND is_revoked = 0
      ORDER BY id DESC
    `)
    .all(userId);

  return rows.map((r) => ({
    id: r.id,
    userId: r.user_id,
    token: r.token,
    deviceName: r.device_name,
    ipAddress: r.ip_address,
    expiresAt: r.expires_at,
    isRevoked: Boolean(r.is_revoked),
    createdAt: r.created_at,
  }));
}

