/// Simplified Inventory Management Page (Strictly NO Barcodes).
///
/// Designed around 3 fundamental operations:
///   1. Suppliers & Purchases: Where you purchase things, supplier payables & bills.
///   2. Customers & Sales: To whom you sell/issue items (Students, Staff, Walk-in buyers).
///   3. Reports & Stock: What comes in, what goes out, catalog balances & valuation.
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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            // Top Page Header
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
                          'Inventory & Store Management',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: headingColor),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Simplified into 3 core sections: Suppliers (Purchases), Customers (Sales), and Reports (Stock In/Out).',
                          style: TextStyle(color: textMutedColor, fontSize: 13),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Refresh'),
                          onPressed: () {
                            ref.invalidate(inventoryItemsProvider);
                            ref.invalidate(suppliersProvider);
                            ref.invalidate(purchasesProvider);
                            ref.invalidate(itemIssuancesProvider);
                            ref.invalidate(inventoryMovementsProvider);
                            ref.invalidate(stockValuationProvider);
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                          label: const Text('New Purchase'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.accent),
                            foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.accent,
                          ),
                          onPressed: () => showDialog<bool>(
                            context: context,
                            builder: (_) => const PurchaseFormDialog(),
                          ),
                        ),
                        PrimaryButton(
                          label: 'Sell / Issue Item',
                          icon: Icons.point_of_sale_outlined,
                          onPressed: () => showDialog<bool>(
                            context: context,
                            builder: (_) => const ItemIssuanceDialog(),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Tab bar: 3 core pillars
            Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
              child: TabBar(
                controller: _tabController,
                labelColor: isDark ? AppColors.accentLight : AppColors.accent,
                unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                indicatorColor: isDark ? AppColors.accentLight : AppColors.accent,
                isScrollable: true,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.local_shipping_outlined),
                    text: '1. Suppliers & Purchases (Where You Buy)',
                  ),
                  Tab(
                    icon: Icon(Icons.people_outline),
                    text: '2. Customers & Sales (To Whom You Sell)',
                  ),
                  Tab(
                    icon: Icon(Icons.analytics_outlined),
                    text: '3. Reports & Stock (In, Out & Current Balance)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _SuppliersAndPurchasesView(),
                  _CustomersAndSalesView(),
                  _ReportsAndStockView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// TAB 1: SUPPLIERS & PURCHASES (From where you purchase things)
// ===========================================================================

class _SuppliersAndPurchasesView extends ConsumerStatefulWidget {
  const _SuppliersAndPurchasesView();

  @override
  ConsumerState<_SuppliersAndPurchasesView> createState() => _SuppliersAndPurchasesViewState();
}

class _SuppliersAndPurchasesViewState extends ConsumerState<_SuppliersAndPurchasesView> {
  String _supplierSearch = '';
  String _purchaseSearch = '';

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final purchasesAsync = ref.watch(purchasesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Suppliers & Payables (Khata)
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suppliers & Khata',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.headingCol(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Vendors from whom items are purchased',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
                      label: const Text('Add Supplier'),
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => const SupplierFormDialog(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Supplier
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search supplier by name or phone...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => setState(() => _supplierSearch = val.toLowerCase().trim()),
                ),
                const SizedBox(height: 12),

                // Suppliers List
                Expanded(
                  child: suppliersAsync.when(
                    data: (suppliers) {
                      final filtered = suppliers.where((s) {
                        if (_supplierSearch.isEmpty) return true;
                        return s.name.toLowerCase().contains(_supplierSearch) ||
                            (s.phone != null && s.phone!.contains(_supplierSearch));
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            _supplierSearch.isEmpty
                                ? 'No suppliers registered yet.\nClick "Add Supplier" to add one.'
                                : 'No matching suppliers found.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                        itemBuilder: (context, idx) {
                          final s = filtered[idx];
                          final hasPayable = s.currentBalance.paisa > 0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                                  child: const Icon(Icons.store_outlined, size: 18, color: AppColors.accent),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '📞 ${s.phone ?? "No Phone"} • ${s.contactPerson ?? "N/A"}${s.address != null ? " • ${s.address}" : ""}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: hasPayable ? Colors.red.shade50 : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: hasPayable ? Colors.red.shade200 : Colors.green.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        hasPayable ? 'Payable: ${s.currentBalance.format()}' : 'Cleared (0)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: hasPayable ? Colors.red.shade800 : Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      children: [
                                        InkWell(
                                          onTap: () => showDialog<bool>(
                                            context: context,
                                            builder: (_) => SupplierPaymentDialog(preselectedSupplierId: s.id),
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            child: Text(
                                              'Pay',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.accent,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                        InkWell(
                                          onTap: () => showDialog<void>(
                                            context: context,
                                            builder: (_) => SupplierLedgerDialog(supplier: s),
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            child: Text(
                                              'Statement',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Right Column: Purchase Invoices / Bills History
        Expanded(
          flex: 6,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Purchase Invoices & Bills',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.headingCol(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Records of stock purchased from suppliers',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_shopping_cart, size: 15),
                      label: const Text('New Purchase Bill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => const PurchaseFormDialog(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Purchases
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search purchases by invoice #, purchase # or supplier...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => setState(() => _purchaseSearch = val.toLowerCase().trim()),
                ),
                const SizedBox(height: 12),

                // Purchases Table
                Expanded(
                  child: purchasesAsync.when(
                    data: (purchases) {
                      final filtered = purchases.where((p) {
                        if (_purchaseSearch.isEmpty) return true;
                        return p.purchaseNumber.toLowerCase().contains(_purchaseSearch) ||
                            p.supplierName.toLowerCase().contains(_purchaseSearch) ||
                            (p.invoiceNumber != null && p.invoiceNumber!.toLowerCase().contains(_purchaseSearch));
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Text(
                            _purchaseSearch.isEmpty
                                ? 'No purchases recorded yet.\nClick "New Purchase Bill" to add incoming stock.'
                                : 'No matching purchase records found.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        );
                      }

                      return Scrollbar(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowHeight: 40,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 52,
                              columns: const [
                                DataColumn(label: Text('Purchase #', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Total Bill', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Paid / Mode', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filtered.map((p) {
                                final isFullPaid = p.balanceDue.isZero;

                                return DataRow(
                                  cells: [
                                    DataCell(Text(p.purchaseNumber, style: const TextStyle(fontWeight: FontWeight.w600))),
                                    DataCell(Text(DateFormat('dd/MM/yyyy').format(p.purchaseDate))),
                                    DataCell(Text(p.supplierName)),
                                    DataCell(Text(p.invoiceNumber ?? '-')),
                                    DataCell(Text(p.totalAmount.format(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.paidAmount.format()),
                                          Text(
                                            p.paymentMode.toUpperCase(),
                                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      StatusBadge(
                                        type: isFullPaid ? StatusBadgeType.paid : StatusBadgeType.overdue,
                                        label: isFullPaid ? 'Paid' : 'Unpaid: ${p.balanceDue.format()}',
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
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
        ),
      ],
    );
  }
}

// ===========================================================================
// TAB 2: CUSTOMERS & SALES (To whom you sell / issue items)
// ===========================================================================

class _CustomersAndSalesView extends ConsumerStatefulWidget {
  const _CustomersAndSalesView();

  @override
  ConsumerState<_CustomersAndSalesView> createState() => _CustomersAndSalesViewState();
}

class _CustomersAndSalesViewState extends ConsumerState<_CustomersAndSalesView> {
  String _searchQuery = '';
  String _recipientFilter = 'all'; // 'all', 'student', 'staff', 'customer'

  @override
  Widget build(BuildContext context) {
    final issuancesAsync = ref.watch(itemIssuancesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Action Bar
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 10,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales & Customer Distribution',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.headingCol(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Record items sold or issued to students, staff, and walk-in buyers',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  PrimaryButton(
                    label: 'Sell / Issue Item',
                    icon: Icons.add,
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => const ItemIssuanceDialog(),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Search & Filter Row
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by item, buyer name, or purpose...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All Sales')),
                  ButtonSegment(value: 'student', label: Text('Students')),
                  ButtonSegment(value: 'staff', label: Text('Staff')),
                  ButtonSegment(value: 'customer', label: Text('Walk-in Customers')),
                ],
                selected: {_recipientFilter},
                onSelectionChanged: (set) => setState(() => _recipientFilter = set.first),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sales / Issuances DataTable with Dual-Axis Scrolling
          Expanded(
            child: issuancesAsync.when(
              data: (issuances) {
                final filtered = issuances.where((iss) {
                  // Filter by recipient type
                  if (_recipientFilter != 'all') {
                    if (_recipientFilter == 'customer') {
                      if (iss.recipientType.toLowerCase() != 'customer' &&
                          !iss.reason.toLowerCase().contains('walk-in') &&
                          !iss.reason.toLowerCase().contains('customer')) {
                        return false;
                      }
                    } else if (iss.recipientType.toLowerCase() != _recipientFilter) {
                      return false;
                    }
                  }

                  // Search filter
                  if (_searchQuery.isNotEmpty) {
                    final itemMatch = iss.itemName.toLowerCase().contains(_searchQuery);
                    final reasonMatch = iss.reason.toLowerCase().contains(_searchQuery);
                    final recMatch = iss.recipientType.toLowerCase().contains(_searchQuery);
                    if (!itemMatch && !reasonMatch && !recMatch) return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty && _recipientFilter == 'all'
                          ? 'No sales or issuances recorded yet.\nClick "Sell / Issue Item" to sell books, uniforms, or stationery.'
                          : 'No matching sales records found.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                return Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 48,
                        dataRowMaxHeight: 52,
                        columns: const [
                          DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Sold / Issued To', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Unit Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Total Sale', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Purpose / Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filtered.map((iss) {
                          final isStudent = iss.recipientType.toLowerCase() == 'student';
                          final isStaff = iss.recipientType.toLowerCase() == 'staff';
                          final isVoucher = iss.feeVoucherId != null;

                          return DataRow(
                            cells: [
                              DataCell(Text(DateFormat('dd/MM/yyyy HH:mm').format(iss.issuedDate))),
                              DataCell(
                                Text(
                                  iss.itemName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${iss.quantity} pcs',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isStudent
                                          ? Icons.school_outlined
                                          : (isStaff ? Icons.badge_outlined : Icons.person_outline),
                                      size: 16,
                                      color: isStudent
                                          ? Colors.blue.shade700
                                          : (isStaff ? Colors.purple.shade700 : Colors.teal.shade700),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isStudent
                                          ? 'Student'
                                          : (isStaff ? 'Staff Member' : 'Walk-in Buyer'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isStudent
                                            ? Colors.blue.shade800
                                            : (isStaff ? Colors.purple.shade800 : Colors.teal.shade800),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(Text(iss.unitPrice.format())),
                              DataCell(
                                Text(
                                  iss.totalCharge.format(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                                ),
                              ),
                              DataCell(
                                isVoucher
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.blue.shade200),
                                        ),
                                        child: Text(
                                          'Voucher #VCH-${iss.feeVoucherId}',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.green.shade200),
                                        ),
                                        child: Text(
                                          'Direct Cash Sale',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                        ),
                                      ),
                              ),
                              DataCell(
                                Text(
                                  iss.reason,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// TAB 3: REPORTS & STOCK (What comes in and goes out)
// ===========================================================================

class _ReportsAndStockView extends ConsumerStatefulWidget {
  const _ReportsAndStockView();

  @override
  ConsumerState<_ReportsAndStockView> createState() => _ReportsAndStockViewState();
}

class _ReportsAndStockViewState extends ConsumerState<_ReportsAndStockView> {
  int _viewIndex = 0; // 0 = Catalog & Current Stock, 1 = In & Out Movements Log
  String _itemSearch = '';
  String _movementSearch = '';

  @override
  Widget build(BuildContext context) {
    final valAsync = ref.watch(stockValuationProvider);
    final itemsAsync = ref.watch(inventoryItemsProvider);
    final movementsAsync = ref.watch(inventoryMovementsProvider);
    final categoriesAsync = ref.watch(inventoryCategoriesProvider);
    final selectedCat = ref.watch(inventoryFilterCategoryProvider);
    final lowStockOnly = ref.watch(inventoryFilterLowStockProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top KPI Summary Cards (What comes in & goes out)
        valAsync.when(
          data: (report) {
            final movements = movementsAsync.asData?.value ?? [];
            int totalIn = 0;
            int totalOut = 0;
            for (final m in movements) {
              if (m.movementType == 'in') totalIn += m.quantity;
              if (m.movementType == 'out') totalOut += m.quantity;
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  children: [
                    _kpiCard(
                      title: 'Total Stock Valuation',
                      value: report.totalInventoryValue.format(),
                      subtitle: 'Current asset value on hand',
                      icon: Icons.savings_outlined,
                      color: AppColors.accent,
                      context: context,
                    ),
                    _kpiCard(
                      title: 'Catalog Items',
                      value: '${report.totalItemsCount} items',
                      subtitle: 'Active product lines',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.headingCol(context),
                      context: context,
                    ),
                    _kpiCard(
                      title: 'Total Stock In (+)',
                      value: '+$totalIn units',
                      subtitle: 'Purchased from suppliers',
                      icon: Icons.move_to_inbox_outlined,
                      color: Colors.green.shade700,
                      context: context,
                    ),
                    _kpiCard(
                      title: 'Total Stock Out (-)',
                      value: '-$totalOut units',
                      subtitle: 'Sold to students & customers',
                      icon: Icons.outbox_outlined,
                      color: Colors.orange.shade700,
                      context: context,
                    ),
                    _kpiCard(
                      title: 'Low Stock Alerts',
                      value: '${report.lowStockCount}',
                      subtitle: report.lowStockCount > 0 ? 'Need immediate reorder' : 'All stocks healthy',
                      icon: Icons.warning_amber_outlined,
                      color: report.lowStockCount > 0 ? Colors.red.shade700 : Colors.green.shade700,
                      context: context,
                    ),
                  ],
                );
              },
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),

        // Sub-View Selector & Actions Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.inventory_2_outlined, size: 16),
                  label: Text('Current Stock Levels (Catalog)'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.history, size: 16),
                  label: Text('In & Out Stock Ledger (Movement Log)'),
                ),
              ],
              selected: {_viewIndex},
              onSelectionChanged: (set) => setState(() => _viewIndex = set.first),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_vert, size: 16),
                  label: const Text('Stock In / Out'),
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => const StockMovementDialog(),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: const Text('Reconcile Count'),
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => const StockReconcileDialog(),
                  ),
                ),
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
        const SizedBox(height: 14),

        // Sub-View Content
        Expanded(
          child: _viewIndex == 0
              // VIEW A: Current Stock Levels (Catalog)
              ? Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Filter bar
                      Row(
                        children: [
                          SizedBox(
                            width: 260,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search catalog by item name...',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) => setState(() => _itemSearch = val.toLowerCase().trim()),
                            ),
                          ),
                          const SizedBox(width: 14),
                          categoriesAsync.when(
                            data: (categories) => SizedBox(
                              width: 200,
                              child: DropdownButtonFormField<int?>(
                                initialValue: selectedCat,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: [
                                  const DropdownMenuItem(child: Text('All Categories')),
                                  ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                                ],
                                onChanged: (id) => ref.read(inventoryFilterCategoryProvider.notifier).state = id,
                              ),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 14),
                          FilterChip(
                            label: const Text('Low Stock Alerts Only'),
                            selected: lowStockOnly,
                            onSelected: (val) => ref.read(inventoryFilterLowStockProvider.notifier).state = val,
                            selectedColor: Colors.amber.shade100,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Items Table
                      Expanded(
                        child: itemsAsync.when(
                          data: (items) {
                            final filtered = items.where((it) {
                              if (_itemSearch.isNotEmpty && !it.name.toLowerCase().contains(_itemSearch)) {
                                return false;
                              }
                              return true;
                            }).toList();

                            if (filtered.isEmpty) {
                              return Center(
                                child: Text(
                                  _itemSearch.isEmpty
                                      ? 'No inventory items registered.\nClick "Add Item" to add items to catalog.'
                                      : 'No items match your search.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textMuted),
                                ),
                              );
                            }

                            return Scrollbar(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingRowHeight: 40,
                                    dataRowMinHeight: 48,
                                    dataRowMaxHeight: 52,
                                    columns: const [
                                      DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Current In Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Unit Cost', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Total Asset Value', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Reorder Limit', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: filtered.map((it) {
                                      final isLow = it.isLowStock;
                                      final totalValuation = it.unitCost * it.quantityOnHand;

                                      return DataRow(
                                        cells: [
                                          DataCell(Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                          DataCell(Text(it.categoryName)),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isLow ? Colors.red.shade50 : Colors.green.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isLow ? Colors.red.shade200 : Colors.green.shade200,
                                                ),
                                              ),
                                              child: Text(
                                                '${it.quantityOnHand} ${it.unit}${isLow ? " (Low Stock)" : ""}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isLow ? Colors.red.shade800 : Colors.green.shade800,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(it.unitCost.format())),
                                          DataCell(Text(it.sellingPrice.format())),
                                          DataCell(Text(totalValuation.format(), style: const TextStyle(fontWeight: FontWeight.bold))),
                                          DataCell(Text('${it.reorderLevel} ${it.unit}', style: const TextStyle(color: AppColors.textMuted))),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Center(child: Text('Error: $err')),
                        ),
                      ),
                    ],
                  ),
                )
              // VIEW B: In & Out Movements Ledger (Audit Log)
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search bar
                      Row(
                        children: [
                          SizedBox(
                            width: 320,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search movement log by item or reason...',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (val) => setState(() => _movementSearch = val.toLowerCase().trim()),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Append-only immutable stock transaction trail',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Movements Table
                      Expanded(
                        child: movementsAsync.when(
                          data: (movements) {
                            final filtered = movements.where((m) {
                              if (_movementSearch.isNotEmpty) {
                                final itemMatch = m.itemName.toLowerCase().contains(_movementSearch);
                                final reasonMatch = m.reason.toLowerCase().contains(_movementSearch);
                                if (!itemMatch && !reasonMatch) return false;
                              }
                              return true;
                            }).toList();

                            if (filtered.isEmpty) {
                              return Center(
                                child: Text(
                                  _movementSearch.isEmpty
                                      ? 'No stock movements recorded yet.'
                                      : 'No movements match your search.',
                                  style: const TextStyle(color: AppColors.textMuted),
                                ),
                              );
                            }

                            return Scrollbar(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingRowHeight: 40,
                                    dataRowMinHeight: 48,
                                    dataRowMaxHeight: 52,
                                    columns: const [
                                      DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Movement Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Unit Cost', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Reason & Document Ref', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: filtered.map((m) {
                                      final isIn = m.movementType == 'in';
                                      final isOut = m.movementType == 'out';

                                      return DataRow(
                                        cells: [
                                          DataCell(Text(DateFormat('dd/MM/yyyy HH:mm').format(m.movementDate))),
                                          DataCell(Text(m.itemName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isIn
                                                    ? Colors.green.shade50
                                                    : (isOut ? Colors.orange.shade50 : Colors.blue.shade50),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: isIn
                                                      ? Colors.green.shade200
                                                      : (isOut ? Colors.orange.shade200 : Colors.blue.shade200),
                                                ),
                                              ),
                                              child: Text(
                                                isIn ? '🟢 Stock In (+)' : (isOut ? '🔴 Stock Out (-)' : '🔵 Adjustment'),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isIn
                                                      ? Colors.green.shade800
                                                      : (isOut ? Colors.orange.shade800 : Colors.blue.shade800),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${isIn ? "+" : (isOut ? "-" : "")}${m.quantity}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isIn ? Colors.green.shade800 : (isOut ? Colors.orange.shade800 : null),
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(m.unitCost.format())),
                                          DataCell(
                                            Text(
                                              m.reason,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
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
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required BuildContext context,
  }) {
    return Container(
      width: 195,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderCol(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
