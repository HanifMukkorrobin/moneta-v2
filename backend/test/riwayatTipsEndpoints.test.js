import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { runMigrations } from '../src/db/migrate.js';

describe('Endpoint Riwayat Tips Hemat (Tips History Endpoints) Tests', () => {
  let server;
  let baseUrl;
  let db;
  let user1Id;
  let user2Id;
  let bekalTipId;
  let kopiTipId;

  before(async () => {
    db = getDatabase();
    runMigrations(db);

    const u1Res = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, 'Gita Gutawa', 'IDR')
    `).run(`riwayat_u1_${Date.now()}@example.com`);
    user1Id = Number(u1Res.lastInsertRowid);

    const u2Res = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, 'Tulus Rusydi', 'IDR')
    `).run(`riwayat_u2_${Date.now()}@example.com`);
    user2Id = Number(u2Res.lastInsertRowid);

    const bekalRow = db.prepare("SELECT id FROM daily_tips WHERE title LIKE '%Bekal%'").get();
    bekalTipId = bekalRow.id;

    const kopiRow = db.prepare("SELECT id FROM daily_tips WHERE title LIKE '%Kopi%'").get();
    kopiTipId = kopiRow.id;

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  beforeEach(() => {
    db.prepare('DELETE FROM user_saving_tips WHERE user_id IN (?, ?)').run(user1Id, user2Id);
  });

  after(async () => {
    if (db) {
      db.prepare('DELETE FROM user_saving_tips WHERE user_id IN (?, ?)').run(user1Id, user2Id);
      db.prepare('DELETE FROM users WHERE id IN (?, ?)').run(user1Id, user2Id);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. GET /api/tips/riwayat & GET /api/riwayat-tips', () => {
    it('returns empty applied count initially and calculates potential savings correctly', async () => {
      const res = await fetch(`${baseUrl}/api/riwayat-tips?userId=${user1Id}&referenceDate=2026-09-27`);
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.strictEqual(body.userId, user1Id);
      assert.strictEqual(body.summary.appliedCount, 0);
      assert.strictEqual(body.summary.totalAppliedSavings, 0);
      assert.ok(body.summary.totalPotentialSavingsAll > 0);
      assert.ok(Array.isArray(body.tips));
      assert.ok(body.tips.length >= 9);
      assert.ok(body.tips[0].formattedDate);
    });

    it('reflects applied tips, calculates totalAppliedSavings and successRate', async () => {
      // User 1 applies 2 tips: bekal (150.000) and kopi (120.000) on 2026-09-27
      await fetch(`${baseUrl}/api/tips/${bekalTipId}/toggle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: user1Id, isApplied: true, date: '2026-09-27' }),
      });

      await fetch(`${baseUrl}/api/tips/${kopiTipId}/toggle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: user1Id, isApplied: true, date: '2026-09-27' }),
      });

      const res = await fetch(`${baseUrl}/api/tips/riwayat?userId=${user1Id}&referenceDate=2026-09-27`);
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.summary.appliedCount, 2);
      assert.strictEqual(body.summary.totalAppliedSavings, 270000); // 150.000 + 120.000
      assert.strictEqual(body.summary.formattedTotalAppliedSavings, 'Rp 270.000');
      assert.ok(body.summary.summaryText.includes('2 dari'));
      assert.ok(body.summary.successRate > 0);

      // Verify date display format matches "Hari Ini, 27 Sep 2026"
      const appliedItem = body.tips.find((t) => t.isApplied);
      assert.ok(appliedItem);
      assert.strictEqual(appliedItem.formattedDate, 'Hari Ini, 27 Sep 2026');
    });

    it('filters tips history by search query', async () => {
      const res = await fetch(`${baseUrl}/api/riwayat-tips?userId=${user1Id}&search=kopi`);
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.ok(body.tips.length >= 1);
      body.tips.forEach((t) => {
        assert.ok(
          t.title.toLowerCase().includes('kopi') ||
          t.description.toLowerCase().includes('kopi')
        );
      });
    });

    it('filters tips history by status (diterapkan vs belum_diterapkan)', async () => {
      // Apply one tip
      await fetch(`${baseUrl}/api/tips/${bekalTipId}/toggle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: user1Id, isApplied: true, date: '2026-09-27' }),
      });

      // Query diterapkan only
      const resApplied = await fetch(`${baseUrl}/api/riwayat-tips?userId=${user1Id}&status=diterapkan`);
      const bodyApplied = await resApplied.json();
      assert.strictEqual(resApplied.status, 200);
      assert.strictEqual(bodyApplied.tips.length, 1);
      assert.strictEqual(bodyApplied.tips[0].isApplied, true);

      // Query belum_diterapkan only
      const resUnapplied = await fetch(`${baseUrl}/api/riwayat-tips?userId=${user1Id}&status=belum_diterapkan`);
      const bodyUnapplied = await resUnapplied.json();
      assert.strictEqual(resUnapplied.status, 200);
      assert.ok(bodyUnapplied.tips.length >= 8);
      bodyUnapplied.tips.forEach((t) => assert.strictEqual(t.isApplied, false));
    });

    it('isolates history strictly between User 1 and User 2', async () => {
      // User 1 applies bekal tip
      await fetch(`${baseUrl}/api/tips/${bekalTipId}/toggle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: user1Id, isApplied: true, date: '2026-09-27' }),
      });

      // User 2 queries history -> appliedCount must be 0
      const res = await fetch(`${baseUrl}/api/riwayat-tips?userId=${user2Id}`);
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.summary.appliedCount, 0);
      assert.strictEqual(body.summary.totalAppliedSavings, 0);
    });
  });

  describe('2. GET /api/riwayat-tips/summary & GET /api/tips/riwayat/summary', () => {
    it('returns executive summary statistics only', async () => {
      await fetch(`${baseUrl}/api/tips/${bekalTipId}/toggle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: user1Id, isApplied: true, date: '2026-09-27' }),
      });

      const res = await fetch(`${baseUrl}/api/riwayat-tips/summary?userId=${user1Id}&referenceDate=2026-09-27`);
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.strictEqual(body.userId, user1Id);
      assert.strictEqual(body.summary.appliedCount, 1);
      assert.strictEqual(body.summary.totalAppliedSavings, 150000);
      assert.ok(body.summary.totalCount >= 9);
      assert.ok(body.summary.summaryText.includes('1 dari'));
    });
  });

  describe('3. POST /api/riwayat-tips/toggle & POST /api/riwayat-tips/:id/toggle', () => {
    it('toggles tip from riwayat-tips route directly', async () => {
      const res = await fetch(`${baseUrl}/api/riwayat-tips/${bekalTipId}/toggle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          isApplied: true,
          date: '2026-09-27',
        }),
      });
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.strictEqual(body.isApplied, true);

      // Verify on summary
      const sumRes = await fetch(`${baseUrl}/api/riwayat-tips/summary?userId=${user1Id}&referenceDate=2026-09-27`);
      const sumBody = await sumRes.json();
      assert.strictEqual(sumBody.summary.appliedCount, 1);
    });
  });

  describe('4. Error Handling and Validation', () => {
    it('returns HTTP 400 when userId is invalid', async () => {
      const res = await fetch(`${baseUrl}/api/riwayat-tips?userId=-5`);
      const body = await res.json();

      assert.strictEqual(res.status, 400);
      assert.strictEqual(body.success, false);
      assert.ok(body.error.includes('userId'));
    });
  });
});
