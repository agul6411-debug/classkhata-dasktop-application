/// Inventory DAO executing transactional stock movements and reconciliations.
library;

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

class InventoryDao {
  final AppDatabase _db;
  const InventoryDao(this._db);

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
    if (lowStockOnly == true) {
      query.where((t) => t.quantityOnHand.isSmallerOrEqual(t.reorderLevel));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.get();
  }

  Future<int> insertItem(InventoryItemsTableCompanion companion) =>
      _db.into(_db.inventoryItemsTable).insert(companion);

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
  }) async {
    return _db.transaction(() async {
      final item = await (_db.select(_db.inventoryItemsTable)..where((t) => t.id.equals(itemId))).getSingle();

      int newQty = item.quantityOnHand;
      if (movementType == 'in') {
        newQty += quantity;
      } else if (movementType == 'out') {
        if (quantity > item.quantityOnHand) {
          throw Exception('Cannot issue $quantity units. Only ${item.quantityOnHand} available on hand.');
        }
        newQty -= quantity;
      } else {
        newQty = quantity; // Adjustment
      }

      // 1. Update on-hand count
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
              unitCostPaisa: Value(unitCostPaisa),
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
  // Stock-Take Reconciliation & Shrinkage (Atomic Transaction)
  // ---------------------------------------------------------------------------

  Future<({StockTakesTableData stockTake, String itemName})> reconcileStockTransaction({
    required int itemId,
    required int actualQuantity,
    String? reason,
    required int reconciledBy,
  }) async {
    return _db.transaction(() async {
      final item = await (_db.select(_db.inventoryItemsTable)..where((t) => t.id.equals(itemId))).getSingle();
      final discrepancy = actualQuantity - item.quantityOnHand;

      // 1. Adjust item quantity on hand
      await (_db.update(_db.inventoryItemsTable)..where((t) => t.id.equals(itemId))).write(
        InventoryItemsTableCompanion(
          quantityOnHand: Value(actualQuantity),
        ),
      );

      // 2. Insert stock take reconciliation record
      final id = await _db.into(_db.stockTakesTable).insert(
            StockTakesTableCompanion.insert(
              itemId: itemId,
              recordedQuantity: item.quantityOnHand,
              actualQuantity: actualQuantity,
              discrepancy: discrepancy,
              reason: Value(reason),
              reconciledBy: reconciledBy,
            ),
          );

      final rec = await (_db.select(_db.stockTakesTable)..where((t) => t.id.equals(id))).getSingle();
      return (stockTake: rec, itemName: item.name);
    });
  }
}
