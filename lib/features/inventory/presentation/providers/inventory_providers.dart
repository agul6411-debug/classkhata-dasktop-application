/// Riverpod providers for Inventory management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../data/datasources/inventory_dao.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/usecases/inventory_usecases.dart';

final inventoryDaoProvider = Provider<InventoryDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return InventoryDao(db);
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final dao = ref.watch(inventoryDaoProvider);
  return InventoryRepositoryImpl(dao);
});

final createInventoryItemUseCaseProvider = Provider<CreateInventoryItemUseCase>((ref) {
  return CreateInventoryItemUseCase(ref.watch(inventoryRepositoryProvider));
});

final recordStockMovementUseCaseProvider = Provider<RecordStockMovementUseCase>((ref) {
  return RecordStockMovementUseCase(ref.watch(inventoryRepositoryProvider));
});

final recordPurchaseUseCaseProvider = Provider<RecordPurchaseUseCase>((ref) {
  return RecordPurchaseUseCase(ref.watch(inventoryRepositoryProvider));
});

final issueItemUseCaseProvider = Provider<IssueItemUseCase>((ref) {
  return IssueItemUseCase(ref.watch(inventoryRepositoryProvider));
});

final recordSupplierPaymentUseCaseProvider = Provider<RecordSupplierPaymentUseCase>((ref) {
  return RecordSupplierPaymentUseCase(ref.watch(inventoryRepositoryProvider));
});

final stockReconciliationUseCaseProvider = Provider<StockReconciliationUseCase>((ref) {
  return StockReconciliationUseCase(ref.watch(inventoryRepositoryProvider));
});

final getStockValuationUseCaseProvider = Provider<GetStockValuationUseCase>((ref) {
  return GetStockValuationUseCase(ref.watch(inventoryRepositoryProvider));
});

// ---------------------------------------------------------------------------
// Data Query Providers
// ---------------------------------------------------------------------------

final inventoryCategoriesProvider = FutureProvider<List<InventoryCategory>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final res = await repo.getCategories();
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});

final inventoryFilterCategoryProvider = StateProvider<int?>((ref) => null);
final inventoryFilterLowStockProvider = StateProvider<bool>((ref) => false);

final inventoryItemsProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final catId = ref.watch(inventoryFilterCategoryProvider);
  final lowStockOnly = ref.watch(inventoryFilterLowStockProvider);
  final repo = ref.watch(inventoryRepositoryProvider);
  final res = await repo.getItems(categoryId: catId, lowStockOnly: lowStockOnly ? true : null);
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});

final lowStockAlertsProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final res = await repo.getLowStockItems();
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});

final inventoryMovementsProvider = FutureProvider<List<InventoryMovement>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final res = await repo.getMovements();
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});

final suppliersProvider = FutureProvider<List<Supplier>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final res = await repo.getSuppliers();
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});

final supplierLedgerProvider = FutureProvider.family<List<SupplierLedgerEntry>, int>((ref, supplierId) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final res = await repo.getSupplierLedger(supplierId);
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});

final purchasesProvider = FutureProvider<List<PurchaseRecord>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final res = await repo.getPurchases();
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});

final itemIssuancesProvider = FutureProvider<List<ItemIssuance>>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final res = await repo.getItemIssuances();
  return res.fold(onSuccess: (list) => list, onFailure: (f) => throw Exception(f.message));
});

final stockValuationProvider = FutureProvider<StockValuationReport>((ref) async {
  final repo = ref.watch(inventoryRepositoryProvider);
  final res = await repo.getStockValuation();
  return res.fold(onSuccess: (report) => report, onFailure: (f) => throw Exception(f.message));
});
