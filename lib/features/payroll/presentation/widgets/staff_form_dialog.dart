/// Comprehensive Add Staff Member Dialog with Extended Bio-Data,
/// live automatic age calculation, photo picker, academic background,
/// subject specialization, 1-month salary deposit policy, bank details,
/// references, and Save & Print Dossier functionality.
library;

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/staff_profile.dart';
import '../../domain/services/staff_profile_service.dart';
import '../providers/payroll_providers.dart';
import 'staff_terms_editor_dialog.dart';

class StaffFormDialog extends ConsumerStatefulWidget {
  const StaffFormDialog({super.key});

  @override
  ConsumerState<StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends ConsumerState<StaffFormDialog> {
  // 1. Personal Bio-Data
  final _nameCtrl = TextEditingController();
  final _fatherOrHusbandCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  String _gender = 'Female';
  String _maritalStatus = 'Single';
  String _bloodGroup = 'Unknown';
  String _religion = 'Islam';
  final _nationalityCtrl = TextEditingController(text: 'Pakistani');
  final _domicileCtrl = TextEditingController(text: 'Lahore');
  String? _photoPath;
  String _displayedAge = '-';

  // 2. Contact & Address
  final _phoneCtrl = TextEditingController();
  final _homePhoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _currentAddressCtrl = TextEditingController();
  final _permanentAddressCtrl = TextEditingController();

  // 3. Academic & Specialization
  final _qualificationCtrl = TextEditingController(text: 'M.A / M.Sc');
  final _instituteCtrl = TextEditingController();
  final _passingYearCtrl = TextEditingController(text: '2020');
  String _professionalTraining = 'B.Ed';
  String _subjectSpecialist = 'Mathematics';
  final _customSpecialistCtrl = TextEditingController();
  bool _isCustomSpecialist = false;
  final _assignedClassesCtrl = TextEditingController(text: 'Primary & Middle Wing');
  final _experienceCtrl = TextEditingController(text: '2');
  final _previousSchoolCtrl = TextEditingController();
  final _lastSalaryCtrl = TextEditingController();

  // 4. Role, Salary & 1-Month Salary Deposit Policy
  final _designationCtrl = TextEditingController(text: 'Teacher');
  String _employmentType = 'Permanent';
  String _structureType = 'fixed';
  final _baseAmountCtrl = TextEditingController(text: '30000');
  final _allowancesCtrl = TextEditingController(text: '0');
  final _deductionsCtrl = TextEditingController(text: '0');
  bool _securityDepositRequired = true;
  final _securityDepositAmountCtrl = TextEditingController(text: '30000');
  final _securityDepositTermsCtrl = TextEditingController(
    text: '1 Month salary held in security deposit; refundable upon completion of academic session and 1 month prior resignation notice clearance.',
  );

  // 5. Bank Account Details
  final _bankNameCtrl = TextEditingController(text: 'HBL / Bank Alfalah');
  final _bankAccountTitleCtrl = TextEditingController();
  final _bankAccountNumberCtrl = TextEditingController();

  // 6. Two Respectable References / Guarantors
  final _ref1NameCtrl = TextEditingController();
  final _ref1PhoneCtrl = TextEditingController();
  final _ref1RelationCtrl = TextEditingController(text: 'Former Principal / Teacher');
  final _ref2NameCtrl = TextEditingController();
  final _ref2PhoneCtrl = TextEditingController();
  final _ref2RelationCtrl = TextEditingController(text: 'Family Friend / Guarantor');

  // 7. Submitted Documents Checklist
  final _docsSubmittedCtrl = TextEditingController(
    text: 'CNIC Copy, Verified Academic Degrees, 2 Photos, Experience Letter',
  );

  // 8. Emergency Contact
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  static const _subjectOptions = [
    'Mathematics',
    'English Language & Literature',
    'Urdu & Islamiyat',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science / IT',
    'General Science',
    'Pakistan Studies / Social Studies',
    'Primary / Montessori / ECE',
    'Arts & Calligraphy',
    'Physical Education / Sports',
    'Accountancy & Commerce',
    'Arabic / Quranic Studies',
    'Other / Custom Specialization',
  ];

  static const _trainingOptions = [
    'B.Ed',
    'M.Ed',
    'Montessori / Early Childhood Diploma',
    'CT / PTC Certified',
    'None / Fresh Subject Specialist',
  ];

  @override
  void initState() {
    super.initState();
    _dobCtrl.addListener(_onDobChanged);
    _baseAmountCtrl.addListener(_onBaseAmountChanged);
  }

  void _onDobChanged() {
    final age = StaffProfile(dob: _dobCtrl.text.trim()).calculatedAge;
    if (_displayedAge != age) {
      setState(() => _displayedAge = age);
    }
  }

  void _onBaseAmountChanged() {
    // Keep security deposit amount updated with base salary by default if desired
    if (_securityDepositRequired && _securityDepositAmountCtrl.text == '30000') {
      final base = _baseAmountCtrl.text.trim();
      if (base.isNotEmpty) {
        _securityDepositAmountCtrl.text = base;
      }
    }
  }

  @override
  void dispose() {
    _dobCtrl.removeListener(_onDobChanged);
    _baseAmountCtrl.removeListener(_onBaseAmountChanged);
    _nameCtrl.dispose();
    _fatherOrHusbandCtrl.dispose();
    _cnicCtrl.dispose();
    _dobCtrl.dispose();
    _nationalityCtrl.dispose();
    _domicileCtrl.dispose();
    _phoneCtrl.dispose();
    _homePhoneCtrl.dispose();
    _emailCtrl.dispose();
    _currentAddressCtrl.dispose();
    _permanentAddressCtrl.dispose();
    _qualificationCtrl.dispose();
    _instituteCtrl.dispose();
    _passingYearCtrl.dispose();
    _customSpecialistCtrl.dispose();
    _assignedClassesCtrl.dispose();
    _experienceCtrl.dispose();
    _previousSchoolCtrl.dispose();
    _lastSalaryCtrl.dispose();
    _designationCtrl.dispose();
    _baseAmountCtrl.dispose();
    _allowancesCtrl.dispose();
    _deductionsCtrl.dispose();
    _securityDepositAmountCtrl.dispose();
    _securityDepositTermsCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountTitleCtrl.dispose();
    _bankAccountNumberCtrl.dispose();
    _ref1NameCtrl.dispose();
    _ref1PhoneCtrl.dispose();
    _ref1RelationCtrl.dispose();
    _ref2NameCtrl.dispose();
    _ref2PhoneCtrl.dispose();
    _ref2RelationCtrl.dispose();
    _docsSubmittedCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (result != null && result.files.single.path != null) {
        final persisted = await StaffProfileService.persistPhoto(result.files.single.path!);
        setState(() => _photoPath = persisted);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick photo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _selectDob() async {
    final now = DateTime.now();
    final initialDate = DateTime(1995, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1945),
      lastDate: now,
    );
    if (picked != null) {
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _dobCtrl.text = formatted;
    }
  }

  void _copyCurrentAddressToPermanent() {
    if (_currentAddressCtrl.text.isNotEmpty) {
      _permanentAddressCtrl.text = _currentAddressCtrl.text;
    }
  }

  Future<void> _submit({required bool andPrint}) async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final designation = _designationCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || designation.isEmpty) {
      setState(() => _errorMessage = 'Full Name, Phone number, and Designation are required.');
      return;
    }

    final baseRupees = double.tryParse(_baseAmountCtrl.text.trim()) ?? 0;
    final allowRupees = double.tryParse(_allowancesCtrl.text.trim()) ?? 0;
    final dedRupees = double.tryParse(_deductionsCtrl.text.trim()) ?? 0;

    if (baseRupees <= 0) {
      setState(() => _errorMessage = 'Base pay must be greater than zero.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final userId = currentUser?.id ?? 1;

    final createStaffUseCase = ref.read(createStaffMemberUseCaseProvider);
    final repo = ref.read(payrollRepositoryProvider);

    final staffRes = await createStaffUseCase(
      name: name,
      phone: phone,
      designation: designation,
      cnic: _cnicCtrl.text.trim().isEmpty ? null : _cnicCtrl.text.trim(),
      createdBy: userId,
    );

    if (!mounted) return;

    if (staffRes.isFailure) {
      setState(() {
        _isLoading = false;
        _errorMessage = staffRes.fold(onSuccess: (_) => '', onFailure: (f) => f.message);
      });
      return;
    }

    final newStaff = staffRes.fold(onSuccess: (s) => s, onFailure: (_) => throw Exception());

    // 1. Assign salary structure
    final structureRes = await repo.setSalaryStructure(
      staffId: newStaff.id,
      structureType: _structureType,
      baseAmount: Money.fromRupees(baseRupees),
      allowances: Money.fromRupees(allowRupees),
      deductions: Money.fromRupees(dedRupees),
      createdBy: userId,
    );

    if (structureRes.isFailure) {
      setState(() {
        _isLoading = false;
        _errorMessage = structureRes.fold(onSuccess: (_) => '', onFailure: (f) => f.message);
      });
      return;
    }

    // 2. Save extended profile
    final finalSpecialist = _isCustomSpecialist ? _customSpecialistCtrl.text.trim() : _subjectSpecialist;
    final depositAmount = int.tryParse(_securityDepositAmountCtrl.text.trim()) ?? baseRupees.toInt();

    final profile = StaffProfile(
      photoPath: _photoPath,
      fatherOrHusbandName: _fatherOrHusbandCtrl.text.trim().isEmpty ? null : _fatherOrHusbandCtrl.text.trim(),
      dob: _dobCtrl.text.trim().isEmpty ? null : _dobCtrl.text.trim(),
      gender: _gender,
      maritalStatus: _maritalStatus,
      religion: _religion,
      nationality: _nationalityCtrl.text.trim().isEmpty ? 'Pakistani' : _nationalityCtrl.text.trim(),
      domicile: _domicileCtrl.text.trim().isEmpty ? null : _domicileCtrl.text.trim(),
      homePhone: _homePhoneCtrl.text.trim().isEmpty ? null : _homePhoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      currentAddress: _currentAddressCtrl.text.trim().isEmpty ? null : _currentAddressCtrl.text.trim(),
      permanentAddress: _permanentAddressCtrl.text.trim().isEmpty ? null : _permanentAddressCtrl.text.trim(),
      highestQualification: _qualificationCtrl.text.trim().isEmpty ? null : _qualificationCtrl.text.trim(),
      institute: _instituteCtrl.text.trim().isEmpty ? null : _instituteCtrl.text.trim(),
      passingYear: _passingYearCtrl.text.trim().isEmpty ? null : _passingYearCtrl.text.trim(),
      professionalTraining: _professionalTraining,
      subjectSpecialist: finalSpecialist.isEmpty ? null : finalSpecialist,
      assignedClasses: _assignedClassesCtrl.text.trim().isEmpty ? null : _assignedClassesCtrl.text.trim(),
      experienceYears: _experienceCtrl.text.trim().isEmpty ? null : _experienceCtrl.text.trim(),
      previousInstitute: _previousSchoolCtrl.text.trim().isEmpty ? null : _previousSchoolCtrl.text.trim(),
      lastDrawnSalary: int.tryParse(_lastSalaryCtrl.text.trim()),
      emergencyContactName: _emergencyNameCtrl.text.trim().isEmpty ? null : _emergencyNameCtrl.text.trim(),
      emergencyContactPhone: _emergencyPhoneCtrl.text.trim().isEmpty ? null : _emergencyPhoneCtrl.text.trim(),
      bloodGroup: _bloodGroup,
      employmentType: _employmentType,
      basicSalary: baseRupees.toInt(),
      allowances: allowRupees.toInt(),
      securityDepositRequired: _securityDepositRequired,
      securityDepositAmount: depositAmount,
      securityDepositTerms: _securityDepositTermsCtrl.text.trim(),
      bankName: _bankNameCtrl.text.trim().isEmpty ? null : _bankNameCtrl.text.trim(),
      bankAccountTitle: _bankAccountTitleCtrl.text.trim().isEmpty ? null : _bankAccountTitleCtrl.text.trim(),
      bankAccountNumber: _bankAccountNumberCtrl.text.trim().isEmpty ? null : _bankAccountNumberCtrl.text.trim(),
      reference1Name: _ref1NameCtrl.text.trim().isEmpty ? null : _ref1NameCtrl.text.trim(),
      reference1Phone: _ref1PhoneCtrl.text.trim().isEmpty ? null : _ref1PhoneCtrl.text.trim(),
      reference1Relation: _ref1RelationCtrl.text.trim().isEmpty ? null : _ref1RelationCtrl.text.trim(),
      reference2Name: _ref2NameCtrl.text.trim().isEmpty ? null : _ref2NameCtrl.text.trim(),
      reference2Phone: _ref2PhoneCtrl.text.trim().isEmpty ? null : _ref2PhoneCtrl.text.trim(),
      reference2Relation: _ref2RelationCtrl.text.trim().isEmpty ? null : _ref2RelationCtrl.text.trim(),
      documentsSubmitted: _docsSubmittedCtrl.text.trim().isEmpty ? null : _docsSubmittedCtrl.text.trim(),
    );

    final db = ref.read(appDatabaseProvider);
    await StaffProfileService.saveProfile(db: db, staffId: newStaff.id, profile: profile);

    ref.invalidate(staffListProvider);

    if (!mounted) return;

    Navigator.of(context).pop({
      'success': true,
      'print': andPrint,
      'staff': newStaff,
      'profile': profile,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 860),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_add_alt_1, color: AppColors.accent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Staff Member & Profile Dossier',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.headingCol(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Staff recruitment form • Auto age calculation, salary deposit policy & 2-page agreement',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.gavel, size: 14),
                        label: const Text('Edit School Terms', style: TextStyle(fontSize: 12)),
                        onPressed: () => showDialog<bool>(
                          context: context,
                          builder: (_) => const StaffTermsEditorDialog(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 6),

              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 10),
              ],

              // Scrollable Multi-Section Form Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SECTION 1: Personal Bio-Data & Photo
                      _buildSectionHeader('1. Personal Information & Bio-Data (Personal Details)', Icons.badge_outlined),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Photo Picker Card
                          Column(
                            children: [
                              Container(
                                width: 100,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.borderCol(context)),
                                  image: _photoPath != null && File(_photoPath!).existsSync()
                                      ? DecorationImage(
                                          image: FileImage(File(_photoPath!)),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _photoPath == null || !File(_photoPath!).existsSync()
                                    ? const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.person, size: 40, color: AppColors.textMuted),
                                          SizedBox(height: 4),
                                          Text('Passport Photo', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                        ],
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: _pickPhoto,
                                icon: const Icon(Icons.camera_alt, size: 14),
                                label: Text(_photoPath == null ? 'Upload' : 'Change', style: const TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                ),
                              ),
                              if (_photoPath != null)
                                TextButton(
                                  onPressed: () => setState(() => _photoPath = null),
                                  child: const Text('Remove', style: TextStyle(fontSize: 10, color: Colors.red)),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),

                          // Fields Right of Photo
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        controller: _nameCtrl,
                                        label: 'Full Name *',
                                        autofocus: true,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: AppTextField(
                                        controller: _fatherOrHusbandCtrl,
                                        label: 'Father / Husband Name',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        controller: _cnicCtrl,
                                        label: 'CNIC / National ID (e.g. 35201-1234567-1)',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: AppTextField(
                                              controller: _dobCtrl,
                                              label: 'Date of Birth (YYYY-MM-DD)',
                                              hint: '1995-08-15',
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.calendar_month, color: AppColors.accent),
                                            tooltip: 'Pick Date of Birth',
                                            onPressed: _selectDob,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Real-time Calculated Age display badge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _displayedAge != '-'
                                            ? Colors.green.withValues(alpha: 0.12)
                                            : Colors.grey.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _displayedAge != '-' ? Colors.green : Colors.grey.shade400,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.cake_outlined,
                                            size: 14,
                                            color: _displayedAge != '-' ? Colors.green.shade800 : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Auto Calculated Age: $_displayedAge',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _displayedAge != '-' ? Colors.green.shade800 : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: const InputDecoration(labelText: 'Gender'),
                              items: const [
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (val) => setState(() => _gender = val ?? 'Female'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _maritalStatus,
                              decoration: const InputDecoration(labelText: 'Marital Status'),
                              items: const [
                                DropdownMenuItem(value: 'Single', child: Text('Single')),
                                DropdownMenuItem(value: 'Married', child: Text('Married')),
                                DropdownMenuItem(value: 'Divorced', child: Text('Divorced')),
                                DropdownMenuItem(value: 'Widowed', child: Text('Widowed')),
                              ],
                              onChanged: (val) => setState(() => _maritalStatus = val ?? 'Single'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _bloodGroup,
                              decoration: const InputDecoration(labelText: 'Blood Group'),
                              items: const [
                                DropdownMenuItem(value: 'Unknown', child: Text('Unknown / Not Tested')),
                                DropdownMenuItem(value: 'A+', child: Text('A+')),
                                DropdownMenuItem(value: 'A-', child: Text('A-')),
                                DropdownMenuItem(value: 'B+', child: Text('B+')),
                                DropdownMenuItem(value: 'B-', child: Text('B-')),
                                DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                                DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                                DropdownMenuItem(value: 'O+', child: Text('O+')),
                                DropdownMenuItem(value: 'O-', child: Text('O-')),
                              ],
                              onChanged: (val) => setState(() => _bloodGroup = val ?? 'Unknown'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _religion,
                              decoration: const InputDecoration(labelText: 'Religion'),
                              items: const [
                                DropdownMenuItem(value: 'Islam', child: Text('Islam')),
                                DropdownMenuItem(value: 'Christianity', child: Text('Christianity')),
                                DropdownMenuItem(value: 'Hinduism', child: Text('Hinduism')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (val) => setState(() => _religion = val ?? 'Islam'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _domicileCtrl,
                              label: 'Domicile District (e.g. Lahore)',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _nationalityCtrl,
                              label: 'Nationality',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECTION 2: Contact & Residential
                      _buildSectionHeader('2. Contact & Residential Details', Icons.contact_phone_outlined),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _phoneCtrl,
                              label: 'Mobile / WhatsApp *',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _homePhoneCtrl,
                              label: 'Home / Landline Phone',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _emailCtrl,
                              label: 'Email Address',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AppTextField(
                        controller: _currentAddressCtrl,
                        label: 'Current Residential Address',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _permanentAddressCtrl,
                              label: 'Permanent Address',
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _copyCurrentAddressToPermanent,
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text('Same as Current', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECTION 3: Academic Qualifications & Subject Specialization
                      _buildSectionHeader('3. Academic Background & Teaching Specialization', Icons.school_outlined),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _qualificationCtrl,
                              label: 'Highest Degree / Qualification',
                              hint: 'e.g. M.Sc, M.Phil, BS CS',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _instituteCtrl,
                              label: 'Institute / University / Board',
                              hint: 'e.g. Punjab University / BZU',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: AppTextField(
                              controller: _passingYearCtrl,
                              label: 'Passing Year',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _professionalTraining,
                              decoration: const InputDecoration(labelText: 'Professional Training / Diploma'),
                              items: _trainingOptions.map((t) {
                                return DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis));
                              }).toList(),
                              onChanged: (val) => setState(() => _professionalTraining = val ?? 'B.Ed'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _subjectSpecialist,
                              decoration: const InputDecoration(labelText: 'Subject Specialist *'),
                              items: _subjectOptions.map((subj) {
                                return DropdownMenuItem(value: subj, child: Text(subj));
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _subjectSpecialist = val ?? 'Mathematics';
                                  _isCustomSpecialist = _subjectSpecialist == 'Other / Custom Specialization';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_isCustomSpecialist) ...[
                        const SizedBox(height: 10),
                        AppTextField(
                          controller: _customSpecialistCtrl,
                          label: 'Specify Subject Specialist *',
                          autofocus: true,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _assignedClassesCtrl,
                              label: 'Assigned Classes / Wing (e.g. Matric / Middle)',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: AppTextField(
                              controller: _experienceCtrl,
                              label: 'Experience (Years)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _previousSchoolCtrl,
                              label: 'Previous School / Institute',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECTION 4: Role, Salary & 1-Month Salary Deposit Policy
                      _buildSectionHeader('4. Job Designation, Salary & 1-Month Salary Deposit Policy', Icons.payments_outlined),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _designationCtrl,
                              label: 'Designation / Role *',
                              hint: 'e.g. Senior Teacher, Coordinator',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _employmentType,
                              decoration: const InputDecoration(labelText: 'Employment Nature'),
                              items: const [
                                DropdownMenuItem(value: 'Permanent', child: Text('Permanent')),
                                DropdownMenuItem(value: 'Contract', child: Text('Contract')),
                                DropdownMenuItem(value: 'Probation', child: Text('Probation (3 Months)')),
                                DropdownMenuItem(value: 'Visiting', child: Text('Visiting / Part-time')),
                              ],
                              onChanged: (val) => setState(() => _employmentType = val ?? 'Permanent'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _structureType,
                              decoration: const InputDecoration(labelText: 'Salary Basis'),
                              items: const [
                                DropdownMenuItem(value: 'fixed', child: Text('Fixed Monthly')),
                                DropdownMenuItem(value: 'per_class', child: Text('Per Class / Lecture')),
                                DropdownMenuItem(value: 'per_hour', child: Text('Per Hour')),
                              ],
                              onChanged: (val) => setState(() => _structureType = val ?? 'fixed'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _baseAmountCtrl,
                              label: 'Base Pay (Rs.) *',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _allowancesCtrl,
                              label: 'Allowances (Rs.)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _deductionsCtrl,
                              label: 'Deductions (Rs.)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _lastSalaryCtrl,
                              label: 'Last Drawn Salary (Rs.)',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 1-Month Salary Deposit Box (Specific User Request)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _securityDepositRequired,
                                  onChanged: (val) => setState(() => _securityDepositRequired = val ?? true),
                                ),
                                const Expanded(
                                  child: Text(
                                    '1-Month Salary Held as Security Deposit (1 Month Salary Deposit Policy)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            if (_securityDepositRequired) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: AppTextField(
                                      controller: _securityDepositAmountCtrl,
                                      label: 'Security Deposit Amount (Rs.)',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: AppTextField(
                                      controller: _securityDepositTermsCtrl,
                                      label: 'Deposit Refund Terms & Conditions',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Bank Account Details
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _bankNameCtrl,
                              label: 'Salary Transfer Bank Name',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _bankAccountTitleCtrl,
                              label: 'Account Title',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _bankAccountNumberCtrl,
                              label: 'Account / IBAN Number',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECTION 5: Two Respectable References / Guarantors
                      _buildSectionHeader('5. Respectable References & Guarantors', Icons.people_outline),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _ref1NameCtrl,
                              label: 'Reference 1 Name',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: AppTextField(
                              controller: _ref1RelationCtrl,
                              label: 'Relationship / Post',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _ref1PhoneCtrl,
                              label: 'Reference 1 Contact Phone',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _ref2NameCtrl,
                              label: 'Reference 2 Name',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: AppTextField(
                              controller: _ref2RelationCtrl,
                              label: 'Relationship / Post',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _ref2PhoneCtrl,
                              label: 'Reference 2 Contact Phone',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECTION 6: Emergency Contact & Verification Checklist
                      _buildSectionHeader('6. Emergency Contact & Documents Verification', Icons.emergency_outlined),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _emergencyNameCtrl,
                              label: 'Emergency Contact Person Name',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _emergencyPhoneCtrl,
                              label: 'Emergency Contact Phone Number',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AppTextField(
                        controller: _docsSubmittedCtrl,
                        label: 'Submitted Documents Checklist',
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 6),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Save & Print Dossier'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? AppColors.accentLight : AppColors.accent,
                          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.accent),
                        ),
                        onPressed: _isLoading ? null : () => _submit(andPrint: true),
                      ),
                      const SizedBox(width: 12),
                      PrimaryButton(
                        label: 'Save Staff Member',
                        icon: Icons.check,
                        isLoading: _isLoading,
                        onPressed: () => _submit(andPrint: false),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.accent),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}
