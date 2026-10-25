/// Students and Academics management page.
/// Provides Class-wise student records, complete admission history (Active/Left),
/// School Classes & Sections management, and Student Directory.
/// Fully in English with responsive overflow-proof layouts.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../../../app/theme/app_theme.dart';
import '../../../../core/money/money.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../academics/domain/entities/academic_entities.dart';
import '../../../academics/presentation/providers/academic_providers.dart';
import '../../../academics/presentation/widgets/academic_dialogs.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../domain/entities/student_entities.dart';
import '../providers/student_providers.dart';
import '../widgets/add_family_dialog.dart';
import '../widgets/student_details_dialog.dart';
import '../widgets/student_fee_card_dialog.dart';
import '../widgets/student_form_dialog.dart';
import '../widgets/student_id_card_dialog.dart';
import '../widgets/student_import_dialog.dart';

class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key});

  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<StudentsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Class-wise Tab State
  int? _selectedClassId;
  StudentStatus? _classWiseStatusFilter; // null = All, active, left
  int? _classWiseBatchFilter;
  final _classWiseSearchCtrl = TextEditingController();
  final _classSearchCtrl = TextEditingController();

  // All Students Tab State
  final _allSearchCtrl = TextEditingController();
  int? _allFilterClassId;
  int? _allFilterBatchId;
  StudentStatus? _allFilterStatus;

  // Selection for bulk promotion
  final Set<int> _selectedStudentIds = {};
  int? _promotionTargetBatchId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _classWiseSearchCtrl.dispose();
    _classSearchCtrl.dispose();
    _allSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleStudentStatus(Student student) async {
    final isCurrentlyActive = student.status == StudentStatus.active;
    final newStatus = isCurrentlyActive ? StudentStatus.left : StudentStatus.active;
    final title = isCurrentlyActive
        ? 'Mark Student as Left / Inactive?'
        : 'Reactivate Student as Active?';
    final message = isCurrentlyActive
        ? 'Are you sure you want to mark "${student.name}" (${student.rollNumber}) as Left? The student record will remain in this class history.'
        : 'Are you sure you want to reactivate "${student.name}" (${student.rollNumber})?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyActive ? Colors.orange.shade700 : const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isCurrentlyActive ? 'Mark as Left' : 'Reactivate'),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && mounted) {
      final repo = ref.read(studentRepositoryProvider);
      final res = await repo.updateStudentStatus(studentId: student.id, status: newStatus);
      if (!mounted) return;
      res.fold(
        onSuccess: (_) {
          ref.read(studentListVersionProvider.notifier).state++;
          ref.invalidate(studentsListProvider);
          ref.invalidate(allStudentsProvider);
          ref.invalidate(dashboardKpisProvider);
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
    }
  }

  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Student Record?'),
        content: Text('Are you sure you want to permanently delete ${student.name} (${student.rollNumber})? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && mounted) {
      final repo = ref.read(studentRepositoryProvider);
      final res = await repo.deleteStudent(student.id);
      if (!mounted) return;
      res.fold(
        onSuccess: (_) {
          ref.read(studentListVersionProvider.notifier).state++;
          ref.invalidate(studentsListProvider);
          ref.invalidate(allStudentsProvider);
          ref.invalidate(dashboardKpisProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student deleted successfully.'), backgroundColor: Color(0xFF16A34A)),
          );
        },
        onFailure: (f) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(f.message), backgroundColor: Colors.red),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? AppColors.darkTextPrimary : AppColors.heading;
    final textMutedColor = isDark ? AppColors.darkTextSecondary : AppColors.textMuted;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Responsive Wrap
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Students & Classes Management',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: headingColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Class-wise student directory, active and left records, and fee packages.',
                          style: TextStyle(color: textMutedColor, fontSize: 13),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Class'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.accent),
                            foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.accent,
                          ),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const CreateClassDialog(),
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.meeting_room, size: 16),
                          label: const Text('Add Section'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.accent),
                            foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.accent,
                          ),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => CreateSectionDialog(initialCourseId: _selectedClassId),
                          ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Bulk Import'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.accent),
                            foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.accent,
                          ),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const StudentImportDialog(),
                          ),
                        ),
                        PrimaryButton(
                          label: 'Register Student',
                          icon: Icons.person_add,
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => StudentFormDialog(
                              initialBatchId: _getInitialBatchIdForClass(_selectedClassId),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: isDark ? AppColors.accentLight : AppColors.accent,
                unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                indicatorColor: isDark ? AppColors.accentLight : AppColors.accent,
                indicatorWeight: 3,
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.class_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Class-wise Students', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_alt_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('All Students Directory'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.meeting_room_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Classes & Sections'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up, size: 18),
                        SizedBox(width: 8),
                        Text('Promotions & Families'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildClassWiseTab(),
                  _buildAllStudentsTab(),
                  _buildClassesAndSectionsTab(),
                  _buildPromotionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _getInitialBatchIdForClass(int? classId) {
    if (classId == null) return null;
    final acadData = ref.read(academicDataProvider).valueOrNull;
    if (acadData == null) return null;
    final secs = acadData.getSectionsForClass(classId);
    return secs.isNotEmpty ? secs.first.id : null;
  }

  // ---------------------------------------------------------------------------
  // TAB 1: CLASS-WISE STUDENTS DIRECTORY
  // ---------------------------------------------------------------------------

  Widget _buildClassWiseTab() {
    final academicDataAsync = ref.watch(academicDataProvider);
    final allStudentsAsync = ref.watch(allStudentsProvider);
    final profilesAsync = ref.watch(allStudentProfilesProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subCardBg = isDark ? AppColors.darkCardSub : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return academicDataAsync.when(
      data: (acadData) {
        final classes = acadData.courses;

        // Auto-select first class if none selected or if selected class was removed
        if (classes.isNotEmpty) {
          if (_selectedClassId == null || !classes.any((c) => c.id == _selectedClassId)) {
            _selectedClassId = classes.first.id;
          }
        } else {
          _selectedClassId = null;
        }

        return allStudentsAsync.when(
          data: (allStudents) {
            final profiles = profilesAsync.valueOrNull ?? {};

            // Map batchId -> Batch
            final batchesMap = {for (final b in acadData.batches) b.id: b};

            // Calculate student counts per class
            final Map<int, List<Student>> classStudentsMap = {};
            for (final c in classes) {
              classStudentsMap[c.id] = [];
            }
            for (final s in allStudents) {
              final b = batchesMap[s.batchId];
              if (b != null && classStudentsMap.containsKey(b.courseId)) {
                classStudentsMap[b.courseId]!.add(s);
              }
            }

            final selectedClass = _selectedClassId != null
                ? classes.where((c) => c.id == _selectedClassId).firstOrNull
                : null;
            final selectedClassSections = _selectedClassId != null
                ? acadData.getSectionsForClass(_selectedClassId!)
                : <Batch>[];
            final selectedClassAllStudents = _selectedClassId != null
                ? (classStudentsMap[_selectedClassId!] ?? [])
                : <Student>[];

            // Counts for selected class
            final activeCount = selectedClassAllStudents.where((s) => s.status == StudentStatus.active).length;
            final leftCount = selectedClassAllStudents.where((s) => s.status == StudentStatus.left).length;

            // Filter students based on status, batch, and search query
            var displayedStudents = selectedClassAllStudents;

            if (_classWiseStatusFilter != null) {
              displayedStudents = displayedStudents
                  .where((s) => s.status == _classWiseStatusFilter)
                  .toList();
            }

            if (_classWiseBatchFilter != null) {
              displayedStudents = displayedStudents
                  .where((s) => s.batchId == _classWiseBatchFilter)
                  .toList();
            }

            final query = _classWiseSearchCtrl.text.trim().toLowerCase();
            if (query.isNotEmpty) {
              displayedStudents = displayedStudents.where((s) {
                final prof = profiles[s.id];
                final fatherName = prof?.fatherName?.toLowerCase() ?? '';
                final roll = s.rollNumber.toLowerCase();
                final name = s.name.toLowerCase();
                final phone = s.guardianPhone.toLowerCase();
                return roll.contains(query) ||
                    name.contains(query) ||
                    fatherName.contains(query) ||
                    phone.contains(query);
              }).toList();
            }

            displayedStudents.sort((a, b) {
              final aNum = int.tryParse(a.rollNumber.trim());
              final bNum = int.tryParse(b.rollNumber.trim());
              if (aNum != null && bNum != null) {
                return aNum.compareTo(bNum);
              }
              if (aNum != null) return -1;
              if (bNum != null) return 1;
              return a.rollNumber.compareTo(b.rollNumber);
            });

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT PANE: School Classes Directory
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'School Classes',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'Select a class to view records',
                                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                              IconButton(
                                tooltip: 'Add Class',
                                icon: const Icon(Icons.add_circle, color: AppColors.accent),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => const CreateClassDialog(),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          AppTextField(
                            controller: _classSearchCtrl,
                            label: 'Search Classes',
                            hint: 'Search class...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: classes.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.school_outlined, size: 40, color: AppColors.textMuted),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'No classes created yet.',
                                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.accent,
                                            foregroundColor: Colors.white,
                                          ),
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text('Add First Class'),
                                          onPressed: () => showDialog(
                                            context: context,
                                            builder: (_) => const CreateClassDialog(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: classes.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                                    itemBuilder: (context, idx) {
                                      final c = classes[idx];
                                      final q = _classSearchCtrl.text.trim().toLowerCase();
                                      if (q.isNotEmpty && !c.name.toLowerCase().contains(q) && !(c.code?.toLowerCase().contains(q) ?? false)) {
                                        return const SizedBox.shrink();
                                      }
                                      final isSelected = _selectedClassId == c.id;
                                      final students = classStudentsMap[c.id] ?? [];
                                      final actCount = students.where((s) => s.status == StudentStatus.active).length;
                                      final lCount = students.where((s) => s.status == StudentStatus.left).length;

                                      return InkWell(
                                        onTap: () => setState(() {
                                          _selectedClassId = c.id;
                                          _classWiseBatchFilter = null; // reset section filter when class changes
                                        }),
                                        borderRadius: BorderRadius.circular(10),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.accent.withOpacity(0.12) : subCardBg,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSelected ? AppColors.accent : borderColor,
                                              width: isSelected ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: isSelected ? AppColors.accent : borderColor,
                                                child: Text(
                                                  c.code ?? (c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C'),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSelected ? Colors.white : AppColors.heading,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      c.name,
                                                      style: TextStyle(
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                        fontSize: 14,
                                                        color: isSelected ? AppColors.accent : AppColors.heading,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: Colors.green.withOpacity(0.12),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            '$actCount Active',
                                                            style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                        if (lCount > 0) ...[
                                                          const SizedBox(width: 6),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                            decoration: BoxDecoration(
                                                              color: Colors.orange.withOpacity(0.12),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              '$lCount Left',
                                                              style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isSelected ? AppColors.accent : Colors.grey.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${students.length}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSelected ? Colors.white : AppColors.heading,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // RIGHT PANE: Selected Class Students Record
                Expanded(
                  flex: 7,
                  child: selectedClass == null
                      ? const Card(
                          child: Center(
                            child: Text('Please select a class from the left or create a new class.'),
                          ),
                        )
                      : Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Class Header & KPI Bar: Overflow-proof Layout
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkCardSub : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 12,
                                        runSpacing: 10,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: AppColors.accent.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.school, color: AppColors.accent, size: 26),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        selectedClass.name,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 17,
                                                          color: AppColors.heading,
                                                        ),
                                                      ),
                                                      if (selectedClass.code != null) ...[
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.accent.withOpacity(0.15),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            selectedClass.code!,
                                                            style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Wrap(
                                                    spacing: 10,
                                                    children: [
                                                      Text(
                                                        'Total: ${selectedClassAllStudents.length}',
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.heading),
                                                      ),
                                                      Text(
                                                        'Active: $activeCount',
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                                                      ),
                                                      Text(
                                                        'Left: $leftCount',
                                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade800),
                                                      ),
                                                      Text(
                                                        'Sections: ${selectedClassSections.length}',
                                                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              OutlinedButton.icon(
                                                icon: const Icon(Icons.add, size: 15),
                                                label: const Text('Add Section'),
                                                onPressed: () => showDialog(
                                                  context: context,
                                                  builder: (_) => CreateSectionDialog(initialCourseId: selectedClass.id),
                                                ),
                                              ),
                                              PrimaryButton(
                                                label: 'Register Student',
                                                icon: Icons.person_add,
                                                onPressed: () => showDialog(
                                                  context: context,
                                                  builder: (_) => StudentFormDialog(
                                                    initialBatchId: selectedClassSections.isNotEmpty ? selectedClassSections.first.id : null,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Controls Bar: Search, Status Filter, Section Filter (Responsive Wrap)
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 12,
                                      runSpacing: 10,
                                      children: [
                                        SizedBox(
                                          width: constraints.maxWidth > 500 ? 300 : constraints.maxWidth,
                                          child: AppTextField(
                                            controller: _classWiseSearchCtrl,
                                            label: 'Search Students',
                                            hint: 'Roll no, name, father, phone...',
                                            prefixIcon: const Icon(Icons.search, size: 18),
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 10,
                                          runSpacing: 8,
                                          children: [
                                            // Status Segmented Controls
                                            Container(
                                              decoration: BoxDecoration(
                                                color: subCardBg,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: borderColor),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _statusFilterChip(null, 'All (${selectedClassAllStudents.length})'),
                                                  _statusFilterChip(StudentStatus.active, 'Active ($activeCount)'),
                                                  _statusFilterChip(StudentStatus.left, 'Left ($leftCount)'),
                                                ],
                                              ),
                                            ),
                                            if (selectedClassSections.length > 1)
                                              DropdownButton<int?>(
                                                value: _classWiseBatchFilter,
                                                hint: const Text('All Sections'),
                                                underline: const SizedBox.shrink(),
                                                items: [
                                                  const DropdownMenuItem(value: null, child: Text('All Sections')),
                                                  ...selectedClassSections.map((b) => DropdownMenuItem(
                                                        value: b.id,
                                                        child: Text(b.name),
                                                      )),
                                                ],
                                                onChanged: (val) => setState(() => _classWiseBatchFilter = val),
                                              ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Student Records Roster Table (Both Horizontal & Vertical Scroll to prevent any overflow)
                                Expanded(
                                  child: displayedStudents.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.person_search_outlined, size: 48, color: AppColors.textMuted),
                                              const SizedBox(height: 8),
                                              Text(
                                                _classWiseStatusFilter == StudentStatus.left
                                                    ? 'No past (left) students found in this class.'
                                                    : 'No students found in this class.',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                selectedClassSections.isEmpty
                                                    ? 'Please create at least one section before enrolling students.'
                                                    : 'Click "Register Student" above to enroll students.',
                                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Scrollbar(
                                          thumbVisibility: true,
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.vertical,
                                              child: DataTable(
                                                headingRowHeight: 40,
                                                dataRowMinHeight: 50,
                                                dataRowMaxHeight: 56,
                                                columns: const [
                                                  DataColumn(label: Text('Roll No')),
                                                  DataColumn(label: Text('Student Name')),
                                                  DataColumn(label: Text('Father Name')),
                                                  DataColumn(label: Text('Section')),
                                                  DataColumn(label: Text('Phone (WhatsApp)')),
                                                  DataColumn(label: Text('Fee Package')),
                                                  DataColumn(label: Text('Status')),
                                                  DataColumn(label: Text('Actions')),
                                                ],
                                                rows: displayedStudents.map((student) {
                                                  final batch = batchesMap[student.batchId];
                                                  final sectionDisplay = acadData.getFullSectionName(student.batchId);
                                                  final profile = profiles[student.id];
                                                  final fatherName = profile?.fatherName ?? 'Not Specified';
                                                  final discount = profile?.monthlyDiscount ?? 0;
                                                  final baseFee = (profile?.customMonthlyFee != null && profile!.customMonthlyFee! > 0)
                                                      ? Money.fromRupees(profile.customMonthlyFee!.toDouble())
                                                      : (batch?.monthlyFee ?? const Money(0));
                                                  final netFee = Money(baseFee.paisa - (discount * 100) > 0 ? baseFee.paisa - (discount * 100) : 0);

                                                  final photoPath = profile?.photoPath;
                                                  final hasPhoto = photoPath != null &&
                                                      photoPath.isNotEmpty &&
                                                      File(photoPath).existsSync();

                                                  return DataRow(
                                                    cells: [
                                                      DataCell(
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.accent.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            student.rollNumber,
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.accent),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        InkWell(
                                                          onTap: () => showDialog(
                                                            context: context,
                                                            builder: (_) => StudentDetailsDialog(
                                                              student: student,
                                                              sectionDisplay: sectionDisplay,
                                                              monthlyFee: baseFee,
                                                              dueDay: batch?.dueDay ?? 10,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              CircleAvatar(
                                                                radius: 14,
                                                                backgroundColor: AppColors.accent.withOpacity(0.15),
                                                                backgroundImage: hasPhoto ? FileImage(File(photoPath)) : null,
                                                                child: !hasPhoto
                                                                    ? Text(
                                                                        student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                                                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent),
                                                                      )
                                                                    : null,
                                                              ),
                                                              const SizedBox(width: 8),
                                                              Column(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    student.name,
                                                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                                  ),
                                                                  Text(
                                                                    'Adm: ${student.joiningDate.day}/${student.joiningDate.month}/${student.joiningDate.year}',
                                                                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Text(fatherName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                                      ),
                                                      DataCell(Text(batch?.name ?? 'Sec #${student.batchId}')),
                                                      DataCell(Text(student.guardianPhone, style: const TextStyle(fontSize: 12))),
                                                      DataCell(
                                                        Column(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              netFee.format(),
                                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.accent),
                                                            ),
                                                            if (discount > 0)
                                                              Text(
                                                                'Rs. $discount off',
                                                                style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      DataCell(
                                                        StatusBadge(
                                                          type: student.status == StudentStatus.active
                                                              ? StatusBadgeType.active
                                                              : StatusBadgeType.inactive,
                                                          label: student.status == StudentStatus.active
                                                              ? 'ACTIVE'
                                                              : 'LEFT',
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              tooltip: 'View Profile',
                                                              icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.accent),
                                                              splashRadius: 14,
                                                              padding: const EdgeInsets.all(4),
                                                              constraints: const BoxConstraints(),
                                                              onPressed: () => showDialog(
                                                                context: context,
                                                                builder: (_) => StudentDetailsDialog(
                                                                  student: student,
                                                                  sectionDisplay: sectionDisplay,
                                                                  monthlyFee: baseFee,
                                                                  dueDay: batch?.dueDay ?? 10,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            IconButton(
                                                              tooltip: 'Edit Profile',
                                                              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                                              splashRadius: 14,
                                                              padding: const EdgeInsets.all(4),
                                                              constraints: const BoxConstraints(),
                                                              onPressed: () => showDialog(
                                                                context: context,
                                                                builder: (_) => StudentFormDialog(studentToEdit: student),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            IconButton(
                                                              tooltip: 'Student ID Card',
                                                              icon: const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF0D9488)),
                                                              splashRadius: 14,
                                                              padding: const EdgeInsets.all(4),
                                                              constraints: const BoxConstraints(),
                                                              onPressed: () => showDialog(
                                                                context: context,
                                                                builder: (_) => StudentIdCardDialog(
                                                                  student: student,
                                                                  batchName: sectionDisplay,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            IconButton(
                                                              tooltip: 'Fee Reminder Card',
                                                              icon: const Icon(Icons.credit_card, size: 18, color: AppColors.heading),
                                                              splashRadius: 14,
                                                              padding: const EdgeInsets.all(4),
                                                              constraints: const BoxConstraints(),
                                                              onPressed: () => showDialog(
                                                                context: context,
                                                                builder: (_) => StudentFeeCardDialog(
                                                                  student: student,
                                                                  batchName: sectionDisplay,
                                                                  monthlyFee: baseFee,
                                                                  dueDay: batch?.dueDay ?? 10,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            IconButton(
                                                              tooltip: student.status == StudentStatus.active
                                                                  ? 'Mark as Left'
                                                                  : 'Reactivate Student',
                                                              icon: Icon(
                                                                student.status == StudentStatus.active
                                                                    ? Icons.person_off_outlined
                                                                    : Icons.person_add_alt_1,
                                                                size: 18,
                                                                color: student.status == StudentStatus.active
                                                                    ? Colors.orange.shade800
                                                                    : const Color(0xFF16A34A),
                                                              ),
                                                              splashRadius: 14,
                                                              padding: const EdgeInsets.all(4),
                                                              constraints: const BoxConstraints(),
                                                              onPressed: () => _toggleStudentStatus(student),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            IconButton(
                                                              tooltip: 'Delete Student',
                                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                              splashRadius: 14,
                                                              padding: const EdgeInsets.all(4),
                                                              constraints: const BoxConstraints(),
                                                              onPressed: () => _deleteStudent(student),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading students: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading academics: $e')),
    );
  }

  Widget _statusFilterChip(StudentStatus? status, String label) {
    final isSelected = _classWiseStatusFilter == status;
    return InkWell(
      onTap: () => setState(() => _classWiseStatusFilter = status),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.heading,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: ALL STUDENTS DIRECTORY
  // ---------------------------------------------------------------------------

  Widget _buildAllStudentsTab() {
    final allStudentsAsync = ref.watch(allStudentsProvider);
    final academicDataAsync = ref.watch(academicDataProvider);
    final profilesAsync = ref.watch(allStudentProfilesProvider);

    return academicDataAsync.when(
      data: (acadData) {
        final batchesMap = {for (final b in acadData.batches) b.id: b};

        return allStudentsAsync.when(
          data: (allStudents) {
            final profiles = profilesAsync.valueOrNull ?? {};

            // Filter
            var filtered = allStudents;
            final query = _allSearchCtrl.text.trim().toLowerCase();
            if (query.isNotEmpty) {
              filtered = filtered.where((s) {
                final prof = profiles[s.id];
                final fatherName = prof?.fatherName?.toLowerCase() ?? '';
                final roll = s.rollNumber.toLowerCase();
                final name = s.name.toLowerCase();
                final phone = s.guardianPhone.toLowerCase();
                return roll.contains(query) ||
                    name.contains(query) ||
                    fatherName.contains(query) ||
                    phone.contains(query);
              }).toList();
            }

            if (_allFilterClassId != null) {
              final classBatchIds = acadData.getSectionsForClass(_allFilterClassId!).map((b) => b.id).toSet();
              filtered = filtered.where((s) => classBatchIds.contains(s.batchId)).toList();
            }

            if (_allFilterBatchId != null) {
              filtered = filtered.where((s) => s.batchId == _allFilterBatchId).toList();
            }

            if (_allFilterStatus != null) {
              filtered = filtered.where((s) => s.status == _allFilterStatus).toList();
            }

            // Natural numeric sequence sort by roll number
            filtered.sort((a, b) {
              final aNum = int.tryParse(a.rollNumber.trim());
              final bNum = int.tryParse(b.rollNumber.trim());
              if (aNum != null && bNum != null) {
                return aNum.compareTo(bNum);
              }
              if (aNum != null) return -1;
              if (bNum != null) return 1;
              return a.rollNumber.compareTo(b.rollNumber);
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filter bar: Responsive Wrap
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: constraints.maxWidth > 700 ? 280 : constraints.maxWidth,
                              child: AppTextField(
                                controller: _allSearchCtrl,
                                label: 'Search All Students',
                                hint: 'Name, roll no, father, phone…',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            SizedBox(
                              width: 170,
                              child: DropdownButtonFormField<int?>(
                                initialValue: _allFilterClassId,
                                decoration: const InputDecoration(labelText: 'Class'),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('All Classes')),
                                  ...acadData.courses.map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                                      )),
                                ],
                                onChanged: (val) => setState(() {
                                  _allFilterClassId = val;
                                  _allFilterBatchId = null;
                                }),
                              ),
                            ),
                            SizedBox(
                              width: 170,
                              child: DropdownButtonFormField<int?>(
                                initialValue: _allFilterBatchId,
                                decoration: const InputDecoration(labelText: 'Section'),
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('All Sections')),
                                  ...(_allFilterClassId != null
                                          ? acadData.getSectionsForClass(_allFilterClassId!)
                                          : acadData.batches)
                                      .map((b) => DropdownMenuItem(
                                            value: b.id,
                                            child: Text(acadData.getFullSectionName(b.id), overflow: TextOverflow.ellipsis),
                                          )),
                                ],
                                onChanged: (val) => setState(() => _allFilterBatchId = val),
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: DropdownButtonFormField<StudentStatus?>(
                                initialValue: _allFilterStatus,
                                decoration: const InputDecoration(labelText: 'Status'),
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: null, child: Text('All Statuses')),
                                  DropdownMenuItem(value: StudentStatus.active, child: Text('Active')),
                                  DropdownMenuItem(value: StudentStatus.left, child: Text('Left')),
                                ],
                                onChanged: (val) => setState(() => _allFilterStatus = val),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Table: Both Horizontal and Vertical Scroll
                Expanded(
                  child: Card(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No students found matching your filters.', style: TextStyle(color: AppColors.textMuted)),
                          )
                        : Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: DataTable(
                                  headingRowHeight: 40,
                                  dataRowMinHeight: 50,
                                  dataRowMaxHeight: 56,
                                  columns: const [
                                    DataColumn(label: Text('Roll No')),
                                    DataColumn(label: Text('Student Name')),
                                    DataColumn(label: Text('Father Name')),
                                    DataColumn(label: Text('Class & Section')),
                                    DataColumn(label: Text('Guardian Phone')),
                                    DataColumn(label: Text('Fee Package')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: filtered.map((student) {
                                    final batch = batchesMap[student.batchId];
                                    final sectionDisplay = acadData.getFullSectionName(student.batchId);
                                    final profile = profiles[student.id];
                                    final fatherName = profile?.fatherName ?? 'Not Specified';
                                    final discount = profile?.monthlyDiscount ?? 0;
                                    final baseFee = (profile?.customMonthlyFee != null && profile!.customMonthlyFee! > 0)
                                        ? Money.fromRupees(profile.customMonthlyFee!.toDouble())
                                        : (batch?.monthlyFee ?? const Money(0));
                                    final netFee = Money(baseFee.paisa - (discount * 100) > 0 ? baseFee.paisa - (discount * 100) : 0);

                                    final photoPath = profile?.photoPath;
                                    final hasPhoto = photoPath != null &&
                                        photoPath.isNotEmpty &&
                                        File(photoPath).existsSync();

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(student.rollNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        DataCell(
                                          InkWell(
                                            onTap: () => showDialog(
                                              context: context,
                                              builder: (_) => StudentDetailsDialog(
                                                student: student,
                                                sectionDisplay: sectionDisplay,
                                                monthlyFee: baseFee,
                                                dueDay: batch?.dueDay ?? 10,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: AppColors.accent.withOpacity(0.15),
                                                  backgroundImage: hasPhoto ? FileImage(File(photoPath)) : null,
                                                  child: !hasPhoto
                                                      ? Text(
                                                          student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent),
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        DataCell(Text(fatherName)),
                                        DataCell(Text(sectionDisplay)),
                                        DataCell(Text(student.guardianPhone)),
                                        DataCell(
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(netFee.format(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.accent)),
                                              if (discount > 0)
                                                Text('Rs. $discount off', style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A))),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          StatusBadge(
                                            type: student.status == StudentStatus.active ? StatusBadgeType.active : StatusBadgeType.inactive,
                                            label: student.status == StudentStatus.active ? 'ACTIVE' : 'LEFT',
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'View Profile',
                                                icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.accent),
                                                splashRadius: 14,
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                onPressed: () => showDialog(
                                                  context: context,
                                                  builder: (_) => StudentDetailsDialog(
                                                    student: student,
                                                    sectionDisplay: sectionDisplay,
                                                    monthlyFee: baseFee,
                                                    dueDay: batch?.dueDay ?? 10,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                tooltip: 'Edit Profile',
                                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                                splashRadius: 14,
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                onPressed: () => showDialog(
                                                  context: context,
                                                  builder: (_) => StudentFormDialog(studentToEdit: student),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                tooltip: 'Student ID Card',
                                                icon: const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF0D9488)),
                                                splashRadius: 14,
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                onPressed: () => showDialog(
                                                  context: context,
                                                  builder: (_) => StudentIdCardDialog(
                                                    student: student,
                                                    batchName: sectionDisplay,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                tooltip: 'Fee Reminder Card',
                                                icon: const Icon(Icons.credit_card, size: 18, color: AppColors.heading),
                                                splashRadius: 14,
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                onPressed: () => showDialog(
                                                  context: context,
                                                  builder: (_) => StudentFeeCardDialog(
                                                    student: student,
                                                    batchName: sectionDisplay,
                                                    monthlyFee: baseFee,
                                                    dueDay: batch?.dueDay ?? 10,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                tooltip: student.status == StudentStatus.active ? 'Mark as Left' : 'Reactivate Student',
                                                icon: Icon(
                                                  student.status == StudentStatus.active ? Icons.person_off_outlined : Icons.person_add_alt_1,
                                                  size: 18,
                                                  color: student.status == StudentStatus.active ? Colors.orange.shade800 : const Color(0xFF16A34A),
                                                ),
                                                splashRadius: 14,
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _toggleStudentStatus(student),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                tooltip: 'Delete Student',
                                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                splashRadius: 14,
                                                padding: const EdgeInsets.all(4),
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _deleteStudent(student),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading students: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading academics: $e')),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: CLASSES & SECTIONS (NO SESSION OVERHEAD)
  // ---------------------------------------------------------------------------

  Widget _buildClassesAndSectionsTab() {
    final academicDataAsync = ref.watch(academicDataProvider);

    return academicDataAsync.when(
      data: (data) {
        final selectedClass = _selectedClassId == null
            ? null
            : data.courses.where((c) => c.id == _selectedClassId).firstOrNull;
        final displayedSections = _selectedClassId == null
            ? data.batches
            : data.getSectionsForClass(_selectedClassId!);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: School Classes / Grades
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('School Classes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          PrimaryButton(
                            label: 'Add Class',
                            icon: Icons.add,
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => const CreateClassDialog(),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      // All Classes option
                      InkWell(
                        onTap: () => setState(() => _selectedClassId = null),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedClassId == null ? AppColors.accent.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _selectedClassId == null ? AppColors.accent : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.layers, size: 16, color: _selectedClassId == null ? AppColors.accent : AppColors.textMuted),
                                  const SizedBox(width: 8),
                                  Text(
                                    'All Classes',
                                    style: TextStyle(
                                      fontWeight: _selectedClassId == null ? FontWeight.bold : FontWeight.w500,
                                      color: _selectedClassId == null ? AppColors.accent : AppColors.heading,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${data.courses.length} total',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: data.courses.isEmpty
                            ? const Center(
                                child: Text(
                                  'No classes created yet.\nClick "Add Class" to start.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              )
                            : ListView.separated(
                                itemCount: data.courses.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 4),
                                itemBuilder: (context, idx) {
                                  final c = data.courses[idx];
                                  final isSelected = _selectedClassId == c.id;
                                  final secCount = data.getSectionsForClass(c.id).length;
                                  return InkWell(
                                    onTap: () => setState(() {
                                      _selectedClassId = isSelected ? null : c.id;
                                    }),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.accent.withOpacity(0.12) : AppColors.inputFill,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected ? AppColors.accent : Colors.transparent,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: isSelected ? AppColors.accent : AppColors.border,
                                            child: Text(
                                              c.code ?? (c.name.isNotEmpty ? c.name[0] : 'C'),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? Colors.white : AppColors.heading,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  c.name,
                                                  style: TextStyle(
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                    color: AppColors.heading,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                if (c.code != null)
                                                  Text('Code: ${c.code}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.subCardBg(context),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppColors.borderCol(context)),
                                            ),
                                            child: Text(
                                              '$secCount sec',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Right: Class Sections
            Expanded(
              flex: 3,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedClass != null
                                ? '${selectedClass.name} Sections (${displayedSections.length})'
                                : 'All Class Sections (${displayedSections.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          PrimaryButton(
                            label: 'Add Section',
                            icon: Icons.add,
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => CreateSectionDialog(initialCourseId: _selectedClassId),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: displayedSections.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.meeting_room_outlined, size: 40, color: AppColors.textMuted),
                                    const SizedBox(height: 8),
                                    Text(
                                      selectedClass != null
                                          ? 'No sections created for ${selectedClass.name} yet.'
                                          : 'No class sections created yet.',
                                      style: const TextStyle(color: AppColors.textMuted),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Add Section Now'),
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (_) => CreateSectionDialog(initialCourseId: _selectedClassId),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: displayedSections.length,
                                itemBuilder: (context, idx) {
                                  final b = displayedSections[idx];
                                  return Card(
                                    color: AppColors.inputFill,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: AppColors.accent.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.meeting_room, color: AppColors.accent, size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  data.getFullSectionName(b.id),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.heading),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.person, size: 13, color: AppColors.textMuted),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'Teacher: ${b.classTeacher ?? "Not Assigned"}',
                                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    const Icon(Icons.room, size: 13, color: AppColors.textMuted),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'Room: ${b.roomOrTiming ?? "N/A"}',
                                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                b.monthlyFee.format(),
                                                style: const TextStyle(
                                                  color: AppColors.accent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text('Due: Day ${b.dueDay}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  OutlinedButton.icon(
                                                    style: OutlinedButton.styleFrom(
                                                      visualDensity: VisualDensity.compact,
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    ),
                                                    icon: const Icon(Icons.person_add, size: 13),
                                                    label: const Text('Enroll', style: TextStyle(fontSize: 11)),
                                                    onPressed: () => showDialog(
                                                      context: context,
                                                      builder: (_) => StudentFormDialog(initialBatchId: b.id),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                    tooltip: 'Delete Section',
                                                    splashRadius: 16,
                                                    onPressed: () async {
                                                      final confirmed = await showDialog<bool>(
                                                        context: context,
                                                        builder: (ctx) => AlertDialog(
                                                          title: const Text('Delete Section?'),
                                                          content: Text('Are you sure you want to delete "${b.name}"?'),
                                                          actions: [
                                                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                                            ElevatedButton(
                                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                              onPressed: () => Navigator.of(ctx).pop(true),
                                                              child: const Text('Delete'),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if ((confirmed ?? false) && context.mounted) {
                                                        final useCase = ref.read(deleteBatchUseCaseProvider);
                                                        final res = await useCase(b.id);
                                                        if (!context.mounted) return;
                                                        res.fold(
                                                          onSuccess: (_) {
                                                            ref.invalidate(academicDataProvider);
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(content: Text('Section deleted.'), backgroundColor: Color(0xFF16A34A)),
                                                            );
                                                          },
                                                          onFailure: (f) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text(f.message), backgroundColor: Colors.red),
                                                            );
                                                          },
                                                        );
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading academics: $e')),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: YEAR-END PROMOTIONS & FAMILIES
  // ---------------------------------------------------------------------------

  Widget _buildPromotionsTab() {
    final allStudentsAsync = ref.watch(allStudentsProvider);
    final academicDataAsync = ref.watch(academicDataProvider);
    final familiesAsync = ref.watch(familiesListProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Year-end Student Promotion
        Expanded(
          flex: 3,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Year-End Student Promotion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text(
                    'Select students and promote them into their next class and section.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const Divider(height: 20),
                  academicDataAsync.when(
                    data: (data) => Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _promotionTargetBatchId,
                            decoration: const InputDecoration(labelText: 'Target Next Class & Section *'),
                            items: data.batches
                                .map((b) => DropdownMenuItem(value: b.id, child: Text(data.getFullSectionName(b.id))))
                                .toList(),
                            onChanged: (val) => setState(() => _promotionTargetBatchId = val),
                          ),
                        ),
                        const SizedBox(width: 12),
                        PrimaryButton(
                          label: 'Promote Selected (${_selectedStudentIds.length})',
                          icon: Icons.trending_up,
                          onPressed: _selectedStudentIds.isEmpty || _promotionTargetBatchId == null
                              ? null
                              : () async {
                                  final useCase = ref.read(promoteStudentsUseCaseProvider);
                                  final res = await useCase(
                                    studentIds: _selectedStudentIds.toList(),
                                    targetBatchId: _promotionTargetBatchId!,
                                  );
                                  if (!mounted) return;
                                  res.fold(
                                    onSuccess: (count) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Successfully promoted $count student(s)!')),
                                      );
                                      setState(() => _selectedStudentIds.clear());
                                      ref.read(studentListVersionProvider.notifier).state++;
                                      ref.invalidate(studentsListProvider);
                                      ref.invalidate(allStudentsProvider);
                                      ref.invalidate(dashboardKpisProvider);
                                    },
                                    onFailure: (f) => ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(f.message)),
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: allStudentsAsync.when(
                      data: (students) {
                        final acadData = academicDataAsync.asData?.value;
                        final activeStudents = students.where((s) => s.status == StudentStatus.active).toList();
                        return ListView.builder(
                          itemCount: activeStudents.length,
                          itemBuilder: (context, idx) {
                            final s = activeStudents[idx];
                            final isSelected = _selectedStudentIds.contains(s.id);
                            final sectionName = acadData?.getFullSectionName(s.batchId) ?? 'Section #${s.batchId}';
                            return CheckboxListTile(
                              value: isSelected,
                              title: Text('${s.rollNumber} - ${s.name}'),
                              subtitle: Text('Current: $sectionName • Guardian: ${s.guardianPhone}'),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked ?? false) {
                                    _selectedStudentIds.add(s.id);
                                  } else {
                                    _selectedStudentIds.remove(s.id);
                                  }
                                });
                              },
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Families / Siblings
        Expanded(
          flex: 2,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Family / Sibling Groups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 2),
                          Text(
                            'Linked families for unified sibling accounting.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.group_add, size: 16),
                        label: const Text('Add Family'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const AddFamilyDialog(),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: familiesAsync.when(
                      data: (families) => families.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.family_restroom, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text('No families linked yet.', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Click "Add Family" above to register a guardian and link siblings.',
                                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: families.length,
                              itemBuilder: (context, idx) {
                                final f = families[idx];
                                return _FamilyCardItem(family: f);
                              },
                            ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FamilyCardItem extends ConsumerWidget {
  const _FamilyCardItem({
    required this.family,
  });

  final Family family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final siblingsAsync = ref.watch(familyStudentsProvider(family.id));
    final acadData = ref.watch(academicDataProvider).valueOrNull;
    final batchesMap = acadData != null
        ? {for (final b in acadData.batches) b.id: b}
        : <int, Batch>{};
    final coursesMap = acadData != null
        ? {for (final c in acadData.courses) c.id: c}
        : <int, Course>{};

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
      ),
      color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row: Avatar, Guardian Name, Family Code, + Add Sibling
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.accent.withOpacity(0.15),
                  child: const Icon(Icons.family_restroom, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            family.guardianName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              family.familyCode,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            family.guardianPhone,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          if (family.address != null && family.address!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.location_on, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                family.address!,
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1, size: 14),
                  label: const Text('Add Sibling', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => StudentFormDialog(initialFamilyId: family.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Sibling Students List
            siblingsAsync.when(
              data: (siblings) {
                if (siblings.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 15, color: AppColors.textMuted),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No siblings registered in this family yet. Click "Add Sibling" to enroll a child.',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: siblings.map((sibling) {
                    final batch = batchesMap[sibling.batchId];
                    final course = batch != null ? coursesMap[batch.courseId] : null;
                    final sectionName = course != null
                        ? '${course.name} (${batch?.name ?? ""})'
                        : (batch?.name ?? 'Section #${sibling.batchId}');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBackground : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: AppColors.accent.withOpacity(0.1),
                            child: Text(
                              sibling.name.isNotEmpty ? sibling.name[0].toUpperCase() : 'S',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sibling.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  'Roll: ${sibling.rollNumber} • Class: $sectionName',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            type: sibling.status == StudentStatus.active ? StatusBadgeType.active : StatusBadgeType.inactive,
                            label: sibling.status.name.toUpperCase(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading siblings: $e', style: const TextStyle(fontSize: 12, color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}
