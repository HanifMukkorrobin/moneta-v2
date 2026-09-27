/**
 * Debt Service (Layanan Catatan Hutang / Paylater & Cicilan)
 *
 * Mengelola operasi tabel `debts` di SQLite, kalkulasi jatuh tempo,
 * status pembayaran, dan ringkasan hutang untuk Moneta AI.
 */

import { formatRupiah } from './dailyAverageSpendingService.js';

export const VALID_DEBT_TYPES = [
  'paylater',
  'cicilan',
  'kartu_kredit',
  'kartuKredit',
  'pinjaman_pribadi',
  'pinjamanPribadi',
  'lainnya',
];

export const VALID_DEBT_STATUSES = ['active', 'paid', 'lunas', 'aktif'];

/**
 * Normalisasi tipe hutang agar sesuai standar
 */
export function normalizeDebtType(type) {
  if (!type) return 'paylater';
  const clean = String(type).trim();
  const lower = clean.toLowerCase();
  if (lower === 'kartukredit' || lower === 'kartu_kredit' || lower === 'kartu' || lower === 'credit_card') return 'kartu_kredit';
  if (lower === 'pinjamanpribadi' || lower === 'pinjaman_pribadi' || lower === 'pinjaman' || lower === 'personal' || lower === 'pribadi') return 'pinjaman_pribadi';
  return clean.toLowerCase();
}

/**
 * Normalisasi status hutang
 */
export function normalizeDebtStatus(status) {
  if (!status) return 'active';
  const s = String(status).trim().toLowerCase();
  if (s === 'lunas') return 'paid';
  if (s === 'aktif') return 'active';
  return s;
}

/**
 * Menghitung selisih hari menuju jatuh tempo dari tanggal target
 *
 * @param {string|Date} dueDate
 * @param {string|Date} [referenceDate=new Date()]
 * @returns {number} Selisih hari (positif: masa depan, negatif: terlambat, 0: hari ini)
 */
export function calculateDaysUntilDue(dueDate, referenceDate = new Date()) {
  const due = new Date(dueDate);
  const ref = new Date(referenceDate);

  const dueMidnight = new Date(due.getFullYear(), due.getMonth(), due.getDate());
  const refMidnight = new Date(ref.getFullYear(), ref.getMonth(), ref.getDate());

  const diffMs = dueMidnight.getTime() - refMidnight.getTime();
  return Math.round(diffMs / (1000 * 60 * 60 * 24));
}

/**
 * Menghasilkan label status jatuh tempo dalam Bahasa Indonesia
 */
export function getDueStatusLabel(daysUntilDue, isPaid) {
  if (isPaid) return 'Lunas';
  if (daysUntilDue < 0) return `Lewat Jatuh Tempo (${Math.abs(daysUntilDue)} hari)`;
  if (daysUntilDue === 0) return 'Jatuh Tempo Hari Ini';
  if (daysUntilDue === 1) return 'Jatuh Tempo Besok';
  return `${daysUntilDue} hari lagi`;
}

/**
 * Format objek baris hutang dari database menjadi objek siap pakai
 */
export function formatDebtRow(row, referenceDate = new Date()) {
  if (!row) return null;

  const totalAmount = Number(row.total_amount) || 0;
  const remainingAmount = Number(row.remaining_amount) || 0;
  const paidAmount = Number(row.paid_amount) || Math.max(0, totalAmount - remainingAmount);

  const isPaid = row.status === 'paid' || row.status === 'lunas' || remainingAmount <= 0;
  const daysUntilDue = calculateDaysUntilDue(row.due_date, referenceDate);
  const isDueSoon = !isPaid && daysUntilDue >= 0 && daysUntilDue <= 3;
  const isOverdue = !isPaid && daysUntilDue < 0;

  const progressRatio = totalAmount > 0 ? Math.min(1.0, Math.max(0.0, paidAmount / totalAmount)) : 1.0;
  const progressPercent = Math.round(progressRatio * 100);

  const monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];
  let formattedDueDate = row.due_date;
  try {
    const d = new Date(row.due_date);
    if (!isNaN(d.getTime())) {
      const m = monthNames[d.getMonth()];
      formattedDueDate = `${d.getDate()} ${m} ${d.getFullYear()}`;
    }
  } catch {}

  return {
    id: row.id,
    userId: row.user_id,
    name: row.name,
    totalAmount,
    remainingAmount,
    paidAmount,
    dueDate: row.due_date,
    status: isPaid ? 'paid' : (row.status || 'active'),
    type: row.type || 'paylater',
    notes: row.notes || null,
    isPaid,
    isDueSoon,
    isOverdue,
    daysUntilDue,
    dueStatusLabel: getDueStatusLabel(daysUntilDue, isPaid),
    progressRatio,
    progressPercent,
    formattedTotalAmount: formatRupiah(totalAmount),
    formattedRemainingAmount: formatRupiah(remainingAmount),
    formattedPaidAmount: formatRupiah(paidAmount),
    formattedDueDate,
    paidAt: row.paid_at || null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/**
 * Membuat catatan hutang baru
 *
 * @param {import('better-sqlite3').Database} db
 * @param {Object} debtData
 * @returns {Object}
 */
export function createDebt(db, {
  userId,
  name,
  totalAmount,
  remainingAmount,
  dueDate,
  type = 'paylater',
  notes = null,
  status = null,
}) {
  if (!userId) {
    throw new Error('userId wajib diisi untuk membuat catatan hutang.');
  }
  if (!name || String(name).trim() === '') {
    throw new Error('Nama hutang/paylater tidak boleh kosong.');
  }

  const numTotal = Number(totalAmount);
  if (isNaN(numTotal) || numTotal <= 0) {
    throw new Error('Total nominal hutang harus berupa angka lebih besar dari 0.');
  }

  const numRemaining = remainingAmount !== undefined && remainingAmount !== null
    ? Number(remainingAmount)
    : numTotal;

  if (isNaN(numRemaining) || numRemaining < 0) {
    throw new Error('Sisa nominal hutang tidak boleh negatif.');
  }

  if (!dueDate) {
    throw new Error('Tanggal jatuh tempo (dueDate) wajib diisi.');
  }

  // Validasi format tanggal YYYY-MM-DD
  const dueDateStr = String(dueDate).slice(0, 10);
  if (isNaN(new Date(dueDateStr).getTime())) {
    throw new Error('Format tanggal jatuh tempo (dueDate) tidak valid.');
  }

  const normalizedType = normalizeDebtType(type);
  const calculatedStatus = status
    ? normalizeDebtStatus(status)
    : (numRemaining <= 0 ? 'paid' : 'active');

  const paidAmount = Math.max(0, numTotal - numRemaining);
  const paidAt = calculatedStatus === 'paid' ? new Date().toISOString() : null;

  const stmt = db.prepare(`
    INSERT INTO debts (
      user_id, name, total_amount, remaining_amount, paid_amount,
      due_date, status, type, notes, paid_at, created_at, updated_at
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
  `);

  const result = stmt.run(
    userId,
    String(name).trim(),
    numTotal,
    numRemaining,
    paidAmount,
    dueDateStr,
    calculatedStatus,
    normalizedType,
    notes ? String(notes).trim() : null,
    paidAt
  );

  const row = db.prepare('SELECT * FROM debts WHERE id = ?').get(result.lastInsertRowid);
  return formatDebtRow(row);
}

/**
 * Mengambil daftar catatan hutang milik pengguna dengan filter dan pengurutan
 *
 * @param {import('better-sqlite3').Database} db
 * @param {number} userId
 * @param {Object} [filters={}]
 * @returns {Array<Object>}
 */
export function getDebtsByUserId(db, userId, {
  status = null,
  type = null,
  isDueSoon = null,
  isOverdue = null,
  filter = null,
  search = null,
  sortBy = 'due_date',
  sortOrder = 'ASC',
  limit = 100,
  offset = 0,
} = {}) {
  if (!userId) {
    throw new Error('userId wajib diisi untuk mengambil catatan hutang.');
  }

  let query = 'SELECT * FROM debts WHERE user_id = ?';
  const params = [userId];

  // Penanganan parameter filter ('active', 'paid', 'due_soon', 'overdue')
  let effectiveStatus = status;
  let effectiveDueSoon = isDueSoon;
  let effectiveOverdue = isOverdue;

  if (filter) {
    const f = String(filter).trim().toLowerCase();
    if (f === 'active' || f === 'aktif') effectiveStatus = 'active';
    else if (f === 'paid' || f === 'lunas') effectiveStatus = 'paid';
    else if (f === 'due_soon' || f === 'segera') effectiveDueSoon = true;
    else if (f === 'overdue' || f === 'lewat') effectiveOverdue = true;
  }

  if (effectiveStatus) {
    const normStatus = normalizeDebtStatus(effectiveStatus);
    query += ' AND status = ?';
    params.push(normStatus);
  }

  if (type) {
    const normType = normalizeDebtType(type);
    query += ' AND type = ?';
    params.push(normType);
  }

  if (search) {
    query += ' AND (name LIKE ? OR notes LIKE ?)';
    const searchPattern = `%${String(search).trim()}%`;
    params.push(searchPattern, searchPattern);
  }

  const validSortColumns = {
    due_date: 'due_date',
    dueDate: 'due_date',
    created_at: 'created_at',
    createdAt: 'created_at',
    remaining_amount: 'remaining_amount',
    remainingAmount: 'remaining_amount',
    total_amount: 'total_amount',
    totalAmount: 'total_amount',
    name: 'name',
  };

  const sortColumn = validSortColumns[sortBy] || 'due_date';
  const order = String(sortOrder).toUpperCase() === 'DESC' ? 'DESC' : 'ASC';

  query += ` ORDER BY ${sortColumn} ${order}, id ASC LIMIT ? OFFSET ?`;
  params.push(Number(limit) || 100, Number(offset) || 0);

  const rows = db.prepare(query).all(...params);
  let list = rows.map((r) => formatDebtRow(r));

  if (effectiveDueSoon === true || effectiveDueSoon === 'true') {
    list = list.filter((d) => d.isDueSoon);
  }
  if (effectiveOverdue === true || effectiveOverdue === 'true') {
    list = list.filter((d) => d.isOverdue);
  }

  return list;
}

/**
 * Mengambil satu catatan hutang berdasarkan ID
 */
export function getDebtById(db, id, userId = null) {
  if (!id) return null;

  let query = 'SELECT * FROM debts WHERE id = ?';
  const params = [id];

  if (userId) {
    query += ' AND user_id = ?';
    params.push(userId);
  }

  const row = db.prepare(query).get(...params);
  return row ? formatDebtRow(row) : null;
}

/**
 * Memperbarui catatan hutang
 */
export function updateDebt(db, id, userId, updates = {}) {
  const existing = getDebtById(db, id, userId);
  if (!existing) {
    throw new Error('Catatan hutang tidak ditemukan.');
  }

  const newName = updates.name !== undefined ? String(updates.name).trim() : existing.name;
  if (!newName) {
    throw new Error('Nama hutang tidak boleh kosong.');
  }

  const newTotal = updates.totalAmount !== undefined
    ? Number(updates.totalAmount)
    : (updates.total_amount !== undefined ? Number(updates.total_amount) : existing.totalAmount);
  if (isNaN(newTotal) || newTotal <= 0) {
    throw new Error('Total hutang harus lebih besar dari 0.');
  }

  let newRemaining = updates.remainingAmount !== undefined
    ? Number(updates.remainingAmount)
    : (updates.remaining_amount !== undefined ? Number(updates.remaining_amount) : existing.remainingAmount);
  if (isNaN(newRemaining) || newRemaining < 0) {
    throw new Error('Sisa hutang tidak boleh negatif.');
  }
  if (newRemaining > newTotal) {
    newRemaining = newTotal;
  }

  const newDueDate = updates.dueDate || updates.due_date || existing.dueDate;
  const newDueDateStr = String(newDueDate).slice(0, 10);
  if (isNaN(new Date(newDueDateStr).getTime())) {
    throw new Error('Format tanggal jatuh tempo tidak valid.');
  }

  const newType = updates.type ? normalizeDebtType(updates.type) : existing.type;
  const newNotes = updates.notes !== undefined ? (updates.notes ? String(updates.notes).trim() : null) : existing.notes;

  let newStatus = updates.status ? normalizeDebtStatus(updates.status) : existing.status;
  if (newRemaining <= 0) {
    newStatus = 'paid';
  } else if (newStatus === 'paid' && newRemaining > 0) {
    newStatus = 'active';
  }

  const newPaidAmount = Math.max(0, newTotal - newRemaining);
  const newPaidAt = newStatus === 'paid' ? (existing.paidAt || new Date().toISOString()) : null;

  const stmt = db.prepare(`
    UPDATE debts
    SET
      name = ?,
      total_amount = ?,
      remaining_amount = ?,
      paid_amount = ?,
      due_date = ?,
      status = ?,
      type = ?,
      notes = ?,
      paid_at = ?,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = ? AND user_id = ?
  `);

  stmt.run(
    newName,
    newTotal,
    newRemaining,
    newPaidAmount,
    newDueDateStr,
    newStatus,
    newType,
    newNotes,
    newPaidAt,
    id,
    userId
  );

  return getDebtById(db, id, userId);
}

/**
 * Menandai hutang sebagai lunas
 */
export function markDebtAsPaid(db, id, userId) {
  const existing = getDebtById(db, id, userId);
  if (!existing) {
    throw new Error('Catatan hutang tidak ditemukan.');
  }

  const stmt = db.prepare(`
    UPDATE debts
    SET
      remaining_amount = 0,
      paid_amount = total_amount,
      status = 'paid',
      paid_at = CURRENT_TIMESTAMP,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = ? AND user_id = ?
  `);

  stmt.run(id, userId);
  return getDebtById(db, id, userId);
}

/**
 * Membuka kembali hutang yang sudah lunas menjadi aktif
 */
export function reopenDebt(db, id, userId, newRemainingAmount = null) {
  const existing = getDebtById(db, id, userId);
  if (!existing) {
    throw new Error('Catatan hutang tidak ditemukan.');
  }

  const remaining = newRemainingAmount !== null && newRemainingAmount !== undefined
    ? Math.max(0, Number(newRemainingAmount))
    : existing.totalAmount;

  const paidAmount = Math.max(0, existing.totalAmount - remaining);

  const stmt = db.prepare(`
    UPDATE debts
    SET
      remaining_amount = ?,
      paid_amount = ?,
      status = 'active',
      paid_at = NULL,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = ? AND user_id = ?
  `);

  stmt.run(remaining, paidAmount, id, userId);
  return getDebtById(db, id, userId);
}

/**
 * Menghapus catatan hutang
 */
export function deleteDebt(db, id, userId) {
  const stmt = db.prepare('DELETE FROM debts WHERE id = ? AND user_id = ?');
  const res = stmt.run(id, userId);
  return res.changes > 0;
}

/**
 * Mengambil ringkasan hutang (total sisa, jatuh tempo terdekat, persentase terbayar, breakdown tipe)
 */
export function getDebtSummary(db, userId, referenceDate = new Date()) {
  if (!userId) {
    throw new Error('userId wajib diisi untuk mengambil ringkasan hutang.');
  }

  const allDebts = getDebtsByUserId(db, userId, { limit: 1000 });

  let totalDebtAmount = 0;
  let totalRemainingAmount = 0;
  let totalPaidAmount = 0;
  let activeDebtsCount = 0;
  let paidDebtsCount = 0;
  let dueSoonCount = 0;
  let overdueCount = 0;
  const dueSoonList = [];

  const breakdownByType = {
    paylater: { count: 0, totalAmount: 0, remainingAmount: 0, paidAmount: 0, label: 'Paylater' },
    cicilan: { count: 0, totalAmount: 0, remainingAmount: 0, paidAmount: 0, label: 'Cicilan' },
    pinjaman_pribadi: { count: 0, totalAmount: 0, remainingAmount: 0, paidAmount: 0, label: 'Pinjaman Pribadi' },
    kartu_kredit: { count: 0, totalAmount: 0, remainingAmount: 0, paidAmount: 0, label: 'Kartu Kredit' },
    lainnya: { count: 0, totalAmount: 0, remainingAmount: 0, paidAmount: 0, label: 'Lainnya' },
  };

  for (const debt of allDebts) {
    totalDebtAmount += debt.totalAmount;
    totalPaidAmount += debt.paidAmount;

    const t = debt.type || 'lainnya';
    if (!breakdownByType[t]) {
      breakdownByType[t] = { count: 0, totalAmount: 0, remainingAmount: 0, paidAmount: 0, label: t };
    }

    if (debt.isPaid) {
      paidDebtsCount += 1;
    } else {
      activeDebtsCount += 1;
      totalRemainingAmount += debt.remainingAmount;
      breakdownByType[t].count += 1;
      breakdownByType[t].remainingAmount += debt.remainingAmount;
      breakdownByType[t].totalAmount += debt.totalAmount;
      breakdownByType[t].paidAmount += debt.paidAmount;

      if (debt.isDueSoon) {
        dueSoonCount += 1;
        dueSoonList.push(debt);
      }
      if (debt.isOverdue) {
        overdueCount += 1;
      }
    }
  }

  const breakdown = Object.entries(breakdownByType).map(([typeKey, data]) => ({
    type: typeKey,
    label: data.label,
    count: data.count,
    totalAmount: data.totalAmount,
    remainingAmount: data.remainingAmount,
    paidAmount: data.paidAmount,
    formattedRemainingAmount: formatRupiah(data.remainingAmount),
    formattedTotalAmount: formatRupiah(data.totalAmount),
  }));

  const clearanceRatio = totalDebtAmount > 0
    ? Math.min(1.0, Math.max(0.0, totalPaidAmount / totalDebtAmount))
    : 1.0;
  const clearancePercent = Math.round(clearanceRatio * 100);

  return {
    userId,
    totalDebtsCount: allDebts.length,
    activeDebtsCount,
    paidDebtsCount,
    totalDebtAmount,
    totalRemainingAmount,
    totalPaidAmount,
    formattedTotalDebtAmount: formatRupiah(totalDebtAmount),
    formattedTotalRemainingAmount: formatRupiah(totalRemainingAmount),
    formattedTotalPaidAmount: formatRupiah(totalPaidAmount),
    clearanceRatio,
    clearancePercent,
    dueSoonCount,
    overdueCount,
    dueSoonList,
    hasDueSoon: dueSoonCount > 0,
    hasOverdue: overdueCount > 0,
    breakdown,
    breakdownByType,
    // snake_case aliases for API and UI compatibility
    total_debts_count: allDebts.length,
    active_debts_count: activeDebtsCount,
    paid_debts_count: paidDebtsCount,
    total_debt_amount: totalDebtAmount,
    total_remaining_amount: totalRemainingAmount,
    total_paid_amount: totalPaidAmount,
    formatted_total_debt_amount: formatRupiah(totalDebtAmount),
    formatted_total_remaining_amount: formatRupiah(totalRemainingAmount),
    formatted_total_paid_amount: formatRupiah(totalPaidAmount),
    clearance_ratio: clearanceRatio,
    clearance_percent: clearancePercent,
    due_soon_count: dueSoonCount,
    overdue_count: overdueCount,
  };
}

