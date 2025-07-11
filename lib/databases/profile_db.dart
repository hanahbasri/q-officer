import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class ProfileDB {
  static Database? _database;

  static Future<Database> getDatabase() async {
    if (_database != null) return _database!;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'profile.db');

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE profile (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            imagePath TEXT
          )
        ''');
      },
    );

    return _database!;
  }

  static Future<void> saveImagePath(String path) async {
    final db = await getDatabase();
    await db.delete('profile');
    await db.insert('profile', {'imagePath': path});
  }

  static Future<String?> getImagePath() async {
    final db = await getDatabase();
    final result = await db.query('profile', limit: 1);
    if (result.isNotEmpty) {
      return result.first['imagePath'] as String?;
    }
    return null;
  }

  static Future<void> clearImage() async {
    final db = await getDatabase();
    await db.delete('profile');
  }
}
