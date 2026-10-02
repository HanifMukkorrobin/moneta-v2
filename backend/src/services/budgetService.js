import { env } from '../config/env.js';
import { getDaysInMonth, getMonthLabel, getMonthlyTotalsQuery } from './rekapQueryService.js';

/**
 * Formats a number as Indonesian Rupiah (e.g. "Rp 6.000.000")
 */
export function formatRupiah(amount) {
  const num = Math.round(Number(amount || 0));
  const absFormatted = Math.abs(num).toLocaleString('id-ID');
  return `Rp ${absFormatted}`;
}

/**
 * Maps a category name to one of the 3 budget buckets ('needs' | 'savings' | 'fun')
 */
export function inferBucketTypeFromCategory(categoryName = '', explicitBucket = null) {
  if (explicitBucket && ['needs', 'savings', 'fun'].includes(explicitBucket)) {
    return explicitBucket;
  }
  const lower = String(categoryName || '').toLowerCase();
  if (
    lower.includes('tabung') ||
    lower.includes('invest') ||
    lower.includes('reksadana') ||
    lower.includes('emas') ||
    lower.includes('darurat')
  ) {
    return 'savings';
  }
  if (
    lower.includes('hiburan') ||
    lower.includes('belanja') ||
    lower.includes('nongkrong') ||
    lower.includes('bioskop') ||
    lower.includes('game') ||
    lower.includes('hobi') ||
    lower.includes('skincare') ||
    lower.includes('jalan') ||
    lower.includes('liburan')
  ) {
    return 'fun';
  }
  return 'needs';
}

/**
 * Builds the 3 allocation buckets (Kebutuhan Pokok, Tabungan & Investasi, Hiburan & Keinginan)
 */
export function buildBudgetBuckets({
  totalBudget = 0,
  needsPct = env.DEFAULT_NEEDS_PCT,
  savingsPct = env.DEFAULT_SAVINGS_PCT,
  funPct = env.DEFAULT_FUN_PCT,
  needsSpent = 0,
  savingsSpent = 0,
  funSpent = 0,
  daysInMonth = 30,
  bucketCategories = { needs: [], savings: [], fun: [] },
}) {
  const numTotal = Number(totalBudget || 0);
  const nPct = Number(needsPct ?? env.DEFAULT_NEEDS_PCT);
  const sPct = Number(savingsPct ?? 30);
  const fPct = Number(funPct ?? 20);
  const days = Number(daysInMonth || 30);

  const makeBucket = (type, title, pct, spent, color, icon, categories = []) => {
    const amountLimit = Math.round(numTotal * (pct / 100));
    const amountSpent = Number(spent || 0);
    const rawRemaining = amountLimit - amountSpent;
    const amountRemaining = Math.max(0, rawRemaining);
    const overAmount = Math.max(0, amountSpent - amountLimit);
    const percentageUsed = amountLimit > 0 ? Math.round((amountSpent / amountLimit) * 1000) / 10 : 0;
    const remainingPercentage =
      amountLimit > 0
        ? Math.max(0, Math.min(100, Math.round((rawRemaining / amountLimit) * 1000) / 10))
        : 0;
    const progressRatio =
      amountLimit > 0
        ? Math.max(0, Math.min(1, Math.round((amountSpent / amountLimit) * 1000) / 1000))
        : 0;
    const isOverBudget = amountLimit > 0 ? amountSpent > amountLimit : amountSpent > 0;
    const dailySafeSpend =
      amountRemaining > 0 && days > 0 ? Math.round(amountRemaining / days) : 0;
    const formattedRemaining = formatRupiah(amountRemaining);
    const formattedRemainingWithSign =
      rawRemaining < 0 ? `- ${formatRupiah(Math.abs(rawRemaining))}` : formattedRemaining;

    return {
      type,
      title,
      percentage: pct,
      nominalPos: amountLimit,
      amountLimit,
      amountSpent,
      amountRemaining,
      sisaBatas: amountRemaining,
      rawRemaining,
      overAmount,
      percentageUsed,
      remainingPercentage,
      progressRatio,
      isOverBudget,
      dailySafeSpend,
      statusLabel: isOverBudget ? 'Melebihi Limit!' : `Sisa ${formattedRemaining}`,
      color,
      icon,
      formattedLimit: formatRupiah(amountLimit),
      formattedNominalPos: formatRupiah(amountLimit),
      formattedSpent: formatRupiah(amountSpent),
      formattedRemaining,
      formattedRemainingWithSign,
      formattedOverAmount: formatRupiah(overAmount),
      formattedDailySafeSpend: `${formatRupiah(dailySafeSpend)} / hari`,
      categories,
    };
  };

  if (numTotal <= 0) {
    return [];
  }

  return [
    makeBucket(
      'needs',
      'Kebutuhan Pokok',
      nPct,
      needsSpent,
      '#2563EB',
      'home_work_rounded',
      bucketCategories.needs || []
    ),
    makeBucket(
      'savings',
      'Tabungan & Investasi',
      sPct,
      savingsSpent,
      '#10B981',
      'savings_rounded',
      bucketCategories.savings || []
    ),
    makeBucket(
      'fun',
      'Hiburan & Keinginan',
      fPct,
      funSpent,
      '#8B5CF6',
      'celebration_rounded',
      bucketCategories.fun || []
    ),
  ];
}

/**
 * Pure service calculation for "Sisa Batas Bulan Berjalan" and "Nominal Tiap Pos" (50/30/20 & custom %)
 */
export function calculateRemainingAndBucketNominals({
  month = new Date().toISOString().slice(0, 7),
  totalBudget = 0,
  totalSpent = 0,
  needsPct = 50,
  savingsPct = 30,
  funPct = 20,
  needsSpent = 0,
  savingsSpent = 0,
  funSpent = 0,
  bucketCategories = { needs: [], savings: [], fun: [] },
  categoryBudgets = [],
} = {}) {
  const numBudget = Number(totalBudget || 0);
  const numSpent = Number(totalSpent || 0);
  const nPct = Number(needsPct ?? 50);
  const sPct = Number(savingsPct ?? 30);
  const fPct = Number(funPct ?? 20);

  const monthLabel = getMonthLabel(month);
  const daysInMonth = getDaysInMonth(month);

  const totalRemaining = numBudget - numSpent;
  const remainingSafe = Math.max(0, totalRemaining);
  const overBudgetAmount = Math.max(0, numSpent - numBudget);
  const percentageUsed = numBudget > 0 ? Math.round((numSpent / numBudget) * 1000) / 10 : 0;
  const remainingPercentage =
    numBudget > 0
      ? Math.max(0, Math.min(100, Math.round((totalRemaining / numBudget) * 1000) / 10))
      : 0;
  const progressRatio =
    numBudget > 0
      ? Math.max(0, Math.min(1, Math.round((numSpent / numBudget) * 1000) / 1000))
      : 0;
  const remainingRatio =
    numBudget > 0
      ? Math.max(0, Math.min(1, Math.round((totalRemaining / numBudget) * 1000) / 1000))
      : 0;
  const isOverBudget = numBudget > 0 && numSpent > numBudget;

  const dailyRemainingAverage =
    totalRemaining > 0 && daysInMonth > 0 ? Math.round(totalRemaining / daysInMonth) : 0;

  let remainingStatusLabel = 'Batas Aman';
  if (numBudget <= 0) {
    remainingStatusLabel = 'Belum Diatur';
  } else if (isOverBudget) {
    remainingStatusLabel = 'Batas Terlampaui';
  } else if (remainingPercentage <= 15.0) {
    remainingStatusLabel = 'Batas Menipis';
  } else if (remainingPercentage <= 30.0) {
    remainingStatusLabel = 'Perlu Hemat';
  }

  const formattedTotalBudget = formatRupiah(numBudget);
  const formattedTotalSpent = formatRupiah(numSpent);
  const formattedTotalRemaining = formatRupiah(Math.abs(totalRemaining));
  const formattedRemainingWithSign =
    totalRemaining < 0 ? `- ${formattedTotalRemaining}` : formattedTotalRemaining;
  const formattedDailyRemainingAverage = `${formatRupiah(dailyRemainingAverage)} / hari`;

  const persentaseText = isOverBudget
    ? `Pengeluaran ${formattedTotalSpent} telah melebihi plafon ${formattedTotalBudget}`
    : `Tersisa ${remainingPercentage.toFixed(1)}% dari total plafon ${formattedTotalBudget}`;

  let keteranganText;
  if (isOverBudget) {
    keteranganText = `Batas terlampaui sebesar ${formattedTotalRemaining}. Batasi pengeluaran untuk menyeimbangkan keuangan.`;
  } else if (totalRemaining <= 0) {
    keteranganText = 'Batas budget bulan berjalan telah habis digunakan.';
  } else {
    keteranganText = `Estimasi aman belanja: ${formattedDailyRemainingAverage} (tersisa ${daysInMonth} hari).`;
  }

  const buckets = buildBudgetBuckets({
    totalBudget: numBudget,
    needsPct: nPct,
    savingsPct: sPct,
    funPct: fPct,
    needsSpent,
    savingsSpent,
    funSpent,
    daysInMonth,
    bucketCategories,
  });

  const overBudgetBuckets = buckets.filter((b) => b.isOverBudget).map((b) => b.title);

  const bucketsByType = {
    needs: buckets.find((b) => b.type === 'needs') || {
      type: 'needs',
      title: 'Kebutuhan Pokok',
      percentage: nPct,
      nominalPos: Math.round(numBudget * (nPct / 100)),
      amountLimit: Math.round(numBudget * (nPct / 100)),
      amountSpent: Number(needsSpent || 0),
      amountRemaining: Math.max(0, Math.round(numBudget * (nPct / 100)) - Number(needsSpent || 0)),
      isOverBudget: false,
    },
    savings: buckets.find((b) => b.type === 'savings') || {
      type: 'savings',
      title: 'Tabungan & Investasi',
      percentage: sPct,
      nominalPos: Math.round(numBudget * (sPct / 100)),
      amountLimit: Math.round(numBudget * (sPct / 100)),
      amountSpent: Number(savingsSpent || 0),
      amountRemaining: Math.max(0, Math.round(numBudget * (sPct / 100)) - Number(savingsSpent || 0)),
      isOverBudget: false,
    },
    fun: buckets.find((b) => b.type === 'fun') || {
      type: 'fun',
      title: 'Hiburan & Keinginan',
      percentage: fPct,
      nominalPos: Math.round(numBudget * (fPct / 100)),
      amountLimit: Math.round(numBudget * (fPct / 100)),
      amountSpent: Number(funSpent || 0),
      amountRemaining: Math.max(0, Math.round(numBudget * (fPct / 100)) - Number(funSpent || 0)),
      isOverBudget: false,
    },
  };

  const saranHarian = buildDailySpendingAdvice(
    {
      month,
      monthLabel,
      daysInMonth,
      totalBudget: numBudget,
      totalSpent: numSpent,
      totalRemaining,
      remainingSafe,
      overBudgetAmount,
      percentageUsed,
      remainingPercentage,
      isOverBudget,
      dailyRemainingAverage,
      remainingStatusLabel,
      formattedTotalBudget,
      formattedTotalSpent,
      formattedTotalRemaining,
      formattedRemainingWithSign,
      formattedDailyRemainingAverage,
      buckets,
      bucketsByType,
    },
    null
  );

  return {
    month,
    monthLabel,
    daysInMonth,
    totalBudget: numBudget,
    totalSpent: numSpent,
    totalRemaining,
    remainingSafe,
    overBudgetAmount,
    percentageUsed,
    remainingPercentage,
    progressRatio,
    remainingRatio,
    isOverBudget,
    dailyRemainingAverage,
    remainingStatusLabel,
    persentaseText,
    keteranganText,
    formattedTotalBudget,
    formattedTotalSpent,
    formattedTotalRemaining,
    formattedRemainingWithSign,
    formattedDailyRemainingAverage,
    overBudgetBuckets,
    sisaBatas: {
      month,
      monthLabel,
      daysInMonth,
      totalBudget: numBudget,
      totalSpent: numSpent,
      totalRemaining,
      remainingSafe,
      overBudgetAmount,
      percentageUsed,
      remainingPercentage,
      progressRatio,
      remainingRatio,
      isOverBudget,
      dailyRemainingAverage,
      remainingStatusLabel,
      persentaseText,
      keteranganText,
      formattedTotalBudget,
      formattedTotalSpent,
      formattedTotalRemaining,
      formattedRemainingWithSign,
      formattedDailyRemainingAverage,
    },
    posAlokasi: buckets,
    buckets,
    bucketsByType,
    posKategori: categoryBudgets,
    categoryBudgets,
    saranHarian,
    dailyAdvice: saranHarian,
  };
}

/**
 * Builds daily spending advice (Saran Harian) from a budget calculation/summary and optional rekap totals.
 */
export function buildDailySpendingAdvice(calcOrSummary = {}, rekapTotals = null, options = {}) {
  const month = calcOrSummary.month || new Date().toISOString().slice(0, 7);
  const monthLabel = calcOrSummary.monthLabel || getMonthLabel(month);
  const daysInMonth = Number(calcOrSummary.daysInMonth || getDaysInMonth(month));
  const totalBudget = Number(calcOrSummary.totalBudget || 0);
  const totalSpent = Number(calcOrSummary.totalSpent || 0);
  const totalRemaining = totalBudget - totalSpent;
  const isOverBudget = totalBudget > 0 && totalSpent > totalBudget;
  const remainingPercentage =
    totalBudget > 0 ? Math.max(0, Math.min(100, Math.round((totalRemaining / totalBudget) * 1000) / 10)) : 0;
  const percentageUsed = totalBudget > 0 ? Math.round((totalSpent / totalBudget) * 1000) / 10 : 0;

  const remainingDays =
    options.remainingDays !== undefined && options.remainingDays !== null && !isNaN(Number(options.remainingDays))
      ? Math.max(1, Number(options.remainingDays))
      : daysInMonth;

  const dailySafeSpend =
    totalRemaining > 0 && remainingDays > 0 ? Math.round(totalRemaining / remainingDays) : 0;
  const formattedDailySafeSpend = `${formatRupiah(dailySafeSpend)} / hari`;

  const dailyRemainingAverage =
    totalRemaining > 0 && daysInMonth > 0 ? Math.round(totalRemaining / daysInMonth) : 0;
  const formattedDailyRemainingAverage = `${formatRupiah(dailyRemainingAverage)} / hari`;

  const averageDailyExpense = Number(
    rekapTotals?.averageDailyExpense ?? (daysInMonth > 0 ? Math.round(totalSpent / daysInMonth) : 0)
  );
  const formattedAverageDailyExpense = `${formatRupiah(averageDailyExpense)} / hari`;

  const estimatedSurvivalDays =
    totalRemaining <= 0
      ? 0
      : averageDailyExpense > 0
        ? Math.max(0, Math.floor(totalRemaining / averageDailyExpense))
        : remainingDays;

  const buckets = calcOrSummary.buckets || calcOrSummary.posAlokasi || [];
  const bucketDailyAdvice = buckets.map((b) => {
    const rem = Math.max(0, Number(b.amountRemaining ?? (Number(b.amountLimit || 0) - Number(b.amountSpent || 0))));
    const posDaily = rem > 0 && remainingDays > 0 ? Math.round(rem / remainingDays) : 0;
    return {
      type: b.type,
      title: b.title,
      percentage: b.percentage,
      nominalPos: Number(b.nominalPos ?? b.amountLimit ?? 0),
      amountLimit: Number(b.amountLimit ?? b.nominalPos ?? 0),
      amountSpent: Number(b.amountSpent || 0),
      amountRemaining: rem,
      dailySafeSpend: posDaily,
      formattedDailySafeSpend: `${formatRupiah(posDaily)} / hari`,
      isOverBudget: Boolean(b.isOverBudget),
      statusLabel: b.statusLabel || (b.isOverBudget ? 'Melebihi Batas' : `Sisa ${formatRupiah(rem)}`),
    };
  });

  const needsDaily = bucketDailyAdvice.find((b) => b.type === 'needs')?.dailySafeSpend ?? 0;
  const savingsDaily = bucketDailyAdvice.find((b) => b.type === 'savings')?.dailySafeSpend ?? 0;
  const funDaily = bucketDailyAdvice.find((b) => b.type === 'fun')?.dailySafeSpend ?? 0;

  const formattedTotalBudget = calcOrSummary.formattedTotalBudget || formatRupiah(totalBudget);
  const formattedTotalSpent = calcOrSummary.formattedTotalSpent || formatRupiah(totalSpent);
  const formattedTotalRemaining = calcOrSummary.formattedTotalRemaining || formatRupiah(Math.abs(totalRemaining));
  const formattedRemainingWithSign =
    calcOrSummary.formattedRemainingWithSign ||
    (totalRemaining < 0 ? `- ${formattedTotalRemaining}` : formattedTotalRemaining);

  let status = 'safe';
  let adviceTitle = 'Saran Pengeluaran Harian Aman';
  let adviceMessage = `Estimasi aman belanja: ${formattedDailySafeSpend} (tersisa ${remainingDays} hari).`;
  let recommendationText = `Jaga pengeluaran harian maksimal ${formattedDailySafeSpend} (Kebutuhan Pokok maks ${formatRupiah(needsDaily)} / hari, Hiburan maks ${formatRupiah(funDaily)} / hari) agar anggaran bertahan hingga akhir bulan.`;

  if (totalBudget <= 0) {
    status = 'no_budget';
    adviceTitle = 'Belum Ada Target Budget Bulanan';
    adviceMessage = 'Atur batas budget bulanan terlebih dahulu untuk mendapatkan saran pengeluaran harian hingga akhir bulan.';
    recommendationText = 'Tetapkan batas budget bulanan Anda agar Moneta dapat menghitung batas aman belanja harian.';
  } else if (isOverBudget) {
    status = 'over_budget';
    adviceTitle = 'Batas Budget Bulanan Terlampaui';
    adviceMessage = `Batas terlampaui sebesar ${formattedTotalRemaining}. Batasi pengeluaran untuk menyeimbangkan keuangan.`;
    recommendationText = `Pengeluaran bulan ini (${formattedTotalSpent}) telah melampaui plafon ${formattedTotalBudget}. Tunda pengeluaran hiburan dan fokus pada kebutuhan mendesak saja.`;
  } else if (totalRemaining <= 0) {
    status = 'exhausted';
    adviceTitle = 'Batas Budget Bulan Berjalan Habis';
    adviceMessage = 'Batas budget bulan berjalan telah habis digunakan.';
    recommendationText = 'Seluruh plafon budget bulan ini telah terpakai. Hindari pengeluaran tambahan hingga pergantian bulan.';
  } else if (remainingPercentage <= 15) {
    status = 'critical';
    adviceTitle = 'Sisa Budget Menipis — Perketat Pengeluaran Harian';
    recommendationText = `Sisa budget tinggal ${remainingPercentage.toFixed(1)}% (${formattedTotalRemaining}). Batasi belanja harian maksimal ${formattedDailySafeSpend} agar uang cukup hingga akhir bulan.`;
  } else if (remainingPercentage <= 30) {
    status = 'tight';
    adviceTitle = 'Jaga Ritme Belanja Harian Anda';
    recommendationText = `Tersisa ${formattedTotalRemaining} untuk ${remainingDays} hari ke depan. Usahakan pengeluaran harian tidak melebihi ${formattedDailySafeSpend}.`;
  }

  return {
    month,
    monthLabel,
    hasBudget: totalBudget > 0,
    status,
    remainingStatusLabel: calcOrSummary.remainingStatusLabel || 'Batas Aman',
    totalBudget,
    formattedTotalBudget,
    totalSpent,
    formattedTotalSpent,
    totalRemaining,
    formattedTotalRemaining,
    formattedRemainingWithSign,
    percentageUsed,
    remainingPercentage,
    isOverBudget,
    daysInMonth,
    remainingDays,
    dailySafeSpend,
    formattedDailySafeSpend,
    dailyRemainingAverage,
    formattedDailyRemainingAverage,
    averageDailyExpense,
    formattedAverageDailyExpense,
    estimatedSurvivalDays,
    needsDailySafeSpend: needsDaily,
    savingsDailySafeSpend: savingsDaily,
    funDailySafeSpend: funDaily,
    formattedNeedsDailySafeSpend: `${formatRupiah(needsDaily)} / hari`,
    formattedSavingsDailySafeSpend: `${formatRupiah(savingsDaily)} / hari`,
    formattedFunDailySafeSpend: `${formatRupiah(funDaily)} / hari`,
    title: adviceTitle,
    adviceTitle,
    message: adviceMessage,
    adviceMessage,
    keteranganText: adviceMessage,
    recommendationText,
    bucketDailyAdvice,
    posDailyAdvice: bucketDailyAdvice,
  };
}

/**
 * Retrieves the full monthly budget state (root monthly limit + 3 buckets + category budgets + alert config + rekap & daily advice integration)
 */
export function getMonthlyBudgetSummaryQuery(db, userId, targetMonth, options = {}) {
  const month = targetMonth || new Date().toISOString().slice(0, 7);
  const monthPrefix = `${month}%`;

  // 1. Check monthly_budgets table first, then fallback to root row in budgets (category_id IS NULL)
  let monthlyRow = db
    .prepare('SELECT * FROM monthly_budgets WHERE user_id = ? AND month = ?')
    .get(userId, month);

  const rootBudgetRow = db
    .prepare('SELECT * FROM budgets WHERE user_id = ? AND category_id IS NULL AND month = ?')
    .get(userId, month);

  if (!monthlyRow && rootBudgetRow) {
    monthlyRow = {
      id: rootBudgetRow.id,
      user_id: rootBudgetRow.user_id,
      month: rootBudgetRow.month,
      total_amount: Number(rootBudgetRow.total_amount || rootBudgetRow.amount_limit || 0),
      needs_pct: Number(rootBudgetRow.needs_pct ?? 50),
      savings_pct: Number(rootBudgetRow.savings_pct ?? 30),
      fun_pct: Number(rootBudgetRow.fun_pct ?? 20),
      alert_enabled: rootBudgetRow.alert_enabled ?? 1,
      alert_threshold: Number(rootBudgetRow.alert_threshold ?? 80),
      over_budget_alert_enabled: rootBudgetRow.over_budget_alert_enabled ?? 1,
      push_notification_enabled: rootBudgetRow.push_notification_enabled ?? 1,
      created_at: rootBudgetRow.created_at,
      updated_at: rootBudgetRow.updated_at,
    };
  }

  // 2. Calculate confirmed expenses in this month grouped by category
  const expenseRows = db
    .prepare(`
      SELECT
        t.category_id,
        COALESCE(c.name, t.category_name, 'Lainnya') AS category_name,
        SUM(t.amount) AS total_spent
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.user_id = ?
        AND t.type = 'expense'
        AND t.is_confirmed = 1
        AND t.occurred_at LIKE ?
      GROUP BY t.category_id, COALESCE(c.name, t.category_name, 'Lainnya')
    `)
    .all(userId, monthPrefix);

  const totalSpent = expenseRows.reduce((sum, r) => sum + Number(r.total_spent || 0), 0);

  // 3. Category-level budgets for this month
  const categoryBudgetRows = db
    .prepare(`
      SELECT
        b.id,
        b.category_id,
        b.name,
        b.amount_limit,
        b.total_amount,
        b.bucket_type,
        b.period,
        b.month,
        c.name AS category_name,
        c.icon AS category_icon,
        c.color AS category_color,
        COALESCE((
          SELECT SUM(amount)
          FROM transactions
          WHERE user_id = b.user_id
            AND category_id = b.category_id
            AND type = 'expense'
            AND is_confirmed = 1
            AND occurred_at LIKE ?
        ), 0) AS total_spent
      FROM budgets b
      LEFT JOIN categories c ON b.category_id = c.id
      WHERE b.user_id = ?
        AND b.category_id IS NOT NULL
        AND (b.month = ? OR b.month IS NULL)
      ORDER BY b.id ASC
    `)
    .all(monthPrefix, userId, month);

  const categoryBucketMap = new Map();
  const categoryBudgets = categoryBudgetRows.map((b) => {
    const limit = Number(b.amount_limit || b.total_amount || 0);
    const spent = Number(b.total_spent || 0);
    const remaining = limit - spent;
    const percentageUsed = limit > 0 ? Math.round((spent / limit) * 1000) / 10 : 0;
    const catName = b.category_name || b.name;
    const bucketType = inferBucketTypeFromCategory(catName, b.bucket_type);
    if (b.category_id) {
      categoryBucketMap.set(b.category_id, bucketType);
    }

    const bucketLabel =
      bucketType === 'savings' ? 'Tabungan' : bucketType === 'fun' ? 'Hiburan' : 'Kebutuhan';
    const isOver = spent > limit;

    return {
      id: b.id,
      categoryId: b.category_id,
      name: b.name,
      categoryName: catName,
      bucketType,
      bucketLabel,
      categoryIcon: b.category_icon || 'category_rounded',
      categoryColor: b.category_color || 'blue',
      nominalPos: limit,
      amountLimit: limit,
      amountSpent: spent,
      totalSpent: spent,
      remaining,
      amountRemaining: remaining,
      percentageUsed,
      isOverBudget: isOver,
      statusText: isOver
        ? `Lewat ${formatRupiah(Math.abs(remaining))}`
        : `Sisa ${formatRupiah(Math.abs(remaining))}`,
      period: b.period || 'monthly',
      month: b.month || month,
      formattedLimit: formatRupiah(limit),
      formattedSpent: formatRupiah(spent),
      formattedRemaining: formatRupiah(Math.abs(remaining)),
    };
  });

  // 4. Compute spent per bucket ('needs' | 'savings' | 'fun') & breakdown of categories per bucket
  let needsSpent = 0;
  let savingsSpent = 0;
  let funSpent = 0;
  const bucketCategories = { needs: [], savings: [], fun: [] };

  for (const exp of expenseRows) {
    const explicitBucket = exp.category_id ? categoryBucketMap.get(exp.category_id) : null;
    const bucket = inferBucketTypeFromCategory(exp.category_name, explicitBucket);
    const amt = Number(exp.total_spent || 0);
    const catItem = {
      categoryId: exp.category_id,
      categoryName: exp.category_name,
      amountSpent: amt,
      formattedSpent: formatRupiah(amt),
    };
    if (bucket === 'savings') {
      savingsSpent += amt;
      bucketCategories.savings.push(catItem);
    } else if (bucket === 'fun') {
      funSpent += amt;
      bucketCategories.fun.push(catItem);
    } else {
      needsSpent += amt;
      bucketCategories.needs.push(catItem);
    }
  }

  const totalBudget = monthlyRow ? Number(monthlyRow.total_amount || 0) : 0;
  const needsPercentage = monthlyRow ? Number(monthlyRow.needs_pct ?? 50) : 50;
  const savingsPercentage = monthlyRow ? Number(monthlyRow.savings_pct ?? 30) : 30;
  const funPercentage = monthlyRow ? Number(monthlyRow.fun_pct ?? 20) : 20;

  const calc = calculateRemainingAndBucketNominals({
    month,
    totalBudget,
    totalSpent,
    needsPct: needsPercentage,
    savingsPct: savingsPercentage,
    funPct: funPercentage,
    needsSpent,
    savingsSpent,
    funSpent,
    bucketCategories,
    categoryBudgets,
  });

  const alertEnabled = monthlyRow ? Boolean(monthlyRow.alert_enabled) : true;
  const alertThreshold = monthlyRow ? Number(monthlyRow.alert_threshold ?? 80) : 80;
  const overBudgetAlertEnabled = monthlyRow ? Boolean(monthlyRow.over_budget_alert_enabled) : true;
  const pushNotificationEnabled = monthlyRow ? Boolean(monthlyRow.push_notification_enabled) : true;

  const warningDetection = detectBudgetWarningThreshold({
    totalBudget,
    totalSpent,
    threshold: alertThreshold,
    isAlertEnabled: alertEnabled,
    isOverBudgetAlertEnabled: overBudgetAlertEnabled,
    isPushNotificationEnabled: pushNotificationEnabled,
    daysInMonth: calc.daysInMonth,
    dailyRemainingAverage: calc.dailyRemainingAverage,
    formattedDailyRemainingAverage: calc.formattedDailyRemainingAverage,
    buckets: calc.buckets,
    categoryBudgets,
  });

  // 5. Integrate with monthly rekap totals & compute daily spending advice (saranHarian)
  const rekapTotals = getMonthlyTotalsQuery(db, userId, month);
  const saranHarian = buildDailySpendingAdvice(calc, rekapTotals, options);
  saranHarian.warningLevel = warningDetection.warningLevel;
  saranHarian.shouldShowWarningBanner = warningDetection.shouldShowBanner;

  const rekapIntegration = {
    month,
    monthLabel: calc.monthLabel,
    totalIncome: rekapTotals.totalIncome,
    totalExpense: rekapTotals.totalExpense,
    netSavings: rekapTotals.netSavings,
    savingsRate: rekapTotals.savingsRate,
    averageDailyExpense: rekapTotals.averageDailyExpense,
    confirmedTransactionsCount: rekapTotals.confirmedTransactionsCount,
    totalBudget,
    totalSpent,
    totalRemaining: calc.totalRemaining,
    percentageUsed: calc.percentageUsed,
    remainingPercentage: calc.remainingPercentage,
    isOverBudget: calc.isOverBudget,
    remainingStatusLabel: calc.remainingStatusLabel,
    dailyRemainingAverage: calc.dailyRemainingAverage,
    formattedDailyRemainingAverage: calc.formattedDailyRemainingAverage,
    dailySafeSpend: saranHarian.dailySafeSpend,
    formattedDailySafeSpend: saranHarian.formattedDailySafeSpend,
    warningLevel: warningDetection.warningLevel,
    shouldShowWarningBanner: warningDetection.shouldShowBanner,
  };

  return {
    id: monthlyRow?.id || rootBudgetRow?.id || null,
    budgetId: rootBudgetRow?.id || monthlyRow?.id || null,
    userId,
    month,
    monthLabel: calc.monthLabel,
    hasMonthlyBudget: totalBudget > 0,
    isEmpty: totalBudget <= 0 && categoryBudgets.length === 0,
    totalBudget,
    totalAmount: totalBudget,
    amountLimit: totalBudget,
    totalSpent,
    totalRemaining: calc.totalRemaining,
    remaining: calc.totalRemaining,
    remainingSafe: calc.remainingSafe,
    overBudgetAmount: calc.overBudgetAmount,
    percentageUsed: calc.percentageUsed,
    remainingPercentage: calc.remainingPercentage,
    progressRatio: calc.progressRatio,
    remainingRatio: calc.remainingRatio,
    isOverBudget: calc.isOverBudget,
    needsPercentage,
    savingsPercentage,
    funPercentage,
    needsPct: needsPercentage,
    savingsPct: savingsPercentage,
    funPct: funPercentage,
    daysInMonth: calc.daysInMonth,
    dailyRemainingAverage: calc.dailyRemainingAverage,
    remainingStatusLabel: calc.remainingStatusLabel,
    persentaseText: calc.persentaseText,
    keteranganText: calc.keteranganText,
    formattedTotalBudget: calc.formattedTotalBudget,
    formattedTotalSpent: calc.formattedTotalSpent,
    formattedTotalRemaining: calc.formattedTotalRemaining,
    formattedRemainingWithSign: calc.formattedRemainingWithSign,
    formattedDailyRemainingAverage: calc.formattedDailyRemainingAverage,
    overBudgetBuckets: calc.overBudgetBuckets,
    sisaBatas: calc.sisaBatas,
    posAlokasi: calc.posAlokasi,
    bucketsByType: calc.bucketsByType,
    posKategori: calc.posKategori,
    simulation503020: {
      needsAmount: Math.round(totalBudget * (needsPercentage / 100)),
      savingsAmount: Math.round(totalBudget * (savingsPercentage / 100)),
      funAmount: Math.round(totalBudget * (funPercentage / 100)),
      formattedNeeds: formatRupiah(totalBudget * (needsPercentage / 100)),
      formattedSavings: formatRupiah(totalBudget * (savingsPercentage / 100)),
      formattedFun: formatRupiah(totalBudget * (funPercentage / 100)),
    },
    buckets: calc.buckets,
    categoryBudgets,
    warning: warningDetection,
    warningBanner: warningDetection.banner,
    alertSettings: warningDetection.alertSettings,
    saranHarian,
    dailyAdvice: saranHarian,
    rekapIntegration,
    rekapSummary: rekapIntegration,
  };
}


/**
 * Queries DB for the user's month and computes remaining budget & nominal per pos
 * (supports optional override parameters for live simulation)
 */
export function getRemainingAndBucketNominalsQuery(db, userId, options = {}) {
  const month = options.month || new Date().toISOString().slice(0, 7);
  const summary = getMonthlyBudgetSummaryQuery(db, userId, month);

  const hasCustomOverride =
    options.totalBudget !== undefined ||
    options.totalAmount !== undefined ||
    options.needsPct !== undefined ||
    options.savingsPct !== undefined ||
    options.funPct !== undefined;

  if (!hasCustomOverride) {
    return summary;
  }

  const customTotalBudget = Number(
    options.totalBudget ?? options.totalAmount ?? summary.totalBudget
  );
  const customNeedsPct = Number(
    options.needsPct ?? options.needsPercentage ?? summary.needsPercentage
  );
  const customSavingsPct = Number(
    options.savingsPct ?? options.savingsPercentage ?? summary.savingsPercentage
  );
  const customFunPct = Number(
    options.funPct ?? options.funPercentage ?? summary.funPercentage
  );

  const needsSpent = summary.bucketsByType?.needs?.amountSpent ?? 0;
  const savingsSpent = summary.bucketsByType?.savings?.amountSpent ?? 0;
  const funSpent = summary.bucketsByType?.fun?.amountSpent ?? 0;

  return calculateRemainingAndBucketNominals({
    month,
    totalBudget: customTotalBudget,
    totalSpent: summary.totalSpent,
    needsPct: customNeedsPct,
    savingsPct: customSavingsPct,
    funPct: customFunPct,
    needsSpent,
    savingsSpent,
    funSpent,
    categoryBudgets: summary.categoryBudgets,
  });
}


/**
 * Creates or updates a user's monthly budget limit (and optional allocation percentages / alert settings)
 */
export function upsertMonthlyBudgetLimit(db, userId, payload = {}) {
  const month = payload.month || new Date().toISOString().slice(0, 7);
  const rawAmount =
    payload.totalAmount ??
    payload.total_amount ??
    payload.totalBudget ??
    payload.amountLimit ??
    payload.amount_limit ??
    payload.amount;

  const numAmount = Number(rawAmount);
  if (rawAmount === undefined || rawAmount === null || isNaN(numAmount) || numAmount <= 0) {
    const err = new Error('Nominal budget harus lebih besar dari Rp 0.');
    err.statusCode = 400;
    throw err;
  }

  // Read existing monthly budget to preserve percentages and alert settings when not explicitly provided
  const existingMonthly = db
    .prepare('SELECT * FROM monthly_budgets WHERE user_id = ? AND month = ?')
    .get(userId, month);
  const existingRoot = db
    .prepare('SELECT * FROM budgets WHERE user_id = ? AND category_id IS NULL AND month = ?')
    .get(userId, month);

  const needsPct = Number(
    payload.needsPct ??
      payload.needs_pct ??
      payload.needsPercentage ??
      existingMonthly?.needs_pct ??
      existingRoot?.needs_pct ??
      50
  );
  const savingsPct = Number(
    payload.savingsPct ??
      payload.savings_pct ??
      payload.savingsPercentage ??
      existingMonthly?.savings_pct ??
      existingRoot?.savings_pct ??
      30
  );
  const funPct = Number(
    payload.funPct ??
      payload.fun_pct ??
      payload.funPercentage ??
      existingMonthly?.fun_pct ??
      existingRoot?.fun_pct ??
      20
  );

  const pctSum = needsPct + savingsPct + funPct;
  if (
    isNaN(needsPct) ||
    isNaN(savingsPct) ||
    isNaN(funPct) ||
    needsPct < 0 ||
    savingsPct < 0 ||
    funPct < 0 ||
    Math.abs(pctSum - 100) > 0.01
  ) {
    const err = new Error('Total persentase alokasi (Kebutuhan + Tabungan + Hiburan) harus 100%.');
    err.statusCode = 400;
    throw err;
  }

  const alertEnabled =
    payload.alertEnabled !== undefined
      ? payload.alertEnabled
        ? 1
        : 0
      : payload.isAlertEnabled !== undefined
        ? payload.isAlertEnabled
          ? 1
          : 0
        : (existingMonthly?.alert_enabled ?? existingRoot?.alert_enabled ?? 1);

  const alertThreshold = Number(
    payload.alertThreshold ??
      payload.alert_threshold ??
      existingMonthly?.alert_threshold ??
      existingRoot?.alert_threshold ??
      80
  );

  const overBudgetAlert =
    payload.overBudgetAlertEnabled !== undefined
      ? payload.overBudgetAlertEnabled
        ? 1
        : 0
      : payload.isOverBudgetAlertEnabled !== undefined
        ? payload.isOverBudgetAlertEnabled
          ? 1
          : 0
        : (existingMonthly?.over_budget_alert_enabled ?? existingRoot?.over_budget_alert_enabled ?? 1);

  const pushNotification =
    payload.pushNotificationEnabled !== undefined
      ? payload.pushNotificationEnabled
        ? 1
        : 0
      : payload.isPushNotificationEnabled !== undefined
        ? payload.isPushNotificationEnabled
          ? 1
          : 0
        : (existingMonthly?.push_notification_enabled ?? existingRoot?.push_notification_enabled ?? 1);

  const budgetName = payload.name ? String(payload.name).trim() : 'Budget Bulanan';

  const saveTx = db.transaction(() => {
    // 1. Upsert into monthly_budgets
    db.prepare(`
      INSERT INTO monthly_budgets (
        user_id, month, total_amount, needs_pct, savings_pct, fun_pct,
        alert_enabled, alert_threshold, over_budget_alert_enabled, push_notification_enabled, updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(user_id, month) DO UPDATE SET
        total_amount = excluded.total_amount,
        needs_pct = excluded.needs_pct,
        savings_pct = excluded.savings_pct,
        fun_pct = excluded.fun_pct,
        alert_enabled = excluded.alert_enabled,
        alert_threshold = excluded.alert_threshold,
        over_budget_alert_enabled = excluded.over_budget_alert_enabled,
        push_notification_enabled = excluded.push_notification_enabled,
        updated_at = CURRENT_TIMESTAMP
    `).run(
      userId,
      month,
      numAmount,
      needsPct,
      savingsPct,
      funPct,
      alertEnabled,
      alertThreshold,
      overBudgetAlert,
      pushNotification
    );

    // 2. Upsert root row in budgets table (category_id IS NULL)
    if (existingRoot) {
      db.prepare(`
        UPDATE budgets
        SET
          name = ?,
          amount_limit = ?,
          total_amount = ?,
          needs_pct = ?,
          savings_pct = ?,
          fun_pct = ?,
          alert_enabled = ?,
          alert_threshold = ?,
          over_budget_alert_enabled = ?,
          push_notification_enabled = ?,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `).run(
        budgetName,
        numAmount,
        numAmount,
        needsPct,
        savingsPct,
        funPct,
        alertEnabled,
        alertThreshold,
        overBudgetAlert,
        pushNotification,
        existingRoot.id
      );
    } else {
      db.prepare(`
        INSERT INTO budgets (
          user_id, category_id, name, amount_limit, total_amount,
          needs_pct, savings_pct, fun_pct, period, month,
          alert_enabled, alert_threshold, over_budget_alert_enabled, push_notification_enabled
        )
        VALUES (?, NULL, ?, ?, ?, ?, ?, ?, 'monthly', ?, ?, ?, ?, ?)
      `).run(
        userId,
        budgetName,
        numAmount,
        numAmount,
        needsPct,
        savingsPct,
        funPct,
        month,
        alertEnabled,
        alertThreshold,
        overBudgetAlert,
        pushNotification
      );
    }
  });

  saveTx();

  return getMonthlyBudgetSummaryQuery(db, userId, month);
}

/**
 * Deletes the monthly budget limit for a given month (or by ID)
 */
export function deleteMonthlyBudgetLimit(db, userId, { id = null, month = null } = {}) {
  let resolvedMonth = month;

  if (id) {
    const budgetRow = db.prepare('SELECT * FROM budgets WHERE id = ? AND user_id = ?').get(id, userId);
    const monthlyRow = db.prepare('SELECT * FROM monthly_budgets WHERE id = ? AND user_id = ?').get(id, userId);

    if (!budgetRow && !monthlyRow) {
      return null;
    }

    if (budgetRow && budgetRow.category_id !== null) {
      // Category-specific budget deletion
      db.prepare('DELETE FROM budgets WHERE id = ? AND user_id = ?').run(id, userId);
      return {
        deletedType: 'category',
        id: Number(id),
        month: budgetRow.month,
      };
    }

    resolvedMonth = budgetRow?.month || monthlyRow?.month || resolvedMonth;
  }

  if (!resolvedMonth) {
    return null;
  }

  const existingMonthly = db
    .prepare('SELECT id FROM monthly_budgets WHERE user_id = ? AND month = ?')
    .get(userId, resolvedMonth);
  const existingRoot = db
    .prepare('SELECT id FROM budgets WHERE user_id = ? AND category_id IS NULL AND month = ?')
    .get(userId, resolvedMonth);

  if (!existingMonthly && !existingRoot) {
    return null;
  }

  const delTx = db.transaction(() => {
    db.prepare('DELETE FROM monthly_budgets WHERE user_id = ? AND month = ?').run(userId, resolvedMonth);
    db.prepare('DELETE FROM budgets WHERE user_id = ? AND category_id IS NULL AND month = ?').run(
      userId,
      resolvedMonth
    );
  });

  delTx();

  return {
    deletedType: 'monthly',
    id: existingRoot?.id || existingMonthly?.id || Number(id) || null,
    month: resolvedMonth,
    summary: getMonthlyBudgetSummaryQuery(db, userId, resolvedMonth),
  };
}

/**
 * Popular allocation templates matching frontend AdjustAllocationPercentagesSheet
 */
export const ALLOCATION_PRESETS = [
  {
    id: '50_30_20',
    key: 'preset_allocation_50_30_20',
    label: 'Klasik (50/30/20)',
    needsPct: 50,
    savingsPct: 30,
    funPct: 20,
  },
  {
    id: '40_40_20',
    key: 'preset_allocation_40_40_20',
    label: 'Hemat & Invest (40/40/20)',
    needsPct: 40,
    savingsPct: 40,
    funPct: 20,
  },
  {
    id: '60_25_15',
    key: 'preset_allocation_60_25_15',
    label: 'Kebutuhan Tinggi (60/25/15)',
    needsPct: 60,
    savingsPct: 25,
    funPct: 15,
  },
  {
    id: '35_50_15',
    key: 'preset_allocation_35_50_15',
    label: 'Agresif Nabung (35/50/15)',
    needsPct: 35,
    savingsPct: 50,
    funPct: 15,
  },
];

/**
 * Resolves a preset name/id into { needsPct, savingsPct, funPct } if matched
 */
export function resolveAllocationPreset(presetInput) {
  if (!presetInput) return null;
  const norm = String(presetInput).trim().toLowerCase().replace(/[\s/-]+/g, '_');
  const map = {
    '50_30_20': { needsPct: 50, savingsPct: 30, funPct: 20 },
    klasik: { needsPct: 50, savingsPct: 30, funPct: 20 },
    classic: { needsPct: 50, savingsPct: 30, funPct: 20 },
    default: { needsPct: 50, savingsPct: 30, funPct: 20 },
    '40_40_20': { needsPct: 40, savingsPct: 40, funPct: 20 },
    hemat: { needsPct: 40, savingsPct: 40, funPct: 20 },
    hemat_invest: { needsPct: 40, savingsPct: 40, funPct: 20 },
    '60_25_15': { needsPct: 60, savingsPct: 25, funPct: 15 },
    kebutuhan_tinggi: { needsPct: 60, savingsPct: 25, funPct: 15 },
    '35_50_15': { needsPct: 35, savingsPct: 50, funPct: 15 },
    agresif: { needsPct: 35, savingsPct: 50, funPct: 15 },
    agresif_nabung: { needsPct: 35, savingsPct: 50, funPct: 15 },
  };
  return map[norm] || null;
}

/**
 * Validates that needsPct, savingsPct, and funPct are valid numbers in [0, 100] and sum to 100%.
 */
export function validateAllocationPercentages(rawNeeds, rawSavings, rawFun) {
  const needsPct = Number(rawNeeds);
  const savingsPct = Number(rawSavings);
  const funPct = Number(rawFun);

  if (
    rawNeeds === undefined ||
    rawNeeds === null ||
    rawSavings === undefined ||
    rawSavings === null ||
    rawFun === undefined ||
    rawFun === null ||
    isNaN(needsPct) ||
    isNaN(savingsPct) ||
    isNaN(funPct)
  ) {
    return {
      isValid: false,
      error: 'Persentase Kebutuhan, Tabungan, dan Hiburan wajib berupa angka yang valid.',
      validationMessage: 'Persentase alokasi tidak valid.',
      needsPct: isNaN(needsPct) ? 0 : needsPct,
      savingsPct: isNaN(savingsPct) ? 0 : savingsPct,
      funPct: isNaN(funPct) ? 0 : funPct,
      totalPercentage: 0,
      difference: -100,
      shortage: 100,
      excess: 0,
    };
  }

  if (
    needsPct < 0 ||
    savingsPct < 0 ||
    funPct < 0 ||
    needsPct > 100 ||
    savingsPct > 100 ||
    funPct > 100
  ) {
    return {
      isValid: false,
      error: 'Setiap persentase alokasi harus berada di antara 0% hingga 100%.',
      validationMessage: 'Setiap pos alokasi harus bernilai antara 0% sampai 100%.',
      needsPct,
      savingsPct,
      funPct,
      totalPercentage: Math.round((needsPct + savingsPct + funPct) * 100) / 100,
      difference: Math.round((needsPct + savingsPct + funPct - 100) * 100) / 100,
      shortage: Math.max(0, Math.round((100 - (needsPct + savingsPct + funPct)) * 100) / 100),
      excess: Math.max(0, Math.round((needsPct + savingsPct + funPct - 100) * 100) / 100),
    };
  }

  const totalPercentage = Math.round((needsPct + savingsPct + funPct) * 100) / 100;
  const difference = Math.round((totalPercentage - 100) * 100) / 100;
  const isValid = Math.abs(difference) < 0.01;

  if (!isValid) {
    if (totalPercentage < 100) {
      const shortage = Math.round((100 - totalPercentage) * 100) / 100;
      const shortageLabel = Number.isInteger(shortage) ? shortage.toFixed(0) : String(shortage);
      const totalLabel = Number.isInteger(totalPercentage)
          ? totalPercentage.toFixed(0)
          : String(totalPercentage);
      return {
        isValid: false,
        error: `Total persentase harus 100%. Masih kurang ${shortageLabel}%.`,
        validationMessage: `Total alokasi ${totalLabel}%. Kurang ${shortageLabel}% lagi untuk mencapai 100%.`,
        needsPct,
        savingsPct,
        funPct,
        totalPercentage,
        difference,
        shortage,
        excess: 0,
      };
    } else {
      const excess = Math.round((totalPercentage - 100) * 100) / 100;
      const excessLabel = Number.isInteger(excess) ? excess.toFixed(0) : String(excess);
      const totalLabel = Number.isInteger(totalPercentage)
          ? totalPercentage.toFixed(0)
          : String(totalPercentage);
      return {
        isValid: false,
        error: `Total persentase harus 100%. Melebihi batas sebesar ${excessLabel}%.`,
        validationMessage: `Total alokasi ${totalLabel}%. Kelebihan ${excessLabel}% dari batas 100%.`,
        needsPct,
        savingsPct,
        funPct,
        totalPercentage,
        difference,
        shortage: 0,
        excess,
      };
    }
  }

  return {
    isValid: true,
    error: null,
    validationMessage: 'Total Alokasi 100% (Sempurna & Siap Digunakan)',
    needsPct,
    savingsPct,
    funPct,
    totalPercentage: 100,
    difference: 0,
    shortage: 0,
    excess: 0,
  };
}

/**
 * Retrieves the allocation percentages, calculated bucket nominals, and available presets for a month.
 */
export function getAllocationPercentagesQuery(db, userId, targetMonth) {
  const month = targetMonth || new Date().toISOString().slice(0, 7);
  const summary = getMonthlyBudgetSummaryQuery(db, userId, month);

  const needsPct = summary.needsPercentage;
  const savingsPct = summary.savingsPercentage;
  const funPct = summary.funPercentage;
  const totalBudget = summary.totalBudget;

  const activePreset =
    ALLOCATION_PRESETS.find(
      (p) => p.needsPct === needsPct && p.savingsPct === savingsPct && p.funPct === funPct
    )?.id || 'custom';

  return {
    month: summary.month,
    monthLabel: summary.monthLabel,
    totalBudget,
    formattedTotalBudget: summary.formattedTotalBudget,
    needsPercentage: needsPct,
    savingsPercentage: savingsPct,
    funPercentage: funPct,
    needsPct,
    savingsPct,
    funPct,
    totalPercentage: Math.round((needsPct + savingsPct + funPct) * 100) / 100,
    isValid: Math.abs(needsPct + savingsPct + funPct - 100) < 0.01,
    validationMessage: 'Total Alokasi 100% (Sempurna & Siap Digunakan)',
    activePreset,
    presets: ALLOCATION_PRESETS,
    allocation: {
      needsPercentage: needsPct,
      savingsPercentage: savingsPct,
      funPercentage: funPct,
      needsPct,
      savingsPct,
      funPct,
      needsAmount: Math.round(totalBudget * (needsPct / 100)),
      savingsAmount: Math.round(totalBudget * (savingsPct / 100)),
      funAmount: Math.round(totalBudget * (funPct / 100)),
      formattedNeedsAmount: formatRupiah(totalBudget * (needsPct / 100)),
      formattedSavingsAmount: formatRupiah(totalBudget * (savingsPct / 100)),
      formattedFunAmount: formatRupiah(totalBudget * (funPct / 100)),
      totalPercentage: 100,
      isValid: true,
    },
    buckets: summary.buckets,
    saranHarian: summary.saranHarian,
    dailyAdvice: summary.dailyAdvice,
    rekapIntegration: summary.rekapIntegration,
    rekapSummary: summary.rekapSummary,
    summary,
  };
}

/**
 * Updates or creates the 3-bucket allocation percentages for a user & month with strict 100% sum validation.
 */
export function upsertAllocationPercentages(db, userId, payload = {}) {
  const month = payload.month || new Date().toISOString().slice(0, 7);

  // Check if a preset was requested
  const presetValues = resolveAllocationPreset(payload.preset || payload.template);

  const rawNeeds =
    payload.needsPct ??
    payload.needs_pct ??
    payload.needsPercentage ??
    payload.needs ??
    presetValues?.needsPct;
  const rawSavings =
    payload.savingsPct ??
    payload.savings_pct ??
    payload.savingsPercentage ??
    payload.savings ??
    presetValues?.savingsPct;
  const rawFun =
    payload.funPct ??
    payload.fun_pct ??
    payload.funPercentage ??
    payload.fun ??
    presetValues?.funPct;

  const validation = validateAllocationPercentages(rawNeeds, rawSavings, rawFun);
  if (!validation.isValid) {
    const err = new Error(validation.error);
    err.statusCode = 400;
    err.validation = validation;
    throw err;
  }

  const { needsPct, savingsPct, funPct } = validation;

  const existingMonthly = db
    .prepare('SELECT * FROM monthly_budgets WHERE user_id = ? AND month = ?')
    .get(userId, month);
  const existingRoot = db
    .prepare('SELECT * FROM budgets WHERE user_id = ? AND category_id IS NULL AND month = ?')
    .get(userId, month);

  const rawTotal =
    payload.totalAmount ??
    payload.total_amount ??
    payload.totalBudget ??
    payload.amountLimit ??
    payload.amount_limit;

  const resolvedTotalAmount =
    rawTotal !== undefined && rawTotal !== null && !isNaN(Number(rawTotal)) && Number(rawTotal) >= 0
      ? Number(rawTotal)
      : Number(existingMonthly?.total_amount ?? existingRoot?.total_amount ?? existingRoot?.amount_limit ?? 0);

  const alertEnabled = existingMonthly?.alert_enabled ?? existingRoot?.alert_enabled ?? 1;
  const alertThreshold = Number(existingMonthly?.alert_threshold ?? existingRoot?.alert_threshold ?? 80);
  const overBudgetAlert =
    existingMonthly?.over_budget_alert_enabled ?? existingRoot?.over_budget_alert_enabled ?? 1;
  const pushNotification =
    existingMonthly?.push_notification_enabled ?? existingRoot?.push_notification_enabled ?? 1;

  const saveTx = db.transaction(() => {
    db.prepare(`
      INSERT INTO monthly_budgets (
        user_id, month, total_amount, needs_pct, savings_pct, fun_pct,
        alert_enabled, alert_threshold, over_budget_alert_enabled, push_notification_enabled, updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(user_id, month) DO UPDATE SET
        total_amount = excluded.total_amount,
        needs_pct = excluded.needs_pct,
        savings_pct = excluded.savings_pct,
        fun_pct = excluded.fun_pct,
        updated_at = CURRENT_TIMESTAMP
    `).run(
      userId,
      month,
      resolvedTotalAmount,
      needsPct,
      savingsPct,
      funPct,
      alertEnabled,
      alertThreshold,
      overBudgetAlert,
      pushNotification
    );

    if (existingRoot) {
      db.prepare(`
        UPDATE budgets
        SET
          amount_limit = ?,
          total_amount = ?,
          needs_pct = ?,
          savings_pct = ?,
          fun_pct = ?,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `).run(resolvedTotalAmount, resolvedTotalAmount, needsPct, savingsPct, funPct, existingRoot.id);
    } else {
      db.prepare(`
        INSERT INTO budgets (
          user_id, category_id, name, amount_limit, total_amount,
          needs_pct, savings_pct, fun_pct, period, month,
          alert_enabled, alert_threshold, over_budget_alert_enabled, push_notification_enabled
        )
        VALUES (?, NULL, 'Budget Bulanan', ?, ?, ?, ?, ?, 'monthly', ?, ?, ?, ?, ?)
      `).run(
        userId,
        resolvedTotalAmount,
        resolvedTotalAmount,
        needsPct,
        savingsPct,
        funPct,
        month,
        alertEnabled,
        alertThreshold,
        overBudgetAlert,
        pushNotification
      );
    }
  });

  saveTx();

  return getAllocationPercentagesQuery(db, userId, month);
}

/**
 * Resets allocation percentages to the classic 50/30/20 split for a user & month.
 */
export function resetAllocationPercentages(db, userId, targetMonth) {
  const month = targetMonth || new Date().toISOString().slice(0, 7);
  return upsertAllocationPercentages(db, userId, {
    month,
    needsPct: 50,
    savingsPct: 30,
    funPct: 20,
  });
}

/**
 * Pure service function to detect budget warning thresholds (none | nearLimit | overLimit),
 * banner content, affected pos/categories, and alert settings status.
 */
export function detectBudgetWarningThreshold({
  totalBudget = 0,
  totalSpent = 0,
  threshold = undefined,
  alertThreshold = undefined,
  isAlertEnabled = true,
  isOverBudgetAlertEnabled = true,
  isPushNotificationEnabled = true,
  daysInMonth = 30,
  dailyRemainingAverage = null,
  formattedDailyRemainingAverage = null,
  buckets = [],
  categoryBudgets = [],
} = {}) {
  const numBudget = Number(totalBudget || 0);
  const numSpent = Number(totalSpent || 0);
  const rawThreshold = alertThreshold ?? threshold ?? 80.0;
  const numThreshold =
    rawThreshold !== undefined && rawThreshold !== null && !isNaN(Number(rawThreshold)) && Number(rawThreshold) > 0
      ? Math.min(100, Number(rawThreshold))
      : 80.0;

  const alertEnabled = Boolean(isAlertEnabled);
  const overBudgetAlertEnabled = Boolean(isOverBudgetAlertEnabled);
  const pushNotificationEnabled = Boolean(isPushNotificationEnabled);

  const totalRemaining = numBudget - numSpent;
  const percentageUsed = numBudget > 0 ? Math.round((numSpent / numBudget) * 1000) / 10 : 0;
  const isOverBudget = numBudget > 0 && numSpent > numBudget;
  const isNearLimit = numBudget > 0 && !isOverBudget && percentageUsed >= numThreshold;

  const days = Number(daysInMonth || 30);
  const calcDailyAvg =
    dailyRemainingAverage !== null && dailyRemainingAverage !== undefined
      ? Number(dailyRemainingAverage)
      : totalRemaining > 0 && days > 0
        ? Math.round(totalRemaining / days)
        : 0;
  const formattedDailyAvg =
    formattedDailyRemainingAverage || `${formatRupiah(calcDailyAvg)} / hari`;

  const formattedTotalBudget = formatRupiah(numBudget);
  const formattedTotalSpent = formatRupiah(numSpent);
  const formattedTotalRemaining = formatRupiah(Math.abs(totalRemaining));

  // Raw level ignoring master toggle (useful for diagnostics)
  let rawWarningLevel = 'none';
  if (numBudget > 0) {
    if (isOverBudget) {
      rawWarningLevel = 'overLimit';
    } else if (percentageUsed >= numThreshold) {
      rawWarningLevel = 'nearLimit';
    }
  }

  // Effective warning level respecting isAlertEnabled & isOverBudgetAlertEnabled
  let warningLevel = 'none';
  if (numBudget > 0 && alertEnabled) {
    if (isOverBudget) {
      if (overBudgetAlertEnabled) {
        warningLevel = 'overLimit';
      }
    } else if (percentageUsed >= numThreshold) {
      warningLevel = 'nearLimit';
    }
  }

  const shouldShowBanner = warningLevel !== 'none';

  // Detect affected buckets (pos) and categories
  const overBudgetBucketItems = (buckets || []).filter((b) => {
    const spent = Number(b.amountSpent ?? b.spentAmount ?? 0);
    const limit = Number(b.amountLimit ?? b.allocatedAmount ?? b.nominalPos ?? 0);
    return b.isOverBudget || (limit > 0 && spent > limit);
  });
  const overBudgetBucketTitles = overBudgetBucketItems.map((b) => b.title);
  const nearLimitBucketItems = (buckets || []).filter((b) => {
    const spent = Number(b.amountSpent ?? b.spentAmount ?? 0);
    const limit = Number(b.amountLimit ?? b.allocatedAmount ?? b.nominalPos ?? 0);
    const over = b.isOverBudget || (limit > 0 && spent > limit);
    return !over && limit > 0 && (spent / limit) * 100 >= numThreshold;
  });

  const overBudgetCategories = (categoryBudgets || []).filter(
    (c) => c.isOverBudget || c.amountSpent > c.amountLimit
  );
  const nearLimitCategories = (categoryBudgets || []).filter(
    (c) => !c.isOverBudget && c.amountLimit > 0 && (c.amountSpent / c.amountLimit) * 100 >= numThreshold
  );

  const affectedBucketsLabel =
    overBudgetBucketTitles.length > 0
      ? `Pos melebihi limit: ${overBudgetBucketTitles.join(', ')}`
      : null;

  let banner = null;
  if (warningLevel === 'overLimit') {
    banner = {
      key: 'budget_over_limit_banner',
      level: 'overLimit',
      isOverBudget: true,
      title: 'Perhatian: Budget Melewati Batas!',
      message: `Total pengeluaran (${formattedTotalSpent}) telah melewati plafon ${formattedTotalBudget} sebesar ${formattedTotalRemaining}.`,
      adviceText: 'Tunda pengeluaran non-prioritas.',
      overBudgetBuckets: overBudgetBucketTitles,
      overBudgetBucketsChipText: affectedBucketsLabel,
    };
  } else if (warningLevel === 'nearLimit') {
    banner = {
      key: 'budget_near_limit_banner',
      level: 'nearLimit',
      isOverBudget: false,
      title: 'Peringatan: Budget Mendekati Batas!',
      message: `Pengeluaran telah mencapai ${percentageUsed.toFixed(1)}% dari plafon ${formattedTotalBudget}. Sisa batas: ${formattedTotalRemaining}.`,
      adviceText: `Aman belanja: ${formattedDailyAvg}.`,
      overBudgetBuckets: overBudgetBucketTitles,
      overBudgetBucketsChipText: affectedBucketsLabel,
    };
  }

  const thresholdLabel = Math.round(numThreshold);
  const statusSubtitle = alertEnabled
    ? 'Notifikasi & peringatan batas aktif'
    : 'Peringatan dinonaktifkan';
  const statusBoxText = alertEnabled
    ? `Peringatan aktif: Anda akan diberi peringatan saat pengeluaran mencapai ${thresholdLabel}% dari plafon.`
    : 'Peringatan budget sedang dinonaktifkan. Anda tidak akan menerima banner peringatan saat belanja mendekati batas.';

  const overBudgetAmount = Math.max(0, numSpent - numBudget);

  return {
    warningLevel,
    rawWarningLevel,
    shouldShowBanner,
    shouldShowWarningBanner: shouldShowBanner,
    isAlertEnabled: alertEnabled,
    alertThreshold: numThreshold,
    threshold: numThreshold,
    availableThresholds: [80, 85, 90],
    thresholdOptions: [80, 85, 90],
    isOverBudgetAlertEnabled: overBudgetAlertEnabled,
    isPushNotificationEnabled: pushNotificationEnabled,
    isOverBudget,
    isOverLimit: isOverBudget,
    isNearLimit,
    percentageUsed,
    totalBudget: numBudget,
    totalSpent: numSpent,
    totalRemaining,
    overAmount: overBudgetAmount,
    overBudgetAmount,
    formattedTotalBudget,
    formattedTotalSpent,
    formattedTotalRemaining,
    formattedDailyRemainingAverage: formattedDailyAvg,
    banner,
    bannerTitle: banner?.title || null,
    bannerMessage: banner?.message || null,
    affectedBucketsLabel,
    overBudgetBuckets: overBudgetBucketTitles,
    overLimitBucketTitles: overBudgetBucketTitles,
    overBudgetBucketItems,
    nearLimitBucketItems,
    overBudgetCategories,
    nearLimitCategories,
    alertCardStatusText: statusBoxText,
    alertSettings: {
      isAlertEnabled: alertEnabled,
      alertThreshold: numThreshold,
      availableThresholds: [80, 85, 90],
      thresholdOptions: [80, 85, 90],
      isOverBudgetAlertEnabled: overBudgetAlertEnabled,
      isPushNotificationEnabled: pushNotificationEnabled,
      warningLevel,
      shouldShowBanner,
      shouldShowWarningBanner: shouldShowBanner,
      statusSubtitle,
      statusBoxText,
    },
  };
}

/**
 * Queries DB for the user's month and returns the budget warning threshold detection result.
 */
export function getBudgetWarningStatusQuery(db, userId, options = {}) {
  const month = options.month || new Date().toISOString().slice(0, 7);
  const summary = getMonthlyBudgetSummaryQuery(db, userId, month);

  const customThreshold =
    options.threshold ?? options.alertThreshold ?? options.alert_threshold ?? summary.alertSettings.alertThreshold;
  const customAlertEnabled =
    options.isAlertEnabled !== undefined
      ? Boolean(options.isAlertEnabled === 'true' || options.isAlertEnabled === true || options.isAlertEnabled === 1)
      : options.alertEnabled !== undefined
        ? Boolean(options.alertEnabled === 'true' || options.alertEnabled === true || options.alertEnabled === 1)
        : summary.alertSettings.isAlertEnabled;
  const customOverBudgetEnabled =
    options.isOverBudgetAlertEnabled !== undefined
      ? Boolean(
          options.isOverBudgetAlertEnabled === 'true' ||
            options.isOverBudgetAlertEnabled === true ||
            options.isOverBudgetAlertEnabled === 1
        )
      : summary.alertSettings.isOverBudgetAlertEnabled;
  const customPushEnabled =
    options.isPushNotificationEnabled !== undefined
      ? Boolean(
          options.isPushNotificationEnabled === 'true' ||
            options.isPushNotificationEnabled === true ||
            options.isPushNotificationEnabled === 1
        )
      : summary.alertSettings.isPushNotificationEnabled;

  const detection = detectBudgetWarningThreshold({
    totalBudget: options.totalBudget ?? summary.totalBudget,
    totalSpent: options.totalSpent ?? summary.totalSpent,
    threshold: customThreshold,
    isAlertEnabled: customAlertEnabled,
    isOverBudgetAlertEnabled: customOverBudgetEnabled,
    isPushNotificationEnabled: customPushEnabled,
    daysInMonth: summary.daysInMonth,
    dailyRemainingAverage: summary.dailyRemainingAverage,
    formattedDailyRemainingAverage: summary.formattedDailyRemainingAverage,
    buckets: summary.buckets,
    categoryBudgets: summary.categoryBudgets,
  });

  return {
    month: summary.month,
    monthLabel: summary.monthLabel,
    ...detection,
    saranHarian: summary.saranHarian,
    dailyAdvice: summary.dailyAdvice,
    rekapIntegration: summary.rekapIntegration,
    rekapSummary: summary.rekapSummary,
    summary,
  };
}

/**
 * Queries DB for the user's month and returns the integrated daily spending advice (Saran Harian) + budget & rekap summary.
 */
export function getBudgetDailyAdviceQuery(db, userId, options = {}) {
  const month = options.month || new Date().toISOString().slice(0, 7);
  const summary = getMonthlyBudgetSummaryQuery(db, userId, month, options);

  // Support optional simulation overrides (totalBudget, remainingDays, needsPct, etc.)
  const hasSimulationOverride =
    options.totalBudget !== undefined ||
    options.totalAmount !== undefined ||
    options.needsPct !== undefined ||
    options.savingsPct !== undefined ||
    options.funPct !== undefined ||
    options.remainingDays !== undefined;

  if (hasSimulationOverride) {
    const simCalc = getRemainingAndBucketNominalsQuery(db, userId, {
      ...options,
      month,
    });
    const rekapTotals = getMonthlyTotalsQuery(db, userId, month);
    const simAdvice = buildDailySpendingAdvice(simCalc, rekapTotals, options);
    return {
      ...simAdvice,
      saranHarian: simAdvice,
      dailyAdvice: simAdvice,
      rekapIntegration: summary.rekapIntegration,
      rekapSummary: summary.rekapSummary,
      monthlyBudget: summary,
      summary,
    };
  }

  return {
    ...summary.saranHarian,
    saranHarian: summary.saranHarian,
    dailyAdvice: summary.dailyAdvice,
    rekapIntegration: summary.rekapIntegration,
    rekapSummary: summary.rekapSummary,
    monthlyBudget: summary,
    summary,
  };
}

/**
 * Updates the user's budget alert settings (master toggle, threshold %, over-budget toggle, daily push toggle)
 */
export function updateBudgetAlertSettings(db, userId, payload = {}) {
  const month = payload.month || new Date().toISOString().slice(0, 7);

  const existingMonthly = db
    .prepare('SELECT * FROM monthly_budgets WHERE user_id = ? AND month = ?')
    .get(userId, month);
  const existingRoot = db
    .prepare('SELECT * FROM budgets WHERE user_id = ? AND category_id IS NULL AND month = ?')
    .get(userId, month);

  const rawThreshold =
    payload.alertThreshold ??
    payload.alert_threshold ??
    payload.threshold ??
    payload.warningThreshold ??
    payload.warning_threshold;
  if (rawThreshold !== undefined && rawThreshold !== null) {
    const numT = Number(rawThreshold);
    if (isNaN(numT) || numT <= 0 || numT > 100) {
      const err = new Error('Ambang batas peringatan harus berada di antara 1% hingga 100%.');
      err.statusCode = 400;
      throw err;
    }
  }

  const resolvedThreshold =
    rawThreshold !== undefined && rawThreshold !== null
      ? Number(rawThreshold)
      : Number(existingMonthly?.alert_threshold ?? existingRoot?.alert_threshold ?? 80);

  const parseBoolInt = (val, fallback) => {
    if (val === undefined || val === null) return fallback;
    if (typeof val === 'boolean') return val ? 1 : 0;
    if (typeof val === 'number') return val ? 1 : 0;
    if (typeof val === 'string') {
      const lower = val.trim().toLowerCase();
      if (lower === 'true' || lower === '1' || lower === 'on' || lower === 'yes') return 1;
      if (lower === 'false' || lower === '0' || lower === 'off' || lower === 'no') return 0;
    }
    return fallback;
  };

  const currentAlertEnabled = existingMonthly?.alert_enabled ?? existingRoot?.alert_enabled ?? 1;
  const rawAlertEnabled =
    payload.isAlertEnabled ??
    payload.alertEnabled ??
    payload.alert_enabled ??
    payload.enabled ??
    payload.isEnabled ??
    payload.active ??
    payload.isActive;

  let resolvedAlertEnabled;
  if (rawAlertEnabled !== undefined && rawAlertEnabled !== null) {
    resolvedAlertEnabled = parseBoolInt(rawAlertEnabled, currentAlertEnabled);
  } else if (payload.toggle === true || payload.toggleAlert === true) {
    resolvedAlertEnabled = currentAlertEnabled ? 0 : 1;
  } else {
    resolvedAlertEnabled = currentAlertEnabled;
  }

  const resolvedOverBudgetAlert = parseBoolInt(
    payload.isOverBudgetAlertEnabled ??
      payload.overBudgetAlertEnabled ??
      payload.over_budget_alert_enabled ??
      payload.overLimitAlertEnabled,
    existingMonthly?.over_budget_alert_enabled ?? existingRoot?.over_budget_alert_enabled ?? 1
  );
  const resolvedPushNotification = parseBoolInt(
    payload.isPushNotificationEnabled ??
      payload.pushNotificationEnabled ??
      payload.push_notification_enabled ??
      payload.dailyReminderEnabled,
    existingMonthly?.push_notification_enabled ?? existingRoot?.push_notification_enabled ?? 1
  );

  const resolvedTotalAmount = Number(
    existingMonthly?.total_amount ?? existingRoot?.total_amount ?? existingRoot?.amount_limit ?? 0
  );
  const needsPct = Number(existingMonthly?.needs_pct ?? existingRoot?.needs_pct ?? 50);
  const savingsPct = Number(existingMonthly?.savings_pct ?? existingRoot?.savings_pct ?? 30);
  const funPct = Number(existingMonthly?.fun_pct ?? existingRoot?.fun_pct ?? 20);

  const saveTx = db.transaction(() => {
    db.prepare(`
      INSERT INTO monthly_budgets (
        user_id, month, total_amount, needs_pct, savings_pct, fun_pct,
        alert_enabled, alert_threshold, over_budget_alert_enabled, push_notification_enabled, updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      ON CONFLICT(user_id, month) DO UPDATE SET
        alert_enabled = excluded.alert_enabled,
        alert_threshold = excluded.alert_threshold,
        over_budget_alert_enabled = excluded.over_budget_alert_enabled,
        push_notification_enabled = excluded.push_notification_enabled,
        updated_at = CURRENT_TIMESTAMP
    `).run(
      userId,
      month,
      resolvedTotalAmount,
      needsPct,
      savingsPct,
      funPct,
      resolvedAlertEnabled,
      resolvedThreshold,
      resolvedOverBudgetAlert,
      resolvedPushNotification
    );

    if (existingRoot) {
      db.prepare(`
        UPDATE budgets
        SET
          alert_enabled = ?,
          alert_threshold = ?,
          over_budget_alert_enabled = ?,
          push_notification_enabled = ?,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `).run(
        resolvedAlertEnabled,
        resolvedThreshold,
        resolvedOverBudgetAlert,
        resolvedPushNotification,
        existingRoot.id
      );
    } else {
      db.prepare(`
        INSERT INTO budgets (
          user_id, category_id, name, amount_limit, total_amount,
          needs_pct, savings_pct, fun_pct, period, month,
          alert_enabled, alert_threshold, over_budget_alert_enabled, push_notification_enabled
        )
        VALUES (?, NULL, 'Budget Bulanan', ?, ?, ?, ?, ?, 'monthly', ?, ?, ?, ?, ?)
      `).run(
        userId,
        resolvedTotalAmount,
        resolvedTotalAmount,
        needsPct,
        savingsPct,
        funPct,
        month,
        resolvedAlertEnabled,
        resolvedThreshold,
        resolvedOverBudgetAlert,
        resolvedPushNotification
      );
    }
  });

  saveTx();

  return getBudgetWarningStatusQuery(db, userId, { month });
}

/**
 * Toggles or sets the master budget warning alert setting for a user & month.
 */
export function toggleBudgetAlert(db, userId, payload = {}) {
  const hasExplicitValue =
    payload.isAlertEnabled !== undefined ||
    payload.alertEnabled !== undefined ||
    payload.alert_enabled !== undefined ||
    payload.enabled !== undefined ||
    payload.isEnabled !== undefined ||
    payload.active !== undefined ||
    payload.isActive !== undefined;

  return updateBudgetAlertSettings(db, userId, {
    ...payload,
    ...(hasExplicitValue ? {} : { toggle: true }),
  });
}


