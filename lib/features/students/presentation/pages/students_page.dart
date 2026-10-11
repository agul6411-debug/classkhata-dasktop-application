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
    return Scaffold(
      backgroundColor: AppColors.background,
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
                    const Text(
                      'Students & Academics',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage registrations, batches, courses, and family links.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Bulk Import'),
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
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.accent,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'All Students'),
                  Tab(text: 'Batches & Courses'),
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
                  _buildBatchesTab(),
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
                      value: filterState.batchId,
                      decoration: const InputDecoration(labelText: 'Filter by Batch'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Batches')),
                        ...data.batches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
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
                    value: filterState.status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Statuses')),
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

                final batchesMap = academicDataAsync.maybeWhen(
                  data: (data) => {for (var b in data.batches) b.id: b},
                  orElse: () => <int, Batch>{},
                );

                return SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Roll No')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Guardian Phone')),
                      DataColumn(label: Text('Batch')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: students.map((student) {
                      final batch = batchesMap[student.batchId];
                      return DataRow(
                        cells: [
                          DataCell(Text(student.rollNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(student.name)),
                          DataCell(Text(student.guardianPhone)),
                          DataCell(Text(batch?.name ?? 'Batch #${student.batchId}')),
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
                                      batchName: batch?.name ?? 'General',
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
                                      batchName: batch?.name ?? 'General',
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

  Widget _buildBatchesTab() {
    final academicDataAsync = ref.watch(academicDataProvider);

    return academicDataAsync.when(
      data: (data) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Courses & Sessions
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
                        const Text('Courses & Classes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 14),
                              label: const Text('Add Session'),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => const CreateSessionDialog(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PrimaryButton(
                              label: 'Add Course',
                              icon: Icons.add,
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => const CreateCourseDialog(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: data.courses.isEmpty
                          ? const Center(child: Text('No courses added yet.'))
                          : ListView.separated(
                              itemCount: data.courses.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final c = data.courses[idx];
                                return ListTile(
                                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(c.code ?? 'Code: N/A'),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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

          // Right: Batches
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
                        const Text('Active Batches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        PrimaryButton(
                          label: 'Add Batch',
                          icon: Icons.add,
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const CreateBatchDialog(),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: data.batches.isEmpty
                          ? const Center(child: Text('No batches created yet.'))
                          : ListView.builder(
                              itemCount: data.batches.length,
                              itemBuilder: (context, idx) {
                                final b = data.batches[idx];
                                return Card(
                                  color: AppColors.inputFill,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      'Instructor: ${b.instructorName ?? "N/A"} • Timing: ${b.timing ?? "N/A"}',
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
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
                            value: _promotionTargetBatchId,
                            decoration: const InputDecoration(labelText: 'Target Next Batch *'),
                            items: data.batches
                                .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
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
                                      ref.invalidate(studentsListProvider);
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
                      data: (students) => ListView.builder(
                        itemCount: students.length,
                        itemBuilder: (context, idx) {
                          final s = students[idx];
                          final isSelected = _selectedStudentIds.contains(s.id);
                          return CheckboxListTile(
                            value: isSelected,
                            title: Text('${s.rollNumber} - ${s.name}'),
                            subtitle: Text('Guardian: ${s.guardianPhone}'),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedStudentIds.add(s.id);
                                } else {
                                  _selectedStudentIds.remove(s.id);
                                }
                              });
                            },
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
