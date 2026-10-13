/// Pure Dart domain entities for School Academics (Sessions, Classes, Sections).
library;

import 'package:equatable/equatable.dart';
import '../../../../core/money/money.dart';

/// School Academic Session (e.g. 2026-2027)
class AcademicSession extends Equatable {

  const AcademicSession({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
  });
  final int id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;

  @override
  List<Object?> get props => [id, name, startDate, endDate, isCurrent];
}

/// School Class / Grade Level (e.g. Nursery, Class 1 - Class 10)
class Course extends Equatable {

  const Course({
    required this.id,
    required this.name,
    this.code,
    this.description,
  });
  final int id;
  final String name;
  final String? code;
  final String? description;

  /// Alias for school terminology
  String get className => name;

  @override
  List<Object?> get props => [id, name, code, description];
}

/// Type alias for school terminology
typedef SchoolClass = Course;

/// Class Section (e.g. Class 9 - Section A in Session 2026-2027)
class Batch extends Equatable {

  const Batch({
    required this.id,
    required this.sessionId,
    required this.courseId,
    required this.name,
    this.instructorName,
    this.timing,
    this.duration,
    required this.monthlyFee,
    required this.dueDay,
    required this.isActive,
  });
  final int id;
  final int sessionId;
  final int courseId;
  final String name;
  final String? instructorName; // Class teacher / in-charge
  final String? timing; // Room number or schedule
  final String? duration;
  final Money monthlyFee;
  final int dueDay; // 1 - 28
  final bool isActive;

  /// Alias for section name
  String get sectionName => name;

  /// Alias for class teacher
  String? get classTeacher => instructorName;

  /// Alias for room/location
  String? get roomOrTiming => timing;

  @override
  List<Object?> get props => [
        id,
        sessionId,
        courseId,
        name,
        instructorName,
        timing,
        duration,
        monthlyFee,
        dueDay,
        isActive,
      ];
}

/// Type alias for school terminology
typedef Section = Batch;

/// Helper extensions on the aggregated academic data record
extension AcademicDataRecordExt on ({
  List<AcademicSession> sessions,
  List<Course> courses,
  List<Batch> batches,
}) {
  /// The active academic session, or the first available session.
  AcademicSession? get currentSession =>
      sessions.where((s) => s.isCurrent).firstOrNull ?? sessions.firstOrNull;

  /// Filter sections belonging to a specific class.
  List<Batch> getSectionsForClass(int classId, {int? sessionId}) {
    return batches.where((b) {
      final matchesClass = b.courseId == classId;
      final matchesSession = sessionId == null || b.sessionId == sessionId;
      return matchesClass && matchesSession;
    }).toList();
  }

  /// Formatted name combining Class and Section (e.g. "Class 9 - Section A")
  String getFullSectionName(int batchId) {
    final batch = batches.where((b) => b.id == batchId).firstOrNull;
    if (batch == null) return 'Section #$batchId';
    final course = courses.where((c) => c.id == batch.courseId).firstOrNull;
    final cName = course?.name ?? 'Class';
    return '$cName - ${batch.name}';
  }
}
