import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import {
  isValidPinFormat,
  setupPin,
  verifyPin,
  changePin,
  togglePinLock,
  toggleBiometric,
  verifyBiometric,
  getSecurityStatus,
} from '../src/services/pinBiometricService.js';

describe('Service PIN & Verifikasi Biometrik Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUser;
  let authToken;

  before(async () => {
    db = getDatabase();
    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const { port } = server.address();
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  beforeEach(async () => {
    db.prepare("DELETE FROM users WHERE email LIKE '%@pintest.moneta.ai'").run();

    const regRes = await fetch(`${baseUrl}/api/auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: 'Fajar Nugroho',
        email: 'fajar@pintest.moneta.ai',
        password: 'password123',
      }),
    });
    const regBody = await regRes.json();
    testUser = regBody.user;
    authToken = regBody.token;
  });

  after(async () => {
    if (db) {
      db.prepare("DELETE FROM users WHERE email LIKE '%@pintest.moneta.ai'").run();
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. Unit Tests: pinBiometricService', () => {
    it('validates 4-6 digit numeric PIN format', () => {
      assert.strictEqual(isValidPinFormat('1234'), true);
      assert.strictEqual(isValidPinFormat('567890'), true);
      assert.strictEqual(isValidPinFormat('123'), false);
      assert.strictEqual(isValidPinFormat('1234567'), false);
      assert.strictEqual(isValidPinFormat('12ab'), false);
    });

    it('sets up PIN, verifies correct PIN, and rejects wrong PIN', () => {
      const setupRes = setupPin(db, testUser.id, { pin: '5678', confirmPin: '5678' });
      assert.strictEqual(setupRes.success, true);
      assert.strictEqual(setupRes.pinEnabled, true);
      assert.strictEqual(setupRes.hasPin, true);

      const verifyRes = verifyPin(db, testUser.id, '5678');
      assert.strictEqual(verifyRes.valid, true);
      assert.strictEqual(verifyRes.unlocked, true);

      assert.throws(() => {
        verifyPin(db, testUser.id, '9999');
      }, /PIN salah/);
    });

    it('changes PIN after verifying old PIN and rejects wrong old PIN', () => {
      setupPin(db, testUser.id, { pin: '1234' });

      assert.throws(() => {
        changePin(db, testUser.id, { oldPin: '0000', newPin: '8888', confirmNewPin: '8888' });
      }, /PIN lama salah/);

      const changed = changePin(db, testUser.id, {
        oldPin: '1234',
        newPin: '8888',
        confirmNewPin: '8888',
      });
      assert.strictEqual(changed.pinChanged, true);

      const verifyNew = verifyPin(db, testUser.id, '8888');
      assert.strictEqual(verifyNew.unlocked, true);
    });

    it('toggles PIN lock and biometric authentication and verifies biometric', () => {
      // Enable PIN lock without prior PIN -> defaults to '1234'
      const toggledPin = togglePinLock(db, testUser.id, { enabled: true });
      assert.strictEqual(toggledPin.pinEnabled, true);
      assert.strictEqual(verifyPin(db, testUser.id, '1234').unlocked, true);

      // Disable PIN lock
      const disabledPin = togglePinLock(db, testUser.id, { enabled: false });
      assert.strictEqual(disabledPin.pinEnabled, false);

      // Biometric verification fails when biometric is disabled
      assert.throws(() => {
        verifyBiometric(db, testUser.id, { sensorType: 'fingerprint' });
      }, /belum diaktifkan/);

      // Enable biometric
      const toggledBio = toggleBiometric(db, testUser.id, { enabled: true });
      assert.strictEqual(toggledBio.biometricEnabled, true);

      // Verify biometric succeeds
      const bioVerified = verifyBiometric(db, testUser.id, { sensorType: 'face_id' });
      assert.strictEqual(bioVerified.valid, true);
      assert.strictEqual(bioVerified.unlocked, true);
      assert.strictEqual(bioVerified.sensorType, 'face_id');

      const secStatus = getSecurityStatus(db, testUser.id);
      assert.strictEqual(secStatus.biometricEnabled, true);
    });
  });

  describe('2. Integration Tests: HTTP Endpoints (/api/auth/pin/* & /api/auth/biometric/*)', () => {
    it('sets up, verifies, changes, and toggles PIN via HTTP endpoints', async () => {
      // 1. Setup PIN
      const setupRes = await fetch(`${baseUrl}/api/auth/pin/setup`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${authToken}`,
        },
        body: JSON.stringify({ pin: '4321', confirmPin: '4321' }),
      });
      assert.strictEqual(setupRes.status, 200);
      const setupBody = await setupRes.json();
      assert.strictEqual(setupBody.pinEnabled, true);

      // 2. Verify PIN (correct)
      const verifyOk = await fetch(`${baseUrl}/api/auth/pin/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${authToken}`,
        },
        body: JSON.stringify({ pin: '4321' }),
      });
      assert.strictEqual(verifyOk.status, 200);
      const verifyOkBody = await verifyOk.json();
      assert.strictEqual(verifyOkBody.unlocked, true);

      // 3. Verify PIN (wrong -> 401)
      const verifyBad = await fetch(`${baseUrl}/api/auth/pin/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${authToken}`,
        },
        body: JSON.stringify({ pin: '1111' }),
      });
      assert.strictEqual(verifyBad.status, 401);

      // 4. Change PIN
      const changeRes = await fetch(`${baseUrl}/api/auth/pin/change`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${authToken}`,
        },
        body: JSON.stringify({ oldPin: '4321', newPin: '2468', confirmNewPin: '2468' }),
      });
      assert.strictEqual(changeRes.status, 200);

      // 5. Verify new PIN via /api/security/pin/verify alias
      const verifyNew = await fetch(`${baseUrl}/api/security/pin/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${authToken}`,
        },
        body: JSON.stringify({ pin: '2468' }),
      });
      assert.strictEqual(verifyNew.status, 200);
    });

    it('toggles and verifies biometric via HTTP endpoints', async () => {
      const toggleRes = await fetch(`${baseUrl}/api/auth/biometric/toggle`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${authToken}`,
        },
        body: JSON.stringify({ enabled: true }),
      });
      assert.strictEqual(toggleRes.status, 200);
      const toggleBody = await toggleRes.json();
      assert.strictEqual(toggleBody.biometricEnabled, true);

      const verifyBio = await fetch(`${baseUrl}/api/auth/biometric/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${authToken}`,
        },
        body: JSON.stringify({ sensorType: 'fingerprint' }),
      });
      assert.strictEqual(verifyBio.status, 200);
      const verifyBioBody = await verifyBio.json();
      assert.strictEqual(verifyBioBody.unlocked, true);
      assert.strictEqual(verifyBioBody.method, 'biometric');

      const statusRes = await fetch(`${baseUrl}/api/security/status`, {
        headers: { Authorization: `Bearer ${authToken}` },
      });
      assert.strictEqual(statusRes.status, 200);
      const statusBody = await statusRes.json();
      assert.strictEqual(statusBody.biometricEnabled, true);
    });
  });
});
