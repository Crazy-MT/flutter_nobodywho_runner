import 'package:flutter_test/flutter_test.dart';
import 'package:nobodywho_android_runner/accounting.dart';

void main() {
  test('builds a detailed expense transaction from tool arguments', () {
    final entry = TransactionEntry.fromToolArgs(
      occurredAt: DateTime.utc(2026, 9, 14, 7, 30).toIso8601String(),
      type: 'expense',
      title: '早餐',
      amount: 3,
      currency: 'CNY',
      category: '餐饮',
      account: '微信',
      note: '公司楼下',
      rawText: '三块钱早餐记账',
      createdAt: DateTime.utc(2026, 9, 14, 7, 31),
    );

    expect(entry.id, isNull);
    expect(entry.title, '早餐');
    expect(entry.amount, 3);
    expect(entry.occurredAt, DateTime.utc(2026, 9, 14, 7, 30));
    expect(entry.createdAt, DateTime.utc(2026, 9, 14, 7, 31));
    expect(entry.type, 'expense');
    expect(entry.currency, 'CNY');
    expect(entry.category, '餐饮');
    expect(entry.account, '微信');
    expect(entry.note, '公司楼下');
    expect(entry.rawText, '三块钱早餐记账');
  });

  test('defaults optional transaction fields', () {
    final entry = TransactionEntry.fromToolArgs(
      occurredAt: DateTime.utc(2026, 9, 14, 7, 30).toIso8601String(),
      type: '',
      title: ' 早餐 ',
      amount: 3,
      currency: '',
      category: '',
      rawText: '三块钱早餐记账',
      createdAt: DateTime.utc(2026, 9, 14, 7, 31),
    );

    expect(entry.type, 'expense');
    expect(entry.title, '早餐');
    expect(entry.currency, 'CNY');
    expect(entry.category, '其他');
    expect(entry.account, isNull);
    expect(entry.note, isNull);
  });

  test('rejects missing or invalid amount', () {
    expect(
      () => TransactionEntry.fromToolArgs(
        occurredAt: DateTime.utc(2026, 9, 14, 7, 30).toIso8601String(),
        type: 'expense',
        title: '早餐',
        amount: 0,
        currency: 'CNY',
        category: '餐饮',
        rawText: '早餐记账',
      ),
      throwsArgumentError,
    );
  });

  test('summarizes current month income and expenses', () {
    final summary = MonthlySummary.fromEntries([
      TransactionEntry.fromToolArgs(
        occurredAt: DateTime.utc(2026, 9, 1).toIso8601String(),
        type: 'expense',
        title: '早餐',
        amount: 3,
        currency: 'CNY',
        category: '餐饮',
        rawText: '三块钱早餐记账',
      ),
      TransactionEntry.fromToolArgs(
        occurredAt: DateTime.utc(2026, 9, 2).toIso8601String(),
        type: 'income',
        title: '工资',
        amount: 100,
        currency: 'CNY',
        category: '收入',
        rawText: '工资到账 100',
      ),
      TransactionEntry.fromToolArgs(
        occurredAt: DateTime.utc(2026, 8, 31).toIso8601String(),
        type: 'expense',
        title: '咖啡',
        amount: 9,
        currency: 'CNY',
        category: '餐饮',
        rawText: '咖啡 9',
      ),
    ], month: DateTime.utc(2026, 9, 14));

    expect(summary.income, 100);
    expect(summary.expense, 3);
    expect(summary.balance, 97);
  });
}
