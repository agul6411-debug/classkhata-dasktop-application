/// Domain entities for Inventory Management (Strictly NO barcodes).
library;

import 'package:equatable/equatable.dart';
import '../../../../core/money/money.dart';

class InventoryCategory extends Equatable {
  final int id;
  final String name;
  final String? description;

  const InventoryCategory({
    required this.id,
    required this.name,
    this.description,
  });

  @override
  List<Object?> get props => [id, name, description];
}

class InventoryItem extends Equatable {
  final int id;
  final int categoryId;
  final String categoryName;
  final String name;
  final String unit; // 'pcs', 'box', 'pack'
  final int quantityOnHand;
  final Money unitCost;
  final Money sellingPrice;
  final int reorderLevel;

  const InventoryItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.unit,
    required this.quantityOnHand,
    required this.unitCost,
    this.sellingPrice = const Money(0),
    required this.reorderLevel,
  });

  bool get isLowStock => quantityOnHand <= reorderLevel;
  Money get totalValue => unitCost * quantityOnHand;

  @override
  List<Object?> get props => [
        id,
        categoryId,
        categoryName,
        name,
        unit,
        quantityOnHand,
        unitCost,
        sellingPrice,
        reorderLevel,
      ];
}

class InventoryMovement extends Equatable {
  final int id;
  final int itemId;
  final String itemName;
  final String movementType; // 'in', 'out', 'adjustment'
  final int quantity;
  final Money unitCost;
  final String reason;
  final String? referenceNumber;
  final DateTime movementDate;

  const InventoryMovement({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.movementType,
    required this.quantity,
    required this.unitCost,
    required this.reason,
    this.referenceNumber,
    required this.movementDate,
  });

  bool get isIn => movementType.toLowerCase() == 'in';
  bool get isOut => movementType.toLowerCase() == 'out';

  @override
  List<Object?> get props => [
        id,
        itemId,
        itemName,
        movementType,
        quantity,
        unitCost,
        reason,
        referenceNumber,
        movementDate,
      ];
}

class StockTakeRecord extends Equatable {
  final int id;
  final int itemId;
  final String itemName;
  final int recordedQuantity;
  final int actualQuantity;
  final int discrepancy;
  final String? reason;
  final DateTime reconciledAt;

  const StockTakeRecord({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.recordedQuantity,
    required this.actualQuantity,
    required this.discrepancy,
    this.reason,
    required this.reconciledAt,
  });

  bool get hasDiscrepancy => discrepancy != 0;

  @override
  List<Object?> get props => [
        id,
        itemId,
        itemName,
        recordedQuantity,
        actualQuantity,
        discrepancy,
        reason,
        reconciledAt,
      ];
}

// ---------------------------------------------------------------------------
// Suppliers & Supplier Ledger
// ---------------------------------------------------------------------------

class Supplier extends Equatable {
  final int id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final Money openingBalance;
  final Money currentBalance;

  const Supplier({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    required this.openingBalance,
    required this.currentBalance,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        contactPerson,
        phone,
        email,
        address,
        openingBalance,
        currentBalance,
      ];
}

class SupplierLedgerEntry extends Equatable {
  final int id;
  final int supplierId;
  final String transactionType; // 'purchase', 'payment', 'return', 'opening_balance'
  final Money amount;
  final String? referenceNumber;
  final String? notes;
  final DateTime transactionDate;

  const SupplierLedgerEntry({
    required this.id,
    required this.supplierId,
    required this.transactionType,
    required this.amount,
    this.referenceNumber,
    this.notes,
    required this.transactionDate,
  });

  bool get isPurchase => transactionType == 'purchase';
  bool get isPayment => transactionType == 'payment';

  @override
  List<Object?> get props => [
        id,
        supplierId,
        transactionType,
        amount,
        referenceNumber,
        notes,
        transactionDate,
      ];
}

// ---------------------------------------------------------------------------
// Purchases & Line Items
// ---------------------------------------------------------------------------

class PurchaseLineItem extends Equatable {
  final int id;
  final int purchaseId;
  final int itemId;
  final String itemName;
  final int quantity;
  final Money unitCost;
  final Money totalCost;

  const PurchaseLineItem({
    required this.id,
    required this.purchaseId,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
  });

  @override
  List<Object?> get props => [
        id,
        purchaseId,
        itemId,
        itemName,
        quantity,
        unitCost,
        totalCost,
      ];
}

class PurchaseRecord extends Equatable {
  final int id;
  final String purchaseNumber;
  final int supplierId;
  final String supplierName;
  final Money totalAmount;
  final Money paidAmount;
  final String paymentMode;
  final String? invoiceNumber;
  final String? notes;
  final DateTime purchaseDate;
  final List<PurchaseLineItem> items;

  const PurchaseRecord({
    required this.id,
    required this.purchaseNumber,
    required this.supplierId,
    required this.supplierName,
    required this.totalAmount,
    required this.paidAmount,
    required this.paymentMode,
    this.invoiceNumber,
    this.notes,
    required this.purchaseDate,
    this.items = const [],
  });

  Money get balanceDue => totalAmount - paidAmount;

  @override
  List<Object?> get props => [
        id,
        purchaseNumber,
        supplierId,
        supplierName,
        totalAmount,
        paidAmount,
        paymentMode,
        invoiceNumber,
        notes,
        purchaseDate,
        items,
      ];
}

// ---------------------------------------------------------------------------
// Item Issuances
// ---------------------------------------------------------------------------

class ItemIssuance extends Equatable {
  final int id;
  final int itemId;
  final String itemName;
  final int quantity;
  final Money unitPrice;
  final String recipientType; // 'student' or 'staff'
  final int? studentId;
  final String? studentName;
  final int? staffId;
  final String? staffName;
  final int? feeVoucherId;
  final String reason;
  final DateTime issuedDate;

  const ItemIssuance({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.recipientType,
    this.studentId,
    this.studentName,
    this.staffId,
    this.staffName,
    this.feeVoucherId,
    required this.reason,
    required this.issuedDate,
  });

  Money get totalCharge => unitPrice * quantity;

  @override
  List<Object?> get props => [
        id,
        itemId,
        itemName,
        quantity,
        unitPrice,
        recipientType,
        studentId,
        studentName,
        staffId,
        staffName,
        feeVoucherId,
        reason,
        issuedDate,
      ];
}

// ---------------------------------------------------------------------------
// Valuation
// ---------------------------------------------------------------------------

class StockValuationItem extends Equatable {
  final int itemId;
  final String itemName;
  final String categoryName;
  final String unit;
  final int quantityOnHand;
  final Money unitCost;
  final Money totalValuation;
  final int reorderLevel;
  final bool isLowStock;

  const StockValuationItem({
    required this.itemId,
    required this.itemName,
    required this.categoryName,
    required this.unit,
    required this.quantityOnHand,
    required this.unitCost,
    required this.totalValuation,
    required this.reorderLevel,
    required this.isLowStock,
  });

  @override
  List<Object?> get props => [
        itemId,
        itemName,
        categoryName,
        unit,
        quantityOnHand,
        unitCost,
        totalValuation,
        reorderLevel,
        isLowStock,
      ];
}

class StockValuationReport extends Equatable {
  final List<StockValuationItem> items;
  final Money totalInventoryValue;
  final int totalItemsCount;
  final int lowStockCount;

  const StockValuationReport({
    required this.items,
    required this.totalInventoryValue,
    required this.totalItemsCount,
    required this.lowStockCount,
  });

  @override
  List<Object?> get props => [
        items,
        totalInventoryValue,
        totalItemsCount,
        lowStockCount,
      ];
}
