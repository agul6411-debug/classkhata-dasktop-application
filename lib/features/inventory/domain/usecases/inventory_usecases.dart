/// Inventory domain use cases enforcing validation and permissions.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../../core/security/permission_service.dart';
import '../entities/inventory_entities.dart';
import '../repositories/inventory_repository.dart';

class CreateInventoryItemUseCase {
  const CreateInventoryItemUseCase(this._repository);
  final InventoryRepository _repository;

  Future<Result<InventoryItem>> call({
    required Set<Permission> userPermissions,
    required int categoryId,
    required String name,
    required String unit,
    int initialQuantity = 0,
    required Money unitCost,
    Money sellingPrice = const Money(0),
    int reorderLevel = 5,
    required int createdBy,
  }) async {
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: Permission.inventoryEdit,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

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
      sellingPrice: sellingPrice,
      reorderLevel: reorderLevel < 0 ? 0 : reorderLevel,
      createdBy: createdBy,
    );
  }
}

class RecordStockMovementUseCase {
  const RecordStockMovementUseCase(this._repository);
  final InventoryRepository _repository;

  Future<Result<InventoryMovement>> call({
    required Set<Permission> userPermissions,
    required int itemId,
    required String movementType, // 'in' or 'out'
    required int quantity,
    required Money unitCost,
    required String reason,
    String? referenceNumber,
    required int createdBy,
    bool allowNegativeStock = false,
  }) async {
    final requiredPerm =
        movementType.toLowerCase() == 'in' ? Permission.inventoryStockIn : Permission.inventoryStockOut;
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: requiredPerm,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

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
      allowNegativeStock: allowNegativeStock,
    );
  }
}

class RecordPurchaseUseCase {
  const RecordPurchaseUseCase(this._repository);
  final InventoryRepository _repository;

  Future<Result<PurchaseRecord>> call({
    required Set<Permission> userPermissions,
    required String purchaseNumber,
    required int supplierId,
    required List<({int itemId, int quantity, Money unitCost})> items,
    required Money paidAmount,
    required String paymentMode,
    String? invoiceNumber,
    String? notes,
    required int createdBy,
  }) async {
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: Permission.inventoryStockIn,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

    if (purchaseNumber.trim().isEmpty) {
      return const Failure(ValidationFailure('Purchase number is required.'));
    }
    if (items.isEmpty) {
      return const Failure(ValidationFailure('At least one item must be added to the purchase.'));
    }
    for (final it in items) {
      if (it.quantity <= 0) {
        return const Failure(ValidationFailure('Item quantity must be greater than zero.'));
      }
      if (it.unitCost.isNegative) {
        return const Failure(ValidationFailure('Item unit cost cannot be negative.'));
      }
    }

    return _repository.recordPurchase(
      purchaseNumber: purchaseNumber.trim(),
      supplierId: supplierId,
      items: items,
      paidAmount: paidAmount,
      paymentMode: paymentMode,
      invoiceNumber: invoiceNumber?.trim().isEmpty ?? true ? null : invoiceNumber!.trim(),
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      createdBy: createdBy,
    );
  }
}

class IssueItemUseCase {
  const IssueItemUseCase(this._repository);
  final InventoryRepository _repository;

  Future<Result<ItemIssuance>> call({
    required Set<Permission> userPermissions,
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
  }) async {
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: Permission.inventoryStockOut,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

    if (quantity <= 0) {
      return const Failure(ValidationFailure('Quantity to issue must be greater than zero.'));
    }
    if (reason.trim().isEmpty) {
      return const Failure(ValidationFailure('Reason for issuing item is required.'));
    }
    if (recipientType == 'student' && studentId == null) {
      return const Failure(ValidationFailure('Student must be selected when issuing to student.'));
    }
    if (recipientType == 'staff' && staffId == null) {
      return const Failure(ValidationFailure('Staff member must be selected when issuing to staff.'));
    }

    return _repository.issueItem(
      itemId: itemId,
      quantity: quantity,
      unitPrice: unitPrice,
      recipientType: recipientType,
      studentId: studentId,
      staffId: staffId,
      feeVoucherId: feeVoucherId,
      reason: reason.trim(),
      createdBy: createdBy,
      allowNegativeStock: allowNegativeStock,
    );
  }
}

class RecordSupplierPaymentUseCase {
  const RecordSupplierPaymentUseCase(this._repository);
  final InventoryRepository _repository;

  Future<Result<void>> call({
    required Set<Permission> userPermissions,
    required int supplierId,
    required Money amount,
    required String paymentMode,
    String? notes,
    String? referenceNumber,
    required int createdBy,
  }) async {
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: Permission.inventoryEdit,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

    if (amount.isNegative || amount.paisa <= 0) {
      return const Failure(ValidationFailure('Payment amount must be greater than zero.'));
    }

    return _repository.recordSupplierPayment(
      supplierId: supplierId,
      amount: amount,
      paymentMode: paymentMode,
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      referenceNumber: referenceNumber?.trim().isEmpty ?? true ? null : referenceNumber!.trim(),
      createdBy: createdBy,
    );
  }
}

class StockReconciliationUseCase {
  const StockReconciliationUseCase(this._repository);
  final InventoryRepository _repository;

  Future<Result<({StockTakeRecord? record, bool requiresApproval, int? approvalId})>> call({
    required Set<Permission> userPermissions,
    required int itemId,
    required int actualQuantity,
    String? reason,
    required int reconciledBy,
    Money approvalThreshold = const Money(500000),
  }) async {
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: Permission.inventoryEdit,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

    if (actualQuantity < 0) {
      return const Failure(ValidationFailure('Actual counted quantity cannot be negative.'));
    }

    return _repository.reconcileStock(
      itemId: itemId,
      actualQuantity: actualQuantity,
      reason: reason?.trim().isEmpty ?? true ? null : reason!.trim(),
      reconciledBy: reconciledBy,
      approvalThreshold: approvalThreshold,
    );
  }
}

class GetStockValuationUseCase {
  const GetStockValuationUseCase(this._repository);
  final InventoryRepository _repository;

  Future<Result<StockValuationReport>> call({
    required Set<Permission> userPermissions,
  }) async {
    final permCheck = checkPermission(
      userPermissions: userPermissions,
      required: Permission.inventoryView,
    );
    if (permCheck.isFailure) {
      return Failure(permCheck.fold(onSuccess: (_) => const UnexpectedFailure(''), onFailure: (f) => f));
    }

    return _repository.getStockValuation();
  }
}
