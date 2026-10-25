/// Comprehensive Student Admission & Academic Details Modal Dialog.
/// Displays complete student profile, father details, fee package, and quick actions.
/// Completely in English with responsive overflow-free layout.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../fees/presentation/widgets/fee_collection_wizard.dart';
import '../../domain/entities/student_entities.dart';
import '../providers/student_providers.dart';
import 'student_fee_card_dialog.dart';
import 'student_form_dialog.dart';
import 'student_id_card_dialog.dart';

class StudentDetailsDialog extends ConsumerWidget {
  const StudentDetailsDialog({
    super.key,
    required this.student,
    required this.sectionDisplay,
    required this.monthlyFee,
    required this.dueDay,
  });

  final Student student;
  final String sectionDisplay;
  final Money monthlyFee;
  final int dueDay;

  int _calculateAge(String? dobStr) {
    if (dobStr == null || dobStr.isEmpty) return 0;
    final dob = DateTime.tryParse(dobStr);
    if (dob == null) return 0;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age > 0 ? age : 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? AppColors.darkTextPrimary : AppColors.heading;
    final textMutedColor = isDark ? AppColors.darkTextSecondary : AppColors.textMuted;
    final subBg = isDark ? AppColors.darkCardSub : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    final profileAsync = ref.watch(studentProfileProvider(student.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Student Photo & Main Meta
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  profileAsync.when(
                    data: (profile) {
                      final photoPath = profile.photoPath;
                      final hasPhoto = photoPath != null &&
                          photoPath.isNotEmpty &&
                          File(photoPath).existsSync();
                      return CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.accent.withOpacity(0.15),
                        backgroundImage: hasPhoto ? FileImage(File(photoPath)) : null,
                        child: !hasPhoto
                            ? Text(
                                student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.accent),
                              )
                            : null,
                      );
                    },
                    loading: () => const CircleAvatar(radius: 36, child: CircularProgressIndicator()),
                    error: (_, __) => const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              student.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: headingColor,
                              ),
                            ),
                            StatusBadge(
                              type: student.status == StudentStatus.active
                                  ? StatusBadgeType.active
                                  : StatusBadgeType.inactive,
                              label: student.status == StudentStatus.active ? 'ACTIVE' : 'LEFT',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Roll No: ${student.rollNumber} • Class & Section: $sectionDisplay',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Admission Date: ${student.joiningDate.day}/${student.joiningDate.month}/${student.joiningDate.year}',
                          style: TextStyle(fontSize: 12, color: textMutedColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Scrollable Details Body
              Expanded(
                child: profileAsync.when(
                  data: (profile) {
                    final age = _calculateAge(profile.dob);
                    final effectiveMonthlyFee = (profile.customMonthlyFee != null && profile.customMonthlyFee! > 0)
                        ? Money.fromRupees(profile.customMonthlyFee!.toDouble())
                        : monthlyFee;
                    final discountPaisa = profile.monthlyDiscount * 100;
                    final netFeePaisa = effectiveMonthlyFee.paisa - discountPaisa;
                    final netFee = Money(netFeePaisa > 0 ? netFeePaisa : 0);

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Personal & Guardian Details
                          _sectionTitle('1. Personal & Guardian Details'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: subBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _infoItem('Father Name', profile.fatherName ?? 'Not Specified'),
                                    _infoItem('Father CNIC', profile.fatherCnic ?? 'N/A'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _infoItem('Father Occupation', profile.fatherOccupation ?? 'N/A'),
                                    _infoItem('Gender', profile.gender),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _infoItem(
                                      'DOB & Age',
                                      profile.dob != null && profile.dob!.isNotEmpty
                                          ? '${profile.dob} (${age > 0 ? "$age yrs" : ""})'
                                          : 'N/A',
                                    ),
                                    _infoItem('Blood Group', profile.bloodGroup ?? 'N/A'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _infoItem('Guardian Phone (WhatsApp)', student.guardianPhone),
                                    _infoItem('Student Phone / Email', student.phone ?? student.email ?? 'N/A'),
                                  ],
                                ),
                                if (profile.address != null && profile.address!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      _infoItem('Home Address', profile.address!),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. Fee Package & Financial Profile
                          _sectionTitle('2. Fee Package & Financial Profile'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: subBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _infoItem('Agreed Monthly Tuition Fee', effectiveMonthlyFee.format()),
                                    _infoItem(
                                      'Monthly Discount',
                                      profile.monthlyDiscount > 0
                                          ? 'Rs. ${profile.monthlyDiscount} (${profile.discountReason ?? "Discount"})'
                                          : 'Rs. 0 (No Discount)',
                                      color: profile.monthlyDiscount > 0 ? const Color(0xFF16A34A) : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _infoItem(
                                      'Net Monthly Fee',
                                      netFee.format(),
                                      isBold: true,
                                      color: AppColors.accent,
                                    ),
                                    _infoItem('Fee Due Day', 'Day $dueDay of each month'),
                                  ],
                                ),
                                if (profile.admissionFee > 0 || profile.openingArrears > 0) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      if (profile.admissionFee > 0)
                                        _infoItem('Admission Fee', 'Rs. ${profile.admissionFee}'),
                                      if (profile.openingArrears > 0)
                                        _infoItem('Opening Arrears', 'Rs. ${profile.openingArrears}', color: Colors.red),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading profile: $e')),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Actions (Responsive Wrap to prevent overflow)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Status Toggle Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: student.status == StudentStatus.active ? Colors.orange.shade800 : const Color(0xFF16A34A),
                      side: BorderSide(
                        color: student.status == StudentStatus.active ? Colors.orange.shade800 : const Color(0xFF16A34A),
                      ),
                    ),
                    icon: Icon(
                      student.status == StudentStatus.active ? Icons.person_off_outlined : Icons.check_circle_outline,
                      size: 16,
                    ),
                    label: Text(
                      student.status == StudentStatus.active ? 'Mark as Left' : 'Reactivate Student',
                    ),
                    onPressed: () async {
                      final isCurrentlyActive = student.status == StudentStatus.active;
                      final newStatus = isCurrentlyActive ? StudentStatus.left : StudentStatus.active;
                      final repo = ref.read(studentRepositoryProvider);
                      final res = await repo.updateStudentStatus(studentId: student.id, status: newStatus);
                      res.fold(
                        onSuccess: (_) {
                          ref.read(studentListVersionProvider.notifier).state++;
                          ref.invalidate(studentsListProvider);
                          ref.invalidate(allStudentsProvider);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isCurrentlyActive
                                  ? '${student.name} marked as Left.'
                                  : '${student.name} reactivated successfully.'),
                              backgroundColor: const Color(0xFF16A34A),
                            ),
                          );
                        },
                        onFailure: (f) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(f.message), backgroundColor: Colors.red),
                          );
                        },
                      );
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: const Text('Collect Fee'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          showDialog(
                            context: context,
                            builder: (_) => FeeCollectionWizard(initialStudent: student),
                          );
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.credit_card, size: 16),
                        label: const Text('Fee Card'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          showDialog(
                            context: context,
                            builder: (_) => StudentFeeCardDialog(
                              student: student,
                              batchName: sectionDisplay,
                              monthlyFee: monthlyFee,
                              dueDay: dueDay,
                            ),
                          );
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.badge_outlined, size: 16),
                        label: const Text('ID Card'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          showDialog(
                            context: context,
                            builder: (_) => StudentIdCardDialog(
                              student: student,
                              batchName: sectionDisplay,
                            ),
                          );
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Profile'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          showDialog(
                            context: context,
                            builder: (_) => StudentFormDialog(studentToEdit: student),
                          );
                        },
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent),
    );
  }

  Widget _infoItem(String label, String value, {bool isBold = false, Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.heading,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
