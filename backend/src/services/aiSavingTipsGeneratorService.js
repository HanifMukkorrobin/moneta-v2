/**
 * AI Saving Tips Generator Service (Layanan Generator Tips Hemat via AI & Heuristik)
 *
 * Menghasilkan tips hemat keuangan yang dipersonalisasi berdasarkan pola transaksi riil
 * pengguna (kategori pengeluaran terbesar, frekuensi jajan, dan laju belanja)
 * melalui gateway 9Router, dengan fallback cerdas berbasis heuristik finansial lokal.
 */

import { formatRupiah } from './dailyAverageSpendingService.js';
import { createDailyTip } from './dailyTipsService.js';

const DEFAULT_9ROUTER_BASE_URL = process.env.NINEROUTER_API_URL || 'https://api.9router.com/v1';
const DEFAULT_MODEL = process.env.NINEROUTER_MODEL || 'gpt-4o-mini';

/**
 * Contextual templates for local heuristic generation when AI is unavailable or as instant fallback
 */
const HEURISTIC_TEMPLATES_BY_CATEGORY = {
  'Makan & Minuman': [
    {
      title: 'Bawa Bekal Makan Siang 2x Sepekan',
      category: 'Makan & Minuman',
      description: 'Mengganti makan siang luar dengan bekal rumahan 2 kali seminggu dapat menghemat hingga Rp 150.000 per pekan.',
      potentialSaving: 150000,
      impactLevel: 'Tinggi',
      icon: 'restaurant_rounded',
      actionText: 'Rencanakan Menu Bekal',
    },
    {
      title: 'Seduh Kopi Sendiri di Pagi Hari',
      category: 'Makan & Minuman',
      description: 'Beli bubuk kopi favorit dan seduh sendiri sebelum mulai beraktivitas untuk memangkas jajan kopi kekinian.',
      potentialSaving: 120000,
      impactLevel: 'Sedang',
      icon: 'coffee_rounded',
      actionText: 'Seduh Kopi Rumah',
    },
  ],
  'Belanja': [
    {
      title: 'Aturan Tunda 24 Jam Belanja Online',
      category: 'Belanja',
      description: 'Masukkan barang non-pokok ke keranjang belanja dan tunggu 24 jam sebelum membayar untuk meredam belanja impulsif.',
      potentialSaving: 250000,
      impactLevel: 'Tinggi',
      icon: 'shopping_bag_rounded',
      actionText: 'Terapkan Aturan 24 Jam',
    },
    {
      title: 'Beli Kebutuhan Dapur Kemasan Grosir',
      category: 'Belanja',
      description: 'Beli beras, minyak goreng, dan deterjen dalam ukuran isi ulang besar untuk mendapatkan potongan harga per liter/kg.',
      potentialSaving: 180000,
      impactLevel: 'Tinggi',
      icon: 'storefront_rounded',
      actionText: 'Beli Kemasan Grosir',
    },
  ],
  'Tagihan & Utilitas': [
    {
      title: 'Audit Langganan Aplikasi Digital',
      category: 'Tagihan & Utilitas',
      description: 'Cek aplikasi streaming atau cloud yang jarang dipakai bulan ini. Nonaktifkan tagihan otomatis untuk pos yang tidak aktif.',
      potentialSaving: 89000,
      impactLevel: 'Sedang',
      icon: 'subscriptions_rounded',
      actionText: 'Cek Langganan Aktif',
    },
    {
      title: 'Matikan Saklar Colokan Listrik Malam Hari',
      category: 'Tagihan & Utilitas',
      description: 'Mematikan colokan TV, dispenser, dan charger saat tidur dapat menurunkan tagihan listrik bulanan.',
      potentialSaving: 45000,
      impactLevel: 'Ringan',
      icon: 'power_rounded',
      actionText: 'Cabut Saklar Malam',
    },
  ],
  'Transportasi': [
    {
      title: 'Manfaatkan Promo Transportasi Terpadu',
      category: 'Transportasi',
      description: 'Gunakan kartu langganan bulanan atau tiket komuter terusan saat jam kerja untuk menghemat biaya ojek harian.',
      potentialSaving: 75000,
      impactLevel: 'Ringan',
      icon: 'directions_bus_rounded',
      actionText: 'Cek Jalur Transit',
    },
    {
      title: 'Pilih Berjalan Kaki untuk Jarak < 1 KM',
      category: 'Transportasi',
      description: 'Mengurangi pesanan ojek online untuk rute dekat selain menyehatkan tubuh juga menghemat pengeluaran transportasi mikro.',
      potentialSaving: 50000,
      impactLevel: 'Ringan',
      icon: 'directions_walk_rounded',
      actionText: 'Mulai Jalan Kaki',
    },
  ],
  'Umum': [
    {
      title: 'Evaluasi Pembagian Budget 50/30/20',
      category: 'Umum',
      description: 'Cek apakah pengeluaran kebutuhan Anda masih di bawah 50% dari total pemasukan agar alokasi tabungan tetap terjaga.',
      potentialSaving: 200000,
      impactLevel: 'Tinggi',
      icon: 'pie_chart_rounded',
      actionText: 'Cek Alokasi Budget',
    },
    {
      title: 'Catat Pengeluaran Setiap Malam',
      category: 'Umum',
      description: 'Menutup hari dengan mencatat seluruh transaksi mencegah uang keluar tanpa jejak dan menjaga kesadaran finansial.',
      potentialSaving: 50000,
      impactLevel: 'Sedang',
      icon: 'edit_note_rounded',
      actionText: 'Catat Pengeluaran Hari Ini',
    },
  ],
};

/**
 * Service generator tips hemat AI dengan integrasi 9Router dan fallback lokal
 */
export class AiSavingTipsGeneratorService {
  constructor(options = {}) {
    this.apiKey = options.apiKey || process.env.NINEROUTER_API_KEY;
    this.baseUrl = (options.baseUrl || DEFAULT_9ROUTER_BASE_URL).replace(/\/$/, '');
    this.model = options.model || DEFAULT_MODEL;
    this.fetchFn = options.fetchFn || globalThis.fetch;
    this.timeoutMs = options.timeoutMs || 8000;
  }

  /**
   * Menghasilkan tips hemat berdasarkan data pengguna dari DB atau input finansial
   *
   * @param {import('better-sqlite3').Database} [db]
   * @param {Object} params
   * @param {number|string} [params.userId]
   * @param {Array<Object>} [params.recentTransactions]
   * @param {string} [params.topCategory]
   * @param {number} [params.totalSpent]
   * @param {boolean} [params.saveToDb=true]
   * @returns {Promise<Array<Object>>}
   */
  async generateTips(db = null, {
    userId = null,
    recentTransactions = [],
    topCategory = null,
    totalSpent = 0,
    saveToDb = true,
  } = {}) {
    // 1. Ekstrak data transaksi jika db dan userId tersedia
    let transactions = recentTransactions;
    let detectedTopCategory = topCategory;
    let calculatedTotalSpent = totalSpent;

    if (db && userId) {
      const rows = db.prepare(`
        SELECT t.amount, t.note, COALESCE(c.name, t.category_name, 'Lainnya') AS category, t.occurred_at
        FROM transactions t
        LEFT JOIN categories c ON c.id = t.category_id
        WHERE t.user_id = ? AND t.type = 'expense' AND t.is_confirmed = 1
        ORDER BY t.occurred_at DESC
        LIMIT 30
      `).all(userId);

      transactions = rows;

      // Hitung kategori terbesar
      const categoryTotals = {};
      let total = 0;
      for (const row of rows) {
        const cat = row.category || 'Lainnya';
        const amt = Number(row.amount) || 0;
        categoryTotals[cat] = (categoryTotals[cat] || 0) + amt;
        total += amt;
      }
      calculatedTotalSpent = total;

      const sortedCats = Object.entries(categoryTotals).sort((a, b) => b[1] - a[1]);
      if (sortedCats.length > 0) {
        detectedTopCategory = sortedCats[0][0];
      }
    }

    // 2. Coba panggil AI melalui 9Router jika apiKey tersedia
    let generatedTips = null;
    if (this.apiKey) {
      try {
        generatedTips = await this.call9RouterAi({
          topCategory: detectedTopCategory,
          totalSpent: calculatedTotalSpent,
          transactions,
        });
      } catch (err) {
        console.warn('[AiSavingTipsGenerator] 9Router call failed, falling back to heuristic generator:', err.message);
        generatedTips = null;
      }
    }

    // 3. Fallback Heuristik jika AI tidak tersedia atau gagal
    if (!generatedTips || generatedTips.length === 0) {
      generatedTips = this.generateHeuristicTips({
        topCategory: detectedTopCategory,
        totalSpent: calculatedTotalSpent,
        transactions,
      });
    }

    // 4. Simpan ke database jika diminta dan db tersedia
    if (saveToDb && db && generatedTips.length > 0) {
      for (const tip of generatedTips) {
        // Cek apakah tip dengan judul yang sama sudah ada
        const existing = db.prepare('SELECT id FROM daily_tips WHERE title = ?').get(tip.title);
        if (!existing) {
          const inserted = createDailyTip(db, tip);
          tip.id = inserted.id;
        } else {
          tip.id = existing.id;
        }
      }
    }

    return generatedTips;
  }

  /**
   * Panggilan ke gateway 9Router untuk menghasilkan tips hemat kontekstual
   */
  async call9RouterAi({ topCategory, totalSpent, transactions }) {
    const promptContext = {
      kategoriTerbesar: topCategory || 'Umum',
      totalPengeluaran: formatRupiah(totalSpent),
      contohTransaksi: transactions.slice(0, 10).map((t) => ({
        kategori: t.category,
        nominal: Number(t.amount) || 0,
        catatan: t.note,
      })),
    };

    const systemPrompt = `Anda adalah asisten perencana keuangan pribadi cerdas Moneta AI.
Tugas Anda adalah menganalisis riwayat pengeluaran pengguna dan menghasilkan 2 hingga 3 tips hemat praktis dalam Bahasa Indonesia yang realistis dan dapat langsung diterapkan.

Format JSON yang HARUS dikembalikan:
{
  "tips": [
    {
      "title": "Judul tips singkat & menarik (maks 6 kata)",
      "category": "Nama kategori relevan (Makan & Minuman / Belanja / Tagihan & Utilitas / Transportasi / Umum)",
      "description": "Penjelasan praktis 1-2 kalimat mengapa tips ini efektif dan cara menerapkannya.",
      "potentialSaving": 100000, // Estimasi nominal penghematan (angka murni integer Rupiah)
      "impactLevel": "Tinggi", // 'Tinggi' | 'Sedang' | 'Ringan'
      "icon": "restaurant_rounded", // Material icon identifier
      "actionText": "Aksi singkat tombol (mis. Rencanakan Menu Bekal)"
    }
  ]
}`;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);

    const response = await this.fetchFn(`${this.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify({
        model: this.model,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: JSON.stringify(promptContext) },
        ],
        temperature: 0.2,
        response_format: { type: 'json_object' },
      }),
      signal: controller.signal,
    });

    clearTimeout(timer);

    if (!response.ok) {
      throw new Error(`9Router responded with HTTP ${response.status}`);
    }

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content;
    if (!content) {
      throw new Error('Empty completion content from 9Router');
    }

    const parsed = JSON.parse(content);
    if (!Array.isArray(parsed.tips) || parsed.tips.length === 0) {
      throw new Error('Invalid JSON structure: tips array missing');
    }

    return parsed.tips.map((t) => ({
      title: t.title || 'Tips Hemat Pintar',
      category: t.category || topCategory || 'Umum',
      description: t.description || 'Kelola pengeluaran dengan lebih bijak untuk tabungan masa depan.',
      potentialSaving: Math.max(10000, Number(t.potentialSaving) || 50000),
      impactLevel: ['Tinggi', 'Sedang', 'Ringan'].includes(t.impactLevel) ? t.impactLevel : 'Sedang',
      icon: t.icon || 'lightbulb_outline_rounded',
      actionText: t.actionText || 'Terapkan Hari Ini',
    }));
  }

  /**
   * Generator Heuristik Kontekstual Berdasarkan Pola Belanja Pengguna
   */
  generateHeuristicTips({ topCategory, totalSpent, transactions }) {
    const categoryKey = HEURISTIC_TEMPLATES_BY_CATEGORY[topCategory] ? topCategory : 'Umum';
    const primaryTemplates = HEURISTIC_TEMPLATES_BY_CATEGORY[categoryKey] || HEURISTIC_TEMPLATES_BY_CATEGORY['Umum'];
    const secondaryTemplates = HEURISTIC_TEMPLATES_BY_CATEGORY['Umum'];

    const chosen = [...primaryTemplates];

    // Jika template utama cuma 1 atau butuh variasi, tambahkan dari kategori umum
    if (chosen.length < 2 && secondaryTemplates.length > 0) {
      chosen.push(secondaryTemplates[0]);
    }

    return chosen.map((tip) => {
      // Sesuaikan potensi penghematan dengan skala pengeluaran pengguna jika totalSpent tinggi
      let adjustedSaving = tip.potentialSaving;
      if (totalSpent > 3000000) {
        adjustedSaving = Math.round(tip.potentialSaving * 1.25);
      }

      return {
        ...tip,
        potentialSaving: adjustedSaving,
      };
    });
  }
}

export const defaultAiSavingTipsGenerator = new AiSavingTipsGeneratorService();
