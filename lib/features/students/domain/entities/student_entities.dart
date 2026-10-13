/// Domain entities for Students and Families.
library;

import 'package:equatable/equatable.dart';

enum StudentStatus {
  active,
  inactive,
  left;

  static StudentStatus fromString(String val) {
    return switch (val.toLowerCase()) {
      'active' => StudentStatus.active,
      'inactive' => StudentStatus.inactive,
      'left' => StudentStatus.left,
      _ => StudentStatus.active,
    };
  }
}

class Student extends Equatable {

  const Student({
    required this.id,
    required this.rollNumber,
    this.familyId,
    required this.batchId,
    required this.name,
    this.phone,
    required this.guardianPhone,
    this.email,
    required this.joiningDate,
    required this.status,
  });
  final int id;
  final String rollNumber;
  final int? familyId;
  final int batchId;
  final String name;
  final String? phone;
  final String guardianPhone;
  final String? email;
  final DateTime joiningDate;
  final StudentStatus status;

  @override
  List<Object?> get props => [
        id,
        rollNumber,
        familyId,
        batchId,
        name,
        phone,
        guardianPhone,
        email,
        joiningDate,
        status,
      ];
}

class Family extends Equatable {

  const Family({
    required this.id,
    required this.familyCode,
    required this.guardianName,
    required this.guardianPhone,
    this.address,
  });
  final int id;
  final String familyCode;
  final String guardianName;
  final String guardianPhone;
  final String? address;

  @override
  List<Object?> get props => [id, familyCode, guardianName, guardianPhone, address];
}

class StudentImportRow extends Equatable {

  const StudentImportRow({
    required this.name,
    required this.guardianPhone,
    this.phone,
    this.email,
    this.rollNumber,
  });
  final String name;
  final String guardianPhone;
  final String? phone;
  final String? email;
  final String? rollNumber;

  @override
  List<Object?> get props => [name, guardianPhone, phone, email, rollNumber];
}
