import 'dart:async';

import 'package:floor/floor.dart';
import 'package:nobodywho/nobodywho.dart' as nobodywho;
import 'package:sqflite/sqflite.dart' as sqflite;

part 'accounting.g.dart';

@Entity(tableName: 'transactions')
class TransactionEntry {
  @PrimaryKey(autoGenerate: true)
  final int? id;
  @ColumnInfo(name: 'created_at')
  final String createdAtIso;
  @ColumnInfo(name: 'occurred_at')
  final String occurredAtIso;
  final String type;
  final String title;
  final double amount;
  final String currency;
  final String category;
  final String? account;
  final String? note;
  final String rawText;

  const TransactionEntry({
    this.id,
    required this.createdAtIso,
    required this.occurredAtIso,
    required this.type,
    required this.title,
    required this.amount,
    required this.currency,
    required this.category,
    required this.account,
    required this.note,
    required this.rawText,
  });

  DateTime get createdAt => DateTime.parse(createdAtIso);
  DateTime get occurredAt => DateTime.parse(occurredAtIso);

  factory TransactionEntry.fromToolArgs({
    int? id,
    required String occurredAt,
    required String type,
    required String title,
    required num amount,
    required String currency,
    required String category,
    String? account,
    String? note,
    required String rawText,
    DateTime? createdAt,
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', '金额必须大于 0');
    }

    return TransactionEntry(
      id: id,
      createdAtIso: (createdAt ?? DateTime.now()).toIso8601String(),
      occurredAtIso: DateTime.parse(occurredAt).toIso8601String(),
      type: type.trim().isEmpty ? 'expense' : type.trim(),
      title: title.trim(),
      amount: amount.toDouble(),
      currency: currency.trim().isEmpty ? 'CNY' : currency.trim(),
      category: category.trim().isEmpty ? '其他' : category.trim(),
      account: _blankToNull(account),
      note: _blankToNull(note),
      rawText: rawText.trim(),
    );
  }
}

@dao
abstract class TransactionDao {
  @insert
  Future<void> insertTransaction(TransactionEntry entry);

  @Update()
  Future<void> updateTransaction(TransactionEntry entry);

  @delete
  Future<void> deleteTransaction(TransactionEntry entry);

  @Query('SELECT * FROM transactions ORDER BY occurred_at DESC, id DESC')
  Future<List<TransactionEntry>> listTransactions();
}

@Database(version: 2, entities: [TransactionEntry])
abstract class AppDatabase extends FloorDatabase {
  TransactionDao get transactionDao;
}

final migration1To2 = Migration(1, 2, (database) async {
  await database.execute('''
CREATE TABLE IF NOT EXISTS `transactions` (
  `id` INTEGER PRIMARY KEY AUTOINCREMENT,
  `created_at` TEXT NOT NULL,
  `occurred_at` TEXT NOT NULL,
  `type` TEXT NOT NULL,
  `title` TEXT NOT NULL,
  `amount` REAL NOT NULL,
  `currency` TEXT NOT NULL,
  `category` TEXT NOT NULL,
  `account` TEXT,
  `note` TEXT,
  `rawText` TEXT NOT NULL
)
''');
});

class ExpenseLedger {
  ExpenseLedger(this._db);

  final AppDatabase _db;

  static Future<ExpenseLedger> open(String path) async {
    final db = await $FloorAppDatabase.databaseBuilder(path).addMigrations([
      migration1To2,
    ]).build();
    return ExpenseLedger(db);
  }

  Future<String> record({
    required String occurredAt,
    required String type,
    required String title,
    required double amount,
    required String currency,
    required String category,
    String? account,
    String? note,
    required String rawText,
  }) async {
    final entry = TransactionEntry.fromToolArgs(
      occurredAt: occurredAt,
      type: type,
      title: title,
      amount: amount,
      currency: currency,
      category: category,
      account: account,
      note: note,
      rawText: rawText,
    );
    await _db.transactionDao.insertTransaction(entry);
    final amountText = entry.amount == entry.amount.roundToDouble()
        ? entry.amount.toStringAsFixed(0)
        : entry.amount.toString();
    return '已记账：${entry.category}/${entry.title} $amountText ${entry.currency}';
  }

  Future<List<TransactionEntry>> listTransactions() {
    return _db.transactionDao.listTransactions();
  }

  Future<void> update(TransactionEntry entry) {
    return _db.transactionDao.updateTransaction(entry);
  }

  Future<void> delete(TransactionEntry entry) {
    return _db.transactionDao.deleteTransaction(entry);
  }
}

class MonthlySummary {
  const MonthlySummary({required this.income, required this.expense});

  final double income;
  final double expense;

  double get balance => income - expense;

  factory MonthlySummary.fromEntries(
    List<TransactionEntry> entries, {
    required DateTime month,
  }) {
    var income = 0.0;
    var expense = 0.0;
    for (final entry in entries) {
      final occurredAt = entry.occurredAt;
      if (occurredAt.year != month.year || occurredAt.month != month.month) {
        continue;
      }
      if (entry.type == 'income') {
        income += entry.amount;
      } else {
        expense += entry.amount;
      }
    }
    return MonthlySummary(income: income, expense: expense);
  }
}

nobodywho.Tool createRecordTransactionTool(Future<ExpenseLedger> ledger) {
  return nobodywho.Tool(
    name: 'record_transaction',
    description: '把一条用户明确要求记账的收入或支出保存到本地数据库。',
    parameterDescriptions: {
      'occurredAt': '实际收支时间，ISO 8601 格式；用户没说时间就使用系统提示里的当前时间。',
      'type': 'expense 或 income；普通消费默认 expense，工资、报销等收入用 income。',
      'title': '收支内容，例如早餐、午餐、咖啡、工资。',
      'amount': '金额，单位元，只填数字，必须大于 0。',
      'currency': '币种，默认 CNY。',
      'category': '分类，例如餐饮、交通、购物、娱乐、医疗、收入、其他。',
      'account': '账户，例如微信、支付宝、现金、银行卡；不知道就传空字符串。',
      'note': '备注；没有就传空字符串。',
      'rawText': '用户原始输入。',
    },
    function:
        ({
          required String occurredAt,
          required String type,
          required String title,
          required double amount,
          required String currency,
          required String category,
          required String account,
          required String note,
          required String rawText,
        }) async {
          return (await ledger).record(
            occurredAt: occurredAt,
            type: type,
            title: title,
            amount: amount,
            currency: currency,
            category: category,
            account: account,
            note: note,
            rawText: rawText,
          );
        },
  );
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
