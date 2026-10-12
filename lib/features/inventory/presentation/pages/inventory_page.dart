/// Main Inventory Management Page (Strictly NO Barcodes).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../providers/inventory_providers.dart';
import '../widgets/item_form_dialog.dart';
import '../widgets/item_issuance_dialog.dart';
import '../widgets/purchase_form_dialog.dart';
import '../widgets/stock_movement_dialog.dart';
import '../widgets/stock_reconcile_dialog.dart';
import '../widgets/supplier_dialog.dart';

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
    _tabController = TabController(length: 5, vsync: this);
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
                      'Inventory & Stock Management',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.heading),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Append-only stock ledger, suppliers, multi-item purchases, fee voucher charges, and stock-take audit (no barcodes).',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.outbox, size: 16),
                      label: const Text('Issue Item'),
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => const ItemIssuanceDialog(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.shopping_cart, size: 16),
                      label: const Text('New Purchase'),
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => const PurchaseFormDialog(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.rule, size: 16),
                      label: const Text('Reconcile Count'),
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => const StockReconcileDialog(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Stock In / Out'),
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => const StockMovementDialog(),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.accent,
                isScrollable: true,
                tabs: const [
                  Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Items Catalog'),
                  Tab(icon: Icon(Icons.history), text: 'Movements & Issues'),
                  Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Suppliers & Purchases'),
                  Tab(icon: Icon(Icons.fact_check_outlined), text: 'Stock-Take Audit'),
                  Tab(icon: Icon(Icons.pie_chart_outline), text: 'Stock Valuation'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ItemsCatalogTab(),
                  _MovementsAndIssuesTab(),
                  _SuppliersAndPurchasesTab(),
                  _StockTakeAuditTab(),
                  _StockValuationTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Items Catalog Tab
// ---------------------------------------------------------------------------

class _ItemsCatalogTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              data: (categories) => SizedBox(
                width: 220,
                child: DropdownButtonFormField<int?>(
                  initialValue: selectedCat,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Category',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Categories')),
                    ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (id) => ref.read(inventoryFilterCategoryProvider.notifier).state = id,
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 16),
            FilterChip(
              label: const Text('Low Stock Alerts Only'),
              selected: lowStockOnly,
              onSelected: (val) => ref.read(inventoryFilterLowStockProvider.notifier).state = val,
              selectedColor: Colors.amber.shade100,
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Catalog',
              onPressed: () => ref.invalidate(inventoryItemsProvider),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Items Data Table
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Text('No inventory items found. Click "Add Item" to register items.',
                      style: TextStyle(color: AppColors.textMuted)),
                );
              }
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, idx) {
                    final item = items[idx];
                    return ListTile(
                      title: Row(
                        children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          StatusBadge(type: StatusBadgeType.inactive, label: item.categoryName),
                          if (item.isLowStock) ...[
                            const SizedBox(width: 8),
                            const StatusBadge(type: StatusBadgeType.overdue, label: 'LOW STOCK'),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        'On Hand: ${item.quantityOnHand} ${item.unit} | Unit Cost: ${item.unitCost.format()} | Sale Price: ${item.sellingPrice.format()} | Reorder Alert Level: ${item.reorderLevel}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.totalValue.format(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accent),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.swap_horiz, size: 20),
                            tooltip: 'Quick Movement',
                            onPressed: () => showDialog<bool>(
                              context: context,
                              builder: (_) => StockMovementDialog(preselectedItem: item),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Failed to load catalog: $err')),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Movements & Issues Tab
// ---------------------------------------------------------------------------

class _MovementsAndIssuesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(inventoryMovementsProvider);
    final issuancesAsync = ref.watch(itemIssuancesProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Physical Stock Movements
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Stock Movements Ledger',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.heading)),
              const SizedBox(height: 8),
              Expanded(
                child: movementsAsync.when(
                  data: (movements) {
                    if (movements.isEmpty) {
                      return const Center(
                          child: Text('No movements recorded.', style: TextStyle(color: AppColors.textMuted)));
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListView.separated(
                        itemCount: movements.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, idx) {
                          final m = movements[idx];
                          final isIn = m.isIn;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isIn ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIn ? Colors.green : Colors.orange,
                            ),
                            title: Text('${m.itemName} (${isIn ? "+" : "-"}${m.quantity})'),
                            subtitle: Text(
                              '${m.reason} | ${DateFormat.yMMMd().format(m.movementDate)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                            trailing: Text(m.unitCost.format()),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Right Column: Student / Staff Issuances
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Item Issuance Log',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.heading)),
              const SizedBox(height: 8),
              Expanded(
                child: issuancesAsync.when(
                  data: (issuances) {
                    if (issuances.isEmpty) {
                      return const Center(
                          child: Text('No issuances recorded.', style: TextStyle(color: AppColors.textMuted)));
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListView.separated(
                        itemCount: issuances.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, idx) {
                          final iss = issuances[idx];
                          return ListTile(
                            dense: true,
                            title: Text('${iss.itemName} (Qty: ${iss.quantity})'),
                            subtitle: Text(
                              'To ${iss.recipientType.toUpperCase()} | Reason: ${iss.reason}${iss.feeVoucherId != null ? " [Charged to Voucher #${iss.feeVoucherId}]" : ""}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                            trailing: Text(
                              iss.totalCharge.format(),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Suppliers & Purchases Tab
// ---------------------------------------------------------------------------

class _SuppliersAndPurchasesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final purchasesAsync = ref.watch(purchasesProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Suppliers & Payables
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Suppliers & Payables',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.heading)),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add Supplier'),
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => const SupplierFormDialog(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: suppliersAsync.when(
                  data: (suppliers) {
                    if (suppliers.isEmpty) {
                      return const Center(
                          child: Text('No suppliers recorded.', style: TextStyle(color: AppColors.textMuted)));
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListView.separated(
                        itemCount: suppliers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, idx) {
                          final s = suppliers[idx];
                          return ListTile(
                            dense: true,
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Contact: ${s.phone ?? s.contactPerson ?? "N/A"}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  s.currentBalance.format(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: s.currentBalance.paisa > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.payment, size: 18),
                                  tooltip: 'Record Payment',
                                  onPressed: () => showDialog<bool>(
                                    context: context,
                                    builder: (_) => SupplierPaymentDialog(preselectedSupplierId: s.id),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Right Column: Purchases History
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Purchase Records',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.heading)),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.shopping_bag_outlined, size: 14),
                    label: const Text('Record Purchase'),
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => const PurchaseFormDialog(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: purchasesAsync.when(
                  data: (purchases) {
                    if (purchases.isEmpty) {
                      return const Center(
                          child: Text('No purchases recorded.', style: TextStyle(color: AppColors.textMuted)));
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListView.separated(
                        itemCount: purchases.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, idx) {
                          final p = purchases[idx];
                          return ListTile(
                            dense: true,
                            title: Row(
                              children: [
                                Text(p.purchaseNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Text('(${p.supplierName})', style: const TextStyle(color: AppColors.textMuted)),
                              ],
                            ),
                            subtitle: Text(
                              'Date: ${DateFormat.yMMMd().format(p.purchaseDate)} | Paid: ${p.paidAmount.format()} (${p.paymentMode}) | Due: ${p.balanceDue.format()}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              p.totalAmount.format(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accent),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Stock-Take Audit Tab
// ---------------------------------------------------------------------------

class _StockTakeAuditTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.fact_check_outlined, size: 48, color: AppColors.accent),
              const SizedBox(height: 16),
              const Text(
                'Physical Count Reconciliation',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.heading),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter actual on-hand stock from physical inventory counts. The system computes variances (shrinkage or surplus) and records adjustment movements in the immutable stock ledger.\n\nDiscrepancies exceeding 5,000 PKR require Maker-Checker administrative sign-off.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Launch Physical Count Entry',
                icon: Icons.edit_note,
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => const StockReconcileDialog(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Stock Valuation Tab
// ---------------------------------------------------------------------------

class _StockValuationTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valAsync = ref.watch(stockValuationProvider);

    return valAsync.when(
      data: (report) {
        return Column(
          children: [
            // KPI Summary Strip
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Inventory Asset Valuation',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(
                          report.totalInventoryValue.format(),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Catalog Items',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(
                          report.totalItemsCount.toString(),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.heading),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Low-Stock Reorder Alerts',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(
                          report.lowStockCount.toString(),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: report.lowStockCount > 0 ? Colors.red.shade700 : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Item Breakdown
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.separated(
                  itemCount: report.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, idx) {
                    final item = report.items[idx];
                    return ListTile(
                      title: Text('${item.itemName} (${item.categoryName})',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'Count: ${item.quantityOnHand} ${item.unit} @ ${item.unitCost.format()}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      trailing: Text(
                        item.totalValuation.format(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accent),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error computing valuation: $err')),
    );
  }
}
