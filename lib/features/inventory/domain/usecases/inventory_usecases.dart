/// Inventory use cases for items, movements, and reconciliation.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../entities/inventory_entities.dart';
import '../repositories/inventory_repository.dart';

class CreateInventoryItemUseCase {
  final InventoryRepository _repository;
  const CreateInventoryItemUseCase(this._repository);

  Future<Result<InventoryItem>> call({
    required int categoryId,
    required String name,
    required String unit,
    int initialQuantity = 0,
    required Money unitCost,
    int reorderLevel = 5,
    required int createdBy,
  }) async {
    if (name.trim().isEmpty) {
      return const Failure(ValidationFailure('Item name is required.'));
    }
    if (initialQuantity < 0) {
      return const Failure(ValidationFailure('Initial quantity cannot be negative.'));
    }
    if (unitCost.isNegative) {
      return const Failure(ValidationFailure('Unit cost cannot be negative.'));
    }

    return _repository.createItem(
      categoryId: categoryId,
      name: name.trim(),
      unit: unit.trim().isEmpty ? 'pcs' : unit.trim(),
      initialQuantity: initialQuantity,
      unitCost: unitCost,
      reorderLevel: reorderLevel < 0 ? 0 : reorderLevel,
      createdBy: createdBy,
    );
  }
}

class RecordStockMovementUseCase {
  final InventoryRepository _repository;
  const RecordStockMovementUseCase(this._repository);

  Future<Result<InventoryMovement>> call({
    required int itemId,
    required String movementType, // 'in' or 'out'
    required int quantity,
    required Money unitCost,
    required String reason,
    String? referenceNumber,
    required int createdBy,
  }) async {
    if (quantity <= 0) {
      return const Failure(ValidationFailure('Quantity must be greater than zero.'));
    }
    if (reason.trim().isEmpty) {
      return const Failure(ValidationFailure('Movement reason is required.'));
    }

    return _repository.recordMovement(
      itemId: itemId,
      movementType: movementType.toLowerCase(),
      quantity: quantity,
      unitCost: unitCost,
      reason: reason.trim(),
      referenceNumber: referenceNumber?.trim().isEmpty ?? true ? null : referenceNumber!.trim(),
      createdBy: createdBy,
    );
  }
}

class StockReconciliationUseCase {
  final InventoryRepository _repository;
  const StockReconciliationUseCase(this._repository);

  Future<Result<StockTakeRecord>> call({
    required int itemId,
    required int actualQuantity,
    String? reason,
    required int reconciledBy,
  }) async {
    if (actualQuantity < 0) {
      return const Failure(ValidationFailure('Actual counted quantity cannot be negative.'));
    }

    return _repository.reconcileStock(
      itemId: itemId,
      actualQuantity: actualQuantity,
      reason: reason?.trim().isEmpty ?? true ? null : reason!.trim(),
      reconciledBy: reconciledBy,
    );
  }
}
