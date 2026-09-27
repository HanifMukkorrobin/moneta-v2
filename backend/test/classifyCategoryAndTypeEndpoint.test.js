import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import app from '../src/index.js';
import { getDatabase } from '../src/config/database.js';
import { AiParserService, heuristicClassifyIndonesian, buildClassifierSystemPrompt } from '../src/services/aiParserService.js';

describe('Endpoint Klasifikasi Kategori dan Jenis Transaksi Tests', () => {
  let server;
  let baseUrl;
  let db;

  before(async () => {
    db = getDatabase();
    db.prepare('DELETE FROM categories WHERE is_default = 0').run();
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

  describe('1. Unit Heuristic & Prompt Builder Tests', () => {
    it('classifies expense with high confidence and alternative categories', () => {
      const res = heuristicClassifyIndonesian('Kopi kenangan mantan 24rb');
      assert.equal(res.success, true);
      assert.equal(res.type, 'expense');
      assert.equal(res.category, 'Makan & Minuman');
      assert.equal(res.amount, 24000);
      assert.equal(res.confidenceLevel, 'high');
      assert.ok(res.confidenceScore >= 0.85);
      assert.ok(Array.isArray(res.alternativeCategories));
      assert.ok(res.alternativeCategories.length > 0);
    });

    it('classifies income with salary keywords accurately', () => {
      const res = heuristicClassifyIndonesian('Transfer gaji kantor 8.500.000');
      assert.equal(res.success, true);
      assert.equal(res.type, 'income');
      assert.equal(res.category, 'Gaji');
      assert.equal(res.amount, 8500000);
      assert.equal(res.confidenceLevel, 'high');
      assert.ok(res.typeReasoning.length > 0);
      assert.ok(res.alternativeCategories.includes('Bonus') || res.alternativeCategories.includes('Transfer Masuk'));
    });

    it('assigns low confidence and "Belum Dikategorikan" for ambiguous phrases', () => {
      const res = heuristicClassifyIndonesian('Transfer bayar urusan tadi siang 75rb');
      assert.equal(res.success, true);
      assert.equal(res.category, 'Belum Dikategorikan');
      assert.equal(res.confidenceLevel, 'low');
      assert.ok(res.confidenceScore < 0.70);
      assert.ok(res.alternativeCategories.length >= 3);
    });

    it('builds system prompt containing instructions and categories', () => {
      const prompt = buildClassifierSystemPrompt(['Gym & Fitness', 'Hobi']);
      assert.ok(prompt.includes('AI Classifier Keuangan'));
      assert.ok(prompt.includes('Gym & Fitness'));
      assert.ok(prompt.includes('confidenceScore'));
      assert.ok(prompt.includes('alternativeCategories'));
    });
  });

  describe('2. POST /api/categories/classify Expense Categories', () => {
    it('classifies "Makan & Minuman" expense', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Makan siang ayam bakar 28rb' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'expense');
      assert.equal(data.category, 'Makan & Minuman');
      assert.equal(data.amount, 28000);
      assert.ok(data.categoryId);
      assert.equal(data.categoryIcon, 'restaurant_rounded');
      assert.equal(data.confidenceLevel, 'high');
      assert.ok(data.aiReasoning.length > 0);
      assert.ok(Array.isArray(data.alternativeCategories));
    });

    it('classifies "Transportasi" expense', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Beli bensin pertamax di SPBU 45rb' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'expense');
      assert.equal(data.category, 'Transportasi');
      assert.equal(data.amount, 45000);
      assert.equal(data.categoryIcon, 'directions_car_rounded');
    });

    it('classifies "Hiburan" expense', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Langganan netflix premium 186rb' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'expense');
      assert.equal(data.category, 'Hiburan');
      assert.equal(data.amount, 186000);
    });

    it('classifies "Tagihan & Utilitas" expense', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Bayar tagihan listrik PLN rumah 210rb' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'expense');
      assert.equal(data.category, 'Tagihan & Utilitas');
      assert.equal(data.amount, 210000);
    });

    it('classifies "Hutang & Paylater" expense', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Cicilan spaylater bulan ini 150rb' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'expense');
      assert.equal(data.category, 'Hutang & Paylater');
      assert.equal(data.amount, 150000);
    });

    it('classifies "Kebutuhan Rumah" expense', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Beli sabun mandi dan deterjen 45rb' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'expense');
      assert.equal(data.category, 'Kebutuhan Rumah');
    });

    it('classifies "Kesehatan" expense', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Beli obat dan vitamin di apotek 65rb' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'expense');
      assert.equal(data.category, 'Kesehatan');
      assert.equal(data.amount, 65000);
    });

    it('classifies "Belanja" expense', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Beli baju kaos polos di mall 120rb' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'expense');
      assert.equal(data.category, 'Belanja');
      assert.equal(data.amount, 120000);
    });
  });

  describe('3. POST /api/categories/classify Income Categories (Pilah Masuk vs Keluar)', () => {
    it('classifies "Gaji" income', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Transfer gaji kantor PT Maju 8.500.000' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'income');
      assert.equal(data.category, 'Gaji');
      assert.equal(data.amount, 8500000);
      assert.equal(data.categoryIcon, 'account_balance_wallet_rounded');
    });

    it('classifies "Freelance" income', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Fee freelance proyek redesign UI 1.250.000' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'income');
      assert.equal(data.category, 'Freelance');
      assert.equal(data.amount, 1250000);
    });

    it('classifies "Bonus" income', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Bonus insentif penjualan kuartal 1jt' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'income');
      assert.equal(data.category, 'Bonus');
      assert.equal(data.amount, 1000000);
    });

    it('classifies "Investasi" income', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Dividen saham BBCA masuk rekening 500rb' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'income');
      assert.equal(data.category, 'Investasi');
      assert.equal(data.amount, 500000);
    });

    it('classifies "Transfer Masuk" income', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Dapat kiriman uang dari orang tua 400rb' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'income');
      assert.equal(data.category, 'Transfer Masuk');
      assert.equal(data.amount, 400000);
    });
  });

  describe('4. Custom Category & Low Confidence Tests', () => {
    it('matches custom user category with isCustomCategory=true', async () => {
      // Insert a custom category in db for default user (id: 1)
      const user = db.prepare('SELECT id FROM users LIMIT 1').get();
      const userId = user ? user.id : 1;

      db.prepare(`
        INSERT OR IGNORE INTO categories (user_id, name, type, is_default, icon, color)
        VALUES (?, 'Perawatan Kucing', 'expense', 0, 'pets_rounded', 'purple')
      `).run(userId);

      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Beli makanan kucing whiskers 85rb', userId }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.category, 'Perawatan Kucing');
      assert.equal(data.isCustomCategory, true);
      assert.equal(data.confidenceLevel, 'high');
    });

    it('handles ambiguous text with Belum Dikategorikan and low confidence', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Transfer bayar urusan tadi siang 75rb' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.category, 'Belum Dikategorikan');
      assert.equal(data.confidenceLevel, 'low');
      assert.ok(data.confidenceScore < 0.70);
      assert.ok(data.alternativeCategories.length >= 3);
    });

    it('allows forced type override via type parameter', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Transfer dana 100rb', type: 'income' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.type, 'income');
    });

    it('classifies text without amount and sets amount=null', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Nasi padang rendang dan es teh' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.category, 'Makan & Minuman');
      assert.equal(data.amount, null);
    });
  });

  describe('5. Validation, Greetings, and Error Handling', () => {
    it('returns HTTP 400 when text is empty or missing', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: '   ' }),
      });

      assert.equal(res.status, 400);
      const data = await res.json();
      assert.equal(data.success, false);
      assert.ok(data.error.includes('wajib diisi'));
    });

    it('returns fallbackManual: true for casual greetings without transaction content', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Halo apa kabar bot?' }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, false);
      assert.equal(data.fallbackManual, true);
    });
  });

  describe('6. Classify Existing Transaction & Batch Classification', () => {
    it('classifies and applies to an existing transaction row', async () => {
      const user = db.prepare('SELECT id FROM users LIMIT 1').get();
      const userId = user ? user.id : 1;

      // Insert an unclassified transaction
      const txRes = db.prepare(`
        INSERT INTO transactions (user_id, type, amount, note, occurred_at, is_confirmed, is_guessed)
        VALUES (?, 'expense', 45000, 'Bensin Shell Super isi motor 45rb', CURRENT_TIMESTAMP, 0, 1)
      `).run(userId);
      const txId = txRes.lastInsertRowid;

      // Call classify with transactionId and apply: true
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ transactionId: txId, apply: true, userId }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.category, 'Transportasi');
      assert.equal(data.applied, true);

      // Verify DB was updated
      const updatedTx = db.prepare('SELECT * FROM transactions WHERE id = ?').get(txId);
      assert.equal(updatedTx.category_name, 'Transportasi');
      assert.ok(updatedTx.category_id);
      assert.ok(updatedTx.confidence_score >= 0.85);
      assert.ok(updatedTx.ai_reasoning);
    });

    it('supports batch classification of multiple items', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          items: [
            'Kopi latte 25rb',
            'Gaji bulanan 8jt',
            'Beli obat flu 15rb',
          ],
        }),
      });

      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.total, 3);
      assert.equal(data.classifications[0].category, 'Makan & Minuman');
      assert.equal(data.classifications[1].category, 'Gaji');
      assert.equal(data.classifications[2].category, 'Kesehatan');
    });
  });

  describe('7. Route Aliases & HTTP GET support', () => {
    it('supports GET /api/categories/classify?text=...', async () => {
      const res = await fetch(`${baseUrl}/api/categories/classify?text=${encodeURIComponent('Makan siang 25rb')}`);
      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.category, 'Makan & Minuman');
    });

    it('supports direct /classify endpoint', async () => {
      const res = await fetch(`${baseUrl}/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Beli token listrik PLN 50rb' }),
      });
      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.category, 'Tagihan & Utilitas');
    });

    it('supports /api/classify endpoint', async () => {
      const res = await fetch(`${baseUrl}/api/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Bonus thr 2jt' }),
      });
      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.category, 'Bonus');
      assert.equal(data.type, 'income');
    });

    it('supports /api/transactions/classify endpoint', async () => {
      const res = await fetch(`${baseUrl}/api/transactions/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Servis motor honda 80rb' }),
      });
      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.category, 'Transportasi');
    });

    it('supports /api/chat/classify endpoint', async () => {
      const res = await fetch(`${baseUrl}/api/chat/classify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: 'Beli buku gramedia 90rb' }),
      });
      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.category, 'Belanja');
    });
  });

  describe('8. Category Listing and Suggestions Endpoints', () => {
    it('retrieves category list via GET /api/categories', async () => {
      const res = await fetch(`${baseUrl}/api/categories`);
      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.ok(data.total >= 15);
      assert.ok(data.defaultCategories.length >= 15);
    });

    it('filters category list by type=income', async () => {
      const res = await fetch(`${baseUrl}/api/categories?type=income`);
      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.ok(data.categories.every((c) => c.type === 'income'));
    });

    it('retrieves category suggestions via GET /api/categories/frequent', async () => {
      const res = await fetch(`${baseUrl}/api/categories/frequent?type=expense&limit=5`);
      assert.equal(res.status, 200);
      const data = await res.json();
      assert.equal(data.success, true);
      assert.equal(data.type, 'expense');
      assert.ok(Array.isArray(data.suggestions));
      assert.ok(data.suggestions.length <= 5);
    });
  });
});
