import 'package:flutter_test/flutter_test.dart';
import 'package:classkhata/core/errors/failures.dart';
import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/core/security/permission_service.dart';
import 'package:classkhata/features/fees/domain/entities/fee_entities.dart';
import 'package:classkhata/features/fees/domain/repositories/fee_repository.dart';
import 'package:classkhata/features/fees/domain/usecases/collect_fee_usecase.dart';
import 'package:classkhata/features/fees/domain/usecases/fee_management_usecases.dart';

class MockFeeRepository implements FeeRepository {
  final List<FeeVoucher> vouchers = [];

  @override
  Future<Result<({Payment payment, Receipt receipt, FeeVoucher updatedVoucher})>> collectFee({
    required int voucherId,
    required int studentId,
    required Money amount,
    required String paymentMode,
    String? referenceNumber,
    required int createdBy,
  }) async {
    final payment = Payment(
      id: 1,
      voucherId: voucherId,
      studentId: studentId,
      receiptId: 1,
      amount: amount,
      paymentMode: paymentMode,
      paymentDate: DateTime.now(),
    );

    final receipt = Receipt(
      id: 1,
      receiptNumber: 'RCP-000001',
      voucherId: voucherId,
      studentId: studentId,
      amount: amount,
      qrData: '{"receipt":"RCP-000001"}',
      receiptDate: DateTime.now(),
      isCancelled: false,
    );

    final updatedVoucher = FeeVoucher(
      id: voucherId,
      voucherNumber: 'VCH-202610-0001',
      studentId: studentId,
      batchId: 1,
      monthYear: '2026-10',
      issueDate: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 10)),
      baseAmount: amount,
      discount: const Money(0),
      lateFee: const Money(0),
      carryForward: const Money(0),
      totalDue: amount,
      amountPaid: amount,
      status: VoucherStatus.paid,
      createdAt: DateTime.now(),
    );

    return Success((payment: payment, receipt: receipt, updatedVoucher: updatedVoucher));
  }

  @override
  Future<Result<int>> requestFeeApproval({
    required String type,
    required int voucherId,
    required Money amount,
    required String reason,
    required int requestedBy,
  }) async {
    return const Success(1); // request id 1
  }

  @override
  Future<Result<void>> cancelVoucher({required int voucherId, required String reason, required int cancelledBy}) async =>
      const Success(null);

  @override
  Future<Result<int>> generateBatchVouchers({
    required int batchId,
    required String monthYear,
    required DateTime dueDate,
    required int createdBy,
  }) async =>
      const Success(5);

  @override
  Future<Result<List<DefaulterAgingRecord>>> getDefaulterAgingReport({int? batchId}) async => const Success([]);

  @override
  Future<Result<List<Receipt>>> getReceiptsForStudent(int studentId) async => const Success([]);

  @override
  Future<Result<FeeVoucher?>> getVoucherById(int id) async => const Success(null);

  @override
  Future<Result<List<FeeVoucher>>> getVouchers({int? batchId, int? studentId, VoucherStatus? status, String? monthYear}) async =>
      const Success([]);
}

void main() {
  late MockFeeRepository repo;
  late CollectFeeUseCase collectUseCase;
  late FeeApprovalsUseCase approvalsUseCase;

  setUp(() {
    repo = MockFeeRepository();
    collectUseCase = CollectFeeUseCase(repo);
    approvalsUseCase = FeeApprovalsUseCase(repo);
  });

  group('Maker-Checker & Permission Enforcement', () {
    test('CollectFeeUseCase rejects action if user lacks feesCollect permission', () async {
      // User with Viewer permissions (only has view permissions)
      final viewerPerms = permissionsForRole(AppRole.viewer);

      final result = await collectUseCase(
        userPermissions: viewerPerms,
        voucherId: 1,
        studentId: 1,
        amount: const Money(300000),
        paymentMode: 'cash',
        createdBy: 2,
      );

      expect(result.isFailure, true);
      expect(result.fold(onSuccess: (_) => null, onFailure: (f) => f), isA<PermissionFailure>());
    });

    test('CollectFeeUseCase succeeds when user has Accountant role', () async {
      final accountantPerms = permissionsForRole(AppRole.accountant);

      final result = await collectUseCase(
        userPermissions: accountantPerms,
        voucherId: 1,
        studentId: 1,
        amount: const Money(300000),
        paymentMode: 'cash',
        createdBy: 2,
      );

      expect(result.isSuccess, true);
      expect(result.valueOrThrow.receipt.receiptNumber, 'RCP-000001');
    });

    test('CollectFeeUseCase rejects non-positive payment amounts', () async {
      final accountantPerms = permissionsForRole(AppRole.accountant);

      final zeroResult = await collectUseCase(
        userPermissions: accountantPerms,
        voucherId: 1,
        studentId: 1,
        amount: const Money(0),
        paymentMode: 'cash',
        createdBy: 2,
      );
      expect(zeroResult.isFailure, true);
      expect(zeroResult.fold(onSuccess: (_) => null, onFailure: (f) => f), isA<ValidationFailure>());
    });

    test('FeeApprovalsUseCase requires non-empty justification reason', () async {
      final resEmpty = await approvalsUseCase.requestAdjustment(
        type: 'waiver',
        voucherId: 1,
        amount: const Money(100000),
        reason: '   ',
        requestedBy: 2,
      );

      expect(resEmpty.isFailure, true);
      expect(resEmpty.fold(onSuccess: (_) => null, onFailure: (f) => f)?.message, contains('reason is required'));

      final resValid = await approvalsUseCase.requestAdjustment(
        type: 'waiver',
        voucherId: 1,
        amount: const Money(100000),
        reason: 'Student father passed away, concession approved by principal',
        requestedBy: 2,
      );

      expect(resValid.isSuccess, true);
    });
  });
}
