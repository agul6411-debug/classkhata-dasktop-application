/// Inventory repository implementation.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/money/money.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_dao.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryDao _dao;
  const InventoryRepositoryImpl(this._dao);

  @override
  Future<Result<List<InventoryCategory>>> getCategories() async {
    try {
      final rows = await _dao.getCategories();
      final list = rows
          .map((r) => InventoryCategory(
                id: r.id,
                name: r.name,
                description: r.description,
              ))
          .toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getCategories error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch inventory categories.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<InventoryCategory>> createCategory({
    required String name,
    String? description,
    required int createdBy,
  }) async {
    try {
      final id = await _dao.insertCategory(
        InventoryCategoriesTableCompanion.insert(
          name: name,
          description: Value(description),
          createdBy: Value(createdBy),
        ),
      );
      return Success(InventoryCategory(id: id, name: name, description: description));
    } catch (e, st) {
      await AppLogger.instance.error('createCategory error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not create category.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<InventoryItem>>> getItems({int? categoryId, bool? lowStockOnly}) async {
    try {
      final rows = await _dao.getItems(categoryId: categoryId, lowStockOnly: lowStockOnly);
      final categories = await _dao.getCategories();
      final catMap = {for (var c in categories) c.id: c.name};

      final list = rows
          .map((r) => InventoryItem(
                id: r.id,
                categoryId: r.categoryId,
                categoryName: catMap[r.categoryId] ?? 'General',
                name: r.name,
                unit: r.unit,
                quantityOnHand: r.quantityOnHand,
                unitCost: Money.fromPaisa(r.unitCostPaisa),
                sellingPrice: Money.fromPaisa(r.sellingPricePaisa),
                reorderLevel: r.reorderLevel,
              ))
          .toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getItems error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch inventory items.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<InventoryItem>> createItem({
    required int categoryId,
    required String name,
    required String unit,
    required int initialQuantity,
    required Money unitCost,
    Money sellingPrice = const Money(0),
    required int reorderLevel,
    required int createdBy,
  }) async {
    try {
      final id = await _dao.insertItem(
        InventoryItemsTableCompanion.insert(
          categoryId: categoryId,
          name: name,
          unit: Value(unit),
          quantityOnHand: Value(initialQuantity),
          unitCostPaisa: Value(unitCost.paisa),
          sellingPricePaisa: Value(sellingPrice.paisa),
          reorderLevel: Value(reorderLevel),
          createdBy: Value(createdBy),
        ),
      );

      final categories = await _dao.getCategories();
      final catName = categories.firstWhere((c) => c.id == categoryId, orElse: () => categories.first).name;

      return Success(InventoryItem(
        id: id,
        categoryId: categoryId,
        categoryName: catName,
        name: name,
        unit: unit,
        quantityOnHand: initialQuantity,
        unitCost: unitCost,
        sellingPrice: sellingPrice,
        reorderLevel: reorderLevel,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('createItem error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not create item.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<InventoryItem>>> getLowStockItems() async {
    try {
      final rows = await _dao.getLowStockItems();
      final categories = await _dao.getCategories();
      final catMap = {for (var c in categories) c.id: c.name};

      final list = rows
          .map((r) => InventoryItem(
                id: r.id,
                categoryId: r.categoryId,
                categoryName: catMap[r.categoryId] ?? 'General',
                name: r.name,
                unit: r.unit,
                quantityOnHand: r.quantityOnHand,
                unitCost: Money.fromPaisa(r.unitCostPaisa),
                sellingPrice: Money.fromPaisa(r.sellingPricePaisa),
                reorderLevel: r.reorderLevel,
              ))
          .toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getLowStockItems error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch low stock alerts.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<InventoryMovement>> recordMovement({
    required int itemId,
    required String movementType,
    required int quantity,
    required Money unitCost,
    required String reason,
    String? referenceNumber,
    required int createdBy,
    bool allowNegativeStock = false,
  }) async {
    try {
      final res = await _dao.recordMovementTransaction(
        itemId: itemId,
        movementType: movementType,
        quantity: quantity,
        unitCostPaisa: unitCost.paisa,
        reason: reason,
        referenceNumber: referenceNumber,
        createdBy: createdBy,
        allowNegativeStock: allowNegativeStock,
      );

      return Success(InventoryMovement(
        id: res.movement.id,
        itemId: res.movement.itemId,
        itemName: res.itemName,
        movementType: res.movement.movementType,
        quantity: res.movement.quantity,
        unitCost: Money.fromPaisa(res.movement.unitCostPaisa),
        reason: res.movement.reason,
        referenceNumber: res.movement.referenceNumber,
        movementDate: res.movement.movementDate,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('recordMovement error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not record movement: ${e.toString()}'));
    }
  }

  @override
  Future<Result<List<InventoryMovement>>> getMovements({int? itemId}) async {
    try {
      final rows = await _dao.getMovements(itemId: itemId);
      final items = await _dao.getItems();
      final itemMap = {for (var i in items) i.id: i.name};

      final list = rows
          .map((r) => InventoryMovement(
                id: r.id,
                itemId: r.itemId,
                itemName: itemMap[r.itemId] ?? 'Item #${r.itemId}',
                movementType: r.movementType,
                quantity: r.quantity,
                unitCost: Money.fromPaisa(r.unitCostPaisa),
                reason: r.reason,
                referenceNumber: r.referenceNumber,
                movementDate: r.movementDate,
              ))
          .toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getMovements error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch movements.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<Supplier>>> getSuppliers() async {
    try {
      final rows = await _dao.getSuppliers();
      final list = rows
          .map((r) => Supplier(
                id: r.id,
                name: r.name,
                contactPerson: r.contactPerson,
                phone: r.phone,
                email: r.email,
                address: r.address,
                openingBalance: Money.fromPaisa(r.openingBalancePaisa),
                currentBalance: Money.fromPaisa(r.currentBalancePaisa),
              ))
          .toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getSuppliers error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch suppliers.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<Supplier>> createSupplier({
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    Money openingBalance = const Money(0),
    required int createdBy,
  }) async {
    try {
      final id = await _dao.insertSupplier(
        SuppliersTableCompanion.insert(
          name: name,
          contactPerson: Value(contactPerson),
          phone: Value(phone),
          email: Value(email),
          address: Value(address),
          openingBalancePaisa: Value(openingBalance.paisa),
          currentBalancePaisa: Value(openingBalance.paisa),
          createdBy: Value(createdBy),
        ),
      );

      return Success(Supplier(
        id: id,
        name: name,
        contactPerson: contactPerson,
        phone: phone,
        email: email,
        address: address,
        openingBalance: openingBalance,
        currentBalance: openingBalance,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('createSupplier error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not create supplier.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<List<SupplierLedgerEntry>>> getSupplierLedger(int supplierId) async {
    try {
      final rows = await _dao.getSupplierLedger(supplierId);
      final list = rows
          .map((r) => SupplierLedgerEntry(
                id: r.id,
                supplierId: r.supplierId,
                transactionType: r.transactionType,
                amount: Money.fromPaisa(r.amountPaisa),
                referenceNumber: r.referenceNumber,
                notes: r.notes,
                transactionDate: r.transactionDate,
              ))
          .toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getSupplierLedger error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch supplier ledger.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<void>> recordSupplierPayment({
    required int supplierId,
    required Money amount,
    required String paymentMode,
    String? notes,
    String? referenceNumber,
    required int createdBy,
  }) async {
    try {
      await _dao.recordSupplierPaymentTransaction(
        supplierId: supplierId,
        amountPaisa: amount.paisa,
        paymentMode: paymentMode,
        notes: notes,
        referenceNumber: referenceNumber,
        createdBy: createdBy,
      );
      return const Success(null);
    } catch (e, st) {
      await AppLogger.instance.error('recordSupplierPayment error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not record supplier payment: ${e.toString()}'));
    }
  }

  @override
  Future<Result<PurchaseRecord>> recordPurchase({
    required String purchaseNumber,
    required int supplierId,
    required List<({int itemId, int quantity, Money unitCost})> items,
    required Money paidAmount,
    required String paymentMode,
    String? invoiceNumber,
    String? notes,
    required int createdBy,
  }) async {
    try {
      final rawItems = items
          .map((i) => (
                itemId: i.itemId,
                quantity: i.quantity,
                unitCostPaisa: i.unitCost.paisa,
              ))
          .toList();

      final purchase = await _dao.recordPurchaseTransaction(
        purchaseNumber: purchaseNumber,
        supplierId: supplierId,
        items: rawItems,
        paidAmountPaisa: paidAmount.paisa,
        paymentMode: paymentMode,
        invoiceNumber: invoiceNumber,
        notes: notes,
        createdBy: createdBy,
      );

      final supplier = await _dao.getSupplierById(supplierId);
      final purchaseLineRows = await _dao.getPurchaseItems(purchase.id);
      final itemCatalog = await _dao.getItems();
      final itemMap = {for (var it in itemCatalog) it.id: it.name};

      final lines = purchaseLineRows
          .map((r) => PurchaseLineItem(
                id: r.id,
                purchaseId: r.purchaseId,
                itemId: r.itemId,
                itemName: itemMap[r.itemId] ?? 'Item #${r.itemId}',
                quantity: r.quantity,
                unitCost: Money.fromPaisa(r.unitCostPaisa),
                totalCost: Money.fromPaisa(r.totalCostPaisa),
              ))
          .toList();

      return Success(PurchaseRecord(
        id: purchase.id,
        purchaseNumber: purchase.purchaseNumber,
        supplierId: purchase.supplierId,
        supplierName: supplier.name,
        totalAmount: Money.fromPaisa(purchase.totalAmountPaisa),
        paidAmount: Money.fromPaisa(purchase.paidAmountPaisa),
        paymentMode: purchase.paymentMode,
        invoiceNumber: purchase.invoiceNumber,
        notes: purchase.notes,
        purchaseDate: purchase.purchaseDate,
        items: lines,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('recordPurchase error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not record purchase: ${e.toString()}'));
    }
  }

  @override
  Future<Result<List<PurchaseRecord>>> getPurchases({int? supplierId}) async {
    try {
      final rows = await _dao.getPurchases(supplierId: supplierId);
      final suppliers = await _dao.getSuppliers();
      final supMap = {for (var s in suppliers) s.id: s.name};

      final list = <PurchaseRecord>[];
      for (final r in rows) {
        list.add(PurchaseRecord(
          id: r.id,
          purchaseNumber: r.purchaseNumber,
          supplierId: r.supplierId,
          supplierName: supMap[r.supplierId] ?? 'Supplier #${r.supplierId}',
          totalAmount: Money.fromPaisa(r.totalAmountPaisa),
          paidAmount: Money.fromPaisa(r.paidAmountPaisa),
          paymentMode: r.paymentMode,
          invoiceNumber: r.invoiceNumber,
          notes: r.notes,
          purchaseDate: r.purchaseDate,
        ));
      }
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getPurchases error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch purchases.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<ItemIssuance>> issueItem({
    required int itemId,
    required int quantity,
    required Money unitPrice,
    required String recipientType,
    int? studentId,
    int? staffId,
    int? feeVoucherId,
    required String reason,
    required int createdBy,
    bool allowNegativeStock = false,
  }) async {
    try {
      final row = await _dao.issueItemTransaction(
        itemId: itemId,
        quantity: quantity,
        unitPricePaisa: unitPrice.paisa,
        recipientType: recipientType,
        studentId: studentId,
        staffId: staffId,
        feeVoucherId: feeVoucherId,
        reason: reason,
        createdBy: createdBy,
        allowNegativeStock: allowNegativeStock,
      );

      final item = await _dao.getItemById(itemId);

      return Success(ItemIssuance(
        id: row.id,
        itemId: row.itemId,
        itemName: item.name,
        quantity: row.quantity,
        unitPrice: Money.fromPaisa(row.unitPricePaisa),
        recipientType: row.recipientType,
        studentId: row.studentId,
        staffId: row.staffId,
        feeVoucherId: row.feeVoucherId,
        reason: row.reason,
        issuedDate: row.issuedDate,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('issueItem error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not issue item: ${e.toString()}'));
    }
  }

  @override
  Future<Result<List<ItemIssuance>>> getItemIssuances({int? itemId, int? studentId, int? staffId}) async {
    try {
      final rows = await _dao.getItemIssuances(itemId: itemId, studentId: studentId, staffId: staffId);
      final items = await _dao.getItems();
      final itemMap = {for (var i in items) i.id: i.name};

      final list = rows
          .map((r) => ItemIssuance(
                id: r.id,
                itemId: r.itemId,
                itemName: itemMap[r.itemId] ?? 'Item #${r.itemId}',
                quantity: r.quantity,
                unitPrice: Money.fromPaisa(r.unitPricePaisa),
                recipientType: r.recipientType,
                studentId: r.studentId,
                staffId: r.staffId,
                feeVoucherId: r.feeVoucherId,
                reason: r.reason,
                issuedDate: r.issuedDate,
              ))
          .toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getItemIssuances error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch issuances.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<({StockTakeRecord? record, bool requiresApproval, int? approvalId})>> reconcileStock({
    required int itemId,
    required int actualQuantity,
    String? reason,
    required int reconciledBy,
    Money approvalThreshold = const Money(500000),
  }) async {
    try {
      final res = await _dao.reconcileStockTransaction(
        itemId: itemId,
        actualQuantity: actualQuantity,
        reason: reason,
        reconciledBy: reconciledBy,
        approvalThresholdPaisa: approvalThreshold.paisa,
      );

      StockTakeRecord? record;
      if (res.stockTake != null) {
        record = StockTakeRecord(
          id: res.stockTake!.id,
          itemId: res.stockTake!.itemId,
          itemName: res.itemName,
          recordedQuantity: res.stockTake!.recordedQuantity,
          actualQuantity: res.stockTake!.actualQuantity,
          discrepancy: res.stockTake!.discrepancy,
          reason: res.stockTake!.reason,
          reconciledAt: res.stockTake!.reconciledAt,
        );
      }

      return Success((
        record: record,
        requiresApproval: res.requiresApproval,
        approvalId: res.approvalId,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('reconcileStock error', error: e, stack: st);
      return Failure(DatabaseFailure('Stock reconciliation failed: ${e.toString()}'));
    }
  }

  @override
  Future<Result<StockValuationReport>> getStockValuation() async {
    try {
      final items = await _dao.getItems();
      final categories = await _dao.getCategories();
      final catMap = {for (var c in categories) c.id: c.name};

      int totalValuationPaisa = 0;
      int lowStockCount = 0;
      final valItems = <StockValuationItem>[];

      for (final item in items) {
        final lineVal = item.quantityOnHand * item.unitCostPaisa;
        totalValuationPaisa += lineVal;
        final isLow = item.quantityOnHand <= item.reorderLevel;
        if (isLow) lowStockCount++;

        valItems.add(StockValuationItem(
          itemId: item.id,
          itemName: item.name,
          categoryName: catMap[item.categoryId] ?? 'General',
          unit: item.unit,
          quantityOnHand: item.quantityOnHand,
          unitCost: Money.fromPaisa(item.unitCostPaisa),
          totalValuation: Money.fromPaisa(lineVal),
          reorderLevel: item.reorderLevel,
          isLowStock: isLow,
        ));
      }

      return Success(StockValuationReport(
        items: valItems,
        totalInventoryValue: Money.fromPaisa(totalValuationPaisa),
        totalItemsCount: items.length,
        lowStockCount: lowStockCount,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('getStockValuation error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not compute stock valuation: ${e.toString()}'));
    }
  }
}
