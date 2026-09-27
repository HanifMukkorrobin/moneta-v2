import { describe, it, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { runMigrations, defaultSavingTips } from '../src/db/migrate.js';

describe('Endpoint Tips Hemat Harian & AI Generator (Daily Tips Endpoints) Tests', () => {
  let server;
  let baseUrl;
  let db;
  let user1Id;
  let user2Id;

  before(async () => {
    db = getDatabase();
    runMigrations(db);

    const u1Res = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, 'Bambang Sudirman', 'IDR')
    `).run(`tips_u1_${Date.now()}@example.com`);
    user1Id = Number(u1Res.lastInsertRowid);

    const u2Res = db.prepare(`
      INSERT INTO users (email, display_name, currency)
      VALUES (?, 'Dewi Lestari', 'IDR')
    `).run(`tips_u2_${Date.now()}@example.com`);
    user2Id = Number(u2Res.lastInsertRowid);

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  beforeEach(() => {
    // Reset user saving tips
    db.prepare('DELETE FROM user_saving_tips WHERE user_id IN (?, ?)').run(user1Id, user2Id);
    db.prepare('DELETE FROM transactions WHERE user_id IN (?, ?)').run(user1Id, user2Id);
  });

  after(async () => {
    if (db) {
      db.prepare('DELETE FROM user_saving_tips WHERE user_id IN (?, ?)').run(user1Id, user2Id);
      db.prepare('DELETE FROM transactions WHERE user_id IN (?, ?)').run(user1Id, user2Id);
      db.prepare('DELETE FROM users WHERE id IN (?, ?)').run(user1Id, user2Id);
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. GET /api/tips - Daftar Tips Harian', () => {
    it('returns daily tips with badge counter and applied statistics', async () => {
      const res = await fetch(`${baseUrl}/api/tips?userId=${user1Id}`);
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.strictEqual(body.userId, user1Id);
      assert.ok(body.totalCount >= defaultSavingTips.length);
      assert.strictEqual(body.appliedCount, 0);
      assert.strictEqual(body.unappliedCount, body.totalCount);
      assert.strictEqual(body.appliedBadgeText, `0/${body.totalCount} Diterapkan`);
      assert.ok(Array.isArray(body.tips));
    });

    it('filters tips by category properly', async () => {
      const res = await fetch(`${baseUrl}/api/tips?userId=${user1Id}&category=Makan%20%26%20Minuman`);
      const body = await res.json();

      assert.strictEqual(res.status, 200);
      assert.strictEqual(body.success, true);
      assert.ok(body.tips.length >= 2);
      body.tips.forEach((t) => {
        assert.strictEqual(t.category, 'Makan & Minuman');
      });
    });
  });

  describe('2. POST /api/tips/:id/toggle - Toggle Status Penerapan Tip', () => {
    it('toggles tip status to applied and reflects in counters', async () => {
      // 1. Get first tip id
      const listRes = await fetch(`${baseUrl}/api/tips?userId=${user1Id}`);
      const listBody = await listRes.json();
      const firstTip = listBody.tips[0];

      // 2. Toggle to applied
      const toggleRes = await fetch(`${baseUrl}/api/tips/${firstTip.id}/toggle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          isApplied: true,
        }),
      });
      const toggleBody = await toggleRes.json();

      assert.strictEqual(toggleRes.status, 200);
      assert.strictEqual(toggleBody.success, true);
      assert.strictEqual(toggleBody.isApplied, true);
      assert.ok(toggleBody.message.includes('berhasil ditandai'));

      // 3. Verify on GET /api/tips that appliedCount is now 1
      const verifyRes = await fetch(`${baseUrl}/api/tips?userId=${user1Id}`);
      const verifyBody = await verifyRes.json();
      assert.strictEqual(verifyBody.appliedCount, 1);
      assert.strictEqual(verifyBody.appliedBadgeText, `1/${verifyBody.totalCount} Diterapkan`);

      // 4. Verify user isolation: User 2 still has 0 applied
      const u2Res = await fetch(`${baseUrl}/api/tips?userId=${user2Id}`);
      const u2Body = await u2Res.json();
      assert.strictEqual(u2Body.appliedCount, 0);

      // 5. Toggle back to false
      const unapplyRes = await fetch(`${baseUrl}/api/tips/${firstTip.id}/toggle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: user1Id,
          isApplied: false,
        }),
      });
      const unapplyBody = await unapplyRes.json();
      assert.strictEqual(unapplyBody.isApplied, false);
    });

    it('returns 404 when tip ID does not exist', async () => {
      const res = await fetch(`${baseUrl}/api/tips/999999/toggle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: user1Id, isApplied: true }),
      });
      const body = await res.json();

      assert.strictEqual(res.status, 404);
      assert.strictEqual(body.success, false);
    });
  });

  describe('3. GET /api/tips/riwayat - Riwayat Tips Hemat', () => {
    it('returns tips history with search filtering and summary metrics', async () => {
      // Toggle one tip to applied
      const listRes = await fetch(`${baseUrl}/api/tips?userId=${user1Id}`);
      const listBody = await listRes.json();
      const bekalTip = listBody.tips.find((t) => t.title.includes('Bekal')) || listBody.tips[0];

      await fetch(`${baseUrl}/api/tips/${bekalTip.id}/toggle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: user1Id, isApplied: true }),
      });

      // Query history
      const historyRes = await fetch(`${baseUrl}/api/tips/riwayat?userId=${user1Id}`);
      const historyBody = await historyRes.json();

      assert.strictEqual(historyRes.status, 200);
      assert.strictEqual(historyBody.success, true);
      assert.strictEqual(historyBody.summary.appliedCount, 1);
      assert.ok(historyBody.summary.summaryText.includes('1 dari'));

      // Filter by search query "bekal"
      const searchRes = await fetch(`${baseUrl}/api/tips/riwayat?userId=${user1Id}&search=bekal`);
      const searchBody = await searchRes.json();

      assert.strictEqual(searchRes.status, 200);
      assert.ok(searchBody.tips.length >= 1);
      assert.ok(searchBody.tips[0].title.toLowerCase().includes('bekal'));

      // Filter by status "diterapkan"
      const appliedOnlyRes = await fetch(`${baseUrl}/api/tips/riwayat?userId=${user1Id}&status=diterapkan`);
      const appliedOnlyBody = await appliedOnlyRes.json();

      assert.strictEqual(appliedOnlyRes.status, 200);
      assert.strictEqual(appliedOnlyBody.tips.length, 1);
      assert.strictEqual(appliedOnlyBody.tips[0].isApplied, true);
    });
  });

  describe('4. POST /api/tips/generate - Generator Tips Hemat via AI', () => {
    it('generates personalized saving tips based on user transactions', async () => {
      // Insert transactions in category Makan & Minuman
      const txStmt = db.prepare(`
        INSERT INTO transactions (user_id, type, amount, note, occurred_at, is_confirmed)
        VALUES (?, 'expense', ?, ?, ?, 1)
      `);
      txStmt.run(user1Id, 50000, 'Jajan Kopi Susu', '2026-09-25 09:00:00');
      txStmt.run(user1Id, 75000, 'Makan Siang Resto', '2026-09-26 12:30:00');
      txStmt.run(user1Id, 80000, 'Makan Malam Kafe', '2026-09-26 19:30:00');

      const genRes = await fetch(`${baseUrl}/api/tips/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: user1Id, saveToDb: true }),
      });
      const genBody = await genRes.json();

      assert.strictEqual(genRes.status, 200);
      assert.strictEqual(genBody.success, true);
      assert.ok(genBody.count >= 1);
      assert.ok(Array.isArray(genBody.tips));
      assert.ok(genBody.tips[0].potentialSaving > 0);
      assert.ok(genBody.tips[0].title);
    });
  });

  describe('5. Custom Tip Creation & Details', () => {
    it('creates custom tip and retrieves detail by ID', async () => {
      const createRes = await fetch(`${baseUrl}/api/tips`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: 'Batasi Belanja Impulsif Akhir Pekan',
          category: 'Belanja',
          description: 'Buat daftar belanja tertulis sebelum ke supermarket dan patuhi daftar tersebut.',
          potentialSaving: 120000,
          impactLevel: 'Sedang',
          icon: 'checklist_rounded',
          actionText: 'Buat Daftar Belanja',
        }),
      });
      const createBody = await createRes.json();

      assert.strictEqual(createRes.status, 201);
      assert.strictEqual(createBody.success, true);
      assert.strictEqual(createBody.tip.title, 'Batasi Belanja Impulsif Akhir Pekan');

      // Fetch detail
      const detailRes = await fetch(`${baseUrl}/api/tips/${createBody.tip.id}`);
      const detailBody = await detailRes.json();

      assert.strictEqual(detailRes.status, 200);
      assert.strictEqual(detailBody.tip.title, 'Batasi Belanja Impulsif Akhir Pekan');
      assert.strictEqual(detailBody.tip.potentialSaving, 120000);
    });

    it('rejects invalid tip creation missing title or description (HTTP 400)', async () => {
      const res = await fetch(`${baseUrl}/api/tips`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: '' }),
      });

      assert.strictEqual(res.status, 400);
    });
  });

  describe('6. Route Aliases Compatibility', () => {
    it('supports aliases /tips, /api/tips, /tips-harian, /api/tips-harian', async () => {
      const r1 = await fetch(`${baseUrl}/tips?userId=${user1Id}`);
      assert.strictEqual(r1.status, 200);

      const r2 = await fetch(`${baseUrl}/tips-harian?userId=${user1Id}`);
      assert.strictEqual(r2.status, 200);

      const r3 = await fetch(`${baseUrl}/api/tips-harian?userId=${user1Id}`);
      assert.strictEqual(r3.status, 200);
    });
  });
});
