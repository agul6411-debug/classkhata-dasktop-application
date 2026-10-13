/// Comprehensive Settings & System Management Screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/error_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../backup/domain/usecases/backup_scheduler_service.dart';
import '../../../backup/presentation/providers/backup_providers.dart';
import '../../../licensing/presentation/providers/licensing_providers.dart';
import '../../../licensing/presentation/widgets/activation_dialog.dart';
import '../providers/settings_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Profile controllers
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _logoCtrl = TextEditingController();

  // Template controllers
  final _waTemplateCtrl = TextEditingController();
  final _receiptFooterCtrl = TextEditingController();

  // Settings state
  int _dueDay = 10;
  bool _siblingDiscount = false;
  bool _lateFee = false;
  bool _allowNegativeStock = false;
  int _autoLockMinutes = 10;
  int _makerCheckerThreshold = 5000;
  String _receiptStyle = 'a4';

  // Backup settings
  bool _autoBackupDaily = true;
  int _backupRetention = 7;

  bool _isSavingProfile = false;
  bool _isSavingTemplates = false;
  bool _isBackingUp = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _logoCtrl.dispose();
    _waTemplateCtrl.dispose();
    _receiptFooterCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _statusMessage = 'Academy Name cannot be empty.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isSavingProfile = true;
      _statusMessage = null;
    });

    final ctrl = ref.read(settingsControllerProvider);
    await ctrl.updateAcademyProfile(
      name: name,
      tagline: _taglineCtrl.text.trim().isEmpty ? null : _taglineCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      logoPath: _logoCtrl.text.trim().isEmpty ? null : _logoCtrl.text.trim(),
    );

    if (!mounted) return;
    ref.invalidate(academyProfileProvider);
    setState(() {
      _isSavingProfile = false;
      _statusMessage = 'Academy profile updated successfully.';
      _isError = false;
    });
  }

  Future<void> _saveTemplates() async {
    setState(() {
      _isSavingTemplates = true;
      _statusMessage = null;
    });

    final ctrl = ref.read(settingsControllerProvider);
    await ctrl.updateSetting('whatsapp_reminder_template', _waTemplateCtrl.text.trim());
    await ctrl.updateSetting('receipt_footer_note', _receiptFooterCtrl.text.trim());
    await ctrl.updateSetting('receipt_style', _receiptStyle);

    if (!mounted) return;
    ref.invalidate(appSettingsMapProvider);
    setState(() {
      _isSavingTemplates = false;
      _statusMessage = 'Messaging & receipt templates updated.';
      _isError = false;
    });
  }

  Future<void> _savePolicy(String key, String value) async {
    final ctrl = ref.read(settingsControllerProvider);
    await ctrl.updateSetting(key, value);
    ref.invalidate(appSettingsMapProvider);
  }

  Future<void> _triggerBackup() async {
    setState(() {
      _isBackingUp = true;
      _statusMessage = null;
    });

    final currentUser = ref.read(authSessionNotifierProvider);
    final repo = ref.read(backupRepositoryProvider);

    final res = await repo.createBackup(
      type: 'manual',
      createdBy: currentUser?.id ?? 1,
    );

    if (!mounted) return;
    setState(() => _isBackingUp = false);

    res.fold(
      onSuccess: (meta) {
        ref.invalidate(backupsListProvider);
        setState(() {
          _statusMessage = 'Encrypted backup created: ${meta.filePath}';
          _isError = false;
        });
      },
      onFailure: (f) {
        setState(() {
          _statusMessage = f.message;
          _isError = true;
        });
      },
    );
  }

  Future<void> _verifyAuditTrail() async {
    setState(() {
      _statusMessage = 'Verifying cryptographic SHA-256 audit chain...';
      _isError = false;
    });

    final res = await ref.read(verifyAuditLogProvider.future);
    if (!mounted) return;

    res.fold(
      onSuccess: (_) {
        setState(() {
          _statusMessage = 'Audit log integrity verified: 100% intact (zero tampering detected).';
          _isError = false;
        });
      },
      onFailure: (f) {
        setState(() {
          _statusMessage = 'Audit integrity ALERT: ${f.message}';
          _isError = true;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Populate profile controllers if loaded
    ref.listen(academyProfileProvider, (_, next) {
      next.whenData((profile) {
        if (profile != null) {
          _nameCtrl.text = profile.name;
          _taglineCtrl.text = profile.tagline ?? '';
          _phoneCtrl.text = profile.phone ?? '';
          _addressCtrl.text = profile.address ?? '';
          _logoCtrl.text = profile.logoPath ?? '';
        }
      });
    });

    ref.listen(appSettingsMapProvider, (_, next) {
      next.whenData((map) {
        setState(() {
          _dueDay = int.tryParse(map['fee_due_day'] ?? '10') ?? 10;
          _siblingDiscount = map['sibling_discount_enabled'] == 'true';
          _lateFee = map['late_fee_enabled'] == 'true';
          _allowNegativeStock = map['allow_negative_stock'] == 'true';
          _autoLockMinutes = int.tryParse(map['auto_lock_minutes'] ?? '10') ?? 10;
          _makerCheckerThreshold = int.tryParse(map['maker_checker_threshold'] ?? '5000') ?? 5000;
          _autoBackupDaily = map['auto_backup_enabled'] != 'false';
          _backupRetention = int.tryParse(map['backup_retention_count'] ?? '7') ?? 7;
          _receiptStyle = map['receipt_style'] ?? 'a4';
          if (_waTemplateCtrl.text.isEmpty) {
            _waTemplateCtrl.text = map['whatsapp_reminder_template'] ??
                'Dear Parent, fee voucher for {student} of Rs. {amount} is due by {due_date}. Thank you, {academy}.';
          }
          if (_receiptFooterCtrl.text.isEmpty) {
            _receiptFooterCtrl.text = map['receipt_footer_note'] ?? 'Fee once paid is non-refundable. Thank you!';
          }
        });
      });
    });

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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings & System Management',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.heading),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Academy profile, policies, templates, encrypted backups, and offline licensing.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.accent),
                  label: const Text('Verify Audit Log Integrity'),
                  onPressed: _verifyAuditTrail,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab bar
            Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.accent,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Academy Profile'),
                  Tab(text: 'Policies & Security'),
                  Tab(text: 'Templates & Messaging'),
                  Tab(text: 'Backups & Recovery'),
                  Tab(text: 'Licensing & Activation'),
                  Tab(text: 'Display & Preferences'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Status message banner
            if (_statusMessage != null) ...[
              if (_isError)
                ErrorBanner(message: _statusMessage!)
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_statusMessage!, style: TextStyle(color: Colors.teal.shade900, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProfileTab(),
                  _buildPoliciesTab(),
                  _buildTemplatesTab(),
                  _buildBackupsTab(),
                  _buildLicensingTab(),
                  _buildPreferencesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Academy Profile
  // ---------------------------------------------------------------------------
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Academy Profile & Receipt Header', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Displayed on all student fee receipts, cards, and reports.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const Divider(height: 24),
            AppTextField(controller: _nameCtrl, label: 'Academy / School Name *'),
            const SizedBox(height: 12),
            AppTextField(controller: _taglineCtrl, label: 'Tagline / Motto (Optional)'),
            const SizedBox(height: 12),
            AppTextField(controller: _phoneCtrl, label: 'Official Contact Phone'),
            const SizedBox(height: 12),
            AppTextField(controller: _addressCtrl, label: 'Official Campus Address'),
            const SizedBox(height: 12),
            AppTextField(controller: _logoCtrl, label: 'Academy Logo File Path (Optional)'),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: PrimaryButton(
                label: 'Save Profile',
                isLoading: _isSavingProfile,
                onPressed: _saveProfile,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Policies & Security
  // ---------------------------------------------------------------------------
  Widget _buildPoliciesTab() {
    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Operational & Financial Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default Fee Due Day of Month'),
              subtitle: const Text('Day between 1 and 28 assigned to newly generated vouchers.'),
              trailing: DropdownButton<int>(
                value: _dueDay,
                items: List.generate(28, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('Day $d'))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _dueDay = val);
                    _savePolicy('fee_due_day', val.toString());
                  }
                },
              ),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sibling / Family Discounts'),
              subtitle: const Text('Automatically apply configured concessions for linked sibling students.'),
              value: _siblingDiscount,
              onChanged: (val) {
                setState(() => _siblingDiscount = val);
                _savePolicy('sibling_discount_enabled', val.toString());
              },
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Late Fee Fines'),
              subtitle: const Text('Automatically assess overdue penalties after the due day expires.'),
              value: _lateFee,
              onChanged: (val) {
                setState(() => _lateFee = val);
                _savePolicy('late_fee_enabled', val.toString());
              },
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow Negative Inventory Stock'),
              subtitle: const Text('Permit item stock issuance even when current physical balance is zero.'),
              value: _allowNegativeStock,
              onChanged: (val) {
                setState(() => _allowNegativeStock = val);
                _savePolicy('allow_negative_stock', val.toString());
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-Lock Inactivity Timer'),
              subtitle: const Text('Automatically lock current screen after period of inactivity.'),
              trailing: DropdownButton<int>(
                value: _autoLockMinutes,
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5 Minutes')),
                  DropdownMenuItem(value: 10, child: Text('10 Minutes')),
                  DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                  DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _autoLockMinutes = val);
                    _savePolicy('auto_lock_minutes', val.toString());
                  }
                },
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Maker-Checker Approval Limit'),
              subtitle: const Text('Discounts, waivers, refunds, and shrinkage adjustments above this require admin approval.'),
              trailing: DropdownButton<int>(
                value: _makerCheckerThreshold,
                items: const [
                  DropdownMenuItem(value: 1000, child: Text('Rs. 1,000')),
                  DropdownMenuItem(value: 2500, child: Text('Rs. 2,500')),
                  DropdownMenuItem(value: 5000, child: Text('Rs. 5,000')),
                  DropdownMenuItem(value: 10000, child: Text('Rs. 10,000')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _makerCheckerThreshold = val);
                    _savePolicy('maker_checker_threshold', val.toString());
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Templates & Messaging
  // ---------------------------------------------------------------------------
  Widget _buildTemplatesTab() {
    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Messaging & Receipt Templates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Customize WhatsApp reminder messages and receipt presentation.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const Divider(height: 24),
            const Text('WhatsApp Reminder Message Template', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            AppTextField(
              controller: _waTemplateCtrl,
              label: 'Message Template',
              maxLines: 3,
            ),
            const SizedBox(height: 6),
            const Wrap(
              spacing: 6,
              children: [
                Chip(label: Text('{student}', style: TextStyle(fontSize: 11))),
                Chip(label: Text('{amount}', style: TextStyle(fontSize: 11))),
                Chip(label: Text('{due_date}', style: TextStyle(fontSize: 11))),
                Chip(label: Text('{academy}', style: TextStyle(fontSize: 11))),
              ],
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default Fee Receipt Format'),
              subtitle: const Text('Preferred printing layout for generated receipts.'),
              trailing: DropdownButton<String>(
                value: _receiptStyle,
                items: const [
                  DropdownMenuItem(value: 'a4', child: Text('A4 Portrait (Standard)')),
                  DropdownMenuItem(value: 'thermal', child: Text('Thermal 80mm Roll')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _receiptStyle = val);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _receiptFooterCtrl,
              label: 'Receipt Footer Note',
              hint: 'e.g. Fee once paid is non-refundable.',
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: PrimaryButton(
                label: 'Save Templates',
                isLoading: _isSavingTemplates,
                onPressed: _saveTemplates,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Backups & Recovery
  // ---------------------------------------------------------------------------
  Widget _buildBackupsTab() {
    final backupsAsync = ref.watch(backupsListProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Switch(
                    value: _autoBackupDaily,
                    onChanged: (val) {
                      setState(() => _autoBackupDaily = val);
                      _savePolicy('auto_backup_enabled', val.toString());
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text('Automatic Daily Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 24),
                  const Text('Retention: Keep Last', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _backupRetention,
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('7 Backups')),
                      DropdownMenuItem(value: 14, child: Text('14 Backups')),
                      DropdownMenuItem(value: 30, child: Text('30 Backups')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _backupRetention = val);
                        _savePolicy('backup_retention_count', val.toString());
                      }
                    },
                  ),
                ],
              ),
              PrimaryButton(
                label: 'Create Backup Now',
                icon: Icons.backup,
                isLoading: _isBackingUp,
                onPressed: _triggerBackup,
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: backupsAsync.when(
              data: (backups) {
                if (backups.isEmpty) {
                  return const Center(
                    child: Text('No backup files created yet.', style: TextStyle(color: AppColors.textMuted)),
                  );
                }

                return SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Size', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Checksum', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: backups.map((b) {
                      return DataRow(
                        cells: [
                          DataCell(Text('${b.createdAt.day}/${b.createdAt.month}/${b.createdAt.year} ${b.createdAt.hour}:${b.createdAt.minute.toString().padLeft(2, '0')}')),
                          DataCell(Text(b.type.toUpperCase())),
                          DataCell(Text('${(b.sizeBytes / 1024).toStringAsFixed(1)} KB')),
                          DataCell(Text(b.checksum.substring(0, 10) + '...', style: const TextStyle(fontFamily: 'monospace'))),
                          DataCell(StatusBadge(
                            label: b.isVerified ? 'VERIFIED' : 'PENDING CHECK',
                            type: b.isVerified ? StatusBadgeType.paid : StatusBadgeType.pending,
                          )),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  child: const Text('Verify'),
                                  onPressed: () async {
                                    final repo = ref.read(backupRepositoryProvider);
                                    final res = await repo.verifyBackup(b.id);
                                    ref.invalidate(backupsListProvider);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(res.valueOrThrow ? 'Checksum verified: File intact.' : 'Checksum verification FAILED.'),
                                          backgroundColor: res.valueOrThrow ? Colors.teal : Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 4),
                                TextButton(
                                  child: const Text('Test Restore', style: TextStyle(color: Colors.blueAccent)),
                                  onPressed: () async {
                                    final scheduler = ref.read(backupSchedulerServiceProvider);
                                    final res = await scheduler.testRestoreBackup(b.id);
                                    if (mounted) {
                                      res.fold(
                                        onSuccess: (TestRestoreResult tr) => ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Test restore passed: ${tr.recordsCount} student records verified in isolated sandbox.'),
                                            backgroundColor: Colors.teal,
                                          ),
                                        ),
                                        onFailure: (AppFailure f) => ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Test restore error: ${f.message}'), backgroundColor: Colors.red),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 4),
                                TextButton(
                                  child: const Text('Restore', style: TextStyle(color: Colors.redAccent)),
                                  onPressed: () => _confirmRestore(b.id),
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
              error: (err, _) => Center(child: Text('Error loading backups: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmRestore(int backupId) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Database Restore'),
        content: const Text(
          'WARNING: Restoring this backup will replace current operational data with the snapshot. The app will verify checksums before overwriting. Are you sure you wish to proceed?',
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Proceed with Restore'),
            onPressed: () async {
              Navigator.of(context).pop(true);
              final repo = ref.read(backupRepositoryProvider);
              final res = await repo.restoreBackup(backupId);
              if (mounted) {
                res.fold(
                  onSuccess: (_) {
                    showDialog<void>(
                      context: context,
                      builder: (_) => const AlertDialog(
                        title: Text('Restore Complete'),
                        content: Text('Database restored successfully. Please restart the application.'),
                      ),
                    );
                  },
                  onFailure: (f) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Restore error: ${f.message}'), backgroundColor: Colors.red),
                    );
                  },
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 5: Licensing & Activation
  // ---------------------------------------------------------------------------
  Widget _buildLicensingTab() {
    final licenseAsync = ref.watch(licenseInfoProvider);

    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: licenseAsync.when(
          data: (info) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ClassKhata Offline Licensing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    StatusBadge(
                      label: info.status.name.toUpperCase(),
                      type: info.isActivated ? StatusBadgeType.paid : (info.isReadonly ? StatusBadgeType.overdue : StatusBadgeType.pending),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Fully offline RSA-2048 cryptographically verified license.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const Divider(height: 24),

                // Machine ID container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.computer, size: 22, color: AppColors.heading),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Hardware Machine ID:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            SelectableText(
                              info.machineId,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: info.machineId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Machine ID copied to clipboard.')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('License Status'),
                  subtitle: Text(
                    info.isActivated
                        ? 'Lifetime Permanent License Active (${info.academyName ?? "Registered"})'
                        : (info.isReadonly ? 'Trial Expired — System in Read-Only mode' : 'Free Trial: ${info.daysRemaining} days remaining'),
                  ),
                  trailing: info.isActivated
                      ? const Icon(Icons.check_circle, color: AppColors.accent, size: 28)
                      : null,
                ),
                const Divider(),

                if (!info.isActivated) ...[
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Activate Lifetime License',
                    icon: Icons.vpn_key,
                    onPressed: () {
                      showDialog<bool>(
                        context: context,
                        builder: (_) => ActivationDialog(machineId: info.machineId),
                      );
                    },
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error loading license: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 6: Display & Preferences
  // ---------------------------------------------------------------------------
  Widget _buildPreferencesTab() {
    final locale = ref.watch(localeNotifierProvider);
    final theme = ref.watch(themeModeNotifierProvider);

    return SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('UI Display & Localization', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Language / زبان'),
              subtitle: const Text('English (LTR) or Urdu (اردو RTL) UI.'),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'ur', label: Text('اردو')),
                ],
                selected: {locale},
                onSelectionChanged: (s) => ref.read(localeNotifierProvider.notifier).setLocale(s.first),
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Theme Mode'),
              subtitle: const Text('Switch between Light and Dark interface.'),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'light', label: Text('Light')),
                  ButtonSegment(value: 'dark', label: Text('Dark')),
                ],
                selected: {theme},
                onSelectionChanged: (s) => ref.read(themeModeNotifierProvider.notifier).setTheme(s.first),
              ),
            ),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              subtitle: const Text('Lock current workstation session.'),
              onTap: () => ref.read(authSessionNotifierProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}
