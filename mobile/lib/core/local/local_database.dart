import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

final localDatabaseProvider = Provider<LocalDatabase>((_) => LocalDatabase.instance);

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'readlog.db');

    return openDatabase(
      path,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        author TEXT,
        cover_url TEXT,
        total_pages INTEGER,
        genre TEXT,
        publisher TEXT,
        status TEXT NOT NULL,
        start_date TEXT,
        end_date TEXT,
        rating INTEGER,
        current_page INTEGER,
        source_club_id TEXT,
        deadline TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE reading_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        book_id TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        duration_minutes INTEGER,
        paused_duration_seconds INTEGER NOT NULL DEFAULT 0,
        paused_at TEXT,
        start_page INTEGER,
        end_page INTEGER,
        pages_read INTEGER,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        session_goal TEXT,
        goal_value INTEGER,
        mood TEXT,
        mini_review TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        book_id TEXT NOT NULL,
        type TEXT NOT NULL,
        content TEXT NOT NULL,
        page_number INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE profile (
        id TEXT PRIMARY KEY,
        name TEXT,
        bio TEXT,
        avatar_url TEXT,
        yearly_goal INTEGER,
        favorite_genre TEXT,
        favorite_authors TEXT,
        favorite_book TEXT,
        onboarding_completed INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    // Fila de operações pendentes para sincronização
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Cache de stats diárias para o dashboard offline
    await db.execute('''
      CREATE TABLE daily_stats_cache (
        user_id TEXT NOT NULL,
        date TEXT NOT NULL,
        total_minutes INTEGER NOT NULL DEFAULT 0,
        total_pages INTEGER NOT NULL DEFAULT 0,
        session_count INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, date)
      )
    ''');
  }

  /// Migração incremental para usuários que já têm o banco em versões anteriores.
  ///
  /// Cada bloco é protegido individualmente por try/catch para tolerar builds
  /// intermediários em que a coluna já pode existir (duplicate column → ignora).
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _tryAlter(db, 'ALTER TABLE reading_sessions ADD COLUMN paused_duration_seconds INTEGER NOT NULL DEFAULT 0');
      await _tryAlter(db, 'ALTER TABLE reading_sessions ADD COLUMN pages_read INTEGER');
      await _tryAlter(db, "ALTER TABLE reading_sessions ADD COLUMN status TEXT NOT NULL DEFAULT 'active'");
      await _tryAlter(db, 'ALTER TABLE reading_sessions ADD COLUMN session_goal TEXT');
      await _tryAlter(db, 'ALTER TABLE reading_sessions ADD COLUMN goal_value INTEGER');
      await db.execute(
          "UPDATE reading_sessions SET status = 'finished' WHERE ended_at IS NOT NULL");
    }
    if (oldVersion < 3) {
      await _tryAlter(db, 'ALTER TABLE profile ADD COLUMN favorite_authors TEXT');
      await _tryAlter(db, 'ALTER TABLE profile ADD COLUMN favorite_book TEXT');
      await _tryAlter(db, 'ALTER TABLE profile ADD COLUMN onboarding_completed INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 4) {
      await _tryAlter(db, 'ALTER TABLE books ADD COLUMN source_club_id TEXT');
    }
    if (oldVersion < 5) {
      await _tryAlter(db, 'ALTER TABLE reading_sessions ADD COLUMN paused_at TEXT');
    }
    if (oldVersion < 6) {
      await _tryAlter(db, 'ALTER TABLE reading_sessions ADD COLUMN mood TEXT');
      await _tryAlter(db, 'ALTER TABLE reading_sessions ADD COLUMN mini_review TEXT');
    }
    if (oldVersion < 7) {
      await _tryAlter(db, 'ALTER TABLE books ADD COLUMN deadline TEXT');
    }
  }

  /// Executa um ALTER TABLE ignorando erros de "duplicate column".
  /// Qualquer outro erro é re-lançado normalmente.
  Future<void> _tryAlter(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (e) {
      // SQLite retorna "duplicate column name" quando a coluna já existe.
      // Isso acontece em devices que instalaram builds intermediárias.
      if (!e.toString().toLowerCase().contains('duplicate column')) {
        rethrow;
      }
    }
  }

  /// Remove todos os dados locais do usuário — chamado no logout para evitar
  /// que uma conta diferente leia dados cacheados de outra conta.
  Future<void> clearUserData() async {
    final database = await db;
    await database.delete('books');
    await database.delete('reading_sessions');
    await database.delete('notes');
    await database.delete('profile');
    await database.delete('sync_queue');
    await database.delete('daily_stats_cache');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Deleta o banco e o recria do zero.
  ///
  /// Usado como último recurso quando a abertura/migração falha de forma
  /// irrecuperável. O usuário perde dados locais mas o app volta a funcionar.
  Future<void> deleteAndRecreate() async {
    await close();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'readlog.db');
    await deleteDatabase(path);
    await db; // reabre/cria do zero
  }

  /// Injeta um banco externo no singleton — uso exclusivo em testes.
  // ignore: invalid_use_of_visible_for_testing_member
  void injectForTest(Database db) {
    _db = db;
  }
}
