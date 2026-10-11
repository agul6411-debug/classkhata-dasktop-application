/// Main Inventory Management Page (Strictly NO Barcodes).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../providers/inventory_providers.dart';
import '../widgets/item_form_dialog.dart';
import '../widgets/stock_movement_dialog.dart';
import '../widgets/stock_reconcile_dialog.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            // Header & Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inventory Management',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.heading),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Stock in/out, reorder alerts, and stock-take reconciliation (no barcodes).',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.rule, size: 16),
                      label: const Text('Reconcile Count'),
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => const StockReconcileDialog(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Record Movement'),
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => const StockMovementDialog(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PrimaryButton(
                      label: 'Add Item',
                      icon: Icons.add,
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => const ItemFormDialog(),
                      ),
                    ),
                  ],
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
                  Tab(text: 'Items Catalog & Stock'),
                  Tab(text: 'Stock Movements History'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildItemsTab(),
                  _buildMovementsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Items Catalog & Stock
  // ---------------------------------------------------------------------------
  Widget _buildItemsTab() {
    final itemsAsync = ref.watch(inventoryItemsProvider);
    final categoriesAsync = ref.watch(inventoryCategoriesProvider);
    final selectedCat = ref.watch(inventoryFilterCategoryProvider);
    final lowStockOnly = ref.watch(inventoryFilterLowStockProvider);

    return Column(
      children: [
        // Filter bar
        Row(
          children: [
            categoriesAsync.when(
              data: (cats) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButton<int?>(
                    value: selectedCat,
                    underline: const SizedBox.shrink(),
                    hint: const Text('All Categories'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Categories')),
                      ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (val) {
                      ref.read(inventoryFilterCategoryProvider.notifier).state = val;
                    },
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 16),
            FilterChip(
              label: const Text('Low Stock Alerts Only'),
              selected: lowStockOnly,
              selectedColor: Colors.red.shade100,
              onSelected: (val) {
                ref.read(inventoryFilterLowStockProvider.notifier).state = val;
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Table
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      const Text('No inventory items found.', style: TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => showDialog<bool>(context: context, builder: (_) => const ItemFormDialog()),
                        child: const Text('Add First Inventory Item'),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('On Hand', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Unit Cost', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Total Value', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Reorder Level', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: items.map((item) {
                      return DataRow(
                        cells: [
                          DataCell(Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(item.categoryName)),
                          DataCell(Text(item.unit)),
                          DataCell(Text('${item.quantityOnHand}', style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: item.isLowStock ? Colors.red : AppColors.textPrimary,
                          ))),
                          DataCell(Text(item.unitCost.format())),
                          DataCell(Text(item.totalValue.format())),
                          DataCell(Text('${item.reorderLevel}')),
                          DataCell(StatusBadge(
                            label: item.isLowStock ? 'LOW STOCK' : 'IN STOCK',
                            type: item.isLowStock ? StatusBadgeType.overdue : StatusBadgeType.paid,
                          )),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.green),
                                  tooltip: 'Stock In',
                                  onPressed: () => showDialog<bool>(
                                    context: context,
                                    builder: (_) => StockMovementDialog(preselectedItem: item, initialMovementType: 'in'),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.orange),
                                  tooltip: 'Stock Out',
                                  onPressed: () => showDialog<bool>(
                                    context: context,
                                    builder: (_) => StockMovementDialog(preselectedItem: item, initialMovementType: 'out'),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.rule, size: 18, color: AppColors.accent),
                                  tooltip: 'Reconcile Physical Count',
                                  onPressed: () => showDialog<bool>(
                                    context: context,
                                    builder: (_) => StockReconcileDialog(preselectedItem: item),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading items: $err', style: const TextStyle(color: Colors.red))),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Stock Movements History
  // ---------------------------------------------------------------------------
  Widget _buildMovementsTab() {
    final movementsAsync = ref.watch(inventoryMovementsProvider);

    return movementsAsync.when(
      data: (movements) {
        if (movements.isEmpty) {
          return const Center(
            child: Text('No stock movements recorded yet.', style: TextStyle(color: AppColors.textMuted)),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Movement Type', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Unit Cost', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Reason / Destination', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Ref #', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: movements.map((m) {
                return DataRow(
                  cells: [
                    DataCell(Text('${m.movementDate.day}/${m.movementDate.month}/${m.movementDate.year}')),
                    DataCell(Text(m.itemName, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(StatusBadge(
                      label: m.movementType.toUpperCase(),
                      type: m.isIn
                          ? StatusBadgeType.paid
                          : m.isOut
                              ? StatusBadgeType.overdue
                              : StatusBadgeType.partial,
                    )),
                    DataCell(Text(
                      m.isIn ? '+${m.quantity}' : m.isOut ? '-${m.quantity}' : '${m.quantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: m.isIn ? Colors.green : m.isOut ? Colors.red : AppColors.textPrimary,
                      ),
                    )),
                    DataCell(Text(m.unitCost.format())),
                    DataCell(Text(m.reason)),
                    DataCell(Text(m.referenceNumber ?? '-')),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading movements: $err', style: const TextStyle(color: Colors.red))),
    );
  }
}
