import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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
    final map = hero.toMap();
    // Sandbox paths change on iOS/macOS across launches. Only store the filename.
    map['spriteSheetPath'] = basename(hero.spriteSheetPath);
    
    await db.insert(
      'heroes',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<HeroCharacter>> getAllHeroes() async {
    final db = await database;
    final orderBy = 'createdAt DESC';
    final result = await db.query('heroes', orderBy: orderBy);
    
    final docsDir = await getApplicationDocumentsDirectory();

    return result.map((map) {
      final mutableMap = Map<String, dynamic>.from(map);
      // Reconstruct the absolute path using the CURRENT documents directory.
      // We use basename() to gracefully handle any older rows that stored the full absolute path.
      final fileName = basename(mutableMap['spriteSheetPath'] as String);
      mutableMap['spriteSheetPath'] = join(docsDir.path, fileName);
      
      return HeroCharacter.fromMap(mutableMap);
    }).toList();
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
