import dotenv from 'dotenv';
import { env } from '../config/env.js';
dotenv.config();

const DEFAULT_9ROUTER_BASE_URL = env.NINEROUTER_API_URL;
const DEFAULT_MODEL = env.NINEROUTER_MODEL;

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
 * Heuristic classifier for transaction category, transaction type (income vs expense),
 * confidence score, AI reasoning, and alternative categories.
 */
export function heuristicClassifyIndonesian(text, options = {}) {
  const trimmed = (text || '').trim();
  if (!trimmed) {
    return {
      success: false,
      error: 'Teks atau kalimat transaksi wajib diisi.',
      rawSentence: text,
    };
  }

  const lower = trimmed.toLowerCase();

  // If greeting or casual non-transaction
  const greetingPhrases = ['halo', 'hai', 'test', 'tes', 'ping', 'apa kabar', 'bingung', 'tolong', 'selamat pagi', 'selamat siang', 'selamat malam', 'assalamualaikum'];
  const hasGreeting = greetingPhrases.some((g) => lower.includes(g));
  const hasFinanceKeywords = /(\b(rb|ribu|jt|juta|rp|beli|bayar|gaji|bensin|sewa|tagihan|cicilan|investasi|bonus)\b|\d+\s*(k|rb|jt|ribu|juta)?\b)/i.test(lower);
  if (hasGreeting && !hasFinanceKeywords) {
    return {
      success: false,
      error: 'Kalimat bukan merupakan catatan transaksi keuangan.',
      fallbackManual: true,
      rawSentence: trimmed,
    };
  }

  // Parse amount if present:
  // First match Indonesian dot-separated thousands: "8.500.000", "1.250.000", "25.000"
  let amount = null;
  const amountWithDotRegex = /\b(\d{1,3}(?:\.\d{3})+)(?:,\d+)?\b/;
  const amountDotMatch = lower.match(amountWithDotRegex);
  if (amountDotMatch) {
    const cleanNum = parseInt(amountDotMatch[1].replace(/\./g, ''), 10);
    if (!isNaN(cleanNum) && cleanNum > 0) {
      amount = cleanNum;
    }
  }

  if (!amount) {
    const amountRegex = /(\d+(?:[.,]\d+)?)\s*(rb|k|ribu|jt|juta|m|miliar)?\b/i;
    const match = lower.match(amountRegex);
    if (match) {
      let baseNum = parseFloat(match[1].replace(',', '.'));
      const unit = (match[2] || '').toLowerCase();
      if (unit === 'rb' || unit === 'k' || unit === 'ribu') {
        baseNum *= 1000;
      } else if (unit === 'jt' || unit === 'juta') {
        baseNum *= 1000000;
      } else if (unit === 'm' || unit === 'miliar') {
        baseNum *= 1000000000;
      }
      const parsedAmount = Math.round(baseNum);
      if (parsedAmount > 0 && !isNaN(parsedAmount)) {
        amount = parsedAmount;
      }
    }
  }

  // Determine transaction type (income vs expense)
  let type = options.forcedType;
  let typeReasoning = '';

  const incomeKeywords = [
    'gaji', 'gajian', 'freelance', 'bonus', 'investasi', 'transfer masuk',
    'dapat', 'terima', 'penjualan', 'laku', 'komisi', 'cashback', 'hadiah', 'dividen',
    'proyek', 'upah', 'honor', 'payroll', 'salary', 'penghasilan', 'omset'
  ];

  const matchedIncomeKeyword = incomeKeywords.find((kw) => lower.includes(kw));

  if (type !== 'income' && type !== 'expense') {
    if (matchedIncomeKeyword) {
      type = 'income';
      typeReasoning = `Kata kunci "${matchedIncomeKeyword}" menandakan penerimaan pemasukan/dana.`;
    } else {
      type = 'expense';
      typeReasoning = 'Kalimat terdeteksi sebagai pengeluaran atau konsumsi uang.';
    }
  } else {
    typeReasoning = type === 'income'
      ? 'Jenis transaksi ditentukan sebagai pemasukan.'
      : 'Jenis transaksi ditentukan sebagai pengeluaran.';
  }

  // Categories matching
  const availableCategories = options.availableCategories || [];
  let category = '';
  let aiReasoning = '';
  let confidenceScore = 0.95;
  let isCustomCategory = false;
  let alternativeCategories = [];

  const defaultCategoryNames = new Set([
    'makan & minuman', 'transportasi', 'belanja', 'hiburan',
    'tagihan & utilitas', 'hutang & paylater', 'kebutuhan rumah',
    'kesehatan', 'lainnya', 'gaji', 'freelance', 'bonus',
    'investasi', 'transfer masuk', 'belum dikategorikan'
  ]);

  // Check custom user categories first if provided (exclude default categories)
  if (Array.isArray(availableCategories) && availableCategories.length > 0) {
    for (const item of availableCategories) {
      const catName = typeof item === 'string' ? item : item.name;
      if (!catName) continue;
      const rawCustom = catName.toLowerCase().trim();

      // Skip default categories so built-in rules take priority
      if (defaultCategoryNames.has(rawCustom)) continue;
      if (typeof item === 'object' && (item.is_default === 1 || item.user_id === null)) continue;

      const catType = typeof item === 'string' ? null : item.type;
      if (catType && catType !== type) continue;

      if (lower.includes(rawCustom)) {
        category = catName;
        isCustomCategory = true;
        aiReasoning = `Cocok dengan kategori kustom: "${catName}".`;
        confidenceScore = 0.96;
        break;
      }

      const tokens = rawCustom.split(/[\s&/,]+/).filter((t) => t.length >= 3 && !['dan', 'atau', 'untuk', 'masuk', 'keluar'].includes(t));
      if (tokens.length > 0 && tokens.some((t) => lower.includes(t))) {
        category = catName;
        isCustomCategory = true;
        aiReasoning = `Cocok dengan kategori kustom: "${catName}".`;
        confidenceScore = 0.96;
        break;
      }
    }
  }

  // Standard category heuristic
  if (!category) {
    if (type === 'income') {
      if (lower.includes('freelance') || lower.includes('proyek') || lower.includes('klien') || lower.includes('fee')) {
        category = 'Freelance';
        aiReasoning = 'Kata kunci pekerjaan lepas atau proyek terdeteksi sebagai pendapatan freelance.';
        confidenceScore = 0.94;
        alternativeCategories = ['Bonus', 'Gaji', 'Transfer Masuk', 'Investasi'];
      } else if (lower.includes('gaji') || lower.includes('gajian') || lower.includes('payroll') || lower.includes('salary')) {
        category = 'Gaji';
        aiReasoning = 'Kata kunci gaji/payroll cocok dengan pendapatan upah bulanan utama.';
        confidenceScore = 0.99;
        alternativeCategories = ['Bonus', 'Transfer Masuk', 'Freelance', 'Investasi'];
      } else if (lower.includes('bonus') || lower.includes('thr') || lower.includes('insentif') || lower.includes('komisi') || lower.includes('hadiah')) {
        category = 'Bonus';
        aiReasoning = 'Terdeteksi penerimaan insentif, komisi, atau bonus tambahan.';
        confidenceScore = 0.93;
        alternativeCategories = ['Freelance', 'Gaji', 'Transfer Masuk'];
      } else if (lower.includes('investasi') || lower.includes('saham') || lower.includes('dividen') || lower.includes('reksadana') || lower.includes('crypto')) {
        category = 'Investasi';
        aiReasoning = 'Terdeteksi imbal hasil instrumen investasi atau dividen.';
        confidenceScore = 0.95;
        alternativeCategories = ['Transfer Masuk', 'Bonus', 'Freelance'];
      } else if (lower.includes('transfer masuk') || lower.includes('kiriman') || lower.includes('ditransfer') || lower.includes('dapat kiriman')) {
        category = 'Transfer Masuk';
        aiReasoning = 'Terdeteksi penerimaan dana atau kiriman transfer masuk.';
        confidenceScore = 0.92;
        alternativeCategories = ['Bonus', 'Gaji', 'Freelance'];
      } else {
        category = 'Belum Dikategorikan';
        aiReasoning = 'Tebakan kategori tidak pasti: kalimat tidak mengandung kata kunci pemasukan yang spesifik.';
        confidenceScore = 0.35;
        alternativeCategories = ['Gaji', 'Transfer Masuk', 'Freelance', 'Bonus', 'Lainnya'];
      }
    } else {
      // Expense categories
      if (lower.includes('makan') || lower.includes('kopi') || lower.includes('sarapan') || lower.includes('lunch') || lower.includes('dinner') || lower.includes('resto') || lower.includes('ayam') || lower.includes('nasi') || lower.includes('jajan') || lower.includes('minum') || lower.includes('martabak') || lower.includes('roti') || lower.includes('bakso') || lower.includes('mie') || lower.includes('sate') || lower.includes('snack') || lower.includes('cafe') || lower.includes('kafe') || lower.includes('warung') || lower.includes('kuliner') || lower.includes('boba') || lower.includes('burger') || lower.includes('pizza') || lower.includes('gofood') || lower.includes('grabfood') || lower.includes('shopeefood')) {
        category = 'Makan & Minuman';
        aiReasoning = 'Kata kunci konsumsi makanan atau minuman terdeteksi sebagai kebutuhan pangan.';
        confidenceScore = 0.98;
        alternativeCategories = ['Jajan & Camilan', 'Kebutuhan Pribadi', 'Belanja', 'Hiburan'];
      } else if (lower.includes('bensin') || lower.includes('pertamax') || lower.includes('pertalite') || lower.includes('shell') || lower.includes('ojol') || lower.includes('grab') || lower.includes('gojek') || lower.includes('maxim') || lower.includes('tol') || lower.includes('parkir') || lower.includes('transport') || lower.includes('kereta') || lower.includes('krl') || lower.includes('mrt') || lower.includes('motor') || lower.includes('mobil') || lower.includes('servis')) {
        category = 'Transportasi';
        aiReasoning = 'Kata kunci bahan bakar, ojek online, atau transportasi terdeteksi.';
        confidenceScore = 0.96;
        alternativeCategories = ['Perawatan Kendaraan', 'Kebutuhan Rumah', 'Operasional'];
      } else if (lower.includes('belanja') || lower.includes('baju') || lower.includes('sepatu') || lower.includes('tas') || lower.includes('mall') || lower.includes('tokopedia') || lower.includes('shopee') || lower.includes('lazada') || lower.includes('minimarket') || lower.includes('indomaret') || lower.includes('alfamart') || lower.includes('buku') || lower.includes('gramedia') || lower.includes('jaket') || lower.includes('celana') || lower.includes('kaos')) {
        category = 'Belanja';
        aiReasoning = 'Kata kunci belanja ritel, marketplace, atau perlengkapan terdeteksi.';
        confidenceScore = 0.94;
        alternativeCategories = ['Kebutuhan Rumah', 'Makan & Minuman', 'Hiburan', 'Lainnya'];
      } else if (lower.includes('nonton') || lower.includes('bioskop') || lower.includes('game') || lower.includes('steam') || lower.includes('hiburan') || lower.includes('konser') || lower.includes('karaoke') || lower.includes('netflix') || lower.includes('spotify') || lower.includes('disney')) {
        category = 'Hiburan';
        aiReasoning = 'Layanan hiburan rekreasi atau streaming media digital terdeteksi.';
        confidenceScore = 0.93;
        alternativeCategories = ['Tagihan & Utilitas', 'Langganan Digital', 'Belanja', 'Lainnya'];
      } else if (lower.includes('listrik') || lower.includes('pln') || lower.includes('air') || lower.includes('pdam') || lower.includes('wifi') || lower.includes('indihome') || lower.includes('pulsa') || lower.includes('kuota') || lower.includes('tagihan') || lower.includes('bpjs')) {
        category = 'Tagihan & Utilitas';
        aiReasoning = 'Kata kunci tagihan listrik, air, pulsa, atau utilitas rutin rumah tangga terdeteksi.';
        confidenceScore = 0.97;
        alternativeCategories = ['Kebutuhan Rumah', 'Hutang & Paylater', 'Operasional'];
      } else if (lower.includes('cicilan') || lower.includes('hutang') || lower.includes('paylater') || lower.includes('spaylater') || lower.includes('kredivo') || lower.includes('pinjaman') || lower.includes('angsuran')) {
        category = 'Hutang & Paylater';
        aiReasoning = 'Kata kunci cicilan pinjaman atau kewajiban hutang/paylater terdeteksi.';
        confidenceScore = 0.95;
        alternativeCategories = ['Tagihan & Utilitas', 'Kebutuhan Rumah', 'Lainnya'];
      } else if (lower.includes('sabun') || lower.includes('deterjen') || lower.includes('perabot') || lower.includes('galon') || lower.includes('gas') || lower.includes('rumah') || lower.includes('lpg')) {
        category = 'Kebutuhan Rumah';
        aiReasoning = 'Kata kunci perlengkapan operasional rumah tangga terdeteksi.';
        confidenceScore = 0.92;
        alternativeCategories = ['Belanja', 'Tagihan & Utilitas', 'Lainnya'];
      } else if (lower.includes('obat') || lower.includes('dokter') || lower.includes('klinik') || lower.includes('apotek') || lower.includes('vitamin') || lower.includes('rumah sakit')) {
        category = 'Kesehatan';
        aiReasoning = 'Kata kunci medis, farmasi, atau kesehatan terdeteksi.';
        confidenceScore = 0.95;
        alternativeCategories = ['Kebutuhan Rumah', 'Belanja', 'Lainnya'];
      } else {
        category = 'Belum Dikategorikan';
        aiReasoning = 'Tebakan kategori tidak pasti: kalimat tidak mengandung kata kunci yang spesifik.';
        confidenceScore = 0.35;
        alternativeCategories = ['Makan & Minuman', 'Belanja', 'Transportasi', 'Kebutuhan Rumah', 'Lainnya'];
      }
    }
  }

  // Fallback alternative categories if needed
  if (alternativeCategories.length === 0) {
    if (type === 'income') {
      alternativeCategories = ['Gaji', 'Freelance', 'Bonus', 'Transfer Masuk', 'Investasi']
        .filter((c) => c !== category)
        .slice(0, 4);
    } else {
      alternativeCategories = ['Makan & Minuman', 'Transportasi', 'Belanja', 'Hiburan', 'Tagihan & Utilitas']
        .filter((c) => c !== category)
        .slice(0, 4);
    }
  }

  const confidenceLevel = confidenceScore >= 0.85 ? 'high' : (confidenceScore >= 0.70 ? 'medium' : 'low');

  return {
    success: true,
    rawSentence: trimmed,
    type,
    typeReasoning,
    category,
    confidenceScore,
    confidence: confidenceScore,
    confidenceLevel,
    aiReasoning,
    reasoning: aiReasoning,
    isGuessedCategory: true,
    isCustomCategory,
    alternativeCategories,
    amount,
  };
}

/**
 * Builds the system prompt for 9Router chat completions to classify category and type.
 */
export function buildClassifierSystemPrompt(availableCategories = []) {
  const catListStr = availableCategories.length > 0
    ? `Kategori yang tersedia saat ini: [${availableCategories.join(', ')}]`
    : 'Kategori standar pengeluaran: [Makan & Minuman, Transportasi, Belanja, Hiburan, Tagihan & Utilitas, Hutang & Paylater, Kebutuhan Rumah, Kesehatan, Lainnya]. Kategori standar pemasukan: [Gaji, Freelance, Bonus, Investasi, Transfer Masuk, Lainnya].';

  return `Kamu adalah AI Classifier Keuangan untuk aplikasi Moneta (Catat Uang AI).
Tugasmu: mengklasifikasikan kalimat atau catatan transaksi keuangan ke dalam jenis transaksi ("expense" atau "income") dan kategori yang paling tepat.

Aturan Penting:
1. ${catListStr}
2. Tentukan jenis transaksi ("type"): "expense" (pengeluaran) atau "income" (pemasukan).
3. Berikan alasan penentuan jenis ("typeReasoning") dalam 1 kalimat Bahasa Indonesia.
4. Tentukan kategori transaksi ("category"). Jika ragu/ambigu, gunakan "Belum Dikategorikan" atau "Lainnya".
5. Berikan nilai confidenceScore antara 0.0 sampai 1.0 (tinggi: >= 0.85, sedang: 0.70 - 0.84, rendah: < 0.70).
6. Berikan alasan kategorisasi ("aiReasoning") dalam 1 kalimat Bahasa Indonesia.
7. Berikan 3-4 alternatif kategori yang masuk akal ("alternativeCategories": string[]).
8. Jika ada nominal uang dalam teks, ekstrak sebagai angka murni ("amount"). Jika tidak ada, isi null.
9. Jika kalimat BUKAN transaksi keuangan (mis. sapaan santai), kembalikan {"success": false, "error": "Kalimat bukan transaksi", "fallbackManual": true}.
10. Keluarkan HANYA string JSON valid tanpa format markdown (tanpa \`\`\`json).

Contoh output:
{
  "success": true,
  "type": "expense",
  "typeReasoning": "Pengeluaran pembelian minuman konsumsi.",
  "category": "Makan & Minuman",
  "confidenceScore": 0.95,
  "aiReasoning": "Kata kunci kopi kenangan terdeteksi sebagai konsumsi minuman harian.",
  "alternativeCategories": ["Belanja", "Hiburan", "Lainnya"],
  "amount": 24000
}`;
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
    this.apiKey = options.apiKey || env.NINEROUTER_API_KEY;
    this.baseUrl = (options.baseUrl || env.NINEROUTER_API_URL || DEFAULT_9ROUTER_BASE_URL).replace(/\/$/, '');
    this.model = options.model || env.NINEROUTER_MODEL || DEFAULT_MODEL;
    this.fetchFn = options.fetchFn || globalThis.fetch;
    this.timeoutMs = options.timeoutMs || env.NINEROUTER_TIMEOUT_MS;
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

  /**
   * Classify transaction text into category and transaction type (income vs expense),
   * along with confidence, reasoning, and alternative categories.
   */
  async classify(text, options = {}) {
    const trimmed = (text || '').trim();
    if (!trimmed) {
      return {
        success: false,
        error: 'Teks atau kalimat transaksi wajib diisi.',
        rawSentence: text,
      };
    }

    if (!this.apiKey) {
      return heuristicClassifyIndonesian(trimmed, options);
    }

    try {
      const availableCatNames = (options.availableCategories || []).map((c) =>
        typeof c === 'string' ? c : c.name
      );
      const systemPrompt = buildClassifierSystemPrompt(availableCatNames);
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
        console.warn(`[9Router] API error ${response.status}. Falling back to heuristic classifier.`);
        return heuristicClassifyIndonesian(trimmed, options);
      }

      const data = await response.json();
      const content = data.choices?.[0]?.message?.content;
      if (!content) {
        return heuristicClassifyIndonesian(trimmed, options);
      }

      const parsed = JSON.parse(content);
      if (!parsed.success && parsed.error) {
        return {
          success: false,
          error: parsed.error,
          fallbackManual: true,
          rawSentence: trimmed,
        };
      }

      const type = options.forcedType || (parsed.type === 'income' ? 'income' : 'expense');
      const confidenceScore = typeof parsed.confidenceScore === 'number'
        ? parsed.confidenceScore
        : (typeof parsed.confidence === 'number' ? parsed.confidence : 0.9);
      const confidenceLevel = confidenceScore >= 0.85 ? 'high' : (confidenceScore >= 0.70 ? 'medium' : 'low');

      return {
        success: true,
        rawSentence: trimmed,
        type,
        typeReasoning: parsed.typeReasoning || (type === 'income' ? 'Penerimaan pemasukan dana' : 'Pengeluaran pembelian/konsumsi'),
        category: parsed.category || 'Lainnya',
        confidenceScore,
        confidence: confidenceScore,
        confidenceLevel,
        aiReasoning: parsed.aiReasoning || parsed.reasoning || 'Kategori hasil klasifikasi AI.',
        reasoning: parsed.aiReasoning || parsed.reasoning || 'Kategori hasil klasifikasi AI.',
        isGuessedCategory: true,
        isCustomCategory: Boolean(parsed.isCustomCategory),
        alternativeCategories: Array.isArray(parsed.alternativeCategories) && parsed.alternativeCategories.length > 0
          ? parsed.alternativeCategories
          : (type === 'income' ? ['Gaji', 'Freelance', 'Bonus', 'Transfer Masuk'] : ['Makan & Minuman', 'Transportasi', 'Belanja', 'Hiburan']),
        amount: typeof parsed.amount === 'number' ? parsed.amount : (heuristicClassifyIndonesian(trimmed, options).amount || null),
      };
    } catch (err) {
      console.warn('[9Router] Failed or timed out. Falling back to heuristic classifier:', err.message);
      return heuristicClassifyIndonesian(trimmed, options);
    }
  }
}

export const defaultAiParser = new AiParserService();
