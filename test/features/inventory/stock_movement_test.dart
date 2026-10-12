import 'package:flutter_test/flutter_test.dart';
import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/core/security/permission_service.dart';
import 'package:classkhata/features/inventory/domain/entities/inventory_entities.dart';
import 'package:classkhata/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:classkhata/features/inventory/domain/usecases/inventory_usecases.dart';

void main() {
  group('Inventory Domain & Stock Movement Logic', () {
    test('Calculates low stock threshold and inventory asset valuation', () {
      final itemNormal = InventoryItem(
        id: 1,
        categoryId: 1,
        categoryName: 'Stationery',
        name: 'Whiteboard Markers',
        unit: 'box',
        quantityOnHand: 15,
        unitCost: Money.fromRupees(400),
        sellingPrice: Money.fromRupees(500),
        reorderLevel: 5,
      );

      expect(itemNormal.isLowStock, false);
      expect(itemNormal.totalValue.inRupees, 6000.0);

      final itemLow = InventoryItem(
        id: 2,
        categoryId: 1,
        categoryName: 'Stationery',
        name: 'A4 Paper Reams',
        unit: 'pack',
        quantityOnHand: 3,
        unitCost: Money.fromRupees(1200),
        sellingPrice: Money.fromRupees(1500),
        reorderLevel: 5,
      );

      expect(itemLow.isLowStock, true);
      expect(itemLow.totalValue.inRupees, 3600.0);
    });

    test('InventoryMovement identifies IN and OUT directions correctly', () {
      final movIn = InventoryMovement(
        id: 1,
        itemId: 10,
        itemName: 'Notebooks',
        movementType: 'in',
        quantity: 50,
        unitCost: Money.fromRupees(80),
        reason: 'Vendor Delivery',
        movementDate: DateTime.now(),
      );

      expect(movIn.isIn, true);
      expect(movIn.isOut, false);

      final movOut = InventoryMovement(
        id: 2,
        itemId: 10,
        itemName: 'Notebooks',
        movementType: 'out',
        quantity: 10,
        unitCost: Money.fromRupees(80),
        reason: 'Issued to Exam Dept',
        movementDate: DateTime.now(),
      );

      expect(movOut.isIn, false);
      expect(movOut.isOut, true);
    });

    test('StockTakeRecord detects discrepancies and shrinkage', () {
      final recordExact = StockTakeRecord(
        id: 1,
        itemId: 10,
        itemName: 'Notebooks',
        recordedQuantity: 40,
        actualQuantity: 40,
        discrepancy: 0,
        reconciledAt: DateTime.now(),
      );

      expect(recordExact.hasDiscrepancy, false);

      final recordLoss = StockTakeRecord(
        id: 2,
        itemId: 10,
        itemName: 'Notebooks',
        recordedQuantity: 40,
        actualQuantity: 36,
        discrepancy: -4,
        reason: 'Damaged / Water leak',
        reconciledAt: DateTime.now(),
      );

      expect(recordLoss.hasDiscrepancy, true);
      expect(recordLoss.discrepancy, -4);
    });

    test('CreateInventoryItemUseCase validates input constraints and permissions', () async {
      final useCase = CreateInventoryItemUseCase(_MockInventoryRepo());

      // Permission rejection
      final resDenied = await useCase(
        userPermissions: {Permission.inventoryView},
        categoryId: 1,
        name: 'Markers',
        unit: 'pcs',
        unitCost: Money.fromRupees(100),
        createdBy: 1,
      );
      expect(resDenied.isFailure, true);

      // Empty name
      final resEmpty = await useCase(
        userPermissions: {Permission.inventoryEdit},
        categoryId: 1,
        name: '   ',
        unit: 'pcs',
        unitCost: Money.fromRupees(100),
        createdBy: 1,
      );
      expect(resEmpty.isFailure, true);

      // Negative quantity
      final resNegQty = await useCase(
        userPermissions: {Permission.inventoryEdit},
        categoryId: 1,
        name: 'Markers',
        unit: 'pcs',
        initialQuantity: -5,
        unitCost: Money.fromRupees(100),
        createdBy: 1,
      );
      expect(resNegQty.isFailure, true);
    });

    test('RecordStockMovementUseCase enforces non-zero quantity, reason, and permissions', () async {
      final useCase = RecordStockMovementUseCase(_MockInventoryRepo());

      // Permission rejection
      final resDenied = await useCase(
        userPermissions: {Permission.inventoryView},
        itemId: 1,
        movementType: 'in',
        quantity: 5,
        unitCost: Money.fromRupees(50),
        reason: 'Purchase',
        createdBy: 1,
      );
      expect(resDenied.isFailure, true);

      // Zero quantity
      final resZero = await useCase(
        userPermissions: {Permission.inventoryStockIn},
        itemId: 1,
        movementType: 'in',
        quantity: 0,
        unitCost: Money.fromRupees(50),
        reason: 'Purchase',
        createdBy: 1,
      );
      expect(resZero.isFailure, true);

      // Empty reason
      final resEmptyReason = await useCase(
        userPermissions: {Permission.inventoryStockIn},
        itemId: 1,
        movementType: 'in',
        quantity: 5,
        unitCost: Money.fromRupees(50),
        reason: '  ',
        createdBy: 1,
      );
      expect(resEmptyReason.isFailure, true);
    });

    test('StockReconciliationUseCase enforces non-negative count and permission', () async {
      final useCase = StockReconciliationUseCase(_MockInventoryRepo());

      // Permission rejection
      final resDenied = await useCase(
        userPermissions: {Permission.inventoryView},
        itemId: 1,
        actualQuantity: 10,
        reconciledBy: 1,
      );
      expect(resDenied.isFailure, true);

      // Negative actual count
      final resNeg = await useCase(
        userPermissions: {Permission.inventoryEdit},
        itemId: 1,
        actualQuantity: -2,
        reconciledBy: 1,
      );
      expect(resNeg.isFailure, true);
    });

    test('RecordPurchaseUseCase enforces non-empty item list and permissions', () async {
      final useCase = RecordPurchaseUseCase(_MockInventoryRepo());

      // Permission rejection
      final resDenied = await useCase(
        userPermissions: {Permission.inventoryView},
        purchaseNumber: 'PUR-001',
        supplierId: 1,
        items: [(itemId: 1, quantity: 10, unitCost: Money.fromRupees(100))],
        paidAmount: Money.fromRupees(1000),
        paymentMode: 'cash',
        createdBy: 1,
      );
      expect(resDenied.isFailure, true);

      // Empty items
      final resEmpty = await useCase(
        userPermissions: {Permission.inventoryStockIn},
        purchaseNumber: 'PUR-001',
        supplierId: 1,
        items: [],
        paidAmount: Money.fromRupees(0),
        paymentMode: 'cash',
        createdBy: 1,
      );
      expect(resEmpty.isFailure, true);
    });

    test('IssueItemUseCase enforces valid recipient and permissions', () async {
      final useCase = IssueItemUseCase(_MockInventoryRepo());

      // Permission rejection
      final resDenied = await useCase(
        userPermissions: {Permission.inventoryView},
        itemId: 1,
        quantity: 2,
        unitPrice: Money.fromRupees(100),
        recipientType: 'student',
        studentId: 5,
        reason: 'Exam sheet',
        createdBy: 1,
      );
      expect(resDenied.isFailure, true);

      // Missing student ID
      final resNoStudent = await useCase(
        userPermissions: {Permission.inventoryStockOut},
        itemId: 1,
        quantity: 2,
        unitPrice: Money.fromRupees(100),
        recipientType: 'student',
        studentId: null,
        reason: 'Exam sheet',
        createdBy: 1,
      );
      expect(resNoStudent.isFailure, true);
    });

    test('Supplier Ledger and Valuation models calculate accurately', () {
      final supplier = Supplier(
        id: 1,
        name: 'Allied Paper Mills',
        openingBalance: Money.fromRupees(5000),
        currentBalance: Money.fromRupees(12000),
      );
      expect(supplier.currentBalance.inRupees, 12000.0);

      final valItem1 = StockValuationItem(
        itemId: 1,
        itemName: 'Books',
        categoryName: 'Academics',
        unit: 'pcs',
        quantityOnHand: 20,
        unitCost: Money.fromRupees(300),
        totalValuation: Money.fromRupees(6000),
        reorderLevel: 5,
        isLowStock: false,
      );
      final valItem2 = StockValuationItem(
        itemId: 2,
        itemName: 'Pens',
        categoryName: 'Stationery',
        unit: 'pcs',
        quantityOnHand: 100,
        unitCost: Money.fromRupees(20),
        totalValuation: Money.fromRupees(2000),
        reorderLevel: 10,
        isLowStock: false,
      );

      final report = StockValuationReport(
        items: [valItem1, valItem2],
        totalInventoryValue: valItem1.totalValuation + valItem2.totalValuation,
        totalItemsCount: 2,
        lowStockCount: 0,
      );

      expect(report.totalInventoryValue.inRupees, 8000.0);
      expect(report.totalItemsCount, 2);
    });
  });
}

class _MockInventoryRepo implements InventoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
