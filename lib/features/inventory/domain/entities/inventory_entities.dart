/// Domain entities for Inventory Management (No barcodes).
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
  final int reorderLevel;

  const InventoryItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.unit,
    required this.quantityOnHand,
    required this.unitCost,
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
