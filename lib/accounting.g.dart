// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accounting.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

abstract class $AppDatabaseBuilderContract {
  /// Adds migrations to the builder.
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations);

  /// Adds a database [Callback] to the builder.
  $AppDatabaseBuilderContract addCallback(Callback callback);

  /// Creates the database and initializes it.
  Future<AppDatabase> build();
}

// ignore: avoid_classes_with_only_static_members
class $FloorAppDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract databaseBuilder(String name) =>
      _$AppDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract inMemoryDatabaseBuilder() =>
      _$AppDatabaseBuilder(null);
}

class _$AppDatabaseBuilder implements $AppDatabaseBuilderContract {
  _$AppDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  @override
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  @override
  $AppDatabaseBuilderContract addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  @override
  Future<AppDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$AppDatabase();
    database.database = await database.open(path, _migrations, _callback);
    return database;
  }
}

class _$AppDatabase extends AppDatabase {
  _$AppDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  TransactionDao? _transactionDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 2,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
          database,
          startVersion,
          endVersion,
          migrations,
        );

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
          'CREATE TABLE IF NOT EXISTS `transactions` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `created_at` TEXT NOT NULL, `occurred_at` TEXT NOT NULL, `type` TEXT NOT NULL, `title` TEXT NOT NULL, `amount` REAL NOT NULL, `currency` TEXT NOT NULL, `category` TEXT NOT NULL, `account` TEXT, `note` TEXT, `rawText` TEXT NOT NULL)',
        );

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  TransactionDao get transactionDao {
    return _transactionDaoInstance ??= _$TransactionDao(
      database,
      changeListener,
    );
  }
}

class _$TransactionDao extends TransactionDao {
  _$TransactionDao(this.database, this.changeListener)
    : _queryAdapter = QueryAdapter(database),
      _transactionEntryInsertionAdapter = InsertionAdapter(
        database,
        'transactions',
        (TransactionEntry item) => <String, Object?>{
          'id': item.id,
          'created_at': item.createdAtIso,
          'occurred_at': item.occurredAtIso,
          'type': item.type,
          'title': item.title,
          'amount': item.amount,
          'currency': item.currency,
          'category': item.category,
          'account': item.account,
          'note': item.note,
          'rawText': item.rawText,
        },
      ),
      _transactionEntryUpdateAdapter = UpdateAdapter(
        database,
        'transactions',
        ['id'],
        (TransactionEntry item) => <String, Object?>{
          'id': item.id,
          'created_at': item.createdAtIso,
          'occurred_at': item.occurredAtIso,
          'type': item.type,
          'title': item.title,
          'amount': item.amount,
          'currency': item.currency,
          'category': item.category,
          'account': item.account,
          'note': item.note,
          'rawText': item.rawText,
        },
      ),
      _transactionEntryDeletionAdapter = DeletionAdapter(
        database,
        'transactions',
        ['id'],
        (TransactionEntry item) => <String, Object?>{
          'id': item.id,
          'created_at': item.createdAtIso,
          'occurred_at': item.occurredAtIso,
          'type': item.type,
          'title': item.title,
          'amount': item.amount,
          'currency': item.currency,
          'category': item.category,
          'account': item.account,
          'note': item.note,
          'rawText': item.rawText,
        },
      );

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<TransactionEntry> _transactionEntryInsertionAdapter;

  final UpdateAdapter<TransactionEntry> _transactionEntryUpdateAdapter;

  final DeletionAdapter<TransactionEntry> _transactionEntryDeletionAdapter;

  @override
  Future<List<TransactionEntry>> listTransactions() async {
    return _queryAdapter.queryList(
      'SELECT * FROM transactions ORDER BY occurred_at DESC, id DESC',
      mapper: (Map<String, Object?> row) => TransactionEntry(
        id: row['id'] as int?,
        createdAtIso: row['created_at'] as String,
        occurredAtIso: row['occurred_at'] as String,
        type: row['type'] as String,
        title: row['title'] as String,
        amount: row['amount'] as double,
        currency: row['currency'] as String,
        category: row['category'] as String,
        account: row['account'] as String?,
        note: row['note'] as String?,
        rawText: row['rawText'] as String,
      ),
    );
  }

  @override
  Future<void> insertTransaction(TransactionEntry entry) async {
    await _transactionEntryInsertionAdapter.insert(
      entry,
      OnConflictStrategy.abort,
    );
  }

  @override
  Future<void> updateTransaction(TransactionEntry entry) async {
    await _transactionEntryUpdateAdapter.update(
      entry,
      OnConflictStrategy.abort,
    );
  }

  @override
  Future<void> deleteTransaction(TransactionEntry entry) async {
    await _transactionEntryDeletionAdapter.delete(entry);
  }
}
