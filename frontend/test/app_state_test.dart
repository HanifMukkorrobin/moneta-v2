import 'package:flutter_test/flutter_test.dart';
import 'package:moneta/models/chat_log_item.dart';
import 'package:moneta/models/transaction_item.dart';
import 'package:moneta/state/app_state.dart';

void main() {
  setUp(() {
    AppState.instance.resetToDefault();
  });

  test('AppState initial state is correctly initialized', () {
    final state = AppState.instance;
    expect(state.messages.isNotEmpty, isTrue);
    expect(state.chatLogs.isNotEmpty, isTrue);
    expect(state.confirmedTransactions.isNotEmpty, isTrue);
    expect(state.todayTotalExpense, greaterThan(0));
  });

  test('AppState confirms pending transaction and synchronizes with chat logs',
      () {
    final state = AppState.instance;

    // Find pending transaction
    final pendingTx = state.messages
        .firstWhere((m) => m.transaction != null && !m.transaction!.isConfirmed)
        .transaction!;

    final initialConfirmedExpense = state.todayTotalExpense;

    state.confirmTransaction(pendingTx.id);

    expect(pendingTx.isConfirmed, isTrue);
    expect(state.todayTotalExpense,
        equals(initialConfirmedExpense + pendingTx.amount));

    // Check log status is also confirmed
    final matchingLog =
        state.chatLogs.firstWhere((l) => l.transaction?.id == pendingTx.id);
    expect(matchingLog.status, equals(ChatLogStatus.confirmed));
  });

  test('AppState updates transaction and recalculates totals', () {
    final state = AppState.instance;
    final tx = state.confirmedTransactions.first;
    final oldAmount = tx.amount;
    final initialTotal = state.todayTotalExpense;

    final updated = tx.copyWith(amount: oldAmount + 10000, note: 'Updated note');
    state.updateTransaction(updated);

    expect(tx.amount, equals(oldAmount + 10000));
    expect(tx.note, equals('Updated note'));
    expect(state.todayTotalExpense, equals(initialTotal + 10000));
  });

  test('AppState deleteMessage and restoreMessage syncs logs and totals', () {
    final state = AppState.instance;
    final msgWithTx = state.messages.firstWhere(
        (m) => m.transaction != null && m.transaction!.isConfirmed);
    final txId = msgWithTx.transaction!.id;
    final initialTotal = state.todayTotalExpense;
    final txAmount = msgWithTx.transaction!.amount;

    final index = state.deleteMessage(msgWithTx);
    expect(state.messages.contains(msgWithTx), isFalse);
    expect(state.todayTotalExpense, equals(initialTotal - txAmount));

    final log = state.chatLogs.firstWhere((l) => l.transaction?.id == txId);
    expect(log.status, equals(ChatLogStatus.deleted));

    // Restore
    state.restoreMessage(msgWithTx, index);
    expect(state.messages.contains(msgWithTx), isTrue);
    expect(state.todayTotalExpense, equals(initialTotal));
    expect(log.status, equals(ChatLogStatus.confirmed));
  });

  test('AppState addManualTransaction updates state and logs', () {
    final state = AppState.instance;
    final initialCount = state.messages.length;
    final initialExpense = state.todayTotalExpense;

    final manualTx = TransactionItem(
      id: 'tx_manual_test',
      note: 'Servis motor',
      amount: 120000,
      type: 'expense',
      category: 'Transportasi',
      occurredAt: DateTime.now(),
      isConfirmed: true,
    );

    state.addManualTransaction(manualTx);

    expect(state.messages.length, equals(initialCount + 1));
    expect(state.todayTotalExpense, equals(initialExpense + 120000));
    expect(state.chatLogs.first.message, equals('Servis motor'));
    expect(state.chatLogs.first.status, equals(ChatLogStatus.confirmed));
  });
}
