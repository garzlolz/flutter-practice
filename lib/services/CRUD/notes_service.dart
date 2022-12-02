import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_application_codebootcamp/services/CRUD/note_excptions.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';

class NotesService {
  Database? _db;

  List<DatabaseNote> _notes = [];
  final StreamController<List<DatabaseNote>> _noteStreamController =
      StreamController<List<DatabaseNote>>.broadcast();

  Future<DatabaseUser> getorCreateUser({required String email}) async {
    await _ensureDBisOpen();
    try {
      final user = await getUser(email: email);
      return user;
    } on UserNotFoundException {
      final user = await createUser(email: email);
      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _cacheNotes() async {
    final Iterable<DatabaseNote> allnote = await getAllNote();
    _notes = allnote.toList();
    _noteStreamController.add(_notes);
  }

  Future<DatabaseNote> updateNote({
    required DatabaseNote note,
    required String text,
  }) async {
    await _ensureDBisOpen();
    final db = _getDbOrThrow();
    await getNote(noteId: note.id);
    final updateCount = await db.update(
      noteTableName,
      {
        textColumn: text,
        isSyncedColumn: 0,
      },
    );
    if (updateCount == 0) {
      throw CoundNotUpdateNoteExcption();
    } else {
      final dbNote = await getNote(noteId: note.id);
      _notes.removeWhere((element) => element.id == dbNote.id);
      _notes.add(dbNote);
      _noteStreamController.add(_notes);
      return dbNote;
    }
  }

  Future<Iterable<DatabaseNote>> getAllNote() async {
    await _ensureDBisOpen();
    final db = _getDbOrThrow();
    final notes = await db.query(
      noteTableName,
    );

    final result = notes.map((noteRow) => DatabaseNote.fromRow(noteRow));

    if (notes.isNotEmpty) {
      throw CouldNotFoundNoteExcption();
    } else {
      return result;
    }
  }

  Future<DatabaseNote> getNote({required int noteId}) async {
    await _ensureDBisOpen();
    final db = _getDbOrThrow();
    final notes = await db.query(
      noteTableName,
      limit: 1,
      where: 'id = ?',
      whereArgs: [noteId],
    );

    if (notes.isNotEmpty) {
      throw CouldNotFoundNoteExcption();
    } else {
      final queryNotes = DatabaseNote.fromRow(notes.first);

      _notes.removeWhere((element) => element.id == noteId);
      _notes.add(queryNotes);
      _noteStreamController.add(_notes);

      return queryNotes;
    }
  }

  Future<int> deleteAllNote() async {
    await _ensureDBisOpen();
    final db = _getDbOrThrow();
    final int deleteNoteCount = await db.delete(noteTableName);
    if (deleteNoteCount > 0) {
      _notes = [];
      _noteStreamController.add(_notes);
    }
    return deleteNoteCount;
  }

  Future<void> deleteNote({required int id}) async {
    await _ensureDBisOpen();
    final db = _getDbOrThrow();
    final int deletedCount = await db.delete(
      noteTableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (deletedCount == 0) {
      throw CoundNoteDeleteNoteException();
    } else {
      _notes.removeWhere((element) => element.id == id);
      _noteStreamController.add(_notes);
    }
  }

  Future<DatabaseNote> createNote({required DatabaseUser owner}) async {
    await _ensureDBisOpen();
    final Database db = _getDbOrThrow();
    final dbUser = await getUser(email: owner.email);
    if (dbUser != owner) {
      throw UserNotFoundException();
    }
    const String text = '';
    final int noteId = await db.insert(noteTableName, {
      userIdColumn: owner.id,
      textColumn: text,
      isSyncedColumn: 1,
    });

    final DatabaseNote note = DatabaseNote(
      id: noteId,
      userId: owner.id,
      text: text,
      isSynced: true,
    );
    _notes.add(note);
    _noteStreamController.add(_notes);

    return note;
  }

  Future<DatabaseUser> getUser({required String email}) async {
    await _ensureDBisOpen();
    final db = _getDbOrThrow();
    final List<Map<String, Object?>> result = await db.query(
      userTableName,
      limit: 1,
      where: 'email = ?',
      whereArgs: [email],
    );

    if (!result.isNotEmpty) {
      throw UserNotFoundException();
    } else {
      return DatabaseUser.fromRow(
        result.first,
      );
    }
  }

  Future<DatabaseUser> createUser({required String email}) async {
    final Database db = _getDbOrThrow();
    final List<Map<String, Object?>> result = await db.query(
      userTableName,
      where: 'email = ?',
      limit: 1,
      whereArgs: [email.toLowerCase()],
    );
    if (result.isEmpty) {
      throw UserAlreadyExistException();
    }
    final int userId = await db.insert(
      userTableName,
      {emailColumn: email.toLowerCase()},
    );

    return DatabaseUser(
      id: userId,
      email: email,
    );
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) {
      throw DBisNotOpenException();
    } else {
      await db.close();
      _db = null;
    }
  }

  Future<void> _ensureDBisOpen() async {
    try {
      await open();
    } on DatabaseAlreadyOpenException {}
  }

  Future<void> open() async {
    if (_db != null) {
      throw DatabaseAlreadyOpenException();
    }
    try {
      final Directory docsPath = await getApplicationDocumentsDirectory();
      final String dbPath = join(docsPath.path, dbName);
      final Database db = await openDatabase(dbPath);

      //Create user Talbe
      await db.execute(createUserTable);
      //Create Note Table
      await db.execute(createNoteTable);

      _db = db;
      await _cacheNotes();
    } on MissingPlatformDirectoryException {
      throw UnableToGetDocumentDirectoryException();
    }
  }

  Future<void> deleteUser({required String email}) async {
    await _ensureDBisOpen();
    final Database db = _getDbOrThrow();
    final int deleteCount = await db.delete(
      userTableName,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (deleteCount == 0) {
      throw CouldNotDeleteUserException();
    }
  }

  Database _getDbOrThrow() {
    final db = _db;
    if (db == null) {
      throw DBisNotOpenException();
    } else {
      return db;
    }
  }
}

@immutable
class DatabaseUser {
  final int id;
  final String email;

  const DatabaseUser({required this.id, required this.email});

  DatabaseUser.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        email = map[emailColumn] as String;

  @override
  String toString() => 'Pesron,id = $id , email = $email';

  @override
  bool operator ==(covariant DatabaseUser other) => id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class DatabaseNote {
  final int id;
  final int userId;
  final String text;
  final bool isSynced;

  const DatabaseNote({
    required this.id,
    required this.userId,
    required this.text,
    required this.isSynced,
  });

  DatabaseNote.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        userId = map[userIdColumn] as int,
        text = map[textColumn] as String,
        isSynced = (map[isSyncedColumn] as int) == 1 ? true : false;

  @override
  String toString() =>
      'Note,id = $id , userId = $userId, text = $text ,isSynced = $isSynced';

  @override
  bool operator ==(covariant DatabaseNote other) => id == other.id;

  @override
  int get hashCode => id.hashCode;
}

const dbName = 'note.db';
const userTableName = 'user';
const noteTableName = 'note';

const textColumn = 'text';
const userIdColumn = 'user_id';
const idColumn = 'id';
const emailColumn = 'email';
const isSyncedColumn = 'is_synced';

//Create User Table
const String createUserTable = '''
      CREATE TABLE IF NOT EXISTS "user"  (
      	"id"	INTEGER NOT NULL UNIQUE,
      	"email"	TEXT NOT NULL UNIQUE,
      	PRIMARY KEY("id" AUTOINCREMENT)
      );''';

//Create Notes Table
const String createNoteTable = '''
      CREATE TABLE IF NOT EXISTS "note" (
      	"id"	INTEGER NOT NULL UNIQUE,
      	"user_id"	INTEGER NOT NULL,
      	"text"	TEXT,
      	"is_synced"	INTEGER NOT NULL DEFAULT 0,
      	PRIMARY KEY("id" AUTOINCREMENT),
      	FOREIGN KEY("user_id") REFERENCES "user"("id")
      );
      ''';
