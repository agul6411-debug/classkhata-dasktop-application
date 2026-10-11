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
      final list = rows.map((r) => InventoryCategory(
            id: r.id,
            name: r.name,
            description: r.description,
          )).toList();
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

      final list = rows.map((r) => InventoryItem(
            id: r.id,
            categoryId: r.categoryId,
            categoryName: catMap[r.categoryId] ?? 'General',
            name: r.name,
            unit: r.unit,
            quantityOnHand: r.quantityOnHand,
            unitCost: Money.fromPaisa(r.unitCostPaisa),
            reorderLevel: r.reorderLevel,
          )).toList();
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
        reorderLevel: reorderLevel,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('createItem error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not create item.', technicalDetail: e.toString()));
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

      final list = rows.map((r) => InventoryMovement(
            id: r.id,
            itemId: r.itemId,
            itemName: itemMap[r.itemId] ?? 'Item #${r.itemId}',
            movementType: r.movementType,
            quantity: r.quantity,
            unitCost: Money.fromPaisa(r.unitCostPaisa),
            reason: r.reason,
            referenceNumber: r.referenceNumber,
            movementDate: r.movementDate,
          )).toList();
      return Success(list);
    } catch (e, st) {
      await AppLogger.instance.error('getMovements error', error: e, stack: st);
      return Failure(DatabaseFailure('Could not fetch movements.', technicalDetail: e.toString()));
    }
  }

  @override
  Future<Result<StockTakeRecord>> reconcileStock({
    required int itemId,
    required int actualQuantity,
    String? reason,
    required int reconciledBy,
  }) async {
    try {
      final res = await _dao.reconcileStockTransaction(
        itemId: itemId,
        actualQuantity: actualQuantity,
        reason: reason,
        reconciledBy: reconciledBy,
      );

      return Success(StockTakeRecord(
        id: res.stockTake.id,
        itemId: res.stockTake.itemId,
        itemName: res.itemName,
        recordedQuantity: res.stockTake.recordedQuantity,
        actualQuantity: res.stockTake.actualQuantity,
        discrepancy: res.stockTake.discrepancy,
        reason: res.stockTake.reason,
        reconciledAt: res.stockTake.reconciledAt,
      ));
    } catch (e, st) {
      await AppLogger.instance.error('reconcileStock error', error: e, stack: st);
      return Failure(DatabaseFailure('Stock reconciliation failed.', technicalDetail: e.toString()));
    }
  }
}
