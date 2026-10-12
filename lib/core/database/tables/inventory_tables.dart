/// Drift table definitions for Inventory Management (No barcodes).
///
/// Rules:
///   - Strictly NO barcode columns or features.
///   - All unit costs, prices, and ledger values stored as INTEGER (paisa).
///   - Stock quantity is never stored as an editable number: derived from
///     append-only stock movements (with cached balance updated strictly inside
///     the same transaction as the movement).
///   - Movements track physical flow, purchases, issuances, and shrinkage adjustments.
library;

import 'package:drift/drift.dart';
import 'academic_tables.dart';
import 'core_tables.dart';
import 'fee_tables.dart';
import 'payroll_tables.dart';

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
  IntColumn get sellingPricePaisa => integer().withDefault(const Constant(0))();
  IntColumn get reorderLevel => integer().withDefault(const Constant(5))(); // threshold for low-stock alert
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('invItemsCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Inventory Movements (Stock In / Stock Out / Adjustments)
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
// Suppliers
// ---------------------------------------------------------------------------

class SuppliersTable extends Table {
  @override
  String get tableName => 'suppliers';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  IntColumn get openingBalancePaisa => integer().withDefault(const Constant(0))();
  IntColumn get currentBalancePaisa => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('suppliersCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Supplier Ledger (Purchases, Payments, Adjustments)
// ---------------------------------------------------------------------------

class SupplierLedgerTable extends Table {
  @override
  String get tableName => 'supplier_ledger';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().references(SuppliersTable, #id)();
  /// 'purchase', 'payment', 'return', 'opening_balance'
  TextColumn get transactionType => text()();
  IntColumn get amountPaisa => integer()();
  TextColumn get referenceNumber => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get transactionDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('supplierLedgerCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Purchases (Header)
// ---------------------------------------------------------------------------

class PurchasesTable extends Table {
  @override
  String get tableName => 'purchases';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get purchaseNumber => text().unique()(); // e.g. "PUR-0001"
  IntColumn get supplierId => integer().references(SuppliersTable, #id)();
  IntColumn get totalAmountPaisa => integer()();
  IntColumn get paidAmountPaisa => integer().withDefault(const Constant(0))();
  /// 'cash', 'bank', 'credit'
  TextColumn get paymentMode => text().withDefault(const Constant('cash'))();
  TextColumn get invoiceNumber => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get purchaseDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('purchasesCreated')
  IntColumn get createdBy => integer().nullable().references(UsersTable, #id)();
}

// ---------------------------------------------------------------------------
// Purchase Line Items
// ---------------------------------------------------------------------------

class PurchaseItemsTable extends Table {
  @override
  String get tableName => 'purchase_items';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseId => integer().references(PurchasesTable, #id)();
  IntColumn get itemId => integer().references(InventoryItemsTable, #id)();
  IntColumn get quantity => integer()();
  IntColumn get unitCostPaisa => integer()();
  IntColumn get totalCostPaisa => integer()();
}

// ---------------------------------------------------------------------------
// Item Issuances (To Students or Staff)
// ---------------------------------------------------------------------------

class ItemIssuancesTable extends Table {
  @override
  String get tableName => 'item_issuances';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(InventoryItemsTable, #id)();
  IntColumn get quantity => integer()();
  IntColumn get unitPricePaisa => integer().withDefault(const Constant(0))();
  /// 'student' or 'staff'
  TextColumn get recipientType => text()();
  @ReferenceName('itemIssuancesStudent')
  IntColumn get studentId => integer().nullable().references(StudentsTable, #id)();
  @ReferenceName('itemIssuancesStaff')
  IntColumn get staffId => integer().nullable().references(StaffMembersTable, #id)();
  @ReferenceName('itemIssuancesVoucher')
  IntColumn get feeVoucherId => integer().nullable().references(FeeVouchersTable, #id)();
  TextColumn get reason => text()();
  DateTimeColumn get issuedDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @ReferenceName('itemIssuancesCreated')
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
