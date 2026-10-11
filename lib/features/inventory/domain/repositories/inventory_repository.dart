/// Abstract repository for Inventory Management.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../entities/inventory_entities.dart';

abstract interface class InventoryRepository {
  // Categories
  Future<Result<List<InventoryCategory>>> getCategories();
  Future<Result<InventoryCategory>> createCategory({
    required String name,
    String? description,
    required int createdBy,
  });

  // Items
  Future<Result<List<InventoryItem>>> getItems({int? categoryId, bool? lowStockOnly});
  Future<Result<InventoryItem>> createItem({
    required int categoryId,
    required String name,
    required String unit,
    required int initialQuantity,
    required Money unitCost,
    required int reorderLevel,
    required int createdBy,
  });

  // Movements (Stock In / Stock Out)
  Future<Result<InventoryMovement>> recordMovement({
    required int itemId,
    required String movementType, // 'in' or 'out'
    required int quantity,
    required Money unitCost,
    required String reason,
    String? referenceNumber,
    required int createdBy,
  });
  Future<Result<List<InventoryMovement>>> getMovements({int? itemId});

  // Stock-Take Reconciliation
  Future<Result<StockTakeRecord>> reconcileStock({
    required int itemId,
    required int actualQuantity,
    String? reason,
    required int reconciledBy,
  });
}
