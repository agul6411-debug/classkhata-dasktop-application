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
    Money sellingPrice = const Money(0),
    required int reorderLevel,
    required int createdBy,
  });
  Future<Result<List<InventoryItem>>> getLowStockItems();

  // Movements (Stock In / Stock Out)
  Future<Result<InventoryMovement>> recordMovement({
    required int itemId,
    required String movementType, // 'in' or 'out'
    required int quantity,
    required Money unitCost,
    required String reason,
    String? referenceNumber,
    required int createdBy,
    bool allowNegativeStock = false,
  });
  Future<Result<List<InventoryMovement>>> getMovements({int? itemId});

  // Suppliers & Supplier Ledger
  Future<Result<List<Supplier>>> getSuppliers();
  Future<Result<Supplier>> createSupplier({
    required String name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    Money openingBalance = const Money(0),
    required int createdBy,
  });
  Future<Result<List<SupplierLedgerEntry>>> getSupplierLedger(int supplierId);
  Future<Result<void>> recordSupplierPayment({
    required int supplierId,
    required Money amount,
    required String paymentMode,
    String? notes,
    String? referenceNumber,
    required int createdBy,
  });

  // Purchases (Multi-Item Purchase with Supplier Ledger & Cash Book)
  Future<Result<PurchaseRecord>> recordPurchase({
    required String purchaseNumber,
    required int supplierId,
    required List<({int itemId, int quantity, Money unitCost})> items,
    required Money paidAmount,
    required String paymentMode,
    String? invoiceNumber,
    String? notes,
    required int createdBy,
  });
  Future<Result<List<PurchaseRecord>>> getPurchases({int? supplierId});

  // Item Issuance (To Students or Staff with optional Fee Voucher charge)
  Future<Result<ItemIssuance>> issueItem({
    required int itemId,
    required int quantity,
    required Money unitPrice,
    required String recipientType, // 'student' or 'staff'
    int? studentId,
    int? staffId,
    int? feeVoucherId,
    required String reason,
    required int createdBy,
    bool allowNegativeStock = false,
  });
  Future<Result<List<ItemIssuance>>> getItemIssuances({int? itemId, int? studentId, int? staffId});

  // Stock-Take Reconciliation with Maker-Checker
  Future<Result<({StockTakeRecord? record, bool requiresApproval, int? approvalId})>> reconcileStock({
    required int itemId,
    required int actualQuantity,
    String? reason,
    required int reconciledBy,
    Money approvalThreshold = const Money(500000), // 5,000 PKR default
  });

  // Valuation
  Future<Result<StockValuationReport>> getStockValuation();
}
