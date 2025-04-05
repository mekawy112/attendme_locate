import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class DatabaseHelper {
  static const _databaseName = "MyDatabase.db";
  static const _databaseVersion = 2;

  static const table = 'my_table';

  static const columnId = 'id';
  static const columnName = 'name';
  static const columnEmbedding = 'embedding';
  static const columnStudentId = 'student_id';

  late Database _db;

  // this opens the database (and creates it if it doesn't exist)
  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $table (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnName TEXT NOT NULL,
            $columnEmbedding TEXT NOT NULL,
            $columnStudentId TEXT NOT NULL
          )
          ''');
  }
  
  // ترقية قاعدة البيانات في حال كانت موجودة مسبقًا
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnStudentId TEXT DEFAULT "unknown"');
    }
  }

  // Helper methods

  // Inserts a row in the database where each key in the Map is a column name
  // and the value is the column value. The return value is the id of the
  // inserted row.
  Future<int> insert(Map<String, dynamic> row) async {
    return await _db.insert(table, row);
  }

  // Query the database with custom conditions
  Future<List<Map<String, dynamic>>> query(String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return await _db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  // All of the rows are returned as a list of maps, where each map is
  // a key-value list of columns.
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    return await _db.query(table);
  }

  // Consulta para buscar un estudiante por su ID
  Future<List<Map<String, dynamic>>> queryStudentById(String studentId) async {
    return await query(
      table,
      where: '$columnStudentId = ?',
      whereArgs: [studentId],
    );
  }

  // Eliminar registros por ID de estudiante
  Future<int> deleteByStudentId(String studentId) async {
    return await _db.delete(
      table,
      where: '$columnStudentId = ?',
      whereArgs: [studentId],
    );
  }

  // Verificar si un estudiante ya existe
  Future<bool> checkStudentExists(String studentId) async {
    final result = await queryStudentById(studentId);
    return result.isNotEmpty;
  }

  // Deletes the row specified by the id. The number of affected rows is
  // returned. This should be 1 as long as the row exists.
  Future<int> delete(int id) async {
    return await _db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // All of the methods (insert, query, update, delete) can also be done using
  // raw SQL commands. This method uses a raw query to give the row count.
  Future<int> queryRowCount() async {
    final results = await _db.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(results) ?? 0;
  }

  // We are assuming here that the id column in the map is set. The other
  // column values will be used to update the row.
  Future<int> update(Map<String, dynamic> row) async {
    int id = row[columnId];
    return await _db.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // إضافة وجه جديد إلى قاعدة البيانات
  Future<int> insertFace(String studentId, List<double> embedding, String name) async {
    // تحويل الـ embedding إلى نص JSON للتخزين
    String embeddingJson = jsonEncode(embedding);
    
    Map<String, dynamic> row = {
      columnStudentId: studentId,
      columnName: name,
      columnEmbedding: embeddingJson,
    };
    
    return await insert(row);
  }

  // جلب جميع الوجوه المسجلة
  Future<List<Map<String, dynamic>>> getAllFaces() async {
    return await queryAllRows();
  }

  // جلب وجه طالب معين
  Future<List<Map<String, dynamic>>> getFaceByStudentId(String studentId) async {
    return await queryStudentById(studentId);
  }

  // تحديث وجه طالب موجود
  Future<int> updateFace(String studentId, List<double> embedding, String name) async {
    String embeddingJson = jsonEncode(embedding);
    
    Map<String, dynamic> row = {
      columnName: name,
      columnEmbedding: embeddingJson,
    };
    
    return await _db.update(
      table,
      row,
      where: '$columnStudentId = ?',
      whereArgs: [studentId],
    );
  }

  // حذف جميع الوجوه المسجلة
  Future<void> clearAllFaces() async {
    await _db.delete(table);
  }
}