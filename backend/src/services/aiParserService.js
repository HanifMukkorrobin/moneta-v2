import dotenv from 'dotenv';
dotenv.config();

const DEFAULT_9ROUTER_BASE_URL = process.env.NINEROUTER_API_URL || 'https://api.9router.com/v1';
const DEFAULT_MODEL = process.env.NINEROUTER_MODEL || 'google/gemini-2.0-flash';

/**
 * Heuristic fallback parser when 9Router API is unreachable, offline, or mock testing.
 * Parses common Indonesian natural language transaction patterns.
 */
export function heuristicParseIndonesian(text, availableCategories = []) {
  const trimmed = (text || '').trim();
  if (!trimmed) {
    return {
      success: false,
      error: 'Teks tidak boleh kosong',
      rawText: text,
    };
  }

  const lower = trimmed.toLowerCase();

  // If greeting or no numbers
  if (['halo', 'hai', 'test', 'tes', 'ping', 'apa kabar', 'bingung', 'tolong'].includes(lower)) {
    return {
      success: false,
      error: 'Kalimat bukan merupakan catatan transaksi keuangan.',
      rawText: trimmed,
    };
  }

  // Parse amount with multiplier (rb, k, jt, juta, ribu, perak)
  // Matches: "25rb", "25.000", "2,5jt", "50k", "15000"
  const amountRegex = /(\d+(?:[.,]\d+)?)\s*(rb|k|ribu|jt|juta|m|miliar)?\b/i;
  const match = lower.match(amountRegex);

  if (!match) {
    return {
      success: false,
      error: 'Nominal transaksi tidak terdeteksi dalam kalimat.',
      rawText: trimmed,
    };
  }

  let baseNum = parseFloat(match[1].replace(',', '.'));
  const unit = (match[2] || '').toLowerCase();

  if (unit === 'rb' || unit === 'k' || unit === 'ribu') {
    baseNum *= 1000;
  } else if (unit === 'jt' || unit === 'juta') {
    baseNum *= 1000000;
  } else if (unit === 'm' || unit === 'miliar') {
    baseNum *= 1000000000;
  }

  const amount = Math.round(baseNum);
  if (amount <= 0 || isNaN(amount)) {
    return {
      success: false,
      error: 'Nominal tidak valid atau bernilai nol.',
      rawText: trimmed,
    };
  }

  // Determine transaction type
  const incomeKeywords = [
    'gaji', 'gajian', 'freelance', 'bonus', 'investasi', 'transfer masuk',
    'dapat', 'terima', 'penjualan', 'laku', 'komisi', 'cashback', 'hadiah', 'dividen'
  ];
  const isIncome = incomeKeywords.some((kw) => lower.includes(kw));
  const type = isIncome ? 'income' : 'expense';

  // Determine category
  let category = isIncome ? 'Lainnya' : 'Lainnya';
  let reasoning = 'Kategori default sesuai jenis transaksi.';

  if (isIncome) {
    if (lower.includes('freelance') || lower.includes('proyek') || lower.includes('klien')) {
      category = 'Freelance';
      reasoning = 'Terdeteksi pekerjaan lepas (freelance).';
    } else if (lower.includes('gaji') || lower.includes('gajian')) {
      category = 'Gaji';
      reasoning = 'Terdeteksi kata gaji/gajian sebagai penghasilan utama.';
    } else if (lower.includes('bonus') || lower.includes('thr') || lower.includes('insentif')) {
      category = 'Bonus';
      reasoning = 'Terdeteksi penerimaan bonus atau insentif.';
    } else if (lower.includes('investasi') || lower.includes('saham') || lower.includes('dividen') || lower.includes('reksadana')) {
      category = 'Investasi';
      reasoning = 'Terdeteksi hasil dari imbal hasil investasi.';
    } else if (lower.includes('transfer') || lower.includes('kiriman')) {
      category = 'Transfer Masuk';
      reasoning = 'Terdeteksi penerimaan transfer dana masuk.';
    }
  } else {
    if (lower.includes('makan') || lower.includes('kopi') || lower.includes('sarapan') || lower.includes('lunch') || lower.includes('dinner') || lower.includes('resto') || lower.includes('ayam') || lower.includes('nasi') || lower.includes('jajan') || lower.includes('minum') || lower.includes('martabak') || lower.includes('roti') || lower.includes('bakso') || lower.includes('mie') || lower.includes('sate') || lower.includes('snack')) {
      category = 'Makan & Minuman';
      reasoning = 'Terdeteksi pengeluaran untuk konsumsi makanan atau minuman.';
    } else if (lower.includes('bensin') || lower.includes('pertamax') || lower.includes('pertalite') || lower.includes('ojol') || lower.includes('grab') || lower.includes('gojek') || lower.includes('tol') || lower.includes('parkir') || lower.includes('transport')) {
      category = 'Transportasi';
      reasoning = 'Terdeteksi ongkos perjalanan, ojol, atau bahan bakar kendaraan.';
    } else if (lower.includes('belanja') || lower.includes('baju') || lower.includes('sepatu') || lower.includes('tas') || lower.includes('mall') || lower.includes('tokopedia') || lower.includes('shopee')) {
      category = 'Belanja';
      reasoning = 'Terdeteksi pembelian barang atau belanja retail.';
    } else if (lower.includes('nonton') || lower.includes('bioskop') || lower.includes('game') || lower.includes('steam') || lower.includes('hiburan') || lower.includes('konser') || lower.includes('karaoke')) {
      category = 'Hiburan';
      reasoning = 'Terdeteksi pengeluaran rekreasi atau hiburan.';
    } else if (lower.includes('listrik') || lower.includes('pln') || lower.includes('air') || lower.includes('pdam') || lower.includes('wifi') || lower.includes('indihome') || lower.includes('pulsa') || lower.includes('kuota') || lower.includes('tagihan')) {
      category = 'Tagihan & Utilitas';
      reasoning = 'Terdeteksi pembayaran tagihan rutin utilitas bulanan.';
    } else if (lower.includes('cicilan') || lower.includes('hutang') || lower.includes('paylater') || lower.includes('spaylater') || lower.includes('kredivo') || lower.includes('pinjaman')) {
      category = 'Hutang & Paylater';
      reasoning = 'Terdeteksi pembayaran cicilan atau kewajiban hutang/paylater.';
    } else if (lower.includes('sabun') || lower.includes('deterjen') || lower.includes('perabot') || lower.includes('galon') || lower.includes('gas') || lower.includes('rumah')) {
      category = 'Kebutuhan Rumah';
      reasoning = 'Terdeteksi belanja kebutuhan perlengkapan rumah tangga.';
    } else if (lower.includes('obat') || lower.includes('dokter') || lower.includes('klinik') || lower.includes('apotek') || lower.includes('vitamin') || lower.includes('rumah sakit')) {
      category = 'Kesehatan';
      reasoning = 'Terdeteksi pengeluaran medis, farmasi, atau kesehatan.';
    }
  }

  // Check against custom user categories if any matches
  for (const customCat of availableCategories) {
    const rawCustom = customCat.toLowerCase();
    const tokens = rawCustom.split(/[\s&/,]+/).filter((t) => t.length >= 3);
    if (lower.includes(rawCustom) || tokens.some((t) => lower.includes(t))) {
      category = customCat;
      reasoning = `Mencocokkan kategori kustom: "${customCat}".`;
      break;
    }
  }

  // Clean note by removing amount part if desired, or use sentence directly
  const note = trimmed;

  return {
    success: true,
    amount,
    type,
    typeReasoning: isIncome ? 'Penerimaan dana atau penghasilan' : 'Pengeluaran uang',
    category,
    confidence: 0.92,
    reasoning,
    note,
    occurredAt: new Date().toISOString(),
  };
}

/**
 * Builds the system prompt for 9Router chat completions to parse natural language financial chat into structured JSON.
 */
export function buildParserSystemPrompt(availableCategories = []) {
  const catListStr = availableCategories.length > 0
    ? `Kategori yang tersedia saat ini: [${availableCategories.join(', ')}]`
    : 'Kategori standar pengeluaran: [Makan & Minuman, Transportasi, Belanja, Hiburan, Tagihan & Utilitas, Hutang & Paylater, Kebutuhan Rumah, Kesehatan, Lainnya]. Kategori standar pemasukan: [Gaji, Freelance, Bonus, Investasi, Transfer Masuk, Lainnya].';

  return `Kamu adalah AI Parser Keuangan untuk aplikasi Moneta (Catat Uang AI).
Tugasmu: membaca kalimat bahasa Indonesia bebas dari pengguna dan mengekstrak informasi transaksi keuangan secara akurat ke dalam format JSON murni.

Aturan Penting:
1. ${catListStr}
2. Tentukan jenis transaksi: "expense" (pengeluaran) atau "income" (pemasukan).
3. Ekstrak nominal uang sebagai angka murni (mis. "25rb" -> 25000, "1.5jt" -> 1500000, "50k" -> 50000).
4. Berikan nilai confidenceScore antara 0.0 sampai 1.0.
5. Berikan alasan kategorisasi (reasoning) singkat dalam 1 kalimat Bahasa Indonesia.
6. Berikan alasan penentuan jenis (typeReasoning) singkat dalam 1 kalimat Bahasa Indonesia.
7. Jika kalimat BUKAN transaksi keuangan yang valid (mis. obrolan santai, sapaan tanpa nominal uang), kembalikan {"success": false, "error": "Alasan kenapa gagal"}.
8. Keluarkan HANYA string JSON valid tanpa format markdown (tanpa \`\`\`json).

Contoh output sukses:
{
  "success": true,
  "amount": 25000,
  "type": "expense",
  "typeReasoning": "Pengeluaran pembelian makanan",
  "category": "Makan & Minuman",
  "confidence": 0.95,
  "reasoning": "Kata kunci ayam geprek dan makan siang merujuk ke Makan & Minuman",
  "note": "Makan siang ayam geprek"
}`;
}

/**
 * Service to parse natural language financial chat using 9Router API (with automatic fallback to heuristic parser).
 */
export class AiParserService {
  constructor(options = {}) {
    this.apiKey = options.apiKey || process.env.NINEROUTER_API_KEY;
    this.baseUrl = (options.baseUrl || DEFAULT_9ROUTER_BASE_URL).replace(/\/$/, '');
    this.model = options.model || DEFAULT_MODEL;
    this.fetchFn = options.fetchFn || globalThis.fetch;
    this.timeoutMs = options.timeoutMs || 8000;
  }

  /**
   * Parse natural language text into structured transaction data.
   */
  async parseTransaction(text, options = {}) {
    const trimmed = (text || '').trim();
    if (!trimmed) {
      return {
        success: false,
        error: 'Pesan tidak boleh kosong.',
        rawText: text,
      };
    }

    const availableCategories = options.availableCategories || [];

    // If no 9Router API key configured, use local heuristic parser
    if (!this.apiKey) {
      return heuristicParseIndonesian(trimmed, availableCategories);
    }

    try {
      const systemPrompt = buildParserSystemPrompt(availableCategories);
      const endpoint = `${this.baseUrl}/chat/completions`;

      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), this.timeoutMs);

      const response = await this.fetchFn(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify({
          model: this.model,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: trimmed },
          ],
          temperature: 0.1,
          response_format: { type: 'json_object' },
        }),
        signal: controller.signal,
      });

      clearTimeout(timer);

      if (!response.ok) {
        console.warn(`[9Router] API error ${response.status}. Falling back to heuristic parser.`);
        return heuristicParseIndonesian(trimmed, availableCategories);
      }

      const data = await response.json();
      const content = data.choices?.[0]?.message?.content;

      if (!content) {
        return heuristicParseIndonesian(trimmed, availableCategories);
      }

      const parsed = JSON.parse(content);

      if (!parsed.success) {
        return {
          success: false,
          error: parsed.error || 'AI tidak dapat mendeteksi informasi transaksi.',
          rawText: trimmed,
        };
      }

      return {
        success: true,
        amount: Number(parsed.amount) || 0,
        type: parsed.type === 'income' ? 'income' : 'expense',
        typeReasoning: parsed.typeReasoning || (parsed.type === 'income' ? 'Pemasukan uang' : 'Pengeluaran uang'),
        category: parsed.category || 'Lainnya',
        confidence: typeof parsed.confidence === 'number' ? parsed.confidence : 0.9,
        reasoning: parsed.reasoning || 'Kategori hasil analisis AI.',
        note: parsed.note || trimmed,
        occurredAt: new Date().toISOString(),
      };
    } catch (err) {
      console.warn('[9Router] Failed or timed out. Falling back to heuristic parser:', err.message);
      return heuristicParseIndonesian(trimmed, availableCategories);
    }
  }
}

export const defaultAiParser = new AiParserService();
