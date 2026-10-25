import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../app/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/money/money.dart';
import '../../../../core/services/receipt_image_service.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/entities/fee_entities.dart';
import 'receipt_dialog.dart';

class StudentDuesRecord {
  final int studentId;
  final String studentName;
  final String rollNumber;
  final String guardianPhone;
  final String className;
  final int totalDuePaisa;
  final int voucherCount;
  final String monthYear;
  final DateTime dueDate;
  final FeeVoucher latestVoucher;

  const StudentDuesRecord({
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.guardianPhone,
    required this.className,
    required this.totalDuePaisa,
    required this.voucherCount,
    required this.monthYear,
    required this.dueDate,
    required this.latestVoucher,
  });

  Money get totalDue => Money.fromPaisa(totalDuePaisa);
}

class FeeDuesBroadcastDialog extends ConsumerStatefulWidget {
  const FeeDuesBroadcastDialog({super.key});

  @override
  ConsumerState<FeeDuesBroadcastDialog> createState() => _FeeDuesBroadcastDialogState();
}

class _FeeDuesBroadcastDialogState extends ConsumerState<FeeDuesBroadcastDialog> {
  final _searchCtrl = TextEditingController();
  final Set<int> _sentStudentIds = {};
  bool _isLoading = true;
  String? _error;
  List<StudentDuesRecord> _allRecords = [];

  @override
  void initState() {
    super.initState();
    _loadDues();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDues() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = ref.read(appDatabaseProvider);
      final vouchers = await (db.select(db.feeVouchersTable)
            ..where((t) =>
                t.status.equals('unpaid') |
                t.status.equals('partial') |
                t.status.equals('overdue'))
            ..orderBy([(t) => drift.OrderingTerm.desc(t.dueDate)]))
          .get();

      final Map<int, List<FeeVouchersTableData>> byStudent = {};
      for (final v in vouchers) {
        if (v.totalDuePaisa > v.amountPaidPaisa) {
          byStudent.putIfAbsent(v.studentId, () => []).add(v);
        }
      }

      final List<StudentDuesRecord> records = [];
      for (final entry in byStudent.entries) {
        final studentId = entry.key;
        final sVouchers = entry.value;

        final student = await (db.select(db.studentsTable)..where((t) => t.id.equals(studentId))).getSingleOrNull();
        if (student == null) continue;

        final batch = await (db.select(db.batchesTable)..where((t) => t.id.equals(student.batchId))).getSingleOrNull();
        final course = batch != null
            ? await (db.select(db.coursesTable)..where((t) => t.id.equals(batch.courseId))).getSingleOrNull()
            : null;

        final className = course != null
            ? '${course.name} (${batch?.name ?? ""})'
            : (batch?.name ?? 'Section #${student.batchId}');

        int totalPendingPaisa = 0;
        for (final v in sVouchers) {
          totalPendingPaisa += (v.totalDuePaisa - v.amountPaidPaisa);
        }

        final vData = sVouchers.first;
        final feeVoucher = FeeVoucher(
          id: vData.id,
          voucherNumber: vData.voucherNumber,
          studentId: vData.studentId,
          batchId: vData.batchId,
          monthYear: vData.monthYear,
          issueDate: vData.issueDate,
          dueDate: vData.dueDate,
          baseAmount: Money.fromPaisa(vData.baseAmountPaisa),
          discount: Money.fromPaisa(vData.discountPaisa),
          lateFee: Money.fromPaisa(vData.lateFeePaisa),
          carryForward: Money.fromPaisa(vData.carryForwardPaisa),
          totalDue: Money.fromPaisa(vData.totalDuePaisa),
          amountPaid: Money.fromPaisa(vData.amountPaidPaisa),
          status: VoucherStatus.fromString(vData.status),
          createdAt: vData.createdAt,
        );

        records.add(StudentDuesRecord(
          studentId: studentId,
          studentName: student.name,
          rollNumber: student.rollNumber,
          guardianPhone: student.guardianPhone,
          className: className,
          totalDuePaisa: totalPendingPaisa,
          voucherCount: sVouchers.length,
          monthYear: vData.monthYear,
          dueDate: vData.dueDate,
          latestVoucher: feeVoucher,
        ));
      }

      // Sort highest dues first
      records.sort((a, b) => b.totalDuePaisa.compareTo(a.totalDuePaisa));

      if (mounted) {
        setState(() {
          _allRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _buildReminderText({
    required StudentDuesRecord record,
    required String schoolName,
    String? schoolPhone,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('📢 *FEE DUES REMINDER NOTICE*');
    buffer.writeln('*$schoolName*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Assalam-o-Alaikum,');
    buffer.writeln('Mohtaram Walidain, yeh $schoolName ki janib se fee dues ka reminder notice hai:');
    buffer.writeln();
    buffer.writeln('👤 *Talib-e-Ilm:* ${record.studentName}');
    buffer.writeln('🏷️ *Roll No:* ${record.rollNumber}');
    buffer.writeln('🏫 *Class / Section:* ${record.className}');
    buffer.writeln('📅 *Billing Month:* ${record.monthYear}');
    buffer.writeln('💰 *Wajib-ul-Ada Pending Dues:* ${record.totalDue.format()}');
    buffer.writeln('⏳ *Fee Jama Karwane Ki Tareekh:* Har mahinay ki 10 tareekh');
    buffer.writeln();
    buffer.writeln('Baraye meharbani kisi bhi pareshani se bachnay ke liye baqaya fee barwaqt school office ya bank challan ke zariye ada farmayein.');
    if (schoolPhone != null && schoolPhone.isNotEmpty) {
      buffer.writeln('📞 *School Contact:* $schoolPhone');
    }
    buffer.writeln();
    buffer.writeln('Shukriya,');
    buffer.writeln('*$schoolName Administration*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    return buffer.toString();
  }

  Future<void> _sendWhatsAppNotice(StudentDuesRecord record) async {
    final academy = ref.read(academyProfileProvider).valueOrNull;
    final schoolName = academy?.name ?? 'School Management System';
    final schoolPhone = academy?.phone;

    final message = _buildReminderText(
      record: record,
      schoolName: schoolName,
      schoolPhone: schoolPhone,
    );

    final success = await ReceiptImageService.openWhatsAppChat(
      phone: record.guardianPhone,
      message: message,
    );

    if (mounted) {
      setState(() {
        _sentStudentIds.add(record.studentId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Opening WhatsApp chat for ${record.studentName}...'
              : 'Could not open WhatsApp for ${record.guardianPhone}'),
          backgroundColor: success ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _sendNextPending(List<StudentDuesRecord> records) {
    final pending = records.where((r) => !_sentStudentIds.contains(r.studentId)).toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fee due notices have already been sent!')),
      );
      return;
    }
    _sendWhatsAppNotice(pending.first);
  }

  void _copyAllDuesList(List<StudentDuesRecord> records) {
    if (records.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln('Roll No\tStudent Name\tClass\tGuardian Phone\tTotal Due (PKR)');
    for (final r in records) {
      buffer.writeln('${r.rollNumber}\t${r.studentName}\t${r.className}\t${r.guardianPhone}\t${r.totalDue.inRupees.toInt()}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${records.length} students dues data to clipboard (Excel / SMS format)!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _openPictureSlip(StudentDuesRecord record) {
    final academy = ref.read(academyProfileProvider).valueOrNull;
    showDialog(
      context: context,
      builder: (ctx) => ReceiptDialog(
        studentName: record.studentName,
        guardianPhone: record.guardianPhone,
        voucherNumber: record.latestVoucher.voucherNumber,
        academyName: academy?.name ?? 'School Management System',
        rollNumber: record.rollNumber,
        batchName: record.className,
        academyPhone: academy?.phone,
        academyAddress: academy?.address,
        voucher: record.latestVoucher,
      ),
    );
  }

  Future<void> _exportBulkCsv(List<StudentDuesRecord> records) async {
    if (records.isEmpty) return;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory(p.join(docDir.path, 'ClassKhata', 'Exports'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      final now = DateTime.now();
      final fileName = 'Fee_Dues_Mass_Broadcast_${now.year}_${now.month}_${now.day}.csv';
      final file = File(p.join(exportDir.path, fileName));

      final academy = ref.read(academyProfileProvider).valueOrNull;
      final schoolName = academy?.name ?? 'School Management System';

      final buffer = StringBuffer();
      buffer.writeln('Student ID,Roll Number,Student Name,Class,Guardian Phone,Pending Dues (PKR),Vouchers Count,Due Date,Notice Message');

      for (final r in records) {
        final notice = 'Mohtaram Walidain, $schoolName ki janib se talib-e-ilm ${r.studentName} (Roll: ${r.rollNumber}, Class: ${r.className}) ki pending fee ${r.totalDue.format()} wajibul ada hai. Baraye meharbani barwaqt ada farmayein.';
        final escapedName = '"${r.studentName.replaceAll('"', '""')}"';
        final escapedClass = '"${r.className.replaceAll('"', '""')}"';
        final escapedNotice = '"${notice.replaceAll('"', '""')}"';
        buffer.writeln('${r.studentId},${r.rollNumber},$escapedName,$escapedClass,${r.guardianPhone},${r.totalDue.inRupees.toInt()},${r.voucherCount},${r.dueDate.toIso8601String().substring(0, 10)},$escapedNotice');
      }

      await file.writeAsString(buffer.toString());
      await ReceiptImageService.openFileInExplorer(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mass Broadcast CSV saved (${records.length} students)! Folder opened.'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating CSV: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final academy = ref.watch(academyProfileProvider).valueOrNull;
    final schoolName = academy?.name ?? 'School Management System';

    // Apply filtering
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _allRecords.where((r) {
      final matchesQuery = query.isEmpty ||
          r.studentName.toLowerCase().contains(query) ||
          r.rollNumber.toLowerCase().contains(query) ||
          r.guardianPhone.contains(query);
      return matchesQuery;
    }).toList();

    final totalDuesPaisa = filtered.fold<int>(0, (sum, r) => sum + r.totalDuePaisa);
    final totalDuesMoney = Money.fromPaisa(totalDuesPaisa);
    final pendingCount = filtered.where((r) => !_sentStudentIds.contains(r.studentId)).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.campaign, color: AppColors.warning, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '10th Date Fee Dues Mass Reminders',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Har Mahinay Ki 10 Tareekh',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Automated WhatsApp notices for students with unpaid monthly fee & arrears for $schoolName',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
              const SizedBox(height: 16),

              // KPI Summary Banner
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.people_outline,
                      label: 'Total Defaulters',
                      value: '${filtered.length} Students',
                      color: AppColors.accent,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Total Pending Dues',
                      value: totalDuesMoney.format(),
                      color: AppColors.overdue,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      icon: Icons.check_circle_outline,
                      label: 'Notices Dispatched',
                      value: '${_sentStudentIds.length} Sent (${pendingCount} Pending)',
                      color: AppColors.success,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search & Actions Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search student name, roll number, or phone...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 15),
                    label: const Text('Export CSV'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onPressed: () => _exportBulkCsv(filtered),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_all, size: 15),
                    label: const Text('Copy All'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    onPressed: () => _copyAllDuesList(filtered),
                  ),
                  const SizedBox(width: 8),
                  PrimaryButton(
                    label: 'Send Next ($pendingCount)',
                    icon: Icons.send,
                    onPressed: pendingCount == 0 ? null : () => _sendNextPending(filtered),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Main List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text('Error: $_error', style: const TextStyle(color: AppColors.error)))
                        : filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 54, color: AppColors.success.withValues(alpha: 0.7)),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No pending fee dues found!',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'All students have cleared their vouchers up to date.',
                                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final r = filtered[idx];
                                  final isSent = _sentStudentIds.contains(r.studentId);

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    color: isSent
                                        ? AppColors.success.withValues(alpha: 0.05)
                                        : Colors.transparent,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: isSent
                                              ? AppColors.success.withValues(alpha: 0.15)
                                              : AppColors.accent.withValues(alpha: 0.12),
                                          child: Text(
                                            r.studentName.isNotEmpty ? r.studentName[0].toUpperCase() : 'S',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isSent ? AppColors.success : AppColors.accent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      r.studentName,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade200,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      r.rollNumber,
                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${r.className} • 📞 ${r.guardianPhone}',
                                                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              r.totalDue.format(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppColors.overdue,
                                              ),
                                            ),
                                            Text(
                                              '${r.voucherCount} pending',
                                              style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 14),
                                        ElevatedButton.icon(
                                          icon: const Icon(
                                            Icons.image_outlined,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          label: const Text(
                                            '📸 Picture Slip',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF25D366),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _openPictureSlip(r),
                                        ),
                                        const SizedBox(width: 6),
                                        OutlinedButton.icon(
                                          icon: Icon(
                                            isSent ? Icons.check : Icons.chat_bubble_outline,
                                            size: 13,
                                            color: isSent ? AppColors.success : null,
                                          ),
                                          label: Text(
                                            isSent ? 'Sent ✓' : 'Text',
                                            style: TextStyle(fontSize: 11, color: isSent ? AppColors.success : null),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _sendWhatsAppNotice(r),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
              const SizedBox(height: 12),

              // Bottom note
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '💡 Tip: Click "Send Next" to rapidly dispatch reminders to each parent via WhatsApp desktop/web.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
