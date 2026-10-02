# Laporan Audit Menyeluruh & Spesifikasi Integrasi Backend (`moneta-v2`)

**Tanggal Audit:** 27 September 2026  
**Arsitektur Target:** **Strict API-Only** *(Tanpa ketergantungan mock data pada kode produksi)*  
**Cakupan:** Seluruh komponen `frontend/` (Flutter) dan `backend/` (Node.js / Express + SQLite)

---

## 1. Executive Summary & Kesimpulan Utama

> **Jawaban Singkat:** **Aplikasi Flutter (`frontend/`) saat ini BELUM terintegrasi sama sekali (0%) dengan server `backend/`.**  
> Seluruh fitur pada aplikasi Flutter masih berjalan secara *in-memory* menggunakan data statis dari `frontend/lib/mock/*_mock_data.dart`, sedangkan seluruh endpoint REST API, logika bisnis, AI parser, scheduler, dan database SQLite di `backend/` sudah selesai dibangun (100%) dan lulus seluruh pengujian otomatis.

### Tabel Skor Kesiapan Komponen (Readiness Scorecard)

| Lapisan / Komponen | Status Saat Ini | Skor Kesiapan | Ringkasan Temuan |
| :--- | :---: | :---: | :--- |
| **Backend Database & Migrations (`backend/src/db/`)** | Siap Produksi | **100%** | 12 tabel utama, indeks performa, trigger sinkronisasi, dan view alias Bahasa Indonesia berjalan normal. |
| **Backend Services & Controllers (`backend/src/controllers/`, `services/`)** | Siap Produksi | **100%** | 10 controller & 19 service layer lengkap dengan validasi input, kalkulasi finansial, dan cache. |
| **Backend REST API Routes (`backend/src/routes/`)** | Siap Produksi | **100%** | 10 modul route dengan dukungan prefix `/api/*` dan alias Bahasa Indonesia/Inggris; **449/449 unit & integration test lulus**. |
| **Frontend UI Screens & Widgets (`frontend/lib/screens/`)** | Selesai (Berbasis Mock) | **95%** | 11 modul layar dan puluhan widget sudah terbangun lengkap, namun sebagian masih memegang state mock lokal. |
| **Frontend Data Models (`frontend/lib/models/`)** | Parsial | **15%** | Dari 13 file model, baru **1 model** (`UserProfile`) yang memiliki `fromJson`/`toJson`. 12 model lainnya belum memiliki serializer JSON. |
| **Frontend HTTP / API Service Layer (`frontend/lib/services/`)** | Belum Ada | **0%** | Tidak ada package `http`/`dio` di `pubspec.yaml`, dan tidak ada pemanggilan `HttpClient` di seluruh `frontend/lib/`. |
| **Integrasi End-to-End Frontend $\leftrightarrow$ Backend** | Belum Terhubung | **0%** | `AppState` dan layar-layar UI masih memanggil `MockData`, `RekapMockData`, `BudgetMockData`, `DebtMockData`, dsb. |

---

## 2. Hasil Verifikasi Runtime & Pengujian Otomatis

### 2.1. Hasil Test Suite Backend (`backend/`)
- **Perintah:** `npm test` (Node.js built-in test runner pada 49 file test)
- **Hasil:** **449 Passed, 0 Failed** (193 test suites, durasi ~18.1 detik).
- **Cakupan Terverifikasi:**
  - Skema & migrasi SQLite (`users`, `user_sessions`, `categories`, `transactions`, `chat_logs`, `budgets`, `monthly_budgets`, `ai_insights`, `daily_tips`, `user_saving_tips`, `reminder_settings`, `daily_advice_cache`, `notification_logs`, `debts`).
  - Seluruh endpoint autentikasi, token sesi, PIN & biometrik, preferensi aplikasi, dan sinkronisasi akun.
  - Parsing chat AI, klasifikasi kategori otomatis, konfirmasi/edit/hapus transaksi, dan sinkronisasi ke rekap & budget.
  - Kalkulasi rekap bulanan, perbandingan antar-bulan, alokasi budget 50/30/20, peringatan dini 3-level, proyeksi habis saldo, saran harian AI, tips hemat harian, pengingat terjadwal, dan pencatatan hutang/paylater.

### 2.2. Hasil Static Analysis & Test Suite Frontend (`frontend/`)
- **Perintah `flutter analyze`:**
  - **Hasil:** **0 Error kompilasi**, terdapat **29 warning/info** (mayoritas berupa `unused_import` pada file mock/model dan `deprecated_member_use` untuk `activeColor` pada `Switch`/`Checkbox` di Flutter versi terbaru).
- **Perintah `flutter test`:**
  - **Hasil:** **317 Passed, 2 Failed** (total 319 test kasus di dalam 47 file test, durasi ~40 detik).
  - **Detail 2 Test Gagal Saat Ini (Non-Integrasi / Perubahan Navigasi UI):**
    1. `test/akun_pengaturan_screen_test.dart` (baris 272 — *"ChatScreen AppBar account button navigates to AkunPengaturanScreen"*): Mencari `Key('chat_appbar_account_button')` pada `ChatScreen` yang sudah dipindahkan ke tab navigasi utama (`AkunPengaturanScreen`).
    2. `test/widget_test.dart` (baris 20 — *"Moneta smoke test and ChatScreen verification"*): Mengharapkan teks `"9Router AI Siap"` pada tampilan awal aplikasi, padahal tab default `MainNavigationScreen` kini membuka `BerandaScreen` terlebih dahulu, bukan `ChatScreen`.
  - **Catatan Arsitektur Test:** Seluruh 319 test di `frontend/test/` saat ini masih menguji widget secara sinkron terhadap `AppState` in-memory dan `lib/mock/*_mock_data.dart`.

---

## 3. Audit Ketergantungan Mock Data di Frontend (24 Titik Ketergantungan)

Untuk mencapai arsitektur **Strict API-Only**, seluruh ketergantungan pada `frontend/lib/mock/` dan simulasi lokal berikut **wajib dihapus/diganti** dengan pemanggilan API:

### 3.1. Daftar File Mock (`frontend/lib/mock/`)
1. [`mock_data.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/mock/mock_data.dart) — Pesan chat awal, transaksi awal, kategori awal, dan parser regex lokal `MockData.parseTextOrNull()`.
2. [`rekap_mock_data.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/mock/rekap_mock_data.dart) — Data rekap bulanan statis (`2026-09`, `2026-08`, `2026-07`).
3. [`budget_mock_data.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/mock/budget_mock_data.dart) — Data budget bulanan & alokasi 50/30/20 statis.
4. [`ai_insight_mock_data.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/mock/ai_insight_mock_data.dart) — Preset insight AI (Normal, Warning, Critical).
5. [`daily_spending_mock_data.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/mock/daily_spending_mock_data.dart) — Grafik 7 hari pengeluaran harian statis.
6. [`saving_tips_mock_data.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/mock/saving_tips_mock_data.dart) — Daftar tips hemat harian & riwayat tips statis.
7. [`debt_mock_data.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/mock/debt_mock_data.dart) — Daftar catatan hutang/paylater awal.
8. [`category_confirmation_mock_data.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/mock/category_confirmation_mock_data.dart) — Daftar antrean konfirmasi kategori statis.

### 3.2. Layar & Widget yang Mengakses Mock Secara Langsung (Mem-bypass `AppState`)
Temuan kritis arsitektur frontend saat ini adalah **banyak layar tidak membaca data dari `AppState`**, melainkan langsung memanggil class `*MockData` di dalam `StatefulWidget`:

| File Screen / Widget | Masalah Arsitektur Saat Ini | Solusi pada Strict API-Only |
| :--- | :--- | :--- |
| [`rekap_bulanan_screen.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/rekap/rekap_bulanan_screen.dart) | Memanggil `RekapMockData.availableMonths` dan `RekapMockData.getMonthlyRekap(...)` langsung di `build()`. | Pindahkan state rekap bulanan ke `AppState` / `RekapApiService` (`GET /api/rekap?month=YYYY-MM` & `GET /api/rekap/months`). |
| [`month_navigator_bar.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/rekap/widgets/month_navigator_bar.dart), [`monthly_transaction_list_section.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/rekap/widgets/monthly_transaction_list_section.dart), [`transaction_detail_sheet.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/rekap/widgets/transaction_detail_sheet.dart) | Mengimpor `rekap_mock_data.dart` secara langsung untuk helper/label bulan. | Gunakan data bulan dan detail transaksi dari `AppState` / model `MonthlyRekapData` & `GET /api/transactions/:id`. |
| [`atur_budget_screen.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/budget/atur_budget_screen.dart) | Menyimpan `_budgetSummary` sebagai state lokal dari `BudgetMockData.getMonthlyBudget()`. Perubahan limit/alokasi hanya mengubah variabel lokal di layar. | Hubungkan ke `BudgetApiService` (`GET/PUT/DELETE /api/budgets/monthly`, `PUT /api/budgets/allocation`, `PUT /api/budgets/alerts`) dan sinkronkan dengan `AppState`. |
| [`category_confirmation_screen.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/category_confirmation/category_confirmation_screen.dart) | Menginisialisasi `_items = CategoryConfirmationMockData.getInitialItems()` yang terpisah dari transaksi pending di `AppState`. | Ambil daftar transaksi berstatus `is_confirmed = 0` / `is_guessed = 1` dari `GET /api/transactions?confirmed=false` dan konfirmasi lewat `POST /api/transactions/:id/confirm`. |
| [`daily_saving_tips_card.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/beranda/widgets/daily_saving_tips_card.dart) & [`riwayat_tips_hemat_screen.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/beranda/riwayat_tips_hemat_screen.dart) | Memuat `_tips` dari `SavingTipsMockData.getDailyTips()` dan `getHistoryTips()` secara lokal. Toggle tip tidak tersimpan saat pindah halaman. | Hubungkan ke `TipsApiService` (`GET /api/tips-harian`, `GET /api/riwayat-tips`, `POST /api/tips-harian/:id/toggle`). |
| [`beranda_screen.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/beranda/beranda_screen.dart) & [`analisa_keuangan_screen.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/analisa/analisa_keuangan_screen.dart) | Memiliki tombol simulasi preset mock (`_cycleMockPreset` / `_toggleAnalysisPreset`) yang memanggil `AiInsightMockData` & `DailySpendingMockData`. | Ganti dengan fetch & refresh ke `GET /api/saran-harian`, `POST /api/saran-harian/refresh`, dan `GET /api/analisa`, `POST /api/analisa/recalculate`. |
| [`manual_input_sheet.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/chat/widgets/manual_input_sheet.dart), [`edit_transaction_sheet.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/chat/widgets/edit_transaction_sheet.dart), [`category_picker_sheet.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/category_confirmation/widgets/category_picker_sheet.dart), [`edit_category_sheet.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/screens/category_confirmation/widgets/edit_category_sheet.dart) | Mengimpor `mock_data.dart` untuk daftar pilihan ikon/warna atau kategori default. | Pindahkan konstanta palet ikon & warna ke `lib/utils/category_icon_mapper.dart` (utility murni, bukan mock data) dan baca daftar kategori dari `AppState.categories` (`GET /api/categories`). |

---

## 4. Analisa Gap Kontrak Data: Model Dart vs JSON Response Backend

Tabel berikut merinci hasil pengecekan **13 model di `frontend/lib/models/`** terhadap payload JSON dari **10 controller di `backend/src/controllers/`**:

| No | File Model Dart | Status `fromJson` / `toJson` | Struktur JSON dari Backend | Gap & Penyesuaian yang Diperlukan |
| :--- | :--- | :---: | :--- | :--- |
| 1 | [`user_profile.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/user_profile.dart) | ✅ Ada | `GET /api/preferences` & `POST /api/auth/login` mengembalikan objek `user` / `preferences` dengan camelCase & snake_case alias. | Tambahkan field opsional `sessionToken` atau simpan di `AuthSessionStorage`. Pastikan `pinCode` tidak diharapkan dari response backend (backend menyimpan `pin_hash` demi keamanan dan memverifikasi via `POST /api/auth/pin/verify`). |
| 2 | [`transaction_item.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/transaction_item.dart) | ❌ Belum Ada | `GET /api/transactions` & `POST /api/chat/parse` mengembalikan `{ id: 1, note, amount, type, category / categoryName, occurredAt / occurred_at, isConfirmed / is_confirmed, isGuessed / is_guessed, confidenceScore, aiReasoning, isCustomCategory }`. | 1. Buat `TransactionItem.fromJson` & `toJson`.<br>2. Konversi `json['id'].toString()` karena SQLite menggunakan `INTEGER PRIMARY KEY`.<br>3. Tangani boolean SQLite (`0`/`1` maupun `true`/`false`) untuk `isConfirmed`, `isGuessedCategory`, `isCustomCategory`. |
| 3 | [`chat_message.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/chat_message.dart) | ❌ Belum Ada | Dibentuk dari riwayat `GET /api/chat/history` dan respons `POST /api/chat/parse`. | Buat factory `ChatMessage.fromChatLogJson(Map<String, dynamic> json)` yang mengubah satu entri `chat_logs` menjadi pasangan bubble pesan user + bubble balasan AI. |
| 4 | [`chat_log_item.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/chat_log_item.dart) | ❌ Belum Ada | `GET /api/chat/history` mengembalikan `{ id: 1, message, parsedJson, status, createdAt, transaction: {...} }`. | Buat `ChatLogItem.fromJson` & `toJson`. Konversi `id: json['id'].toString()` dan parse nested `transaction` menggunakan `TransactionItem.fromJson`. |
| 5 | [`category_item.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/category_item.dart) | ❌ Belum Ada | `GET /api/categories` mengembalikan `{ id: 1, name, type, isDefault / is_default, icon: "restaurant", color: "#EF4444", createdAt }`. | Buat `CategoryItem.fromJson` & `toJson` dengan helper mapper `CategoryIconMapper.parseIcon(String?)` $\leftrightarrow$ `IconData` dan `CategoryIconMapper.parseColor(String?)` $\leftrightarrow$ `Color`. |
| 6 | [`category_usage.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/category_usage.dart) | ❌ Belum Ada | `GET /api/categories/frequent` mengembalikan `{ name, type, count / usageCount, icon, color, isCustom }`. | Buat `CategoryUsage.fromJson` menggunakan `CategoryIconMapper`. |
| 7 | [`category_confirmation_item.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/category_confirmation_item.dart) | ❌ Belum Ada | `POST /api/categories/classify` & `GET /api/transactions` mengembalikan `{ id, rawSentence / note, detectedCategory / category, confidenceScore, aiReasoning, type, typeReasoning, amount, occurredAt, isConfirmed, isCustomCategory, alternativeCategories }`. | Buat `CategoryConfirmationItem.fromJson` & `toJson` yang mendukung mapping dari endpoint `/api/categories/classify` maupun transaksi pending. |
| 8 | [`monthly_rekap_data.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/monthly_rekap_data.dart) | ❌ Belum Ada | `GET /api/rekap?month=YYYY-MM` mengembalikan `{ month, monthLabel, summary: {...}, comparison: {...}, categoryBreakdown: [...], transactions: [...] }`. | Buat `MonthlyRekapData.fromJson` dan `CategoryBreakdownItem.fromJson` yang meratakan (*flatten*) properti dari objek `summary` dan `comparison` ke dalam field `MonthlyRekapData`. |
| 9 | [`budget_item.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/budget_item.dart) | ❌ Belum Ada | `GET /api/budgets/monthly?month=YYYY-MM` mengembalikan `{ month, monthLabel, totalBudget, totalSpent, allocation: { needsPct, savingsPct, funPct }, buckets: [...], categoryBudgets: [...], warning: {...} }`. | Buat `MonthlyBudgetSummary.fromJson`, `BudgetBucketItem.fromJson`, dan `CategoryBudgetItem.fromJson` beserta informasi pengaturan alert (`alertEnabled`, `alertThreshold`, `overBudgetAlertEnabled`, `pushNotificationEnabled`). |
| 10 | [`ai_insight_item.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/ai_insight_item.dart) | ❌ Belum Ada | `GET /api/saran-harian` mengembalikan objek `insight` yang **sudah diformat khusus** oleh `formatInsightPayload()` di `dailyAdviceController.js` (`id`, `userId`, `date`, `recommendedDailyBudget`, `estimatedDaysLeft`, `dailyAdvice`, `warnLevel`, `avgDailySpend`, `totalMonthlyBudget`, `totalSpent`, `remainingBalance`). | Buat `AiInsightItem.fromJson` (sangat mudah karena `dailyAdviceController.js` baris 60–81 sudah menyamakan nama field dengan model Flutter). |
| 11 | [`daily_spending_item.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/daily_spending_item.dart) | ❌ Belum Ada | `GET /api/analisa/daily-average` & `GET /api/analisa` (`dailySpending`) mengembalikan `{ avgDailySpend, targetDailySpend, weekOverWeekPercent, highestSpendAmount, highestSpendDay, lowestSpendAmount, lowestSpendDay, topCategoryName, topCategoryPercentage, dailyPoints: [...] }`. | Buat `DailySpendingAnalysis.fromJson` dan `DailySpendingPoint.fromJson`. |
| 12 | [`saving_tip_item.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/saving_tip_item.dart) | ❌ Belum Ada | `GET /api/tips-harian` & `GET /api/riwayat-tips` mengembalikan `{ id, title, category, description, potentialSaving, impactLevel, icon, isApplied, actionText, date, appliedAt }`. | Buat `SavingTipItem.fromJson` & `toJson` dengan konversi `id.toString()` dan pemetaan nama `icon` ke `IconData`. |
| 13 | [`daily_reminder_settings.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/daily_reminder_settings.dart) | ❌ Belum Ada | `GET /api/pengaturan-pengingat` mengembalikan `settings` dengan `morningReminderTime: "08:00"`, `eveningReminderTime: "20:00"`, `activeDays: [1,2,3,4,5,6,7]`, dsb. | Buat `DailyReminderSettings.fromJson` & `toJson` yang mengonversi string `"HH:mm"` $\leftrightarrow$ `TimeOfDay(hour, minute)`. |
| 14 | [`debt_item.dart`](file:///Users/tra-mac-020423/Desktop/personal-space/projects/moneta-v2/frontend/lib/models/debt_item.dart) | ❌ Belum Ada | `GET /api/debts` mengembalikan `{ id, name, totalAmount, remainingAmount, dueDate, status, type, notes }`. | Buat `DebtItem.fromJson` & `toJson` serta parser `DebtType.fromString(String?)` untuk memetakan `'kartu_kredit'`/`'kartuKredit'` dan `'pinjaman_pribadi'`/`'pinjamanPribadi'`. |

---

## 5. Spesifikasi Teknis Integrasi (`Strict API-Only`)

### 5.1. Konfigurasi Dependensi (`frontend/pubspec.yaml`)
Tambahkan package `http` pada `dependencies` di `frontend/pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  intl: ^0.20.3
  http: ^1.2.2
```

### 5.2. Spesifikasi Core HTTP Client (`frontend/lib/services/api/moneta_api_client.dart`)
- **Resolusi Base URL Otomatis:**
  - Dapat dikonfigurasi lewat `--dart-define=API_BASE_URL=http://localhost:3000`
  - Default cerdas berdasarkan platform: Android Emulator menggunakan `http://10.0.2.2:3000`, sedangkan iOS Simulator / macOS / Web / Desktop menggunakan `http://localhost:3000`.
- **Manajemen Autentikasi & Header:**
  - Menyimpan `authToken` dan `userId` aktif (di-persist melalui `LocalPreferenceService`).
  - Menyertakan header `Content-Type: application/json`, `Authorization: Bearer <token>`, dan `x-user-id: <userId>` pada setiap request.
- **Dependency Injection untuk Pengujian (`Strict API-Only Testability`):**
  - Menerima `http.Client` opsional pada constructor (`MonetaApiClient({http.Client? httpClient})`) sehingga pada `flutter test`, seluruh request HTTP dapat di-intercept menggunakan `MockClient` dari `package:http/testing.dart` tanpa menyentuh file `lib/mock/*`.

### 5.3. Spesifikasi 10 Service API (`frontend/lib/services/api/`)

| Nama Service File | Endpoint Backend yang Dipanggil | Method Utama |
| :--- | :--- | :--- |
| `auth_api_service.dart` | `/api/auth/*`, `/api/preferences/*`, `/api/sync/*` | `login()`, `register()`, `verifySession()`, `logout()`, `getSecurityStatus()`, `setupPin()`, `verifyPin()`, `changePin()`, `togglePin()`, `toggleBiometric()`, `verifyBiometric()`, `getPreferences()`, `updatePreferences()`, `resetPreferences()`, `syncAccount()`, `exportData()`, `resetAccountData()` |
| `chat_api_service.dart` | `/api/chat/*` | `parseMessage(String message)`, `getChatHistory()`, `deleteChatLog(String id)`, `restoreChatLog(String id)` |
| `transaction_api_service.dart` | `/api/transactions/*` | `listTransactions({String? month, String? type, bool? confirmed, String? search})`, `getTransactionDetail(String id)`, `confirmTransaction(...)`, `createManualTransaction(...)`, `updateTransaction(...)`, `updateCategoryAndType(...)`, `deleteTransaction(String id)` |
| `category_api_service.dart` | `/api/categories/*` | `listCategories()`, `createCustomCategory(...)`, `updateCustomCategory(...)`, `deleteCustomCategory(String id)`, `classifyText(...)`, `getFrequentCategories({required String type, int limit = 5})` |
| `rekap_api_service.dart` | `/api/rekap/*` | `getMonthlyRekap(String month)`, `refreshMonthlyRekap(String month)`, `getAvailableMonths()`, `getComparison(String month)`, `getCategoryBreakdown(String month)` |
| `budget_api_service.dart` | `/api/budgets/*` | `getMonthlyBudget(String month)`, `upsertMonthlyBudget(String month, double amount)`, `deleteMonthlyBudget(String month)`, `getAllocation(String month)`, `updateAllocation(String month, ...)`, `resetAllocation(String month)`, `getAlertSettings(String month)`, `updateAlertSettings(String month, ...)` |
| `analysis_api_service.dart` | `/api/analisa/*` | `getFullAnalysis({String? date, bool refresh = false})`, `getDailyAverage()`, `getMoneyDepletion()`, `getEarlyWarning()`, `recalculateAnalysis()` |
| `daily_advice_api_service.dart` | `/api/saran-harian/*` | `getTodayAdvice({bool refresh = false})`, `applyTodayAdvice()`, `refreshTodayAdvice()`, `simulateAdvice(double dailyLimit)` |
| `daily_tips_api_service.dart` | `/api/tips-harian/*`, `/api/riwayat-tips/*` | `getDailyTips({String? category})`, `getTipsHistory({String? search, String? status, String? category})`, `toggleTipStatus(String tipId)`, `generateTips()` |
| `reminder_debt_api_service.dart` | `/api/pengaturan-pengingat/*`, `/api/notifikasi/*`, `/api/debts/*` | `getReminderSettings()`, `updateReminderSettings(...)`, `resetReminderSettings()`, `triggerTestReminder()`, `getNotificationHistory()`, `listDebts({String? status, String? search})`, `getDebtSummary()`, `createDebt(...)`, `updateDebt(...)`, `markDebtPaid(String id, ...)`, `reopenDebt(String id)`, `deleteDebt(String id)` |

---

## 6. Roadmap Implementasi Menuju `Strict API-Only` (5 Fase)

### Fase 1: Pondasi HTTP Client, Serializer Model & Autentikasi/Preferensi
1. Tambahkan `http` di `frontend/pubspec.yaml` dan buat utility `CategoryIconMapper` (`lib/utils/category_icon_mapper.dart`).
2. Implementasikan `fromJson` dan `toJson` pada seluruh 13 model di `frontend/lib/models/`.
3. Buat `MonetaApiClient` dan `AuthApiService`.
4. Hubungkan `AuthScreen`, `LoginForm`, `PinLockScreen`, `AkunPengaturanScreen`, dan `PreferensiAplikasiScreen` ke endpoint `/api/auth/*`, `/api/preferences/*`, dan `/api/sync/*`.

### Fase 2: Integrasi Kategori, Chat AI & Transaksi (CRUD)
1. Buat `CategoryApiService`, `ChatApiService`, dan `TransactionApiService`.
2. Refactor `AppState.sendMessage`, `confirmTransaction`, `addManualTransaction`, `updateTransaction`, `deleteTransaction`, `addCustomCategory`, `updateCategory`, dan `deleteCategory` agar memanggil API backend dan memperbarui state dari response server.
3. Hubungkan `ChatScreen`, `ChatHistoryScreen`, `TransactionHistoryScreen`, `CategoryConfirmationScreen`, dan `ManageCategoriesScreen` ke API backend.

### Fase 3: Integrasi Rekap Bulanan & Atur Budget 50/30/20
1. Buat `RekapApiService` dan `BudgetApiService`.
2. Refactor `RekapBulananScreen` agar mengambil daftar bulan tersedia (`GET /api/rekap/months`) dan data rekap (`GET /api/rekap?month=...`) dari backend, serta hapus ketergantungan pada `RekapMockData`.
3. Refactor `AturBudgetScreen` agar seluruh operasi baca/ubah/hapus batas budget, alokasi persen 50/30/20, dan pengaturan peringatan memanggil `/api/budgets/*`, serta hapus ketergantungan pada `BudgetMockData`.

### Fase 4: Integrasi Beranda, Analisa Keuangan AI, Saran Harian & Tips Hemat
1. Buat `AnalysisApiService`, `DailyAdviceApiService`, dan `DailyTipsApiService`.
2. Refactor `BerandaScreen` dan `AnalisaKeuanganScreen` agar memuat `AiInsightItem` dan `DailySpendingAnalysis` dari `/api/saran-harian` dan `/api/analisa`.
3. Refactor `DailySavingTipsCard` dan `RiwayatTipsHematScreen` agar mengambil dan men-toggle tips melalui `/api/tips-harian` dan `/api/riwayat-tips`, serta hapus `SavingTipsMockData`.

### Fase 5: Integrasi Hutang/Paylater, Pengingat Harian, Penghapusan `lib/mock/*` & Penyesuaian Test
1. Buat `ReminderDebtApiService`.
2. Hubungkan `HutangScreen` ke `/api/debts/*` dan `PengaturanPengingatScreen` ke `/api/pengaturan-pengingat/*`.
3. **Pembersihan Strict API-Only:** Hapus seluruh direktori `frontend/lib/mock/` (8 file) dan pastikan `grep -rn "mock" frontend/lib/` bersih dari mock data produksi.
4. Sediakan helper test `MockApiClient` di `frontend/test/helpers/test_api_harness.dart` agar ke-47 file test di `frontend/test/` berjalan hijau menggunakan *mock HTTP response* sesuai standar **Strict API-Only**.
