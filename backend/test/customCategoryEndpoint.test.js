import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';

describe('Endpoint Kategori Pengeluaran Kustom Tests', () => {
  let server;
  let baseUrl;
  let db;
  let testUserId;

  before(async () => {
    db = getDatabase();
    db.prepare('DELETE FROM categories WHERE is_default = 0').run();
    const user = db.prepare('SELECT id FROM users LIMIT 1').get();
    testUserId = user ? user.id : 1;

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        const port = server.address().port;
        baseUrl = `http://localhost:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    if (db) {
      db.prepare('DELETE FROM categories WHERE is_default = 0').run();
    }
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  describe('1. Create Custom Expense Category (POST /api/categories/custom & POST /api/categories)', () => {
    it('creates a custom expense category successfully with 201 Created', async () => {
      const res = await fetch(`${baseUrl}/api/categories/custom`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: 'Skincare & Perawatan',
          type: 'expense',
          icon: 'face_retouching_natural_rounded',
          color: 'pink',
          userId: testUserId,
        }),
      });

      assert.equal(res.status, 201);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.ok(data.category.id);
      assert.equal(data.category.name, 'Skincare & Perawatan');
      assert.equal(data.category.type, 'expense');
      assert.equal(data.category.isCustom, true);
      assert.equal(data.category.isDefault, false);
      assert.equal(data.category.icon, 'face_retouching_natural_rounded');
      assert.equal(data.category.color, 'pink');

      // Verify row in database
      const row = db.prepare('SELECT * FROM categories WHERE id = ?').get(data.category.id);
      assert.ok(row);
      assert.equal(row.is_default, 0);
      assert.equal(row.user_id, testUserId);
    });

    it('defaults type to "expense" when not specified', async () => {
      const res = await fetch(`${baseUrl}/api/categories`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: 'Koleksi Buku & Komik',
          icon: 'menu_book_rounded',
          color: 'deepPurple',
          userId: testUserId,
        }),
      });

      assert.equal(res.status, 201);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.category.type, 'expense');
      assert.equal(data.category.isCustom, true);
    });

    it('rejects duplicate category name for the same user and type', async () => {
      const res = await fetch(`${baseUrl}/api/categories/custom`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: 'skincare & perawatan', // Case insensitive collision
          type: 'expense',
          userId: testUserId,
        }),
      });

      assert.equal(res.status, 400);
      const data = await res.json();
      assert.equal(data.success, false);
      assert.ok(data.error.includes('sudah ada'));
    });

    it('rejects empty or whitespace category name with HTTP 400', async () => {
      const res = await fetch(`${baseUrl}/api/categories/custom`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: '   ',
          type: 'expense',
        }),
      });

      assert.equal(res.status, 400);
      const data = await res.json();
      assert.equal(data.success, false);
      assert.ok(data.error.includes('wajib diisi'));
    });

    it('rejects invalid category type with HTTP 400', async () => {
      const res = await fetch(`${baseUrl}/api/categories/custom`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: 'Investasi Saham Baru',
          type: 'invalid_type',
        }),
      });

      assert.equal(res.status, 400);
      const data = await res.json();
      assert.equal(data.success, false);
      assert.ok(data.error.includes('expense') || data.error.includes('income'));
    });
  });

  describe('2. List Custom Categories (GET /api/categories/custom)', () => {
    it('retrieves all custom categories for user', async () => {
      const res = await fetch(`${baseUrl}/api/categories/custom?userId=${testUserId}`);
      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.ok(Array.isArray(data.categories));
      assert.ok(data.total >= 2);
      assert.ok(data.categories.every((c) => c.isCustom && !c.isDefault));
    });

    it('filters custom categories by type=expense', async () => {
      const res = await fetch(`${baseUrl}/api/categories/custom?type=expense&userId=${testUserId}`);
      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.ok(data.categories.every((c) => c.type === 'expense'));
    });
  });

  describe('3. Get Category by ID (GET /api/categories/:id)', () => {
    it('retrieves single category by id', async () => {
      const cat = db.prepare('SELECT id, name FROM categories WHERE name = ?').get('Skincare & Perawatan');
      assert.ok(cat);

      const res = await fetch(`${baseUrl}/api/categories/${cat.id}`);
      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.category.id, cat.id);
      assert.equal(data.category.name, 'Skincare & Perawatan');
    });

    it('returns 404 for non-existent category id', async () => {
      const res = await fetch(`${baseUrl}/api/categories/999999`);
      assert.equal(res.status, 404);
      const data = await res.json();
      assert.equal(data.success, false);
    });
  });

  describe('4. Update Custom Category (PUT & PATCH /api/categories/:id)', () => {
    it('updates custom category name and icon successfully', async () => {
      const cat = db.prepare('SELECT id FROM categories WHERE name = ?').get('Koleksi Buku & Komik');
      assert.ok(cat);

      const res = await fetch(`${baseUrl}/api/categories/${cat.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: 'Buku & Literasi',
          icon: 'menu_book_sharp',
          color: 'indigo',
        }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.category.name, 'Buku & Literasi');
      assert.equal(data.category.icon, 'menu_book_sharp');
      assert.equal(data.category.color, 'indigo');

      // Verify in DB
      const updated = db.prepare('SELECT name FROM categories WHERE id = ?').get(cat.id);
      assert.equal(updated.name, 'Buku & Literasi');
    });

    it('updates linked transactions when category name is changed', async () => {
      const cat = db.prepare('SELECT id FROM categories WHERE name = ?').get('Buku & Literasi');
      assert.ok(cat);

      // Create a transaction with this category
      const tx = db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at)
        VALUES (?, ?, 'Buku & Literasi', 'expense', 75000, 'Beli komik naruto 75rb', CURRENT_TIMESTAMP)
      `).run(testUserId, cat.id);

      // Rename category via PATCH
      const res = await fetch(`${baseUrl}/api/categories/${cat.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: 'Buku & Majalah',
        }),
      });

      assert.equal(res.status, 200);

      // Verify transaction row was also updated with new category name
      const updatedTx = db.prepare('SELECT category_name FROM transactions WHERE id = ?').get(tx.lastInsertRowid);
      assert.equal(updatedTx.category_name, 'Buku & Majalah');
    });

    it('rejects modifying default system categories with HTTP 400', async () => {
      const defaultCat = db.prepare("SELECT id FROM categories WHERE is_default = 1 AND name = 'Makan & Minuman'").get();
      assert.ok(defaultCat);

      const res = await fetch(`${baseUrl}/api/categories/${defaultCat.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: 'Makan Enak',
        }),
      });

      assert.equal(res.status, 400);
      const data = await res.json();
      assert.equal(data.success, false);
      assert.ok(data.error.includes('bawaan'));
    });

    it('rejects updating to a name that already exists for that type', async () => {
      const cat = db.prepare('SELECT id FROM categories WHERE name = ?').get('Buku & Majalah');
      assert.ok(cat);

      // Attempt to rename to 'Skincare & Perawatan' which already exists
      const res = await fetch(`${baseUrl}/api/categories/${cat.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: 'Skincare & Perawatan',
        }),
      });

      assert.equal(res.status, 400);
      const data = await res.json();
      assert.equal(data.success, false);
      assert.ok(data.error.includes('sudah digunakan'));
    });
  });

  describe('5. Delete Custom Category (DELETE /api/categories/:id)', () => {
    it('rejects deleting default system categories with HTTP 400', async () => {
      const defaultCat = db.prepare("SELECT id FROM categories WHERE is_default = 1 AND name = 'Transportasi'").get();
      assert.ok(defaultCat);

      const res = await fetch(`${baseUrl}/api/categories/${defaultCat.id}`, {
        method: 'DELETE',
      });

      assert.equal(res.status, 400);
      const data = await res.json();
      assert.equal(data.success, false);
      assert.ok(data.error.includes('bawaan'));
    });

    it('deletes custom category and reassigns existing transactions to "Lainnya"', async () => {
      // Create a temporary custom category
      const createRes = await fetch(`${baseUrl}/api/categories/custom`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: 'Hobi Sepeda',
          type: 'expense',
          userId: testUserId,
        }),
      });
      const createData = await createRes.json();
      const catId = createData.category.id;

      // Create 2 transactions linked to this category
      const tx1 = db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at)
        VALUES (?, ?, 'Hobi Sepeda', 'expense', 50000, 'Beli ban dalam 50rb', CURRENT_TIMESTAMP)
      `).run(testUserId, catId);

      const tx2 = db.prepare(`
        INSERT INTO transactions (user_id, category_id, category_name, type, amount, note, occurred_at)
        VALUES (?, ?, 'Hobi Sepeda', 'expense', 120000, 'Pompa sepeda 120rb', CURRENT_TIMESTAMP)
      `).run(testUserId, catId);

      // Delete the category
      const delRes = await fetch(`${baseUrl}/api/categories/${catId}`, {
        method: 'DELETE',
      });

      assert.equal(delRes.status, 200);
      const delData = await delRes.json();
      assert.equal(delData.success, true);
      assert.equal(delData.reassignedTransactionsCount, 2);

      // Verify category was deleted
      const checkCat = db.prepare('SELECT id FROM categories WHERE id = ?').get(catId);
      assert.equal(checkCat, undefined);

      // Verify transactions are now reassigned to 'Lainnya'
      const checkTx1 = db.prepare('SELECT category_id, category_name FROM transactions WHERE id = ?').get(tx1.lastInsertRowid);
      const checkTx2 = db.prepare('SELECT category_id, category_name FROM transactions WHERE id = ?').get(tx2.lastInsertRowid);
      assert.equal(checkTx1.category_name, 'Lainnya');
      assert.equal(checkTx2.category_name, 'Lainnya');
    });

    it('returns 404 when deleting a non-existent category id', async () => {
      const res = await fetch(`${baseUrl}/api/categories/888888`, {
        method: 'DELETE',
      });
      assert.equal(res.status, 404);
      const data = await res.json();
      assert.equal(data.success, false);
    });
  });

  describe('6. Integration with Classifier & AI Recognition', () => {
    it('immediately recognizes newly created custom expense category during classification', async () => {
      // 1. Create custom category "Peralatan Musik"
      const createRes = await fetch(`${baseUrl}/api/categories/custom`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: 'Peralatan Musik',
          type: 'expense',
          icon: 'music_note_rounded',
          color: 'teal',
          userId: testUserId,
        }),
      });
      assert.equal(createRes.status, 201);
      const createData = await createRes.json();

      // 2. Classify a sentence matching this new custom category
      const classifyRes = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          text: 'Beli senar gitar akustik dan peralatan musik 75rb',
          userId: testUserId,
        }),
      });

      assert.equal(classifyRes.status, 200);
      const classifyData = await classifyRes.json();
      assert.equal(classifyData.success, true);
      assert.equal(classifyData.category, 'Peralatan Musik');
      assert.equal(classifyData.categoryId, createData.category.id);
      assert.equal(classifyData.isCustomCategory, true);
      assert.equal(classifyData.confidenceLevel, 'high');
      assert.equal(classifyData.amount, 75000);
    });
  });
});
