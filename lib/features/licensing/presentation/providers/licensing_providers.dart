/// Licensing providers for state management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers.dart';
import '../../data/licensing_repository_impl.dart';
import '../../domain/entities/license_entities.dart';
import '../../domain/repositories/licensing_repository.dart';

final licensingRepositoryProvider = Provider<LicensingRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LicensingRepositoryImpl(db);
});

final licenseInfoProvider = FutureProvider<LicenseInfo>((ref) async {
  final repo = ref.watch(licensingRepositoryProvider);
  final res = await repo.getLicenseInfo();
  return res.fold(
    onSuccess: (info) => info,
    onFailure: (f) => LicenseInfo(
      status: LicenseStatus.expired,
      machineId: 'UNKNOWN',
      trialStartedAt: DateTime.now(),
      daysRemaining: 0,
      alertMessage: f.message,
    ),
  );
});

class LicenseController extends StateNotifier<AsyncValue<LicenseInfo?>> {

  LicenseController(this._repo, this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }
  final LicensingRepository _repo;
  final Ref _ref;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final res = await _repo.getLicenseInfo();
    res.fold(
      onSuccess: (info) => state = AsyncValue.data(info),
      onFailure: (f) => state = AsyncValue.error(f.message, StackTrace.current),
    );
  }

  Future<bool> activate(String key) async {
    state = const AsyncValue.loading();
    final res = await _repo.activateLicense(key);
    return res.fold(
      onSuccess: (info) {
        state = AsyncValue.data(info);
        _ref.invalidate(licenseInfoProvider);
        return true;
      },
      onFailure: (f) {
        state = AsyncValue.error(f.message, StackTrace.current);
        return false;
      },
    );
  }
}

final licenseControllerProvider =
    StateNotifierProvider<LicenseController, AsyncValue<LicenseInfo?>>((ref) {
  final repo = ref.watch(licensingRepositoryProvider);
  return LicenseController(repo, ref);
});
