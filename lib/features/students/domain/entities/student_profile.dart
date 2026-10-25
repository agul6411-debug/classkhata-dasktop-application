/// Rich profile metadata for school students (Photo, Father details, Fee package, Sibling info).
library;

import 'dart:convert';
import 'package:equatable/equatable.dart';

class StudentProfile extends Equatable {
  const StudentProfile({
    this.photoPath,
    this.fatherName,
    this.fatherCnic,
    this.fatherOccupation,
    this.gender = 'Male',
    this.dob,
    this.bloodGroup,
    this.address,
    this.customMonthlyFee,
    this.admissionFee = 0,
    this.openingArrears = 0,
    this.monthlyDiscount = 0,
    this.discountReason,
  });

  final String? photoPath;
  final String? fatherName;
  final String? fatherCnic;
  final String? fatherOccupation;
  final String gender;
  final String? dob;
  final String? bloodGroup;
  final String? address;
  final int? customMonthlyFee; // in Rupees, student-specific agreed monthly tuition fee
  final int admissionFee; // in Rupees
  final int openingArrears; // in Rupees
  final int monthlyDiscount; // in Rupees
  final String? discountReason;

  Map<String, dynamic> toJson() => {
        'photoPath': photoPath,
        'fatherName': fatherName,
        'fatherCnic': fatherCnic,
        'fatherOccupation': fatherOccupation,
        'gender': gender,
        'dob': dob,
        'bloodGroup': bloodGroup,
        'address': address,
        'customMonthlyFee': customMonthlyFee,
        'admissionFee': admissionFee,
        'openingArrears': openingArrears,
        'monthlyDiscount': monthlyDiscount,
        'discountReason': discountReason,
      };

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
        photoPath: json['photoPath'] as String?,
        fatherName: json['fatherName'] as String?,
        fatherCnic: json['fatherCnic'] as String?,
        fatherOccupation: json['fatherOccupation'] as String?,
        gender: (json['gender'] as String?) ?? 'Male',
        dob: json['dob'] as String?,
        bloodGroup: json['bloodGroup'] as String?,
        address: json['address'] as String?,
        customMonthlyFee: (json['customMonthlyFee'] as num?)?.toInt(),
        admissionFee: (json['admissionFee'] as num?)?.toInt() ?? 0,
        openingArrears: (json['openingArrears'] as num?)?.toInt() ?? 0,
        monthlyDiscount: (json['monthlyDiscount'] as num?)?.toInt() ?? 0,
        discountReason: json['discountReason'] as String?,
      );

  factory StudentProfile.fromRawJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const StudentProfile();
    try {
      return StudentProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const StudentProfile();
    }
  }

  String toRawJson() => jsonEncode(toJson());

  StudentProfile copyWith({
    String? photoPath,
    String? fatherName,
    String? fatherCnic,
    String? fatherOccupation,
    String? gender,
    String? dob,
    String? bloodGroup,
    String? address,
    int? customMonthlyFee,
    int? admissionFee,
    int? openingArrears,
    int? monthlyDiscount,
    String? discountReason,
  }) {
    return StudentProfile(
      photoPath: photoPath ?? this.photoPath,
      fatherName: fatherName ?? this.fatherName,
      fatherCnic: fatherCnic ?? this.fatherCnic,
      fatherOccupation: fatherOccupation ?? this.fatherOccupation,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      address: address ?? this.address,
      customMonthlyFee: customMonthlyFee ?? this.customMonthlyFee,
      admissionFee: admissionFee ?? this.admissionFee,
      openingArrears: openingArrears ?? this.openingArrears,
      monthlyDiscount: monthlyDiscount ?? this.monthlyDiscount,
      discountReason: discountReason ?? this.discountReason,
    );
  }

  @override
  List<Object?> get props => [
        photoPath,
        fatherName,
        fatherCnic,
        fatherOccupation,
        gender,
        dob,
        bloodGroup,
        address,
        customMonthlyFee,
        admissionFee,
        openingArrears,
        monthlyDiscount,
        discountReason,
      ];
}
