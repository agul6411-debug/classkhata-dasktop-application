/// Riverpod providers for Fee Management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../data/datasources/fee_dao.dart';
import '../../data/repositories/fee_repository_impl.dart';
import '../../domain/entities/fee_entities.dart';
import '../../domain/repositories/fee_repository.dart';
import '../../domain/usecases/collect_fee_usecase.dart';
import '../../domain/usecases/fee_management_usecases.dart';

final feeDaoProvider = Provider<FeeDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return FeeDao(db);
});

final feeRepositoryProvider = Provider<FeeRepository>((ref) {
  final dao = ref.watch(feeDaoProvider);
  return FeeRepositoryImpl(dao);
});

final collectFeeUseCaseProvider = Provider<CollectFeeUseCase>((ref) {
  return CollectFeeUseCase(ref.watch(feeRepositoryProvider));
});

final generateVouchersUseCaseProvider = Provider<GenerateVouchersUseCase>((ref) {
  return GenerateVouchersUseCase(ref.watch(feeRepositoryProvider));
});

final feeApprovalsUseCaseProvider = Provider<FeeApprovalsUseCase>((ref) {
  return FeeApprovalsUseCase(ref.watch(feeRepositoryProvider));
});

final defaulterAgingUseCaseProvider = Provider<DefaulterAgingUseCase>((ref) {
  return DefaulterAgingUseCase(ref.watch(feeRepositoryProvider));
});

/// Filter state for vouchers list
class VoucherFilterState {

  const VoucherFilterState({
    this.batchId,
    this.studentId,
    this.status,
    this.monthYear,
  });
  final int? batchId;
  final int? studentId;
  final VoucherStatus? status;
  final String? monthYear;

  VoucherFilterState copyWith({
    int? Function()? batchId,
    int? Function()? studentId,
    VoucherStatus? Function()? status,
    String? Function()? monthYear,
  }) {
    return VoucherFilterState(
      batchId: batchId != null ? batchId() : this.batchId,
      studentId: studentId != null ? studentId() : this.studentId,
      status: status != null ? status() : this.status,
      monthYear: monthYear != null ? monthYear() : this.monthYear,
    );
  }
}

class VoucherFilterNotifier extends StateNotifier<VoucherFilterState> {
  VoucherFilterNotifier() : super(const VoucherFilterState());

  void setBatchId(int? id) => state = state.copyWith(batchId: () => id);
  void setStatus(VoucherStatus? s) => state = state.copyWith(status: () => s);
  void setMonthYear(String? my) => state = state.copyWith(monthYear: () => my);
  void reset() => state = const VoucherFilterState();
}

final voucherFilterProvider =
    StateNotifierProvider<VoucherFilterNotifier, VoucherFilterState>((ref) {
  return VoucherFilterNotifier();
});

/// Future provider fetching vouchers based on active filters
final vouchersListProvider = FutureProvider<List<FeeVoucher>>((ref) async {
  final filter = ref.watch(voucherFilterProvider);
  final repo = ref.watch(feeRepositoryProvider);
  final result = await repo.getVouchers(
    batchId: filter.batchId,
    studentId: filter.studentId,
    status: filter.status,
    monthYear: filter.monthYear,
  );
  return result.fold(
    onSuccess: (list) => list,
    onFailure: (f) => throw Exception(f.message),
  );
});

/// Future provider fetching defaulter aging report
final defaulterAgingProvider = FutureProvider<List<DefaulterAgingRecord>>((ref) async {
  final useCase = ref.watch(defaulterAgingUseCaseProvider);
  final result = await useCase();
  return result.fold(
    onSuccess: (records) => records,
    onFailure: (f) => throw Exception(f.message),
  );
});
