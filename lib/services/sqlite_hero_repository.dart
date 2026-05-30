import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/hero_character.dart';
import 'hero_repository.dart';

class SqliteHeroRepository implements HeroRepository {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('heroes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE heroes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        spriteSheetPath TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  @override
  Future<void> saveHero(HeroCharacter hero) async {
    final db = await database;
    await db.insert(
      'heroes',
      hero.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<HeroCharacter>> getAllHeroes() async {
    final db = await database;
    final orderBy = 'createdAt DESC';
    final result = await db.query('heroes', orderBy: orderBy);
    return result.map((map) => HeroCharacter.fromMap(map)).toList();
  }

  @override
  Future<void> deleteHero(String id) async {
    final db = await database;
    await db.delete(
      'heroes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
