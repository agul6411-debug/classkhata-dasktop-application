/// Rich profile metadata for school staff members (Photo, Bio-data, Qualifications,
/// Subject Specialization, Salary Deposit Policy, Bank Details, and References).
library;

import 'dart:convert';
import 'package:equatable/equatable.dart';

class StaffProfile extends Equatable {
  const StaffProfile({
    this.photoPath,
    this.fatherOrHusbandName,
    this.dob,
    this.gender = 'Female',
    this.maritalStatus = 'Single',
    this.religion = 'Islam',
    this.nationality = 'Pakistani',
    this.domicile,
    this.homePhone,
    this.email,
    this.currentAddress,
    this.permanentAddress,
    this.highestQualification,
    this.institute,
    this.passingYear,
    this.professionalTraining,
    this.subjectSpecialist,
    this.assignedClasses,
    this.experienceYears,
    this.previousInstitute,
    this.lastDrawnSalary,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.bloodGroup,
    this.employmentType = 'Permanent',
    this.basicSalary = 0,
    this.allowances = 0,
    this.securityDepositRequired = true,
    this.securityDepositAmount = 0,
    this.securityDepositTerms = '1 Month salary held in security deposit; refundable upon completion of academic session and 1 month prior resignation notice clearance.',
    this.bankName,
    this.bankAccountTitle,
    this.bankAccountNumber,
    this.reference1Name,
    this.reference1Phone,
    this.reference1Relation,
    this.reference2Name,
    this.reference2Phone,
    this.reference2Relation,
    this.documentsSubmitted,
  });

  final String? photoPath;
  final String? fatherOrHusbandName;
  final String? dob; // e.g. "1995-08-15"
  final String gender;
  final String maritalStatus; // 'Single', 'Married', 'Divorced', 'Widowed'
  final String religion;
  final String nationality;
  final String? domicile;
  final String? homePhone;
  final String? email;
  final String? currentAddress;
  final String? permanentAddress;
  final String? highestQualification;
  final String? institute;
  final String? passingYear;
  final String? professionalTraining; // e.g. 'B.Ed', 'M.Ed', 'Montessori Diploma'
  final String? subjectSpecialist;
  final String? assignedClasses; // e.g. 'Primary (1-5)', 'Metric (9-10)'
  final String? experienceYears;
  final String? previousInstitute;
  final int? lastDrawnSalary;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? bloodGroup;
  final String employmentType; // 'Permanent', 'Contract', 'Probation', 'Visiting'
  final int basicSalary; // in Rupees
  final int allowances; // in Rupees

  // Security Deposit & 1 Month Salary Policy
  final bool securityDepositRequired;
  final int securityDepositAmount; // in Rupees (e.g. 1 month salary)
  final String securityDepositTerms;

  // Bank & Salary Payment Info
  final String? bankName;
  final String? bankAccountTitle;
  final String? bankAccountNumber;

  // 2 Official References / Guarantors
  final String? reference1Name;
  final String? reference1Phone;
  final String? reference1Relation;
  final String? reference2Name;
  final String? reference2Phone;
  final String? reference2Relation;

  // Documents Checklist
  final String? documentsSubmitted;

  int get grossPackage => basicSalary + allowances;

  /// Automatically calculates human-readable age based on [dob].
  String get calculatedAge {
    if (dob == null || dob!.trim().isEmpty) return '-';
    try {
      final birthDate = DateTime.parse(dob!);
      final today = DateTime.now();
      int years = today.year - birthDate.year;
      int months = today.month - birthDate.month;
      if (today.day < birthDate.day) {
        months--;
      }
      if (months < 0) {
        years--;
        months += 12;
      }
      if (years < 0) return '-';
      if (months == 0) return '$years Years';
      return '$years Years, $months Months';
    } catch (_) {
      return '-';
    }
  }

  Map<String, dynamic> toJson() => {
        'photoPath': photoPath,
        'fatherOrHusbandName': fatherOrHusbandName,
        'dob': dob,
        'gender': gender,
        'maritalStatus': maritalStatus,
        'religion': religion,
        'nationality': nationality,
        'domicile': domicile,
        'homePhone': homePhone,
        'email': email,
        'currentAddress': currentAddress,
        'permanentAddress': permanentAddress,
        'highestQualification': highestQualification,
        'institute': institute,
        'passingYear': passingYear,
        'professionalTraining': professionalTraining,
        'subjectSpecialist': subjectSpecialist,
        'assignedClasses': assignedClasses,
        'experienceYears': experienceYears,
        'previousInstitute': previousInstitute,
        'lastDrawnSalary': lastDrawnSalary,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'bloodGroup': bloodGroup,
        'employmentType': employmentType,
        'basicSalary': basicSalary,
        'allowances': allowances,
        'securityDepositRequired': securityDepositRequired,
        'securityDepositAmount': securityDepositAmount,
        'securityDepositTerms': securityDepositTerms,
        'bankName': bankName,
        'bankAccountTitle': bankAccountTitle,
        'bankAccountNumber': bankAccountNumber,
        'reference1Name': reference1Name,
        'reference1Phone': reference1Phone,
        'reference1Relation': reference1Relation,
        'reference2Name': reference2Name,
        'reference2Phone': reference2Phone,
        'reference2Relation': reference2Relation,
        'documentsSubmitted': documentsSubmitted,
      };

  factory StaffProfile.fromJson(Map<String, dynamic> json) => StaffProfile(
        photoPath: json['photoPath'] as String?,
        fatherOrHusbandName: json['fatherOrHusbandName'] as String?,
        dob: json['dob'] as String?,
        gender: (json['gender'] as String?) ?? 'Female',
        maritalStatus: (json['maritalStatus'] as String?) ?? 'Single',
        religion: (json['religion'] as String?) ?? 'Islam',
        nationality: (json['nationality'] as String?) ?? 'Pakistani',
        domicile: json['domicile'] as String?,
        homePhone: json['homePhone'] as String?,
        email: json['email'] as String?,
        currentAddress: json['currentAddress'] as String?,
        permanentAddress: json['permanentAddress'] as String?,
        highestQualification: json['highestQualification'] as String?,
        institute: json['institute'] as String?,
        passingYear: json['passingYear'] as String?,
        professionalTraining: json['professionalTraining'] as String?,
        subjectSpecialist: json['subjectSpecialist'] as String?,
        assignedClasses: json['assignedClasses'] as String?,
        experienceYears: json['experienceYears'] as String?,
        previousInstitute: json['previousInstitute'] as String?,
        lastDrawnSalary: (json['lastDrawnSalary'] as num?)?.toInt(),
        emergencyContactName: json['emergencyContactName'] as String?,
        emergencyContactPhone: json['emergencyContactPhone'] as String?,
        bloodGroup: json['bloodGroup'] as String?,
        employmentType: (json['employmentType'] as String?) ?? 'Permanent',
        basicSalary: (json['basicSalary'] as num?)?.toInt() ?? 0,
        allowances: (json['allowances'] as num?)?.toInt() ?? 0,
        securityDepositRequired: (json['securityDepositRequired'] as bool?) ?? true,
        securityDepositAmount: (json['securityDepositAmount'] as num?)?.toInt() ?? 0,
        securityDepositTerms: (json['securityDepositTerms'] as String?) ??
            '1 Month salary held in security deposit; refundable upon completion of academic session and 1 month prior resignation notice clearance.',
        bankName: json['bankName'] as String?,
        bankAccountTitle: json['bankAccountTitle'] as String?,
        bankAccountNumber: json['bankAccountNumber'] as String?,
        reference1Name: json['reference1Name'] as String?,
        reference1Phone: json['reference1Phone'] as String?,
        reference1Relation: json['reference1Relation'] as String?,
        reference2Name: json['reference2Name'] as String?,
        reference2Phone: json['reference2Phone'] as String?,
        reference2Relation: json['reference2Relation'] as String?,
        documentsSubmitted: json['documentsSubmitted'] as String?,
      );

  factory StaffProfile.fromRawJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const StaffProfile();
    try {
      return StaffProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const StaffProfile();
    }
  }

  String toRawJson() => jsonEncode(toJson());

  @override
  List<Object?> get props => [
        photoPath,
        fatherOrHusbandName,
        dob,
        gender,
        maritalStatus,
        religion,
        nationality,
        domicile,
        homePhone,
        email,
        currentAddress,
        permanentAddress,
        highestQualification,
        institute,
        passingYear,
        professionalTraining,
        subjectSpecialist,
        assignedClasses,
        experienceYears,
        previousInstitute,
        lastDrawnSalary,
        emergencyContactName,
        emergencyContactPhone,
        bloodGroup,
        employmentType,
        basicSalary,
        allowances,
        securityDepositRequired,
        securityDepositAmount,
        securityDepositTerms,
        bankName,
        bankAccountTitle,
        bankAccountNumber,
        reference1Name,
        reference1Phone,
        reference1Relation,
        reference2Name,
        reference2Phone,
        reference2Relation,
        documentsSubmitted,
      ];
}
