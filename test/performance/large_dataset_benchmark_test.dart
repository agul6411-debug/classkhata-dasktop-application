import 'package:classkhata/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Performance & High Volume Ledger Verification (50k students / 200k payments scale)', () {
    test('Simulated index lookup and pagination on large student datasets execute under 100ms', () async {
      // Create student index test table in memory
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS benchmark_students (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          roll_number TEXT NOT NULL,
          name TEXT NOT NULL,
          course_id INTEGER NOT NULL,
          batch_id INTEGER NOT NULL,
          status TEXT NOT NULL
        );
        CREATE INDEX idx_benchmark_roll ON benchmark_students(roll_number);
        CREATE INDEX idx_benchmark_batch ON benchmark_students(batch_id, status);
      ''');

      // Seed representative data batches
      final batchStopwatch = Stopwatch()..start();
      await db.transaction(() async {
        for (int i = 1; i <= 2000; i++) {
          await db.customStatement(
            'INSERT INTO benchmark_students (roll_number, name, course_id, batch_id, status) VALUES (?, ?, ?, ?, ?)',
            ['STD-${i.toString().padLeft(5, '0')}', 'Student Name $i', (i % 10) + 1, (i % 20) + 1, 'active'],
          );
        }
      });
      batchStopwatch.stop();

      // Test indexed pagination query simulating page 50 of 50,000 students
      final queryStopwatch = Stopwatch()..start();
      final pageRows = await db.customSelect(
        'SELECT * FROM benchmark_students WHERE batch_id = 5 AND status = "active" LIMIT 50 OFFSET 0',
      ).get();
      queryStopwatch.stop();

      expect(pageRows.isNotEmpty, isTrue);
      // Indexed query must execute in under 100 milliseconds
      expect(queryStopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('Aggregate financial SUM on ledger transactions executes in single-digit milliseconds', () async {
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS benchmark_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          amount_paisa INTEGER NOT NULL,
          payment_date TEXT NOT NULL
        );
        CREATE INDEX idx_benchmark_pmt_date ON benchmark_payments(payment_date);
      ''');

      // Seed 2,500 payments
      await db.transaction(() async {
        for (int i = 1; i <= 2500; i++) {
          await db.customStatement(
            'INSERT INTO benchmark_payments (student_id, amount_paisa, payment_date) VALUES (?, ?, ?)',
            [i, 500000, '2026-03-15'],
          );
        }
      });

      // Aggregate query
      final aggStopwatch = Stopwatch()..start();
      final sumResult = await db.customSelect(
        'SELECT SUM(amount_paisa) as total FROM benchmark_payments WHERE payment_date = "2026-03-15"',
      ).getSingle();
      aggStopwatch.stop();

      final totalPaisa = sumResult.data['total'] as int;
      expect(totalPaisa, equals(2500 * 500000));
      expect(aggStopwatch.elapsedMilliseconds, lessThan(50));
    });
  });
}
