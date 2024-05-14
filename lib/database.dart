import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fit_book/entries.dart';
import 'package:fit_book/foods.dart';
import 'package:fit_book/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// These additional imports are necessary to open the sqlite3 database
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Foods, Entries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) await m.create(db.entries);
        if (from < 3) {
          await m.addColumn(db.entries, db.entries.quantity);
          await m.addColumn(db.entries, db.entries.unit);
        }
        if (from < 4) {
          await m.addColumn(db.entries, db.entries.kCalories);
          await m.addColumn(db.entries, db.entries.proteinG);
          await m.addColumn(db.entries, db.entries.fatG);
          await m.addColumn(db.entries, db.entries.carbG);
        }
        if (from < 5)
          await m.createIndex(
            Index(
              'Foods',
              "CREATE INDEX foods_name ON foods(name);",
            ),
          );
      },
    );
  }
}

LazyDatabase _openConnection() {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    // put the database file, called db.sqlite here, into the documents folder
    // for your app.
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'fitbook.sqlite'));

    if (!await file.exists()) {
      final blob = await rootBundle.load('assets/fitbook.sqlite');
      await file.writeAsBytes(
        blob.buffer.asUint8List(blob.offsetInBytes, blob.lengthInBytes),
      );
    }

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Make sqlite3 pick a more suitable location for temporary files - the
    // one from the system may be inaccessible due to sandboxing.
    final cachebase = (await getTemporaryDirectory()).path;
    // We can't access /tmp on Android, which sqlite3 would try by default.
    // Explicitly tell it about the correct temporary directory.
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(
      file,
      logStatements: kDebugMode ? true : false,
    );
  });
}
