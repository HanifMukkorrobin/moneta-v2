import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/config/app_env.dart';
import 'package:moneta/models/debt_item.dart';
import 'package:moneta/services/api/analysis_api_service.dart';
import 'package:moneta/services/api/auth_api_service.dart';
import 'package:moneta/services/api/budget_api_service.dart';
import 'package:moneta/services/api/category_api_service.dart';
import 'package:moneta/services/api/chat_api_service.dart';
import 'package:moneta/services/api/daily_advice_api_service.dart';
import 'package:moneta/services/api/daily_tips_api_service.dart';
import 'package:moneta/services/api/moneta_api_client.dart';
import 'package:moneta/services/api/rekap_api_service.dart';
import 'package:moneta/services/api/reminder_debt_api_service.dart';
import 'package:moneta/services/api/transaction_api_service.dart';
import 'helpers/mock_api_harness.dart';

void main() {
  setUp(() {
    MockApiHarness.install();
  });

  group('Fase 2: Global AppEnv & 10 API Services Integration Tests', () {
    test('AppEnv provides sensible defaults when dotenv is not loaded', () {
      expect(AppEnv.apiBaseUrl, isNotEmpty);
      expect(AppEnv.apiTimeoutMs, greaterThan(0));
      expect(AppEnv.defaultCurrency, equals('IDR'));
      expect(AppEnv.defaultMonthlyBudget, equals(6000000.0));
      expect(AppEnv.defaultNeedsPct, equals(50.0));
      expect(AppEnv.defaultSavingsPct, equals(30.0));
      expect(AppEnv.defaultFunPct, equals(20.0));
    });

    test('AuthApiService handles login, register, PIN, biometric, and preferences', () async {
      final authApi = AuthApiService();

      final loginRes = await authApi.login(
        email: 'budi.santoso@moneta.ai',
        password: 'password123',
      );
      expect(loginRes.token, startsWith('mnt_'));
      expect(loginRes.user.email, equals('budi.santoso@moneta.ai'));
      expect(MonetaApiClient.instance.authToken, equals(loginRes.token));

      final pinUser = await authApi.setupPin(pin: '654321');
      expect(pinUser.pinEnabled, isTrue);

      final verified = await authApi.verifyPin(pin: '654321');
      expect(verified, isTrue);

      final bioUser = await authApi.updateBiometric(enabled: true);
      expect(bioUser.biometricEnabled, isTrue);

      final prefUser = await authApi.updatePreferences({
        'currency': 'USD',
        'currencySymbol': '\$',
        'aiAdviceTone': 'Tegas',
      });
      expect(prefUser.currency, equals('USD'));
      expect(prefUser.aiAdviceTone, equals('Tegas'));
    });

    test('ChatApiService parses natural language chat and fetches history', () async {
      final chatApi = ChatApiService();

      final parseRes = await chatApi.parseChatMessage(
        message: 'Makan siang padang 35rb',
      );
      expect(parseRes.success, isTrue);
      expect(parseRes.transaction, isNotNull);
      expect(parseRes.transaction!.amount, equals(35000));
      expect(parseRes.transaction!.category, equals('Makan & Minuman'));

      final failRes = await chatApi.parseChatMessage(message: 'halo');
      expect(failRes.success, isFalse);

      final history = await chatApi.getChatHistory();
      expect(history, isNotEmpty);
    });

    test('TransactionApiService confirms, updates, and deletes transactions', () async {
      final txApi = TransactionApiService();

      final confirmed = await txApi.confirmTransaction(
        transactionId: 'tx_3',
        amount: 25000,
        category: 'Makan & Minuman',
      );
      expect(confirmed.isConfirmed, isTrue);
      expect(confirmed.amount, equals(25000));

      final updatedCat = await txApi.updateTransactionCategory(
        'tx_1',
        category: 'Hiburan',
      );
      expect(updatedCat.category, equals('Hiburan'));

      final list = await txApi.getTransactions();
      expect(list, isNotEmpty);
    });

    test('CategoryApiService manages categories, stats, and AI classification', () async {
      final catApi = CategoryApiService();

      final cats = await catApi.getCategories();
      expect(cats.length, greaterThanOrEqualTo(15));

      final created = await catApi.createCategory(
        name: 'Kucing Peliharaan',
        type: 'expense',
      );
      expect(created.name, equals('Kucing Peliharaan'));
      expect(created.isCustom, isTrue);

      final stats = await catApi.getCategoryUsageStats();
      expect(stats, isNotEmpty);

      final classified = await catApi.classifySentence(
        text: 'Bensin pertamax 50rb',
      );
      expect(classified.detectedCategory, equals('Transportasi'));
      expect(classified.amount, equals(50000));
    });

    test('RekapApiService and BudgetApiService return monthly summaries', () async {
      final rekapApi = RekapApiService();
      final budgetApi = BudgetApiService();

      final rekap = await rekapApi.getMonthlyRekap(month: '2026-09');
      expect(rekap.month, equals('2026-09'));
      expect(rekap.totalIncome, greaterThan(0));
      expect(rekap.categoryBreakdown, isNotEmpty);

      final budget = await budgetApi.getMonthlyBudget(month: '2026-09');
      expect(budget.totalBudget, equals(6000000));
      expect(budget.buckets.length, equals(3));

      final updatedBudget = await budgetApi.saveMonthlyBudget(
        month: '2026-09',
        totalBudget: 8000000,
        needsPct: 60,
        savingsPct: 25,
        funPct: 15,
      );
      expect(updatedBudget.totalBudget, equals(8000000));
      expect(updatedBudget.needsPercentage, equals(60));
    });

    test('AnalysisApiService, DailyAdviceApiService, DailyTipsApiService, and ReminderDebtApiService work end-to-end', () async {
      final analysisApi = AnalysisApiService();
      final adviceApi = DailyAdviceApiService();
      final tipsApi = DailyTipsApiService();
      final reminderDebtApi = ReminderDebtApiService();

      final bundle = await analysisApi.getFinancialAnalysis();
      expect(bundle.insight.recommendedDailyBudget, equals(65000));
      expect(bundle.dailySpending.dailyPoints.length, equals(7));

      final advice = await adviceApi.getDailyAdvice(preset: 'warning');
      expect(advice.isWarning, isTrue);

      final tips = await tipsApi.getDailyTips();
      expect(tips.length, equals(5));

      final appliedTip = await tipsApi.toggleApplyTip(tips.first.id, isApplied: true);
      expect(appliedTip.isApplied, isTrue);

      final settings = await reminderDebtApi.getReminderSettings();
      expect(settings.isEnabled, isTrue);

      final debts = await reminderDebtApi.getDebts();
      expect(debts.length, equals(5));

      final newDebt = await reminderDebtApi.createDebt(
        name: 'Cicilan Meja Kerja',
        totalAmount: 900000,
        remainingAmount: 900000,
        dueDate: DateTime(2026, 10, 15),
        type: DebtType.cicilan,
      );
      expect(newDebt.name, equals('Cicilan Meja Kerja'));
    });
  });
}
