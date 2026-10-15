/// Comprehensive Dialog for Student Registration & Profile Editing.
/// Includes Photo Picker, Father/Guardian details, School Fee Package (Tuition,
/// Admission Fee, Opening Arrears, Concessions), and Sibling Auto-Linking.
library;

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart' as drift hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family, Column;

import '../../../../app/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../academics/domain/entities/academic_entities.dart';
import '../../../academics/presentation/providers/academic_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../fees/presentation/providers/fee_providers.dart';
import '../../domain/entities/student_entities.dart';
import '../../domain/entities/student_profile.dart';
import '../../domain/services/student_profile_service.dart';
import '../providers/student_providers.dart';
import 'add_family_dialog.dart';

class StudentFormDialog extends ConsumerStatefulWidget {
  const StudentFormDialog({
    super.key,
    this.initialBatchId,
    this.initialFamilyId,
    this.studentToEdit,
  });

  final int? initialBatchId;
  final int? initialFamilyId;
  final Student? studentToEdit;

  @override
  ConsumerState<StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends ConsumerState<StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // Basic Details
  final _nameCtrl = TextEditingController();
  final _rollNumberCtrl = TextEditingController();
  String _gender = 'Male';
  DateTime? _dob;
  DateTime _joiningDate = DateTime.now();

  // Guardian & Contact
  final _fatherNameCtrl = TextEditingController();
  final _guardianPhoneCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _fatherCnicCtrl = TextEditingController();
  final _fatherOccupationCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // School Fee Package & Dues
  final _admissionFeeCtrl = TextEditingController(text: '0');
  final _openingArrearsCtrl = TextEditingController(text: '0');
  final _monthlyDiscountCtrl = TextEditingController(text: '0');
  final _discountReasonCtrl = TextEditingController();

  // Selections
  int? _selectedClassId;
  int? _selectedBatchId;
  int? _selectedFamilyId;
  String? _photoPath;

  bool _isLoading = false;
  String? _errorMessage;
  bool _initialized = false;
  List<Student> _detectedSiblings = [];

  bool get isEditing => widget.studentToEdit != null;

  @override
  void initState() {
    super.initState();
    _selectedFamilyId = widget.initialFamilyId;

    if (isEditing) {
      final s = widget.studentToEdit!;
      _nameCtrl.text = s.name;
      _rollNumberCtrl.text = s.rollNumber;
      _guardianPhoneCtrl.text = s.guardianPhone;
      _phoneCtrl.text = s.phone ?? '';
      _emailCtrl.text = s.email ?? '';
      _selectedBatchId = s.batchId;
      _selectedFamilyId = s.familyId;
      _joiningDate = s.joiningDate;

      // Load extended profile async
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final db = ref.read(appDatabaseProvider);
        final profile = await StudentProfileService.getProfile(db: db, studentId: s.id);
        if (mounted) {
          setState(() {
            _fatherNameCtrl.text = profile.fatherName ?? '';
            _fatherCnicCtrl.text = profile.fatherCnic ?? '';
            _fatherOccupationCtrl.text = profile.fatherOccupation ?? '';
            _gender = profile.gender;
            _addressCtrl.text = profile.address ?? '';
            _photoPath = profile.photoPath;
            _admissionFeeCtrl.text = profile.admissionFee.toString();
            _openingArrearsCtrl.text = profile.openingArrears.toString();
            _monthlyDiscountCtrl.text = profile.monthlyDiscount.toString();
            _discountReasonCtrl.text = profile.discountReason ?? '';
            if (profile.dob != null && profile.dob!.isNotEmpty) {
              _dob = DateTime.tryParse(profile.dob!);
            }
          });
        }
      });
    }

    if (widget.initialFamilyId != null && !isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final families = await ref.read(studentRepositoryProvider).getFamilies();
        families.fold(
          onSuccess: (list) {
            final f = list.where((x) => x.id == widget.initialFamilyId).firstOrNull;
            if (f != null && mounted) {
              setState(() {
                _guardianPhoneCtrl.text = f.guardianPhone;
                _fatherNameCtrl.text = f.guardianName;
                if (f.address != null && f.address!.isNotEmpty) {
                  _addressCtrl.text = f.address!;
                }
              });
            }
          },
          onFailure: (_) {},
        );
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rollNumberCtrl.dispose();
    _fatherNameCtrl.dispose();
    _guardianPhoneCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _fatherCnicCtrl.dispose();
    _fatherOccupationCtrl.dispose();
    _addressCtrl.dispose();
    _admissionFeeCtrl.dispose();
    _openingArrearsCtrl.dispose();
    _monthlyDiscountCtrl.dispose();
    _discountReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (result != null && result.files.single.path != null) {
        final persisted = await StudentProfileService.persistPhoto(result.files.single.path!);
        setState(() => _photoPath = persisted);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking photo: $e')),
        );
      }
    }
  }

  Future<void> _onGuardianPhoneChanged(String val) async {
    final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length >= 10 && !isEditing) {
      final repo = ref.read(studentRepositoryProvider);
      final res = await repo.getStudentsByGuardianPhone(clean);
      res.fold(
        onSuccess: (siblings) {
          if (mounted) {
            setState(() {
              _detectedSiblings = siblings;
              if (siblings.isNotEmpty && siblings.first.familyId != null) {
                _selectedFamilyId = siblings.first.familyId;
              }
            });
          }
        },
        onFailure: (_) {},
      );
    } else {
      if (_detectedSiblings.isNotEmpty) {
        setState(() => _detectedSiblings = []);
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedBatchId == null) {
      setState(() => _errorMessage = 'Please select a School Class and Section.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final repo = ref.read(studentRepositoryProvider);
    final db = ref.read(appDatabaseProvider);

    final admissionFee = int.tryParse(_admissionFeeCtrl.text.trim()) ?? 0;
    final openingArrears = int.tryParse(_openingArrearsCtrl.text.trim()) ?? 0;
    final monthlyDiscount = int.tryParse(_monthlyDiscountCtrl.text.trim()) ?? 0;

    final profile = StudentProfile(
      photoPath: _photoPath,
      fatherName: _fatherNameCtrl.text.trim().isEmpty ? null : _fatherNameCtrl.text.trim(),
      fatherCnic: _fatherCnicCtrl.text.trim().isEmpty ? null : _fatherCnicCtrl.text.trim(),
      fatherOccupation: _fatherOccupationCtrl.text.trim().isEmpty ? null : _fatherOccupationCtrl.text.trim(),
      gender: _gender,
      dob: _dob?.toIso8601String().split('T').first,
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      admissionFee: admissionFee,
      openingArrears: openingArrears,
      monthlyDiscount: monthlyDiscount,
      discountReason: _discountReasonCtrl.text.trim().isEmpty ? null : _discountReasonCtrl.text.trim(),
    );

    if (isEditing) {
      final s = widget.studentToEdit!;
      final updateRes = await repo.updateStudent(
        id: s.id,
        name: _nameCtrl.text.trim(),
        batchId: _selectedBatchId!,
        guardianPhone: _guardianPhoneCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        rollNumber: _rollNumberCtrl.text.trim().isEmpty ? s.rollNumber : _rollNumberCtrl.text.trim(),
        familyId: _selectedFamilyId,
      );

      if (!mounted) return;

      await updateRes.fold(
        onSuccess: (_) async {
          await StudentProfileService.saveProfile(db: db, studentId: s.id, profile: profile);
          ref.read(studentListVersionProvider.notifier).state++;
          ref.invalidate(studentsListProvider);
          Navigator.of(context).pop(true);
        },
        onFailure: (f) {
          setState(() {
            _isLoading = false;
            _errorMessage = f.message;
          });
        },
      );
    } else {
      // Register New Student
      final registerUseCase = ref.read(registerStudentUseCaseProvider);
      final result = await registerUseCase(
        name: _nameCtrl.text.trim(),
        batchId: _selectedBatchId!,
        guardianPhone: _guardianPhoneCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        familyId: _selectedFamilyId,
        customRollNumber: _rollNumberCtrl.text.trim().isEmpty ? null : _rollNumberCtrl.text.trim(),
        createdBy: currentUser?.id ?? 1,
      );

      if (!mounted) return;

      await result.fold(
        onSuccess: (student) async {
          // Save rich student profile metadata
          await StudentProfileService.saveProfile(db: db, studentId: student.id, profile: profile);

          // If student has opening arrears or admission fee, record voucher or balance note
          if (openingArrears > 0 || admissionFee > 0) {
            final now = DateTime.now();
            final monthYear = '${now.year}-${now.month.toString().padLeft(2, '0')}';
            final academicData = ref.read(academicDataProvider).valueOrNull;
            final batch = academicData?.batches.where((b) => b.id == _selectedBatchId).firstOrNull;
            final baseFee = batch?.monthlyFee.paisa ?? 0;
            final totalDue = baseFee + (openingArrears * 100) + (admissionFee * 100) - (monthlyDiscount * 100);

            // Record initial voucher with opening dues
            await db.into(db.feeVouchersTable).insertOnConflictUpdate(
                  FeeVouchersTableCompanion.insert(
                    voucherNumber: 'VCH-$monthYear-${student.id.toString().padLeft(4, '0')}',
                    studentId: student.id,
                    batchId: _selectedBatchId!,
                    monthYear: monthYear,
                    issueDate: now,
                    dueDate: DateTime(now.year, now.month, batch?.dueDay ?? 10),
                    baseAmountPaisa: drift.Value(baseFee + (admissionFee * 100)),
                    carryForwardPaisa: drift.Value(openingArrears * 100),
                    discountPaisa: drift.Value(monthlyDiscount * 100),
                    totalDuePaisa: drift.Value(totalDue > 0 ? totalDue : 0),
                    amountPaidPaisa: const drift.Value(0),
                    status: const drift.Value('unpaid'),
                    createdBy: drift.Value(currentUser?.id ?? 1),
                  ),
                );
            ref.invalidate(vouchersListProvider);
          }

          ref.read(studentListVersionProvider.notifier).state++;
          ref.invalidate(studentsListProvider);
          ref.invalidate(dashboardKpisProvider);
          Navigator.of(context).pop(student);
        },
        onFailure: (f) {
          setState(() {
            _isLoading = false;
            _errorMessage = f.message;
          });
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final academicDataAsync = ref.watch(academicDataProvider);
    final familiesAsync = ref.watch(familiesListProvider);

    academicDataAsync.whenData((data) {
      if (!_initialized) {
        _initialized = true;
        if (_selectedBatchId == null && widget.initialBatchId != null) {
          _selectedBatchId = widget.initialBatchId;
        }
        if (_selectedBatchId != null) {
          final b = data.batches.where((b) => b.id == _selectedBatchId).firstOrNull;
          if (b != null) _selectedClassId = b.courseId;
        }
      }
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(isEditing ? Icons.edit_note : Icons.person_add_alt_1, color: AppColors.accent, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          isEditing ? 'Edit Student Profile' : 'Student Admission & Registration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.headingCol(context),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 16),
                if (_errorMessage != null) ...[
                  ErrorBanner(message: _errorMessage!),
                  const SizedBox(height: 8),
                ],

                // Body: Scrollable sections
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // PHOTO & BASIC INFO HEADER
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Student Photo Picker Avatar
                            GestureDetector(
                              onTap: _pickPhoto,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 38,
                                    backgroundColor: AppColors.subCardBg(context),
                                    backgroundImage: _photoPath != null && File(_photoPath!).existsSync()
                                        ? FileImage(File(_photoPath!))
                                        : null,
                                    child: _photoPath == null || !File(_photoPath!).existsSync()
                                        ? const Icon(Icons.person, size: 40, color: AppColors.accent)
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppColors.accent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  AppTextField(
                                    controller: _nameCtrl,
                                    label: 'Student Full Name *',
                                    autofocus: !isEditing,
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AppTextField(
                                          controller: _rollNumberCtrl,
                                          label: 'Roll / Admission No.',
                                          hint: 'Auto if empty',
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: _gender,
                                          decoration: const InputDecoration(labelText: 'Gender'),
                                          items: const [
                                            DropdownMenuItem(value: 'Male', child: Text('Male')),
                                            DropdownMenuItem(value: 'Female', child: Text('Female')),
                                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                                          ],
                                          onChanged: (val) => setState(() => _gender = val ?? 'Male'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ACADEMIC ENROLLMENT (Class & Section)
                        _sectionHeader('1. Class & Section Enrollment'),
                        const SizedBox(height: 8),
                        academicDataAsync.when(
                          data: (data) {
                            final availableClasses = data.courses;
                            final availableSections = _selectedClassId != null
                                ? data.getSectionsForClass(_selectedClassId!)
                                : <Batch>[];

                            return Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _selectedClassId,
                                    decoration: const InputDecoration(labelText: 'School Class / Grade *'),
                                    items: availableClasses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedClassId = val;
                                        final secs = val != null ? data.getSectionsForClass(val) : <Batch>[];
                                        _selectedBatchId = secs.length == 1 ? secs.first.id : null;
                                      });
                                    },
                                    validator: (v) => v == null ? 'Class is required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _selectedBatchId,
                                    decoration: InputDecoration(
                                      labelText: 'Section *',
                                      helperText: _selectedClassId == null
                                          ? 'Select Class first'
                                          : (availableSections.isEmpty ? 'No sections found' : null),
                                    ),
                                    items: availableSections.map((b) {
                                      return DropdownMenuItem(
                                        value: b.id,
                                        child: Text('${b.name} (${b.monthlyFee.format()}/mo)'),
                                      );
                                    }).toList(),
                                    onChanged: _selectedClassId == null || availableSections.isEmpty
                                        ? null
                                        : (val) => setState(() => _selectedBatchId = val),
                                    validator: (v) => v == null ? 'Section is required' : null,
                                  ),
                                ),
                              ],
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const Text('Error loading classes'),
                        ),
                        const SizedBox(height: 14),

                        // PARENT & GUARDIAN DETAILS
                        _sectionHeader('2. Parent / Guardian Details'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _fatherNameCtrl,
                                label: 'Father / Guardian Name *',
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Father Name is required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                controller: _guardianPhoneCtrl,
                                label: 'Guardian Phone (WhatsApp) *',
                                keyboardType: TextInputType.phone,
                                onChanged: _onGuardianPhoneChanged,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
                              ),
                            ),
                          ],
                        ),

                        // SIBLING DETECTED BANNER
                        if (_detectedSiblings.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.family_restroom, color: Color(0xFF166534), size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Sibling Detected! Found enrolled student(s): ${_detectedSiblings.map((s) => "${s.name} (${s.rollNumber})").join(", ")}. Automatically linked as siblings.',
                                    style: const TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _fatherCnicCtrl,
                                label: 'Father CNIC (Optional)',
                                hint: '35202-xxxxxxx-x',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                controller: _phoneCtrl,
                                label: 'Alternate / Student Phone',
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AppTextField(
                          controller: _addressCtrl,
                          label: 'Home Address',
                          hint: 'House / Street / City',
                        ),
                        const SizedBox(height: 14),

                        // SCHOOL FEE PACKAGE & DUES
                        _sectionHeader('3. School Fee Package & Outstanding Dues'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _admissionFeeCtrl,
                                label: 'Admission Fee (Rs.)',
                                hint: 'One-time admission charge',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                controller: _openingArrearsCtrl,
                                label: 'Opening Outstanding Dues (Rs.)',
                                hint: 'Pichla baqaya / Previous dues',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _monthlyDiscountCtrl,
                                label: 'Monthly Concession / Discount (Rs.)',
                                hint: 'e.g. 500',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                controller: _discountReasonCtrl,
                                label: 'Discount Reason',
                                hint: 'e.g. Sibling discount / Staff child',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // SIBLINGS / FAMILY LINK
                        _sectionHeader('4. Family Group (Optional)'),
                        const SizedBox(height: 8),
                        familiesAsync.when(
                          data: (families) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int?>(
                                    value: _selectedFamilyId,
                                    decoration: const InputDecoration(
                                      labelText: 'Family / Sibling Group',
                                      helperText: 'Groups brothers & sisters under one parent account for combined accounting.',
                                    ),
                                    isExpanded: true,
                                    items: <DropdownMenuItem<int?>>[
                                      const DropdownMenuItem<int?>(value: null, child: Text('None (Individual Student)')),
                                      ...families.map((f) => DropdownMenuItem<int?>(
                                            value: f.id,
                                            child: Text('${f.familyCode} - ${f.guardianName} (${f.guardianPhone})'),
                                          )),
                                    ],
                                    onChanged: (val) => setState(() => _selectedFamilyId = val),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.group_add, size: 16),
                                    label: const Text('New Family'),
                                    onPressed: () async {
                                      final newFam = await showDialog<Family>(
                                        context: context,
                                        builder: (_) => const AddFamilyDialog(),
                                      );
                                      if (newFam != null) {
                                        setState(() {
                                          _selectedFamilyId = newFam.id;
                                          if (_guardianPhoneCtrl.text.isEmpty) {
                                            _guardianPhoneCtrl.text = newFam.guardianPhone;
                                          }
                                          if (_fatherNameCtrl.text.isEmpty) {
                                            _fatherNameCtrl.text = newFam.guardianName;
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    PrimaryButton(
                      label: isEditing ? 'Update Student Profile' : 'Register Student & Save Package',
                      isLoading: _isLoading,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.subCardBg(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderCol(context)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: AppColors.headingCol(context),
        ),
      ),
    );
  }
}
