import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

enum TxType { achat, paiement }

class Client {
  final int? id;
  final String name;
  final String? phone;
  final String? photo;
  final String? note;
  final DateTime createdAt;

  // Champs calculés (remplis par la requête)
  final double totalPurchases;
  final double totalPayments;
  final DateTime? lastDate;
  final TxType? lastType;
  final double? lastAmount;
  final String? lastNote;

  const Client({
    this.id,
    required this.name,
    this.phone,
    this.photo,
    this.note,
    required this.createdAt,
    this.totalPurchases = 0,
    this.totalPayments = 0,
    this.lastDate,
    this.lastType,
    this.lastAmount,
    this.lastNote,
  });

  /// Positif = le client doit de l'argent. Négatif = avance.
  double get balance => totalPurchases - totalPayments;
  bool get hasDebt => balance >= 1;
  DateTime get activity => lastDate ?? createdAt;

  Map<String, Object?> toMap() => {
        'name': name,
        'phone': phone,
        'photo': photo,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Client.fromMap(Map<String, Object?> m) {
    DateTime? ms(Object? v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
    final lt = m['last_type'] as String?;
    return Client(
      id: m['id'] as int?,
      name: m['name'] as String,
      phone: m['phone'] as String?,
      photo: m['photo'] as String?,
      note: m['note'] as String?,
      createdAt: ms(m['created_at'])!,
      totalPurchases: (m['total_purchases'] as num?)?.toDouble() ?? 0,
      totalPayments: (m['total_payments'] as num?)?.toDouble() ?? 0,
      lastDate: ms(m['last_date']),
      lastType: lt == null ? null : TxType.values.byName(lt),
      lastAmount: (m['last_amount'] as num?)?.toDouble(),
      lastNote: m['last_note'] as String?,
    );
  }
}

class Tx {
  final int? id;
  final int clientId;
  final TxType type;
  final double amount;
  final String? note;
  final DateTime date;

  const Tx({
    this.id,
    required this.clientId,
    required this.type,
    required this.amount,
    this.note,
    required this.date,
  });

  bool get isPurchase => type == TxType.achat;

  Map<String, Object?> toMap() => {
        'client_id': clientId,
        'type': type.name,
        'amount': amount,
        'note': note,
        'date': date.millisecondsSinceEpoch,
      };

  factory Tx.fromMap(Map<String, Object?> m) => Tx(
        id: m['id'] as int?,
        clientId: m['client_id'] as int,
        type: TxType.values.byName(m['type'] as String),
        amount: (m['amount'] as num).toDouble(),
        note: m['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt()),
      );
}

/// Base de données locale (SQLite) — tout reste sur le téléphone.
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'carnet_dettes.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE clients(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT,
            photo TEXT,
            note TEXT,
            created_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id INTEGER NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            note TEXT,
            date INTEGER NOT NULL
          )''');
        await db.execute(
            'CREATE INDEX idx_tx_client ON transactions(client_id, date)');
      },
    );
  }

  static const String _clientSelect = '''
    SELECT c.*,
      COALESCE((SELECT SUM(amount) FROM transactions t
                WHERE t.client_id = c.id AND t.type = 'achat'), 0) AS total_purchases,
      COALESCE((SELECT SUM(amount) FROM transactions t
                WHERE t.client_id = c.id AND t.type = 'paiement'), 0) AS total_payments,
      (SELECT MAX(date) FROM transactions t WHERE t.client_id = c.id) AS last_date,
      (SELECT type FROM transactions t WHERE t.client_id = c.id
         ORDER BY date DESC, id DESC LIMIT 1) AS last_type,
      (SELECT amount FROM transactions t WHERE t.client_id = c.id
         ORDER BY date DESC, id DESC LIMIT 1) AS last_amount,
      (SELECT note FROM transactions t WHERE t.client_id = c.id
         ORDER BY date DESC, id DESC LIMIT 1) AS last_note
    FROM clients c''';

  Future<List<Client>> clients() async {
    final db = await database;
    final rows = await db.rawQuery(
        '$_clientSelect ORDER BY COALESCE(last_date, c.created_at) DESC');
    return rows.map(Client.fromMap).toList();
  }

  Future<Client?> client(int id) async {
    final db = await database;
    final rows = await db.rawQuery('$_clientSelect WHERE c.id = ?', [id]);
    return rows.isEmpty ? null : Client.fromMap(rows.first);
  }

  Future<int> insertClient(Client c) async =>
      (await database).insert('clients', c.toMap());

  Future<void> updateClient(Client c) async {
    final db = await database;
    await db.update('clients', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteClient(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'client_id = ?', whereArgs: [id]);
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Tx>> transactions(int clientId) async {
    final db = await database;
    final rows = await db.query('transactions',
        where: 'client_id = ?',
        whereArgs: [clientId],
        orderBy: 'date ASC, id ASC');
    return rows.map(Tx.fromMap).toList();
  }

  Future<int> insertTx(Tx tx) async =>
      (await database).insert('transactions', tx.toMap());

  Future<void> updateTx(Tx tx) async {
    final db = await database;
    await db.update('transactions', tx.toMap(),
        where: 'id = ?', whereArgs: [tx.id]);
  }

  Future<void> deleteTx(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }
}
