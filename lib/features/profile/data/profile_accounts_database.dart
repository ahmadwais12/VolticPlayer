import 'package:sqflite/sqflite.dart';

/// A locally saved Google account profile. Passwords, OAuth tokens, and other
/// sign-in secrets are deliberately not part of this model or database.
class SavedProfileAccount {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime lastSignedIn;

  const SavedProfileAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.lastSignedIn,
  });

  factory SavedProfileAccount.fromMap(Map<String, Object?> row) =>
      SavedProfileAccount(
        id: row['id']! as String,
        email: row['email']! as String,
        displayName: row['display_name'] as String?,
        photoUrl: row['photo_url'] as String?,
        lastSignedIn: DateTime.fromMillisecondsSinceEpoch(
          row['last_signed_in']! as int,
        ),
      );
}

class ProfileAccountsDatabase {
  ProfileAccountsDatabase._();

  static final ProfileAccountsDatabase instance = ProfileAccountsDatabase._();
  static const _databaseName = 'profile_accounts.db';
  static const _tableName = 'google_accounts';
  Future<Database>? _databaseFuture;

  Future<Database> get _database => _databaseFuture ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final path = await getDatabasesPath();
    return openDatabase(
      '$path/$_databaseName',
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            email TEXT NOT NULL,
            display_name TEXT,
            photo_url TEXT,
            last_signed_in INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> save({
    required String id,
    required String email,
    required String? displayName,
    required String? photoUrl,
  }) async {
    final database = await _database;
    await database.insert(_tableName, {
      'id': id,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'last_signed_in': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SavedProfileAccount>> getAll() async {
    final database = await _database;
    final rows = await database.query(
      _tableName,
      orderBy: 'last_signed_in DESC',
    );
    return rows.map(SavedProfileAccount.fromMap).toList(growable: false);
  }

  Future<void> remove(String id) async {
    final database = await _database;
    await database.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
