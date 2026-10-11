/// Pure Dart domain entities for Academics (Sessions, Courses, Batches).
library;

import 'package:equatable/equatable.dart';
import '../../../../core/money/money.dart';

class AcademicSession extends Equatable {
  final int id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;

  const AcademicSession({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
  });

  @override
  List<Object?> get props => [id, name, startDate, endDate, isCurrent];
}

class Course extends Equatable {
  final int id;
  final String name;
  final String? code;
  final String? description;

  const Course({
    required this.id,
    required this.name,
    this.code,
    this.description,
  });

  @override
  List<Object?> get props => [id, name, code, description];
}

class Batch extends Equatable {
  final int id;
  final int sessionId;
  final int courseId;
  final String name;
  final String? instructorName;
  final String? timing;
  final String? duration;
  final Money monthlyFee;
  final int dueDay; // 1 - 28
  final bool isActive;

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
