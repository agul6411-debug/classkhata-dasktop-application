import 'package:flutter_test/flutter_test.dart';
import 'package:classkhata/core/money/money.dart';
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

    test('CreateInventoryItemUseCase validates input constraints', () async {
      final useCase = CreateInventoryItemUseCase(_MockInventoryRepo());

      // Empty name
      final resEmpty = await useCase(
        categoryId: 1,
        name: '   ',
        unit: 'pcs',
        unitCost: Money.fromRupees(100),
        createdBy: 1,
      );
      expect(resEmpty.isFailure, true);

      // Negative quantity
      final resNegQty = await useCase(
        categoryId: 1,
        name: 'Markers',
        unit: 'pcs',
        initialQuantity: -5,
        unitCost: Money.fromRupees(100),
        createdBy: 1,
      );
      expect(resNegQty.isFailure, true);
    });

    test('RecordStockMovementUseCase enforces non-zero quantity and reason', () async {
      final useCase = RecordStockMovementUseCase(_MockInventoryRepo());

      // Zero quantity
      final resZero = await useCase(
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
        itemId: 1,
        movementType: 'in',
        quantity: 5,
        unitCost: Money.fromRupees(50),
        reason: '  ',
        createdBy: 1,
      );
      expect(resEmptyReason.isFailure, true);
    });

    test('StockReconciliationUseCase enforces non-negative count', () async {
      final useCase = StockReconciliationUseCase(_MockInventoryRepo());

      final resNeg = await useCase(
        itemId: 1,
        actualQuantity: -2,
        reconciledBy: 1,
      );
      expect(resNeg.isFailure, true);
    });
  });
}

class _MockInventoryRepo implements InventoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
