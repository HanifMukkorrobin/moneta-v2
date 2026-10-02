import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moneta/services/api/moneta_api_client.dart';

/// Test harness providing a stateful `MockClient` that emulates the Moneta
/// Express + SQLite backend JSON contracts for unit and widget tests.
class MockApiHarness {
  static Map<String, dynamic> userState = _defaultUserJson();
  static List<Map<String, dynamic>> categoriesState = _defaultCategoriesJson();
  static List<Map<String, dynamic>> transactionsState = _defaultTransactionsJson();
  static List<Map<String, dynamic>> chatLogsState = _defaultChatLogsJson();
  static List<Map<String, dynamic>> debtsState = _defaultDebtsJson();
  static List<Map<String, dynamic>> dailyTipsState = _defaultDailyTipsJson();
  static List<Map<String, dynamic>> historyTipsState = _defaultHistoryTipsJson();
  static Map<String, dynamic> reminderSettingsState = _defaultReminderSettingsJson();
  static Map<String, Map<String, dynamic>> budgetsByMonth = _defaultBudgetsByMonth();

  static void resetState() {
    userState = _defaultUserJson();
    categoriesState = _defaultCategoriesJson();
    transactionsState = _defaultTransactionsJson();
    chatLogsState = _defaultChatLogsJson();
    debtsState = _defaultDebtsJson();
    dailyTipsState = _defaultDailyTipsJson();
    historyTipsState = _defaultHistoryTipsJson();
    reminderSettingsState = _defaultReminderSettingsJson();
    budgetsByMonth = _defaultBudgetsByMonth();
  }

  static MockClient install({bool reset = true}) {
    if (reset) {
      resetState();
    }
    final client = createClient();
    MonetaApiClient.instance.setHttpClient(client);
    return client;
  }

  static MockClient createClient() {
    return MockClient((http.Request request) async {
      final path = request.url.path;
      final method = request.method.toUpperCase();
      final query = request.url.queryParameters;
      Map<String, dynamic> body = <String, dynamic>{};
      if (request.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(request.body);
          if (decoded is Map<String, dynamic>) {
            body = decoded;
          }
        } catch (_) {}
      }

      // 1. Auth & Profile & Preferences & Sync
      if (path.endsWith('/auth/register') && method == 'POST') {
        final email = (body['email'] ?? '').toString().trim();
        final name = (body['displayName'] ?? body['name'] ?? 'Pengguna Baru').toString().trim();
        if (email.isEmpty || !email.contains('@')) {
          return _jsonResponse({'success': false, 'error': 'Format alamat email tidak valid.'}, 400);
        }
        userState = {
          ...userState,
          'id': 1,
          'displayName': name,
          'email': email,
          if (body['currency'] != null) 'currency': body['currency'],
        };
        return _jsonResponse({
          'success': true,
          'token': 'mnt_test_session_token_12345',
          'data': {
            'user': userState,
            'token': 'mnt_test_session_token_12345',
          },
        }, 201);
      }

      if (path.endsWith('/auth/login') && method == 'POST') {
        final email = (body['email'] ?? '').toString().trim();
        final password = (body['password'] ?? '').toString();
        if (email.isEmpty || password.length < 4) {
          return _jsonResponse({'success': false, 'error': 'Email atau kata sandi tidak valid.'}, 401);
        }
        userState = {
          ...userState,
          'email': email,
          if (userState['displayName'] == null || userState['displayName'] == '')
            'displayName': 'Budi Santoso',
        };
        return _jsonResponse({
          'success': true,
          'token': 'mnt_test_session_token_12345',
          'data': {
            'user': userState,
            'token': 'mnt_test_session_token_12345',
          },
        });
      }

      if (path.endsWith('/auth/verify') && method == 'GET') {
        return _jsonResponse({
          'success': true,
          'valid': true,
          'data': {'valid': true, 'user': userState},
        });
      }

      if (path.endsWith('/auth/logout') && method == 'POST') {
        return _jsonResponse({'success': true, 'message': 'Berhasil keluar dari sesi.'});
      }

      if (path.endsWith('/auth/profile')) {
        if (method == 'GET') {
          return _jsonResponse({'success': true, 'data': {'user': userState}});
        }
        if (method == 'PUT' || method == 'PATCH') {
          userState = {...userState, ...body};
          return _jsonResponse({'success': true, 'data': {'user': userState}});
        }
      }

      if (path.endsWith('/auth/pin/setup') && method == 'POST') {
        final pin = (body['pin'] ?? '').toString();
        userState = {
          ...userState,
          'pinEnabled': true,
          'pinCode': pin,
        };
        return _jsonResponse({'success': true, 'data': {'user': userState}});
      }

      if (path.endsWith('/auth/pin/verify') && method == 'POST') {
        final pin = (body['pin'] ?? '').toString();
        final storedPin = (userState['pinCode'] ?? '123456').toString();
        final ok = pin == storedPin;
        return _jsonResponse(
          {'success': ok, 'verified': ok, if (!ok) 'error': 'PIN salah'},
          ok ? 200 : 401,
        );
      }

      if (path.endsWith('/auth/pin') && method == 'DELETE') {
        userState = {
          ...userState,
          'pinEnabled': false,
          'pinCode': null,
        };
        return _jsonResponse({'success': true, 'data': {'user': userState}});
      }

      if (path.endsWith('/auth/biometric') && (method == 'PUT' || method == 'POST')) {
        final enabled = body['enabled'] == true || body['biometricEnabled'] == true;
        userState = {
          ...userState,
          'biometricEnabled': enabled,
        };
        return _jsonResponse({'success': true, 'data': {'user': userState}});
      }

      if (path.endsWith('/preferences/reset') && method == 'POST') {
        userState = {
          ..._defaultUserJson(),
          'displayName': userState['displayName'],
          'email': userState['email'],
        };
        return _jsonResponse({'success': true, 'data': {'preferences': userState}});
      }

      if (path.endsWith('/preferences')) {
        if (method == 'GET') {
          return _jsonResponse({'success': true, 'data': {'preferences': userState}});
        }
        if (method == 'PUT' || method == 'PATCH') {
          userState = {...userState, ...body};
          return _jsonResponse({'success': true, 'data': {'preferences': userState}});
        }
      }

      if (path.endsWith('/sync/clear') && method == 'DELETE') {
        transactionsState = [];
        chatLogsState = [];
        debtsState = [];
        return _jsonResponse({'success': true, 'message': 'Data akun dibersihkan.'});
      }

      if (path.endsWith('/sync')) {
        return _jsonResponse({
          'success': true,
          'data': {
            'user': userState,
            'transactionsCount': transactionsState.length,
            'categoriesCount': categoriesState.length,
            'debtsCount': debtsState.length,
          },
        });
      }

      // 2. Chat Parsing & History
      if (path.endsWith('/chat/parse') && method == 'POST') {
        final msg = (body['message'] ?? '').toString().trim();
        final lower = msg.toLowerCase();
        final hasDigit = RegExp(r'\d').hasMatch(lower);
        if (msg.isEmpty ||
            !hasDigit ||
            lower.contains('gagal') ||
            lower.contains('error') ||
            lower.contains('rusak') ||
            lower == 'halo' ||
            lower == 'test' ||
            lower == 'bingung') {
          final failLog = {
            'id': 'log_${DateTime.now().microsecondsSinceEpoch}',
            'message': msg,
            'status': 'failed',
            'createdAt': DateTime.now().toIso8601String(),
          };
          chatLogsState.insert(0, failLog);
          return _jsonResponse({
            'success': false,
            'chatLogId': failLog['id'],
            'error': 'Nominal transaksi tidak terdeteksi dalam kalimat.',
          }, 422);
        }

        final parsedTx = _heuristicParse(msg);
        transactionsState.insert(0, parsedTx);
        final chatLog = {
          'id': 'log_${DateTime.now().microsecondsSinceEpoch}',
          'message': msg,
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
          'transaction': parsedTx,
        };
        chatLogsState.insert(0, chatLog);
        return _jsonResponse({
          'success': true,
          'chatLogId': chatLog['id'],
          'data': parsedTx,
        }, 201);
      }

      if (path.contains('/chat/history')) {
        if (method == 'GET') {
          final status = query['status'];
          var list = List<Map<String, dynamic>>.from(chatLogsState);
          if (status != null && status.isNotEmpty) {
            list = list.where((l) => l['status'] == status).toList();
          }
          return _jsonResponse({'success': true, 'data': list});
        }
        if (method == 'DELETE') {
          final idPart = path.split('/').last;
          for (final log in chatLogsState) {
            if (log['id'].toString().contains(idPart)) {
              log['status'] = 'deleted';
            }
          }
          return _jsonResponse({'success': true});
        }
        if (path.endsWith('/restore') && method == 'POST') {
          final parts = path.split('/');
          final idPart = parts[parts.length - 2];
          Map<String, dynamic>? restored;
          for (final log in chatLogsState) {
            if (log['id'].toString().contains(idPart)) {
              log['status'] = 'pending';
              restored = log;
            }
          }
          return _jsonResponse({'success': true, 'data': restored ?? chatLogsState.first});
        }
      }

      // 3. Categories & Classification
      if (path.endsWith('/categories/stats') && method == 'GET') {
        final stats = categoriesState.map((cat) {
          final name = cat['name'].toString();
          final count = transactionsState
              .where((t) => t['category'].toString().toLowerCase() == name.toLowerCase())
              .length;
          return {
            'name': name,
            'type': cat['type'],
            'count': count,
            'isCustom': !(cat['isDefault'] == true),
          };
        }).toList();
        return _jsonResponse({'success': true, 'data': stats});
      }

      if (path.endsWith('/categories/classify') && method == 'POST') {
        final text = (body['text'] ?? '').toString();
        final parsed = _heuristicParse(text);
        return _jsonResponse({
          'success': true,
          'data': {
            'id': 'conf_${DateTime.now().microsecondsSinceEpoch}',
            'rawSentence': text,
            'detectedCategory': parsed['category'],
            'confidenceScore': parsed['confidenceScore'] ?? 0.95,
            'aiReasoning': parsed['aiReasoning'] ?? 'Kategori hasil klasifikasi AI',
            'type': parsed['type'],
            'typeReasoning': parsed['type'] == 'income'
                ? 'Penerimaan pemasukan dana'
                : 'Pengeluaran konsumsi/pembelian',
            'amount': parsed['amount'],
            'occurredAt': parsed['occurredAt'],
            'isConfirmed': false,
          },
        });
      }

      if (path.contains('/categories')) {
        if (method == 'GET') {
          final type = query['type'];
          var list = List<Map<String, dynamic>>.from(categoriesState);
          if (type != null && type.isNotEmpty) {
            list = list.where((c) => c['type'] == type).toList();
          }
          return _jsonResponse({'success': true, 'data': list});
        }
        if (method == 'POST') {
          final newCat = {
            'id': 'cat_custom_${DateTime.now().microsecondsSinceEpoch}',
            'name': (body['name'] ?? '').toString().trim(),
            'type': (body['type'] ?? 'expense').toString(),
            'isDefault': false,
            'createdAt': DateTime.now().toIso8601String(),
          };
          categoriesState.add(newCat);
          return _jsonResponse({'success': true, 'data': newCat}, 201);
        }
        if (method == 'PUT' || method == 'PATCH') {
          final idPart = path.split('/').last;
          Map<String, dynamic>? updated;
          for (final cat in categoriesState) {
            if (cat['id'].toString().contains(idPart)) {
              cat['name'] = (body['name'] ?? cat['name']).toString().trim();
              cat['type'] = (body['type'] ?? cat['type']).toString();
              updated = cat;
              break;
            }
          }
          updated ??= {
            'id': idPart,
            'name': (body['name'] ?? 'Kategori').toString(),
            'type': (body['type'] ?? 'expense').toString(),
            'isDefault': false,
          };
          return _jsonResponse({'success': true, 'data': updated});
        }
        if (method == 'DELETE') {
          final idPart = path.split('/').last;
          categoriesState.removeWhere((c) => c['id'].toString().contains(idPart));
          return _jsonResponse({'success': true});
        }
      }

      // 4. Transactions
      if (path.endsWith('/transactions/confirm') && method == 'POST') {
        final txId = body['transactionId']?.toString();
        Map<String, dynamic>? target;
        if (txId != null) {
          for (final t in transactionsState) {
            if (t['id'].toString().contains(txId)) {
              t['isConfirmed'] = true;
              if (body['note'] != null) t['note'] = body['note'];
              if (body['amount'] != null) t['amount'] = body['amount'];
              if (body['type'] != null) t['type'] = body['type'];
              if (body['category'] != null) t['category'] = body['category'];
              target = t;
              break;
            }
          }
        }
        target ??= {
          'id': txId ?? 'tx_${DateTime.now().microsecondsSinceEpoch}',
          'note': body['note'] ?? 'Transaksi Manual',
          'amount': body['amount'] ?? 25000,
          'type': body['type'] ?? 'expense',
          'category': body['category'] ?? 'Lainnya',
          'occurredAt': body['occurredAt'] ?? DateTime.now().toIso8601String(),
          'isConfirmed': true,
        };
        if (!transactionsState.contains(target)) {
          transactionsState.insert(0, target);
        }
        return _jsonResponse({'success': true, 'data': target});
      }

      if (path.contains('/transactions')) {
        if (method == 'GET') {
          final segments = path.split('/').where((s) => s.isNotEmpty).toList();
          if (segments.length >= 3 && segments.last != 'transactions') {
            final idPart = segments.last;
            final found = transactionsState.firstWhere(
              (t) => t['id'].toString().contains(idPart),
              orElse: () => transactionsState.first,
            );
            return _jsonResponse({'success': true, 'data': found});
          }
          return _jsonResponse({'success': true, 'data': transactionsState});
        }
        if (method == 'PUT' || method == 'PATCH') {
          final segments = path.split('/').where((s) => s.isNotEmpty).toList();
          final isCategoryRoute = segments.last == 'category';
          final isTypeRoute = segments.last == 'type';
          final idPart = (isCategoryRoute || isTypeRoute)
              ? segments[segments.length - 2]
              : segments.last;

          Map<String, dynamic>? updated;
          for (final t in transactionsState) {
            if (t['id'].toString().contains(idPart)) {
              if (body['note'] != null) t['note'] = body['note'];
              if (body['amount'] != null) t['amount'] = body['amount'];
              if (body['type'] != null) t['type'] = body['type'];
              if (body['category'] != null) t['category'] = body['category'];
              if (body['isConfirmed'] != null) t['isConfirmed'] = body['isConfirmed'];
              if (body['isCustom'] != null) t['isCustomCategory'] = body['isCustom'];
              updated = t;
              break;
            }
          }
          updated ??= {
            ...transactionsState.first,
            ...body,
            'id': idPart,
          };
          return _jsonResponse({'success': true, 'data': updated});
        }
        if (method == 'DELETE') {
          final idPart = path.split('/').last;
          transactionsState.removeWhere((t) => t['id'].toString().contains(idPart));
          return _jsonResponse({'success': true});
        }
      }

      // 5. Rekap Bulanan
      if (path.endsWith('/rekap/months') && method == 'GET') {
        return _jsonResponse({
          'success': true,
          'data': ['2026-09', '2026-08', '2026-07'],
        });
      }

      if (path.contains('/rekap') && method == 'GET') {
        final month = query['month'] ?? '2026-09';
        return _jsonResponse({
          'success': true,
          'data': _buildRekapResponse(month),
        });
      }

      // 6. Budgets 50/30/20
      if (path.endsWith('/budgets/reset') && method == 'POST') {
        final month = (body['month'] ?? '2026-09').toString();
        budgetsByMonth = _defaultBudgetsByMonth();
        return _jsonResponse({
          'success': true,
          'data': budgetsByMonth[month] ?? budgetsByMonth['2026-09'],
        });
      }

      if (path.contains('/budgets')) {
        if (method == 'GET') {
          final month = query['month'] ?? '2026-09';
          if (month == '2026-10' || month == 'empty_month') {
            return _jsonResponse({
              'success': true,
              'data': {
                'month': month,
                'monthLabel': 'Oktober 2026',
                'totalBudget': 0,
                'totalSpent': 0,
                'needsPercentage': 50.0,
                'savingsPercentage': 30.0,
                'funPercentage': 20.0,
                'buckets': <Map<String, dynamic>>[],
                'categoryBudgets': <Map<String, dynamic>>[],
              },
            });
          }
          return _jsonResponse({
            'success': true,
            'data': budgetsByMonth[month] ?? budgetsByMonth['2026-09'],
          });
        }
        if (method == 'POST' || method == 'PUT') {
          final month = (body['month'] ?? '2026-09').toString();
          final current = budgetsByMonth[month] ?? budgetsByMonth['2026-09']!;
          final totalBudget = (body['totalBudget'] as num?)?.toDouble() ?? 6000000.0;
          final needsPct = (body['needsPercentage'] as num?)?.toDouble() ?? 50.0;
          final savingsPct = (body['savingsPercentage'] as num?)?.toDouble() ?? 30.0;
          final funPct = (body['funPercentage'] as num?)?.toDouble() ?? 20.0;

          final updated = {
            ...current,
            'month': month,
            'totalBudget': totalBudget,
            'needsPercentage': needsPct,
            'savingsPercentage': savingsPct,
            'funPercentage': funPct,
            'buckets': [
              {
                'type': 'needs',
                'title': 'Kebutuhan Pokok',
                'percentage': needsPct,
                'amountLimit': totalBudget * (needsPct / 100),
                'amountSpent': 1600000.0,
              },
              {
                'type': 'savings',
                'title': 'Tabungan & Investasi',
                'percentage': savingsPct,
                'amountLimit': totalBudget * (savingsPct / 100),
                'amountSpent': 800000.0,
              },
              {
                'type': 'fun',
                'title': 'Hiburan & Keinginan',
                'percentage': funPct,
                'amountLimit': totalBudget * (funPct / 100),
                'amountSpent': 450000.0,
              },
            ],
            if (body['categoryBudgets'] != null)
              'categoryBudgets': body['categoryBudgets'],
          };
          budgetsByMonth[month] = updated;
          return _jsonResponse({'success': true, 'data': updated});
        }
      }

      // 7. Analisa Keuangan & Rata-Rata Harian
      if (path.endsWith('/analisa/rata-rata-harian') && method == 'GET') {
        final preset = query['preset'] ?? 'normal';
        return _jsonResponse({
          'success': true,
          'data': _buildDailySpendingJson(preset: preset),
        });
      }

      if (path.contains('/analisa') && method == 'GET') {
        final preset = query['preset'] ?? 'normal';
        return _jsonResponse({
          'success': true,
          'data': {
            'insight': _buildInsightJson(preset: preset),
            'dailyAnalysis': _buildDailySpendingJson(preset: preset),
          },
        });
      }

      // 8. Saran Harian AI
      if (path.contains('/saran-harian')) {
        final preset = query['preset'] ?? 'normal';
        return _jsonResponse({
          'success': true,
          'data': _buildInsightJson(preset: preset),
        });
      }

      // 9. Tips Hemat Harian & Riwayat Tips
      if (path.contains('/riwayat-tips') && method == 'GET') {
        return _jsonResponse({'success': true, 'data': historyTipsState});
      }

      if (path.endsWith('/tips/generate') && method == 'POST') {
        return _jsonResponse({'success': true, 'data': dailyTipsState});
      }

      if (path.contains('/tips/') && path.endsWith('/apply') && method == 'POST') {
        final parts = path.split('/');
        final idPart = parts[parts.length - 2];
        final isApplied = body['isApplied'] ?? true;
        Map<String, dynamic>? updated;
        for (final tip in dailyTipsState) {
          if (tip['id'].toString().contains(idPart)) {
            tip['isApplied'] = isApplied;
            updated = tip;
          }
        }
        for (final tip in historyTipsState) {
          if (tip['id'].toString().contains(idPart)) {
            tip['isApplied'] = isApplied;
            updated ??= tip;
          }
        }
        return _jsonResponse({
          'success': true,
          'data': updated ?? {...dailyTipsState.first, 'isApplied': isApplied},
        });
      }

      if (path.contains('/tips') && method == 'GET') {
        return _jsonResponse({'success': true, 'data': dailyTipsState});
      }

      // 10. Pengaturan Pengingat & Notifikasi & Hutang
      if (path.endsWith('/pengaturan-pengingat/reset') && method == 'POST') {
        reminderSettingsState = _defaultReminderSettingsJson();
        return _jsonResponse({'success': true, 'data': reminderSettingsState});
      }

      if (path.contains('/pengaturan-pengingat')) {
        if (method == 'GET') {
          return _jsonResponse({'success': true, 'data': reminderSettingsState});
        }
        if (method == 'PUT' || method == 'POST') {
          reminderSettingsState = {...reminderSettingsState, ...body};
          return _jsonResponse({'success': true, 'data': reminderSettingsState});
        }
      }

      if (path.contains('/notifikasi')) {
        if (method == 'POST') {
          return _jsonResponse({
            'success': true,
            'data': {
              'title': 'Pengingat Harian Moneta AI',
              'body': 'Batas aman pengeluaran harian Anda hari ini adalah Rp 65.000.',
            },
          });
        }
        return _jsonResponse({'success': true, 'data': <Map<String, dynamic>>[]});
      }

      if (path.contains('/debts')) {
        if (method == 'GET') {
          return _jsonResponse({'success': true, 'data': debtsState});
        }
        if (method == 'POST' && path.endsWith('/pay')) {
          final parts = path.split('/');
          final idPart = parts[parts.length - 2];
          Map<String, dynamic>? updated;
          for (final d in debtsState) {
            if (d['id'].toString().contains(idPart)) {
              d['remainingAmount'] = 0.0;
              d['status'] = 'paid';
              updated = d;
              break;
            }
          }
          return _jsonResponse({'success': true, 'data': updated ?? debtsState.first});
        }
        if (method == 'POST' && path.endsWith('/reopen')) {
          final parts = path.split('/');
          final idPart = parts[parts.length - 2];
          Map<String, dynamic>? updated;
          for (final d in debtsState) {
            if (d['id'].toString().contains(idPart)) {
              d['remainingAmount'] = body['remainingAmount'] ?? d['totalAmount'];
              d['status'] = 'active';
              updated = d;
              break;
            }
          }
          return _jsonResponse({'success': true, 'data': updated ?? debtsState.first});
        }
        if (method == 'POST') {
          final newDebt = {
            'id': 'debt_${DateTime.now().microsecondsSinceEpoch}',
            'name': body['name'] ?? 'Hutang Baru',
            'totalAmount': body['totalAmount'] ?? 500000,
            'remainingAmount': body['remainingAmount'] ?? body['totalAmount'] ?? 500000,
            'dueDate': body['dueDate'] ?? DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            'status': 'active',
            'type': body['type'] ?? 'paylater',
            'notes': body['notes'],
          };
          debtsState.insert(0, newDebt);
          return _jsonResponse({'success': true, 'data': newDebt}, 201);
        }
        if (method == 'PUT' || method == 'PATCH') {
          final idPart = path.split('/').last;
          Map<String, dynamic>? updated;
          for (final d in debtsState) {
            if (d['id'].toString().contains(idPart)) {
              d.addAll(body);
              updated = d;
              break;
            }
          }
          return _jsonResponse({'success': true, 'data': updated ?? debtsState.first});
        }
        if (method == 'DELETE') {
          final idPart = path.split('/').last;
          debtsState.removeWhere((d) => d['id'].toString().contains(idPart));
          return _jsonResponse({'success': true});
        }
      }

      return _jsonResponse({'success': true, 'data': <String, dynamic>{}});
    });
  }

  static http.Response _jsonResponse(Map<String, dynamic> data, [int statusCode = 200]) {
    return http.Response(
      jsonEncode(data),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  static Map<String, dynamic> _defaultUserJson() {
    return {
      'id': 1,
      'displayName': 'Budi Santoso',
      'email': 'budi.santoso@moneta.ai',
      'currency': 'IDR',
      'currencySymbol': 'Rp',
      'pinEnabled': false,
      'pinCode': null,
      'biometricEnabled': false,
      'notificationsEnabled': true,
      'aiAdviceTone': 'Standar',
      'monthlyBudgetLimit': 6000000.0,
      'accountTier': 'Personal AI',
      'dateFormat': 'DD/MM/YYYY',
      'firstDayOfWeek': 'Senin',
      'themeMode': 'Terang',
      'hideBalance': false,
      'autoConfirmChat': false,
      'hapticFeedback': true,
      'budgetAlertThreshold': 80,
      'createdAt': '2026-01-01T00:00:00.000Z',
    };
  }

  static List<Map<String, dynamic>> _defaultCategoriesJson() {
    return [
      {'id': 'cat_exp_1', 'name': 'Makan & Minuman', 'type': 'expense', 'isDefault': true},
      {'id': 'cat_exp_2', 'name': 'Transportasi', 'type': 'expense', 'isDefault': true},
      {'id': 'cat_exp_3', 'name': 'Belanja', 'type': 'expense', 'isDefault': true},
      {'id': 'cat_exp_4', 'name': 'Hiburan', 'type': 'expense', 'isDefault': true},
      {'id': 'cat_exp_5', 'name': 'Tagihan & Utilitas', 'type': 'expense', 'isDefault': true},
      {'id': 'cat_exp_6', 'name': 'Hutang & Paylater', 'type': 'expense', 'isDefault': true},
      {'id': 'cat_exp_7', 'name': 'Kebutuhan Rumah', 'type': 'expense', 'isDefault': true},
      {'id': 'cat_exp_8', 'name': 'Kesehatan', 'type': 'expense', 'isDefault': true},
      {'id': 'cat_exp_9', 'name': 'Lainnya', 'type': 'expense', 'isDefault': true},
      {'id': 'cat_custom_1', 'name': 'Gym & Fitness', 'type': 'expense', 'isDefault': false},
      {'id': 'cat_custom_2', 'name': 'Skincare & Perawatan', 'type': 'expense', 'isDefault': false},
      {'id': 'cat_custom_3', 'name': 'Langganan AI & Software', 'type': 'expense', 'isDefault': false},
      {'id': 'cat_inc_1', 'name': 'Gaji', 'type': 'income', 'isDefault': true},
      {'id': 'cat_inc_2', 'name': 'Freelance', 'type': 'income', 'isDefault': true},
      {'id': 'cat_inc_3', 'name': 'Bonus', 'type': 'income', 'isDefault': true},
      {'id': 'cat_inc_4', 'name': 'Investasi', 'type': 'income', 'isDefault': true},
      {'id': 'cat_inc_5', 'name': 'Transfer Masuk', 'type': 'income', 'isDefault': true},
      {'id': 'cat_inc_6', 'name': 'Lainnya', 'type': 'income', 'isDefault': true},
    ];
  }

  static List<Map<String, dynamic>> _defaultTransactionsJson() {
    final now = DateTime.now();
    return [
      {
        'id': 'tx_1',
        'note': 'Makan siang ayam geprek',
        'amount': 25000.0,
        'type': 'expense',
        'category': 'Makan & Minuman',
        'occurredAt': now.subtract(const Duration(minutes: 45)).toIso8601String(),
        'isConfirmed': true,
      },
      {
        'id': 'tx_2',
        'note': 'Bensin pertamax',
        'amount': 50000.0,
        'type': 'expense',
        'category': 'Transportasi',
        'occurredAt': now.subtract(const Duration(minutes: 20)).toIso8601String(),
        'isConfirmed': true,
      },
      {
        'id': 'tx_3',
        'note': 'Kopi americano',
        'amount': 22000.0,
        'type': 'expense',
        'category': 'Makan & Minuman',
        'occurredAt': now.subtract(const Duration(minutes: 5)).toIso8601String(),
        'isConfirmed': false,
      },
    ];
  }

  static List<Map<String, dynamic>> _defaultChatLogsJson() {
    final now = DateTime.now();
    return [
      {
        'id': 'log_1',
        'message': 'Makan siang ayam geprek 25rb',
        'status': 'confirmed',
        'createdAt': now.subtract(const Duration(minutes: 45)).toIso8601String(),
        'transaction': {
          'id': 'tx_1',
          'note': 'Makan siang ayam geprek',
          'amount': 25000.0,
          'type': 'expense',
          'category': 'Makan & Minuman',
          'occurredAt': now.subtract(const Duration(minutes: 45)).toIso8601String(),
          'isConfirmed': true,
        },
      },
      {
        'id': 'log_2',
        'message': 'Bensin pertamax 50rb',
        'status': 'confirmed',
        'createdAt': now.subtract(const Duration(minutes: 20)).toIso8601String(),
        'transaction': {
          'id': 'tx_2',
          'note': 'Bensin pertamax',
          'amount': 50000.0,
          'type': 'expense',
          'category': 'Transportasi',
          'occurredAt': now.subtract(const Duration(minutes: 20)).toIso8601String(),
          'isConfirmed': true,
        },
      },
      {
        'id': 'log_3',
        'message': 'Kopi americano 22rb',
        'status': 'pending',
        'createdAt': now.subtract(const Duration(minutes: 5)).toIso8601String(),
        'transaction': {
          'id': 'tx_3',
          'note': 'Kopi americano',
          'amount': 22000.0,
          'type': 'expense',
          'category': 'Makan & Minuman',
          'occurredAt': now.subtract(const Duration(minutes: 5)).toIso8601String(),
          'isConfirmed': false,
        },
      },
      {
        'id': 'log_4',
        'message': 'Gajian freelance 2.5jt',
        'status': 'confirmed',
        'createdAt': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'transaction': {
          'id': 'tx_4',
          'note': 'Gajian freelance',
          'amount': 2500000.0,
          'type': 'income',
          'category': 'Freelance',
          'occurredAt': now.subtract(const Duration(hours: 3)).toIso8601String(),
          'isConfirmed': true,
        },
      },
      {
        'id': 'log_5',
        'message': 'Beli baju kemeja kerja 185rb',
        'status': 'deleted',
        'createdAt': now.subtract(const Duration(hours: 6)).toIso8601String(),
        'transaction': {
          'id': 'tx_5',
          'note': 'Beli baju kemeja kerja',
          'amount': 185000.0,
          'type': 'expense',
          'category': 'Belanja',
          'occurredAt': now.subtract(const Duration(hours: 6)).toIso8601String(),
          'isConfirmed': false,
        },
      },
      {
        'id': 'log_6',
        'message': 'error tidak jelas',
        'status': 'failed',
        'createdAt': now.subtract(const Duration(hours: 12)).toIso8601String(),
      },
    ];
  }

  static Map<String, dynamic> _heuristicParse(String input) {
    final lower = input.toLowerCase();
    final isIncome = lower.contains('gaji') ||
        lower.contains('terima') ||
        lower.contains('bonus') ||
        lower.contains('freelance') ||
        lower.contains('transfer masuk') ||
        lower.contains('dapat');
    final type = isIncome ? 'income' : 'expense';

    String category = 'Lainnya';
    if (isIncome) {
      if (lower.contains('gaji')) {
        category = 'Gaji';
      } else if (lower.contains('freelance')) {
        category = 'Freelance';
      } else if (lower.contains('bonus')) {
        category = 'Bonus';
      } else if (lower.contains('invest')) {
        category = 'Investasi';
      } else {
        category = 'Transfer Masuk';
      }
    } else {
      if (lower.contains('kopi') ||
          lower.contains('makan') ||
          lower.contains('minum') ||
          lower.contains('ayam') ||
          lower.contains('padang') ||
          lower.contains('bakso') ||
          lower.contains('mie') ||
          lower.contains('sarapan') ||
          lower.contains('snack')) {
        category = 'Makan & Minuman';
      } else if (lower.contains('bensin') ||
          lower.contains('pertamax') ||
          lower.contains('ojol') ||
          lower.contains('grab') ||
          lower.contains('gojek') ||
          lower.contains('parkir') ||
          lower.contains('toll') ||
          lower.contains('kereta')) {
        category = 'Transportasi';
      } else if (lower.contains('baju') ||
          lower.contains('sepatu') ||
          lower.contains('beli') ||
          lower.contains('shopee') ||
          lower.contains('tokped')) {
        category = 'Belanja';
      } else if (lower.contains('nonton') ||
          lower.contains('bioskop') ||
          lower.contains('game') ||
          lower.contains('hiburan') ||
          lower.contains('steam')) {
        category = 'Hiburan';
      } else if (lower.contains('listrik') ||
          lower.contains('wifi') ||
          lower.contains('air') ||
          lower.contains('pulsa') ||
          lower.contains('kuota')) {
        category = 'Tagihan & Utilitas';
      } else if (lower.contains('hutang') ||
          lower.contains('paylater') ||
          lower.contains('spaylater') ||
          lower.contains('cicilan')) {
        category = 'Hutang & Paylater';
      } else if (lower.contains('obat') || lower.contains('dokter')) {
        category = 'Kesehatan';
      }
    }

    double amount = 20000;
    final jtMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:jt|juta)').firstMatch(lower);
    if (jtMatch != null) {
      amount = (double.tryParse(jtMatch.group(1)!.replaceAll(',', '.')) ?? 1) * 1000000;
    } else {
      final rbMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:rb|ribu|k)').firstMatch(lower);
      if (rbMatch != null) {
        amount = (double.tryParse(rbMatch.group(1)!.replaceAll(',', '.')) ?? 1) * 1000;
      } else {
        final numMatch = RegExp(r'(\d{4,})')
            .firstMatch(lower.replaceAll('.', '').replaceAll(',', ''));
        if (numMatch != null) {
          amount = double.tryParse(numMatch.group(1)!) ?? 20000;
        }
      }
    }

    return {
      'id': 'tx_${DateTime.now().microsecondsSinceEpoch}',
      'note': input.trim(),
      'amount': amount,
      'type': type,
      'category': category,
      'occurredAt': DateTime.now().toIso8601String(),
      'isConfirmed': false,
      'confidenceScore': category != 'Lainnya' ? 0.96 : 0.72,
      'aiReasoning': 'Kata kunci terdeteksi cocok dengan kategori $category',
    };
  }

  static Map<String, dynamic> _buildRekapResponse(String month) {
    if (month == '2026-10' || month == 'empty_month') {
      return {
        'month': month,
        'monthLabel': 'Oktober 2026',
        'totalIncome': 0.0,
        'totalExpense': 0.0,
        'netSavings': 0.0,
        'savingsRate': 0.0,
        'confirmedTransactionsCount': 0,
        'pendingTransactionsCount': 0,
        'lastMonthTotalExpense': 0.0,
        'lastMonthTotalIncome': 0.0,
        'expenseDiffPct': 0.0,
        'incomeDiffPct': 0.0,
        'categoryBreakdown': <Map<String, dynamic>>[],
        'transactions': <Map<String, dynamic>>[],
      };
    }

    final baseSep = [
      {
        'id': 'tx_sep_01',
        'note': 'Gaji Bulanan PT Teknologi Maju',
        'amount': 8500000.0,
        'type': 'income',
        'category': 'Gaji',
        'occurredAt': '2026-09-25T09:00:00.000',
        'isConfirmed': true,
      },
      {
        'id': 'tx_sep_02',
        'note': 'Proyek UI/UX Desain Landing Page',
        'amount': 2500000.0,
        'type': 'income',
        'category': 'Freelance',
        'occurredAt': '2026-09-20T14:30:00.000',
        'isConfirmed': true,
      },
      {
        'id': 'tx_sep_03',
        'note': 'Dividen Saham BBCA Masuk Rekening',
        'amount': 450000.0,
        'type': 'income',
        'category': 'Investasi',
        'occurredAt': '2026-09-15T11:00:00.000',
        'isConfirmed': true,
      },
      {
        'id': 'tx_sep_04',
        'note': 'Sewa Kamar Kos Bulanan',
        'amount': 1750000.0,
        'type': 'expense',
        'category': 'Kebutuhan Rumah',
        'occurredAt': '2026-09-01T10:00:00.000',
        'isConfirmed': true,
      },
      {
        'id': 'tx_sep_05',
        'note': 'Makan Malam Sushi Tei bareng Teman',
        'amount': 285000.0,
        'type': 'expense',
        'category': 'Makan & Minuman',
        'occurredAt': '2026-09-26T19:45:00.000',
        'isConfirmed': true,
      },
      {
        'id': 'tx_sep_06',
        'note': 'Belanja Bulanan Superindo & Buah Segar',
        'amount': 780000.0,
        'type': 'expense',
        'category': 'Belanja',
        'occurredAt': '2026-09-22T16:20:00.000',
        'isConfirmed': true,
      },
      {
        'id': 'tx_sep_07',
        'note': 'Tagihan Listrik PLN & Indihome WiFi',
        'amount': 620000.0,
        'type': 'expense',
        'category': 'Tagihan & Utilitas',
        'occurredAt': '2026-09-05T13:00:00.000',
        'isConfirmed': true,
      },
      {
        'id': 'tx_sep_08',
        'note': 'Cicilan Paylater Sepatu Lari',
        'amount': 420000.0,
        'type': 'expense',
        'category': 'Hutang & Paylater',
        'occurredAt': '2026-09-10T15:00:00.000',
        'isConfirmed': true,
      },
      {
        'id': 'tx_sep_09',
        'note': 'Nonton IMAX & Popcorn Akhir Pekan',
        'amount': 195000.0,
        'type': 'expense',
        'category': 'Hiburan',
        'occurredAt': '2026-09-18T20:15:00.000',
        'isConfirmed': true,
      },
      {
        'id': 'tx_sep_10',
        'note': 'Membership Gym Bulanan',
        'amount': 350000.0,
        'type': 'expense',
        'category': 'Gym & Fitness',
        'occurredAt': '2026-09-03T08:30:00.000',
        'isConfirmed': true,
        'isCustomCategory': true,
      },
    ];

    final txList = month == '2026-09'
        ? [...baseSep, ...transactionsState]
        : baseSep;

    double totalInc = 0;
    double totalExp = 0;
    int confirmed = 0;
    int pending = 0;
    final catTotals = <String, Map<String, dynamic>>{};

    for (final tx in txList) {
      final isConf = tx['isConfirmed'] == true;
      if (isConf) {
        confirmed++;
      } else {
        pending++;
      }
      final amt = (tx['amount'] as num).toDouble();
      final type = tx['type'].toString();
      final cat = tx['category'].toString();
      if (type == 'income') {
        totalInc += amt;
      } else {
        totalExp += amt;
      }
      final key = '${type}_$cat';
      catTotals.putIfAbsent(key, () => {
        'category': cat,
        'type': type,
        'total': 0.0,
        'transactionCount': 0,
        'isCustom': tx['isCustomCategory'] == true,
      });
      catTotals[key]!['total'] = (catTotals[key]!['total'] as double) + amt;
      catTotals[key]!['transactionCount'] = (catTotals[key]!['transactionCount'] as int) + 1;
    }

    final breakdown = catTotals.values.map((entry) {
      final t = entry['type'] as String;
      final tot = entry['total'] as double;
      final denom = t == 'expense' ? totalExp : totalInc;
      return {
        ...entry,
        'percentage': denom > 0 ? (tot / denom) * 100 : 0.0,
      };
    }).toList();

    return {
      'month': month,
      'monthLabel': month == '2026-08'
          ? 'Agustus 2026'
          : (month == '2026-07' ? 'Juli 2026' : 'September 2026'),
      'totalIncome': totalInc,
      'totalExpense': totalExp,
      'netSavings': totalInc - totalExp,
      'savingsRate': totalInc > 0 ? ((totalInc - totalExp) / totalInc) * 100 : 0.0,
      'confirmedTransactionsCount': confirmed,
      'pendingTransactionsCount': pending,
      'lastMonthTotalExpense': 6250000.0,
      'lastMonthTotalIncome': 10500000.0,
      'expenseDiffPct': -10.5,
      'incomeDiffPct': 9.0,
      'categoryBreakdown': breakdown,
      'transactions': txList,
    };
  }

  static Map<String, Map<String, dynamic>> _defaultBudgetsByMonth() {
    List<Map<String, dynamic>> defaultCatBudgets() => [
          {
            'id': 'b_cat_1',
            'categoryName': 'Sewa Kos & Tagihan Rumah',
            'bucketType': 'needs',
            'amountLimit': 1750000.0,
            'amountSpent': 1750000.0,
          },
          {
            'id': 'b_cat_2',
            'categoryName': 'Makan & Minuman',
            'bucketType': 'needs',
            'amountLimit': 1250000.0,
            'amountSpent': 980000.0,
          },
          {
            'id': 'b_cat_3',
            'categoryName': 'Transportasi Harian',
            'bucketType': 'needs',
            'amountLimit': 400000.0,
            'amountSpent': 320000.0,
          },
          {
            'id': 'b_cat_4',
            'categoryName': 'Reksadana & Tabungan Darurat',
            'bucketType': 'savings',
            'amountLimit': 1800000.0,
            'amountSpent': 1500000.0,
          },
          {
            'id': 'b_cat_5',
            'categoryName': 'Nongkrong & Bioskop',
            'bucketType': 'fun',
            'amountLimit': 750000.0,
            'amountSpent': 650000.0,
          },
          {
            'id': 'b_cat_6',
            'categoryName': 'Belanja & Skincare',
            'bucketType': 'fun',
            'amountLimit': 450000.0,
            'amountSpent': 450000.0,
          },
        ];

    return {
      '2026-09': {
        'month': '2026-09',
        'monthLabel': 'September 2026',
        'totalBudget': 6000000.0,
        'totalSpent': 2850000.0,
        'needsPercentage': 50.0,
        'savingsPercentage': 30.0,
        'funPercentage': 20.0,
        'buckets': [
          {
            'type': 'needs',
            'title': 'Kebutuhan Pokok',
            'percentage': 50.0,
            'amountLimit': 3000000.0,
            'amountSpent': 1600000.0,
          },
          {
            'type': 'savings',
            'title': 'Tabungan & Investasi',
            'percentage': 30.0,
            'amountLimit': 1800000.0,
            'amountSpent': 800000.0,
          },
          {
            'type': 'fun',
            'title': 'Hiburan & Keinginan',
            'percentage': 20.0,
            'amountLimit': 1200000.0,
            'amountSpent': 450000.0,
          },
        ],
        'categoryBudgets': defaultCatBudgets(),
      },
      '2026-08': {
        'month': '2026-08',
        'monthLabel': 'Agustus 2026',
        'totalBudget': 6000000.0,
        'totalSpent': 5400000.0,
        'needsPercentage': 50.0,
        'savingsPercentage': 30.0,
        'funPercentage': 20.0,
        'buckets': [
          {
            'type': 'needs',
            'title': 'Kebutuhan Pokok',
            'percentage': 50.0,
            'amountLimit': 3000000.0,
            'amountSpent': 2800000.0,
          },
          {
            'type': 'savings',
            'title': 'Tabungan & Investasi',
            'percentage': 30.0,
            'amountLimit': 1800000.0,
            'amountSpent': 1600000.0,
          },
          {
            'type': 'fun',
            'title': 'Hiburan & Keinginan',
            'percentage': 20.0,
            'amountLimit': 1200000.0,
            'amountSpent': 1000000.0,
          },
        ],
        'categoryBudgets': defaultCatBudgets(),
      },
      '2026-07': {
        'month': '2026-07',
        'monthLabel': 'Juli 2026',
        'totalBudget': 6000000.0,
        'totalSpent': 6250000.0,
        'needsPercentage': 50.0,
        'savingsPercentage': 30.0,
        'funPercentage': 20.0,
        'buckets': [
          {
            'type': 'needs',
            'title': 'Kebutuhan Pokok',
            'percentage': 50.0,
            'amountLimit': 3000000.0,
            'amountSpent': 3200000.0,
          },
          {
            'type': 'savings',
            'title': 'Tabungan & Investasi',
            'percentage': 30.0,
            'amountLimit': 1800000.0,
            'amountSpent': 1800000.0,
          },
          {
            'type': 'fun',
            'title': 'Hiburan & Keinginan',
            'percentage': 20.0,
            'amountLimit': 1200000.0,
            'amountSpent': 1250000.0,
          },
        ],
        'categoryBudgets': defaultCatBudgets(),
      },
    };
  }

  static Map<String, dynamic> _buildInsightJson({String preset = 'normal'}) {
    if (preset == 'warning') {
      return {
        'id': 'insight_warning',
        'date': DateTime.now().toIso8601String(),
        'avgDailySpend': 135000.0,
        'estimatedDaysLeft': 9,
        'recommendedDailyBudget': 42000.0,
        'dailyAdvice':
            'Perhatian: Pengeluaran 3 hari terakhir meningkat 40%! Batasi jajan dan hiburan maksimal Rp 42.000 hari ini.',
        'warnLevel': 'warning',
        'totalMonthlyBudget': 6000000.0,
        'totalSpent': 4800000.0,
        'remainingBalance': 1200000.0,
      };
    }
    if (preset == 'critical') {
      return {
        'id': 'insight_critical',
        'date': DateTime.now().toIso8601String(),
        'avgDailySpend': 215000.0,
        'estimatedDaysLeft': 3,
        'recommendedDailyBudget': 15000.0,
        'dailyAdvice':
            'Kritis: Sisa saldo menipis lebih cepat dari jadwal. Stop pengeluaran sekunder dan fokus hanya pada kebutuhan makan pokok.',
        'warnLevel': 'critical',
        'totalMonthlyBudget': 6000000.0,
        'totalSpent': 5650000.0,
        'remainingBalance': 350000.0,
      };
    }
    return {
      'id': 'insight_default',
      'date': DateTime.now().toIso8601String(),
      'avgDailySpend': 78500.0,
      'estimatedDaysLeft': 18,
      'recommendedDailyBudget': 65000.0,
      'dailyAdvice':
          'Pertahankan ritme belanja Anda. Batasi pos non-esensial maksimal Rp 65.000 hari ini agar saldo aman sampai akhir bulan.',
      'warnLevel': 'normal',
      'totalMonthlyBudget': 6000000.0,
      'totalSpent': 2850000.0,
      'remainingBalance': 3150000.0,
    };
  }

  static Map<String, dynamic> _buildDailySpendingJson({String preset = 'normal'}) {
    final now = DateTime.now();
    if (preset == 'warning' || preset == 'critical' || preset == 'high') {
      return {
        'avgDailySpend': 139285.0,
        'targetDailySpend': 65000.0,
        'weekOverWeekPercent': 34.5,
        'highestSpendAmount': 220000.0,
        'highestSpendDay': 'Sabtu',
        'lowestSpendAmount': 85000.0,
        'lowestSpendDay': 'Minggu',
        'topCategoryName': 'Hiburan & Belanja',
        'topCategoryPercentage': 54.0,
        'dailyPoints': [
          {'dayLabel': 'Sen', 'date': now.subtract(const Duration(days: 6)).toIso8601String(), 'amount': 110000.0, 'isAboveAverage': false},
          {'dayLabel': 'Sel', 'date': now.subtract(const Duration(days: 5)).toIso8601String(), 'amount': 95000.0, 'isAboveAverage': false},
          {'dayLabel': 'Rab', 'date': now.subtract(const Duration(days: 4)).toIso8601String(), 'amount': 160000.0, 'isAboveAverage': true},
          {'dayLabel': 'Kam', 'date': now.subtract(const Duration(days: 3)).toIso8601String(), 'amount': 130000.0, 'isAboveAverage': false},
          {'dayLabel': 'Jum', 'date': now.subtract(const Duration(days: 2)).toIso8601String(), 'amount': 175000.0, 'isAboveAverage': true},
          {'dayLabel': 'Sab', 'date': now.subtract(const Duration(days: 1)).toIso8601String(), 'amount': 220000.0, 'isAboveAverage': true},
          {'dayLabel': 'Min', 'date': now.toIso8601String(), 'amount': 85000.0, 'isAboveAverage': false},
        ],
      };
    }
    return {
      'avgDailySpend': 78500.0,
      'targetDailySpend': 65000.0,
      'weekOverWeekPercent': 6.8,
      'highestSpendAmount': 145000.0,
      'highestSpendDay': 'Sabtu',
      'lowestSpendAmount': 35000.0,
      'lowestSpendDay': 'Selasa',
      'topCategoryName': 'Makan & Minuman',
      'topCategoryPercentage': 48.0,
      'dailyPoints': [
        {'dayLabel': 'Sen', 'date': now.subtract(const Duration(days: 6)).toIso8601String(), 'amount': 62000.0, 'isAboveAverage': false},
        {'dayLabel': 'Sel', 'date': now.subtract(const Duration(days: 5)).toIso8601String(), 'amount': 35000.0, 'isAboveAverage': false},
        {'dayLabel': 'Rab', 'date': now.subtract(const Duration(days: 4)).toIso8601String(), 'amount': 88000.0, 'isAboveAverage': true},
        {'dayLabel': 'Kam', 'date': now.subtract(const Duration(days: 3)).toIso8601String(), 'amount': 72000.0, 'isAboveAverage': false},
        {'dayLabel': 'Jum', 'date': now.subtract(const Duration(days: 2)).toIso8601String(), 'amount': 95000.0, 'isAboveAverage': true},
        {'dayLabel': 'Sab', 'date': now.subtract(const Duration(days: 1)).toIso8601String(), 'amount': 145000.0, 'isAboveAverage': true},
        {'dayLabel': 'Min', 'date': now.toIso8601String(), 'amount': 52500.0, 'isAboveAverage': false},
      ],
    };
  }

  static List<Map<String, dynamic>> _defaultDailyTipsJson() {
    return [
      {
        'id': 'tip_1',
        'title': 'Bawa Bekal Makan Siang 2x Sepekan',
        'category': 'Makan & Minuman',
        'description':
            'Mengganti makan siang luar dengan bekal rumahan 2 kali seminggu dapat menghemat hingga Rp 150.000 per pekan.',
        'potentialSaving': 150000.0,
        'impactLevel': 'Tinggi',
        'icon': 'restaurant_rounded',
        'actionText': 'Rencanakan Menu Bekal',
        'isApplied': false,
      },
      {
        'id': 'tip_2',
        'title': 'Aturan Tunda 24 Jam Belanja Online',
        'category': 'Belanja',
        'description':
            'Masukkan barang non-pokok ke keranjang belanja dan tunggu 24 jam sebelum bayar untuk meredam belanja impulsif.',
        'potentialSaving': 250000.0,
        'impactLevel': 'Tinggi',
        'icon': 'shopping_bag_rounded',
        'actionText': 'Terapkan Aturan 24 Jam',
        'isApplied': false,
      },
      {
        'id': 'tip_3',
        'title': 'Audit Langganan Aplikasi Digital',
        'category': 'Tagihan & Utilitas',
        'description':
            'Cek aplikasi streaming atau cloud yang jarang dipakai bulan ini. Nonaktifkan tagihan otomatis untuk pos yang tidak aktif.',
        'potentialSaving': 89000.0,
        'impactLevel': 'Sedang',
        'icon': 'subscriptions_rounded',
        'actionText': 'Cek Langganan Aktif',
        'isApplied': false,
      },
      {
        'id': 'tip_4',
        'title': 'Seduh Kopi Sendiri di Pagi Hari',
        'category': 'Makan & Minuman',
        'description':
            'Beli bubuk kopi favorit dan seduh sendiri sebelum berangkat kerja. Mengurangi frekuensi jajan kopi susu kekinian.',
        'potentialSaving': 120000.0,
        'impactLevel': 'Sedang',
        'icon': 'coffee_rounded',
        'actionText': 'Seduh Kopi Rumah',
        'isApplied': false,
      },
      {
        'id': 'tip_5',
        'title': 'Manfaatkan Promo Transportasi Terpadu',
        'category': 'Transportasi',
        'description':
            'Gunakan kartu langganan bulanan atau tiket komuter terusan saat jam kerja untuk menghemat biaya ojek harian.',
        'potentialSaving': 75000.0,
        'impactLevel': 'Ringan',
        'icon': 'directions_bus_rounded',
        'actionText': 'Cek Jalur Transit',
        'isApplied': false,
      },
    ];
  }

  static List<Map<String, dynamic>> _defaultHistoryTipsJson() {
    return [
      {
        'id': 'tip_hist_1',
        'title': 'Bawa Bekal Makan Siang 2x Sepekan',
        'category': 'Makan & Minuman',
        'description':
            'Mengganti makan siang luar dengan bekal rumahan 2 kali seminggu dapat menghemat hingga Rp 150.000 per pekan.',
        'potentialSaving': 150000.0,
        'impactLevel': 'Tinggi',
        'icon': 'restaurant_rounded',
        'actionText': 'Rencanakan Menu Bekal',
        'isApplied': true,
        'date': 'Hari Ini, 27 Sep 2026',
      },
      {
        'id': 'tip_hist_2',
        'title': 'Aturan Tunda 24 Jam Belanja Online',
        'category': 'Belanja',
        'description':
            'Masukkan barang non-pokok ke keranjang belanja dan tunggu 24 jam sebelum bayar untuk meredam belanja impulsif.',
        'potentialSaving': 250000.0,
        'impactLevel': 'Tinggi',
        'icon': 'shopping_bag_rounded',
        'actionText': 'Terapkan Aturan 24 Jam',
        'isApplied': false,
        'date': 'Hari Ini, 27 Sep 2026',
      },
      {
        'id': 'tip_hist_3',
        'title': 'Matikan Saklar Colokan Listrik Malam Hari',
        'category': 'Tagihan & Utilitas',
        'description':
            'Mematikan colokan TV, dispenser, dan charger saat tidur dapat menurunkan tagihan listrik bulanan.',
        'potentialSaving': 45000.0,
        'impactLevel': 'Ringan',
        'icon': 'bolt_rounded',
        'actionText': 'Cek Saklar Malam',
        'isApplied': true,
        'date': 'Kemarin, 26 Sep 2026',
      },
      {
        'id': 'tip_hist_4',
        'title': 'Audit Langganan Aplikasi Digital',
        'category': 'Tagihan & Utilitas',
        'description':
            'Cek aplikasi streaming atau cloud yang jarang dipakai bulan ini. Nonaktifkan tagihan otomatis untuk pos yang tidak aktif.',
        'potentialSaving': 89000.0,
        'impactLevel': 'Sedang',
        'icon': 'subscriptions_rounded',
        'actionText': 'Cek Langganan Aktif',
        'isApplied': true,
        'date': 'Kemarin, 26 Sep 2026',
      },
      {
        'id': 'tip_hist_5',
        'title': 'Seduh Kopi Sendiri di Pagi Hari',
        'category': 'Makan & Minuman',
        'description':
            'Beli bubuk kopi favorit dan seduh sendiri sebelum berangkat kerja. Mengurangi frekuensi jajan kopi susu kekinian.',
        'potentialSaving': 120000.0,
        'impactLevel': 'Sedang',
        'icon': 'coffee_rounded',
        'actionText': 'Seduh Kopi Rumah',
        'isApplied': false,
        'date': '25 Sep 2026',
      },
      {
        'id': 'tip_hist_6',
        'title': 'Manfaatkan Promo Transportasi Terpadu',
        'category': 'Transportasi',
        'description':
            'Gunakan kartu langganan bulanan atau tiket komuter terusan saat jam kerja untuk menghemat biaya ojek harian.',
        'potentialSaving': 75000.0,
        'impactLevel': 'Ringan',
        'icon': 'directions_bus_rounded',
        'actionText': 'Cek Jalur Transit',
        'isApplied': true,
        'date': '25 Sep 2026',
      },
      {
        'id': 'tip_hist_7',
        'title': 'Sisihkan 10% Gaji di Awal Bulan',
        'category': 'Tabungan',
        'description':
            'Pindahkan minimal 10% pemasukan ke rekening terpisah tepat saat gaji masuk agar tidak terpakai untuk belanja.',
        'potentialSaving': 500000.0,
        'impactLevel': 'Tinggi',
        'icon': 'savings_rounded',
        'actionText': 'Transfer Tabungan',
        'isApplied': true,
        'date': '24 Sep 2026',
      },
      {
        'id': 'tip_hist_8',
        'title': 'Beli Kebutuhan Dapur Kemasan Grosir',
        'category': 'Belanja',
        'description':
            'Beli beras, minyak, dan sabun dalam ukuran isi ulang besar untuk mendapatkan potongan harga per liter.',
        'potentialSaving': 180000.0,
        'impactLevel': 'Tinggi',
        'icon': 'storefront_rounded',
        'actionText': 'Beli Kemasan Besar',
        'isApplied': false,
        'date': '24 Sep 2026',
      },
    ];
  }

  static Map<String, dynamic> _defaultReminderSettingsJson() {
    return {
      'isEnabled': true,
      'morningReminderTime': '08:00',
      'isMorningReminderEnabled': true,
      'eveningReminderTime': '20:00',
      'isEveningReminderEnabled': true,
      'activeDays': [1, 2, 3, 4, 5, 6, 7],
      'notifyOnOverbudget': true,
      'notifySavingTips': true,
      'notifyDebtDue': true,
      'soundEnabled': true,
      'vibrationEnabled': true,
    };
  }

  static List<Map<String, dynamic>> _defaultDebtsJson() {
    final now = DateTime.now();
    return [
      {
        'id': 'debt_1',
        'name': 'Paylater Belanja Online (Spay)',
        'totalAmount': 1250000.0,
        'remainingAmount': 450000.0,
        'dueDate': now.add(const Duration(days: 2)).toIso8601String(),
        'status': 'active',
        'type': 'paylater',
        'notes': 'Belanja perlengkapan rumah & elektronik ringan',
      },
      {
        'id': 'debt_2',
        'name': 'Cicilan Laptop Kerja (Bulan 3/6)',
        'totalAmount': 6000000.0,
        'remainingAmount': 3000000.0,
        'dueDate': now.add(const Duration(days: 12)).toIso8601String(),
        'status': 'active',
        'type': 'cicilan',
        'notes': 'Tenor 6 bulan cicilan 0% keperluan kantor',
      },
      {
        'id': 'debt_3',
        'name': 'Tagihan Kartu Kredit Bank BCA',
        'totalAmount': 850000.0,
        'remainingAmount': 850000.0,
        'dueDate': now.add(const Duration(days: 1)).toIso8601String(),
        'status': 'active',
        'type': 'kartu_kredit',
        'notes': 'Transaksi groceries & bensin pertengahan bulan',
      },
      {
        'id': 'debt_4',
        'name': 'Pinjaman Teman (Budi - Talangan)',
        'totalAmount': 300000.0,
        'remainingAmount': 0.0,
        'dueDate': now.subtract(const Duration(days: 5)).toIso8601String(),
        'status': 'paid',
        'type': 'pinjaman_pribadi',
        'notes': 'Talangan beli tiket kereta pulang kampung',
      },
      {
        'id': 'debt_5',
        'name': 'Paylater Tagihan Listrik (Kredivo)',
        'totalAmount': 275000.0,
        'remainingAmount': 0.0,
        'dueDate': now.subtract(const Duration(days: 7)).toIso8601String(),
        'status': 'paid',
        'type': 'paylater',
        'notes': 'Token listrik PLN 500rb awal bulan',
      },
    ];
  }
}
