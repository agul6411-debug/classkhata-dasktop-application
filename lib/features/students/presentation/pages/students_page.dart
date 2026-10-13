/// Students and Academics management page.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final _searchCtrl = TextEditingController();

  // Selection for bulk promotion
  final Set<int> _selectedStudentIds = {};
  int? _promotionTargetBatchId;

  // Selected class filter for Classes & Sections tab
  int? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Students & Academics',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: headingColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage student registrations, classes, sections, and academic sessions.',
                      style: TextStyle(color: textMutedColor, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
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
                    const SizedBox(width: 12),
                    PrimaryButton(
                      label: 'Register Student',
                      icon: Icons.person_add,
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const StudentFormDialog(),
                      ),
                    ),
                  ],
                ),
              ],
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
                  Tab(text: 'All Students'),
                  Tab(text: 'Classes & Sections'),
                  Tab(text: 'Promotions & Families'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab contents
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStudentsTab(),
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

  // ---------------------------------------------------------------------------
  // Tab 1: Students Directory
  // ---------------------------------------------------------------------------

  Widget _buildStudentsTab() {
    final studentsAsync = ref.watch(studentsListProvider);
    final academicDataAsync = ref.watch(academicDataProvider);
    final filterState = ref.watch(studentFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter bar
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    controller: _searchCtrl,
                    label: 'Search by name, roll no, or phone…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    onChanged: (val) => ref.read(studentFilterProvider.notifier).setQuery(val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: academicDataAsync.when(
                    data: (data) => DropdownButtonFormField<int?>(
                      initialValue: filterState.batchId,
                      decoration: const InputDecoration(labelText: 'Filter by Section'),
                      items: [
                        const DropdownMenuItem(child: Text('All Sections')),
                        ...data.batches.map((b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(data.getFullSectionName(b.id)),
                            )),
                      ],
                      onChanged: (val) => ref.read(studentFilterProvider.notifier).setBatchId(val),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<StudentStatus?>(
                    initialValue: filterState.status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(child: Text('All Statuses')),
                      DropdownMenuItem(value: StudentStatus.active, child: Text('Active')),
                      DropdownMenuItem(value: StudentStatus.inactive, child: Text('Inactive')),
                      DropdownMenuItem(value: StudentStatus.left, child: Text('Left')),
                    ],
                    onChanged: (val) => ref.read(studentFilterProvider.notifier).setStatus(val),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Students Table
        Expanded(
          child: Card(
            child: studentsAsync.when(
              data: (students) {
                if (students.isEmpty) {
                  return const Center(
                    child: Text('No students found.', style: TextStyle(color: AppColors.textMuted)),
                  );
                }

                final acadData = academicDataAsync.asData?.value;
                final batchesMap = acadData != null
                    ? {for (final b in acadData.batches) b.id: b}
                    : <int, Batch>{};

                return SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Roll No')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Guardian Phone')),
                      DataColumn(label: Text('Class & Section')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: students.map((student) {
                      final batch = batchesMap[student.batchId];
                      final sectionDisplay = acadData?.getFullSectionName(student.batchId) ??
                          (batch?.name ?? 'Section #${student.batchId}');
                      return DataRow(
                        cells: [
                          DataCell(Text(student.rollNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(student.name)),
                          DataCell(Text(student.guardianPhone)),
                          DataCell(Text(sectionDisplay)),
                          DataCell(
                            StatusBadge(
                              type: student.status == StudentStatus.active
                                  ? StatusBadgeType.active
                                  : StatusBadgeType.inactive,
                              label: student.status.name.toUpperCase(),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Print ID Card',
                                  icon: const Icon(Icons.badge_outlined, size: 18, color: AppColors.accent),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => StudentIdCardDialog(
                                      student: student,
                                      batchName: sectionDisplay,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Fee Reminder Card',
                                  icon: const Icon(Icons.credit_card, size: 18, color: AppColors.heading),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => StudentFeeCardDialog(
                                      student: student,
                                      batchName: sectionDisplay,
                                      monthlyFee: batch?.monthlyFee ?? const Money(0),
                                      dueDay: batch?.dueDay ?? 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.overdue))),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Batches & Courses Directory
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Tab 2: Classes & Sections Directory (School Hierarchy)
  // ---------------------------------------------------------------------------

  Widget _buildClassesAndSectionsTab() {
    final academicDataAsync = ref.watch(academicDataProvider);

    return academicDataAsync.when(
      data: (data) {
        final activeSession = data.currentSession;
        final selectedClass = _selectedClassId == null
            ? null
            : data.courses.where((c) => c.id == _selectedClassId).firstOrNull;
        final displayedSections = _selectedClassId == null
            ? data.batches
            : data.getSectionsForClass(_selectedClassId!);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top: Active Academic Session Banner
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.school, color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Academic Session: ${activeSession?.name ?? "No Active Session"}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.heading),
                              ),
                              if (activeSession != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.paidBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('ACTIVE', style: TextStyle(color: AppColors.paid, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeSession != null
                                ? 'Session Period: ${activeSession.startDate.day}/${activeSession.startDate.month}/${activeSession.startDate.year} - ${activeSession.endDate.day}/${activeSession.endDate.month}/${activeSession.endDate.year} • All student enrollments and fee schedules are bound to this session.'
                                : 'Please create or switch an active session to organize academic classes and sections.',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.history_edu, size: 15),
                      label: const Text('Manage Sessions'),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const ManageSessionsDialog(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PrimaryButton(
                      label: 'New Session',
                      icon: Icons.add,
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => const CreateSessionDialog(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Split View: Classes on Left, Sections on Right
            Expanded(
              child: Row(
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
  // Tab 3: Year-end Promotions & Families
  // ---------------------------------------------------------------------------

  Widget _buildPromotionsTab() {
    final studentsAsync = ref.watch(studentsListProvider);
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
                    'Select students and promote them into their new academic batch.',
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
                    child: studentsAsync.when(
                      data: (students) {
                        final acadData = academicDataAsync.asData?.value;
                        return ListView.builder(
                          itemCount: students.length,
                          itemBuilder: (context, idx) {
                            final s = students[idx];
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

        // Families
        Expanded(
          flex: 2,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Family / Sibling Groups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text(
                    'Linked families for unified sibling accounting.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: familiesAsync.when(
                      data: (families) => families.isEmpty
                          ? const Center(child: Text('No families linked yet.'))
                          : ListView.separated(
                              itemCount: families.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, idx) {
                                final f = families[idx];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.accent,
                                    child: Icon(Icons.group, color: Colors.white, size: 18),
                                  ),
                                  title: Text(f.guardianName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${f.familyCode} • ${f.guardianPhone}'),
                                );
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
