/// Inventory DAO executing transactional stock movements, purchases, issuances,
/// supplier ledgers, and reconciliations.
///
/// Rules:
///   - Strictly NO barcode columns or features.
///   - All currency values stored as INTEGER (paisa).
///   - Stock quantity is never stored as an editable number: derived from
///     append-only stock movements (with cached balance updated strictly inside
///     the same transaction as the movement).
///   - Purchase payments create Cash Book entries in the exact same transaction.
///   - Item issuances can link to Fee Vouchers to charge student accounts.
library;

import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class InventoryDao {
  const InventoryDao(this._db);
  final AppDatabase _db;

  AppDatabase get db => _db;

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  Future<List<InventoryCategoriesTableData>> getCategories() =>
      (_db.select(_db.inventoryCategoriesTable)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<int> insertCategory(InventoryCategoriesTableCompanion companion) =>
      _db.into(_db.inventoryCategoriesTable).insert(companion);

  // ---------------------------------------------------------------------------
  // Items Catalog
  // ---------------------------------------------------------------------------

  Future<List<InventoryItemsTableData>> getItems({int? categoryId, bool? lowStockOnly}) {
    final query = _db.select(_db.inventoryItemsTable);
    if (categoryId != null) query.where((t) => t.categoryId.equals(categoryId));
    if (lowStockOnly ?? false) {
      query.where((t) => t.quantityOnHand.isSmallerOrEqual(t.reorderLevel));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.get();
  }

  Future<InventoryItemsTableData> getItemById(int itemId) =>
      (_db.select(_db.inventoryItemsTable)..where((t) => t.id.equals(itemId))).getSingle();

  Future<int> insertItem(InventoryItemsTableCompanion companion) =>
      _db.into(_db.inventoryItemsTable).insert(companion);

  Future<List<InventoryItemsTableData>> getLowStockItems() {
    return (_db.select(_db.inventoryItemsTable)
          ..where((t) => t.quantityOnHand.isSmallerOrEqual(t.reorderLevel))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Stock Movements (In / Out / Adjustment - Transactional)
  // ---------------------------------------------------------------------------

  Future<({InventoryMovementsTableData movement, String itemName})> recordMovementTransaction({
    required int itemId,
    required String movementType,
    required int quantity,
    required int unitCostPaisa,
    required String reason,
    String? referenceNumber,
    required int createdBy,
    bool allowNegativeStock = false,
  }) async {
    return _db.transaction(() async {
      final item = await (_db.select(_db.inventoryItemsTable)..where((t) => t.id.equals(itemId))).getSingle();

      int newQty = item.quantityOnHand;
      if (movementType == 'in') {
        newQty += quantity;
      } else if (movementType == 'out') {
        if (quantity > item.quantityOnHand && !allowNegativeStock) {
          throw Exception('Cannot issue $quantity units. Only ${item.quantityOnHand} available on hand.');
        }
        newQty -= quantity;
      } else {
        newQty = quantity; // Adjustment
      }

      // 1. Update on-hand count inside same transaction
      await (_db.update(_db.inventoryItemsTable)..where((t) => t.id.equals(itemId))).write(
        InventoryItemsTableCompanion(
          quantityOnHand: Value(newQty),
          unitCostPaisa: Value(unitCostPaisa > 0 ? unitCostPaisa : item.unitCostPaisa),
        ),
      );

      // 2. Insert movement record
      final movementId = await _db.into(_db.inventoryMovementsTable).insert(
            InventoryMovementsTableCompanion.insert(
              itemId: itemId,
              movementType: movementType,
              quantity: quantity,
              unitCostPaisa: Value(unitCostPaisa > 0 ? unitCostPaisa : item.unitCostPaisa),
              reason: reason,
              referenceNumber: Value(referenceNumber),
              createdBy: Value(createdBy),
            ),
          );

      final mov = await (_db.select(_db.inventoryMovementsTable)..where((t) => t.id.equals(movementId))).getSingle();
      return (movement: mov, itemName: item.name);
    });
  }

  Future<List<InventoryMovementsTableData>> getMovements({int? itemId}) {
    final query = _db.select(_db.inventoryMovementsTable);
    if (itemId != null) query.where((t) => t.itemId.equals(itemId));
    query.orderBy([(t) => OrderingTerm.desc(t.movementDate)]);
    return query.get();
  }

  // ---------------------------------------------------------------------------
  // Stock-Take Reconciliation & Shrinkage (Atomic Transaction with Maker-Checker)
  // ---------------------------------------------------------------------------

  Future<({StockTakesTableData? stockTake, String itemName, bool requiresApproval, int? approvalId})>
      reconcileStockTransaction({
    required int itemId,
    required int actualQuantity,
    String? reason,
    required int reconciledBy,
    int approvalThresholdPaisa = 500000, // 5,000 PKR default threshold for maker-checker
  }) async {
    return _db.transaction(() async {
      final item = await (_db.select(_db.inventoryItemsTable)..where((t) => t.id.equals(itemId))).getSingle();
      final discrepancy = actualQuantity - item.quantityOnHand;
      final discrepancyValuePaisa = discrepancy.abs() * item.unitCostPaisa;

      // Escalation to maker-checker if discrepancy value exceeds threshold
      if (discrepancyValuePaisa > approvalThresholdPaisa) {
        final payload = jsonEncode({
          'itemId': itemId,
          'itemName': item.name,
          'recordedQuantity': item.quantityOnHand,
          'actualQuantity': actualQuantity,
          'discrepancy': discrepancy,
          'discrepancyValuePaisa': discrepancyValuePaisa,
          'reason': reason,
        });

        final approvalId = await _db.into(_db.approvalRequestsTable).insert(
              ApprovalRequestsTableCompanion.insert(
                type: 'stock_adjustment',
                entityType: 'inventory_item',
                entityId: itemId.toString(),
                requestedBy: reconciledBy,
                reason: reason ?? 'Large stock take discrepancy ($discrepancy units)',
                payload: payload,
              ),
            );

        return (stockTake: null, itemName: item.name, requiresApproval: true, approvalId: approvalId);
      }

      // Under threshold: Apply reconciliation directly
      await (_db.update(_db.inventoryItemsTable)..where((t) => t.id.equals(itemId))).write(
        InventoryItemsTableCompanion(
          quantityOnHand: Value(actualQuantity),
        ),
      );

      final takeId = await _db.into(_db.stockTakesTable).insert(
            StockTakesTableCompanion.insert(
              itemId: itemId,
              recordedQuantity: item.quantityOnHand,
              actualQuantity: actualQuantity,
              discrepancy: discrepancy,
              reason: Value(reason),
              reconciledBy: reconciledBy,
            ),
          );

      // Append adjustment movement
      await _db.into(_db.inventoryMovementsTable).insert(
            InventoryMovementsTableCompanion.insert(
              itemId: itemId,
              movementType: 'adjustment',
              quantity: discrepancy.abs(),
              unitCostPaisa: Value(item.unitCostPaisa),
              reason: 'Stock Take Reconciliation: ${reason ?? "Inventory Audit Adjustment"}',
              createdBy: Value(reconciledBy),
            ),
          );

      final rec = await (_db.select(_db.stockTakesTable)..where((t) => t.id.equals(takeId))).getSingle();
      return (stockTake: rec, itemName: item.name, requiresApproval: false, approvalId: null);
    });
  }

  // ---------------------------------------------------------------------------
  // Suppliers & Supplier Ledger
  // ---------------------------------------------------------------------------

  Future<List<SuppliersTableData>> getSuppliers() =>
      (_db.select(_db.suppliersTable)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<SuppliersTableData> getSupplierById(int supplierId) =>
      (_db.select(_db.suppliersTable)..where((t) => t.id.equals(supplierId))).getSingle();

  Future<int> insertSupplier(SuppliersTableCompanion companion) =>
      _db.into(_db.suppliersTable).insert(companion);

  Future<List<SupplierLedgerTableData>> getSupplierLedger(int supplierId) =>
      (_db.select(_db.supplierLedgerTable)
            ..where((t) => t.supplierId.equals(supplierId))
            ..orderBy([(t) => OrderingTerm.asc(t.transactionDate)]))
          .get();

  Future<void> recordSupplierPaymentTransaction({
    required int supplierId,
    required int amountPaisa,
    required String paymentMode,
    String? notes,
    String? referenceNumber,
    required int createdBy,
  }) async {
    return _db.transaction(() async {
      final supplier = await getSupplierById(supplierId);

      // 1. Insert supplier ledger entry
      await _db.into(_db.supplierLedgerTable).insert(
            SupplierLedgerTableCompanion.insert(
              supplierId: supplierId,
              transactionType: 'payment',
              amountPaisa: amountPaisa,
              referenceNumber: Value(referenceNumber),
              notes: Value(notes ?? 'Payment to supplier ${supplier.name}'),
              createdBy: Value(createdBy),
            ),
          );

      // 2. Reduce supplier balance
      final newBalance = supplier.currentBalancePaisa - amountPaisa;
      await (_db.update(_db.suppliersTable)..where((t) => t.id.equals(supplierId))).write(
        SuppliersTableCompanion(
          currentBalancePaisa: Value(newBalance),
        ),
      );

      // 3. Create Cash Book Outflow entry in the exact same transaction
      await _db.into(_db.cashBookEntriesTable).insert(
            CashBookEntriesTableCompanion.insert(
              entryType: 'outflow',
              category: 'inventory',
              amountPaisa: amountPaisa,
              description: 'Supplier payment: ${supplier.name} - ${notes ?? ""}',
              paymentMode: Value(paymentMode),
              referenceId: Value(supplierId),
              createdBy: Value(createdBy),
            ),
          );
    });
  }

  // ---------------------------------------------------------------------------
  // Purchases (Multi-Item Purchase Transaction with Supplier Ledger & Cash Book)
  // ---------------------------------------------------------------------------

  Future<PurchasesTableData> recordPurchaseTransaction({
    required String purchaseNumber,
    required int supplierId,
    required List<({int itemId, int quantity, int unitCostPaisa})> items,
    required int paidAmountPaisa,
    required String paymentMode,
    String? invoiceNumber,
    String? notes,
    required int createdBy,
  }) async {
    return _db.transaction(() async {
      final supplier = await getSupplierById(supplierId);

      int totalAmountPaisa = 0;
      for (final it in items) {
        totalAmountPaisa += it.quantity * it.unitCostPaisa;
      }

      // 1. Insert Purchase Header
      final purchaseId = await _db.into(_db.purchasesTable).insert(
            PurchasesTableCompanion.insert(
              purchaseNumber: purchaseNumber,
              supplierId: supplierId,
              totalAmountPaisa: totalAmountPaisa,
              paidAmountPaisa: Value(paidAmountPaisa),
              paymentMode: Value(paymentMode),
              invoiceNumber: Value(invoiceNumber),
              notes: Value(notes),
              createdBy: Value(createdBy),
            ),
          );

      // 2. Insert line items, stock movements, and update on-hand balance
      for (final it in items) {
        final lineTotal = it.quantity * it.unitCostPaisa;
        await _db.into(_db.purchaseItemsTable).insert(
              PurchaseItemsTableCompanion.insert(
                purchaseId: purchaseId,
                itemId: it.itemId,
                quantity: it.quantity,
                unitCostPaisa: it.unitCostPaisa,
                totalCostPaisa: lineTotal,
              ),
            );

        final currentItem =
            await (_db.select(_db.inventoryItemsTable)..where((t) => t.id.equals(it.itemId))).getSingle();
        final newQty = currentItem.quantityOnHand + it.quantity;

        // Update item quantity on hand and latest unit cost
        await (_db.update(_db.inventoryItemsTable)..where((t) => t.id.equals(it.itemId))).write(
          InventoryItemsTableCompanion(
            quantityOnHand: Value(newQty),
            unitCostPaisa: Value(it.unitCostPaisa),
          ),
        );

        // Record stock in movement
        await _db.into(_db.inventoryMovementsTable).insert(
              InventoryMovementsTableCompanion.insert(
                itemId: it.itemId,
                movementType: 'in',
                quantity: it.quantity,
                unitCostPaisa: Value(it.unitCostPaisa),
                reason: 'Purchase: $purchaseNumber',
                referenceNumber: Value(invoiceNumber ?? purchaseNumber),
                createdBy: Value(createdBy),
              ),
            );
      }

      // 3. Insert Purchase into Supplier Ledger
      await _db.into(_db.supplierLedgerTable).insert(
            SupplierLedgerTableCompanion.insert(
              supplierId: supplierId,
              transactionType: 'purchase',
              amountPaisa: totalAmountPaisa,
              referenceNumber: Value(purchaseNumber),
              notes: Value(notes ?? 'Purchase $purchaseNumber'),
              createdBy: Value(createdBy),
            ),
          );

      // 4. Update supplier balance (unpaid balance added to ledger)
      final balanceDelta = totalAmountPaisa - paidAmountPaisa;
      final newSupplierBalance = supplier.currentBalancePaisa + balanceDelta;
      await (_db.update(_db.suppliersTable)..where((t) => t.id.equals(supplierId))).write(
        SuppliersTableCompanion(
          currentBalancePaisa: Value(newSupplierBalance),
        ),
      );

      // 5. If paid amount > 0, record supplier payment in ledger & cash book outflow
      if (paidAmountPaisa > 0) {
        await _db.into(_db.supplierLedgerTable).insert(
              SupplierLedgerTableCompanion.insert(
                supplierId: supplierId,
                transactionType: 'payment',
                amountPaisa: paidAmountPaisa,
                referenceNumber: Value(purchaseNumber),
                notes: Value('Payment on purchase $purchaseNumber'),
                createdBy: Value(createdBy),
              ),
            );

        await _db.into(_db.cashBookEntriesTable).insert(
              CashBookEntriesTableCompanion.insert(
                entryType: 'outflow',
                category: 'inventory',
                amountPaisa: paidAmountPaisa,
                description: 'Inventory Purchase: $purchaseNumber ($paymentMode)',
                paymentMode: Value(paymentMode),
                referenceId: Value(purchaseId),
                createdBy: Value(createdBy),
              ),
            );
      }

      return (_db.select(_db.purchasesTable)..where((t) => t.id.equals(purchaseId))).getSingle();
    });
  }

  Future<List<PurchasesTableData>> getPurchases({int? supplierId}) {
    final query = _db.select(_db.purchasesTable);
    if (supplierId != null) query.where((t) => t.supplierId.equals(supplierId));
    query.orderBy([(t) => OrderingTerm.desc(t.purchaseDate)]);
    return query.get();
  }

  Future<List<PurchaseItemsTableData>> getPurchaseItems(int purchaseId) =>
      (_db.select(_db.purchaseItemsTable)..where((t) => t.purchaseId.equals(purchaseId))).get();

  // ---------------------------------------------------------------------------
  // Item Issuance (To Students or Staff, with Optional Fee Voucher Linking)
  // ---------------------------------------------------------------------------

  Future<ItemIssuancesTableData> issueItemTransaction({
    required int itemId,
    required int quantity,
    required int unitPricePaisa,
    required String recipientType,
    int? studentId,
    int? staffId,
    int? feeVoucherId,
    required String reason,
    required int createdBy,
    bool allowNegativeStock = false,
  }) async {
    return _db.transaction(() async {
      final item = await getItemById(itemId);

      if (quantity > item.quantityOnHand && !allowNegativeStock) {
        throw Exception('Cannot issue $quantity units. Only ${item.quantityOnHand} available on hand.');
      }

      final newQty = item.quantityOnHand - quantity;

      // 1. Update on-hand count
      await (_db.update(_db.inventoryItemsTable)..where((t) => t.id.equals(itemId))).write(
        InventoryItemsTableCompanion(
          quantityOnHand: Value(newQty),
        ),
      );

      // 2. Insert stock movement (outflow)
      await _db.into(_db.inventoryMovementsTable).insert(
            InventoryMovementsTableCompanion.insert(
              itemId: itemId,
              movementType: 'out',
              quantity: quantity,
              unitCostPaisa: Value(item.unitCostPaisa),
              reason: 'Issued to $recipientType: $reason',
              referenceNumber: Value(feeVoucherId != null ? 'VCH-$feeVoucherId' : null),
              createdBy: Value(createdBy),
            ),
          );

      // 3. Insert issuance record
      final issuanceId = await _db.into(_db.itemIssuancesTable).insert(
            ItemIssuancesTableCompanion.insert(
              itemId: itemId,
              quantity: quantity,
              unitPricePaisa: Value(unitPricePaisa),
              recipientType: recipientType,
              studentId: Value(studentId),
              staffId: Value(staffId),
              feeVoucherId: Value(feeVoucherId),
              reason: reason,
              createdBy: Value(createdBy),
            ),
          );

      // 4. If linked to fee voucher, atomically add item charge to student's fee voucher
      if (feeVoucherId != null) {
        final voucher =
            await (_db.select(_db.feeVouchersTable)..where((t) => t.id.equals(feeVoucherId))).getSingle();
        final totalCharge = quantity * unitPricePaisa;
        final updatedBase = voucher.baseAmountPaisa + totalCharge;
        final updatedTotal = voucher.totalDuePaisa + totalCharge;

        await (_db.update(_db.feeVouchersTable)..where((t) => t.id.equals(feeVoucherId))).write(
          FeeVouchersTableCompanion(
            baseAmountPaisa: Value(updatedBase),
            totalDuePaisa: Value(updatedTotal),
          ),
        );
      } else if (unitPricePaisa > 0 && quantity > 0) {
        // 5. If sold directly for cash (not linked to voucher), record Cash Book Inflow
        final totalSalePaisa = quantity * unitPricePaisa;
        await _db.into(_db.cashBookEntriesTable).insert(
              CashBookEntriesTableCompanion.insert(
                entryType: 'inflow',
                category: 'inventory_sale',
                amountPaisa: totalSalePaisa,
                description: 'Store Sale: ${item.name} x$quantity ($recipientType)',
                paymentMode: const Value('cash'),
                referenceId: Value(issuanceId),
                createdBy: Value(createdBy),
              ),
            );
      }

      return (_db.select(_db.itemIssuancesTable)..where((t) => t.id.equals(issuanceId))).getSingle();
    });
  }

  Future<List<ItemIssuancesTableData>> getItemIssuances({int? itemId, int? studentId, int? staffId}) {
    final query = _db.select(_db.itemIssuancesTable);
    if (itemId != null) query.where((t) => t.itemId.equals(itemId));
    if (studentId != null) query.where((t) => t.studentId.equals(studentId));
    if (staffId != null) query.where((t) => t.staffId.equals(staffId));
    query.orderBy([(t) => OrderingTerm.desc(t.issuedDate)]);
    return query.get();
  }

  // ---------------------------------------------------------------------------
  // Stock Valuation
  // ---------------------------------------------------------------------------

  Future<({int totalValuationPaisa, int totalItemsCount, int lowStockCount})> getStockValuationSummary() async {
    final items = await _db.select(_db.inventoryItemsTable).get();
    int totalValuation = 0;
    int lowStock = 0;

    for (final item in items) {
      totalValuation += item.quantityOnHand * item.unitCostPaisa;
      if (item.quantityOnHand <= item.reorderLevel) {
        lowStock++;
      }
    }

    return (
      totalValuationPaisa: totalValuation,
      totalItemsCount: items.length,
      lowStockCount: lowStock,
    );
  }
}
