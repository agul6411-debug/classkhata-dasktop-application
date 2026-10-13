/// Global search command palette searching students, staff, items, and receipts.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';

enum SearchResultType { student, staff, item, receipt }

class SearchResultItem {
  final String title;
  final String subtitle;
  final SearchResultType type;
  final dynamic payload;

  const SearchResultItem({
    required this.title,
    required this.subtitle,
    required this.type,
    this.payload,
  });
}

class GlobalSearchDialog extends ConsumerStatefulWidget {
  const GlobalSearchDialog({super.key});

  @override
  ConsumerState<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends ConsumerState<GlobalSearchDialog> {
  final _searchCtrl = TextEditingController();
  List<SearchResultItem> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);
    final db = ref.read(appDatabaseProvider);
    final items = <SearchResultItem>[];

    try {
      // 1. Search Students
      final allStudents = await db.select(db.studentsTable).get();
      for (final s in allStudents) {
        if (s.name.toLowerCase().contains(q) ||
            s.rollNumber.toLowerCase().contains(q) ||
            s.guardianPhone.contains(q)) {
          items.add(SearchResultItem(
            title: s.name,
            subtitle: 'Student • Roll: ${s.rollNumber} • Phone: ${s.guardianPhone}',
            type: SearchResultType.student,
            payload: s,
          ));
          if (items.length >= 15) break;
        }
      }

      // 2. Search Staff
      final allStaff = await db.select(db.staffMembersTable).get();
      for (final sm in allStaff) {
        if (sm.name.toLowerCase().contains(q) ||
            sm.staffCode.toLowerCase().contains(q) ||
            sm.phone.contains(q)) {
          items.add(SearchResultItem(
            title: sm.name,
            subtitle: 'Staff • Code: ${sm.staffCode} • ${sm.designation}',
            type: SearchResultType.staff,
            payload: sm,
          ));
          if (items.length >= 25) break;
        }
      }

      // 3. Search Inventory Items
      final allItems = await db.select(db.inventoryItemsTable).get();
      for (final it in allItems) {
        if (it.name.toLowerCase().contains(q)) {
          items.add(SearchResultItem(
            title: it.name,
            subtitle: 'Inventory Item • In Stock: ${it.quantityOnHand} ${it.unit}',
            type: SearchResultType.item,
            payload: it,
          ));
          if (items.length >= 35) break;
        }
      }

      // 4. Search Receipts
      final allReceipts = await db.select(db.receiptsTable).get();
      for (final r in allReceipts) {
        if (r.receiptNumber.toLowerCase().contains(q)) {
          items.add(SearchResultItem(
            title: 'Receipt ${r.receiptNumber}',
            subtitle: 'Fee Receipt • Paid: Rs. ${(r.amountPaisa / 100).toStringAsFixed(0)}',
            type: SearchResultType.receipt,
            payload: r,
          ));
          if (items.length >= 45) break;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _results = items;
        _isSearching = false;
      });
    }
  }

  void _onSelectResult(SearchResultItem item) {
    Navigator.of(context).pop();
    switch (item.type) {
      case SearchResultType.student:
        context.go('/students');
        break;
      case SearchResultType.staff:
        context.go('/payroll');
        break;
      case SearchResultType.item:
        context.go('/inventory');
        break;
      case SearchResultType.receipt:
        context.go('/fees');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 32, right: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search input field
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search students, staff, items, receipts... (Ctrl+K)',
                  prefixIcon: const Icon(Icons.search, color: AppColors.accent),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
                onChanged: _performSearch,
              ),
              const SizedBox(height: 12),

              // Search results list
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_searchCtrl.text.length >= 2 && _results.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('No results found matching your search.', style: TextStyle(color: AppColors.textMuted)),
                  ),
                )
              else if (_results.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      IconData icon;
                      Color iconColor;

                      switch (item.type) {
                        case SearchResultType.student:
                          icon = Icons.school;
                          iconColor = AppColors.accent;
                          break;
                        case SearchResultType.staff:
                          icon = Icons.badge;
                          iconColor = Colors.indigo;
                          break;
                        case SearchResultType.item:
                          icon = Icons.inventory_2;
                          iconColor = Colors.orange.shade700;
                          break;
                        case SearchResultType.receipt:
                          icon = Icons.receipt_long;
                          iconColor = Colors.green.shade700;
                          break;
                      }

                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: iconColor.withOpacity(0.12),
                          child: Icon(icon, size: 16, color: iconColor),
                        ),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textMuted),
                        onTap: () => _onSelectResult(item),
                      );
                    },
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickHint(Icons.school, 'Students (Name, Roll, Phone)'),
                      _buildQuickHint(Icons.badge, 'Staff (Name, Code)'),
                      _buildQuickHint(Icons.inventory_2, 'Items (Name)'),
                      _buildQuickHint(Icons.receipt, 'Receipts (Number)'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickHint(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
