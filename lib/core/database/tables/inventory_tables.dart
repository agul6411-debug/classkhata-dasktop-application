/// Drift table definitions for Inventory Management (No barcodes).
///
/// Rules:
///   - Strictly NO barcode columns or features.
///   - All unit costs and values stored as INTEGER (paisa).
///   - Movements track physical flow and shrinkage adjustments.
library;

import 'package:drift/drift.dart';
import 'core_tables.dart';

// ---------------------------------------------------------------------------
// Inventory Categories
// ---------------------------------------------------------------------------

class InventoryCategoriesTable extends Table {
  @override
  String get tableName => 'inventory_categories';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)(); // e.g. "Stationery", "Books", "Uniforms"
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('invCategoriesCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Inventory Items
// ---------------------------------------------------------------------------

class InventoryItemsTable extends Table {
  @override
  String get tableName => 'inventory_items';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(InventoryCategoriesTable, #id)();
  TextColumn get name => text().withLength(min: 1, max: 120)(); // e.g. "Mathematics Textbook 9th"
  TextColumn get unit => text().withDefault(const Constant('pcs'))(); // e.g. "pcs", "box", "pack"
  IntColumn get quantityOnHand => integer().withDefault(const Constant(0))();
  IntColumn get unitCostPaisa => integer().withDefault(const Constant(0))();
  IntColumn get reorderLevel => integer().withDefault(const Constant(5))(); // threshold for low-stock alert
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('invItemsCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Inventory Movements (Stock In / Stock Out)
// ---------------------------------------------------------------------------

class InventoryMovementsTable extends Table {
  @override
  String get tableName => 'inventory_movements';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(InventoryItemsTable, #id)();
  /// 'in', 'out', 'adjustment'
  TextColumn get movementType => text()();
  IntColumn get quantity => integer()();
  IntColumn get unitCostPaisa => integer().withDefault(const Constant(0))();
  TextColumn get reason => text()(); // e.g. "Purchase from supplier", "Issued to Class 10", "Damaged"
  TextColumn get referenceNumber => text().nullable()();
  DateTimeColumn get movementDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('invMovementsCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Stock Takes (Reconciliation & Shrinkage)
// ---------------------------------------------------------------------------

class StockTakesTable extends Table {
  @override
  String get tableName => 'stock_takes';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(InventoryItemsTable, #id)();
  IntColumn get recordedQuantity => integer()();
  IntColumn get actualQuantity => integer()();
  IntColumn get discrepancy => integer()(); // actual - recorded
  TextColumn get reason => text().nullable()(); // shrinkage reason
  DateTimeColumn get reconciledAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('stockTakesReconciled')
  IntColumn get reconciledBy => integer().references(UsersTable, #id)();
}
