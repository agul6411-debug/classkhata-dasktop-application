/// Use case calculating executive Dashboard KPIs.
library;

import '../../../../core/errors/failures.dart';
import '../../../../core/money/money.dart';
import '../../../academics/domain/repositories/academic_repository.dart';
import '../../../fees/domain/entities/fee_entities.dart';
import '../../../fees/domain/repositories/fee_repository.dart';
import '../../../students/domain/entities/student_entities.dart';
import '../../../students/domain/repositories/student_repository.dart';
import '../entities/dashboard_kpis.dart';

class GetDashboardKpisUseCase {
  final FeeRepository _feeRepo;
  final StudentRepository _studentRepo;
  final AcademicRepository _academicRepo;

  const GetDashboardKpisUseCase({
    required FeeRepository feeRepo,
    required StudentRepository studentRepo,
    required AcademicRepository academicRepo,
  })  : _feeRepo = feeRepo,
        _studentRepo = studentRepo,
        _academicRepo = academicRepo;

  Future<Result<DashboardKpis>> call(String monthYear) async {
    // 1. Fetch vouchers for the selected month (gracefully defaults to empty list if none exist or error)
    final vouchersRes = await _feeRepo.getVouchers(monthYear: monthYear);
    final vouchers = vouchersRes.fold(
      onSuccess: (list) => list,
      onFailure: (_) => <FeeVoucher>[],
    );

    // 2. Fetch counts
    final studentsRes = await _studentRepo.getStudents(status: StudentStatus.active);
    final coursesRes = await _academicRepo.getCourses();
    final batchesRes = await _academicRepo.getBatches();

    final studentsCount = studentsRes.fold(onSuccess: (list) => list.length, onFailure: (_) => 0);
    final coursesCount = coursesRes.fold(onSuccess: (list) => list.length, onFailure: (_) => 0);
    final batchesCount = batchesRes.fold(onSuccess: (list) => list.length, onFailure: (_) => 0);

    // 3. Aggregate totals in paisa
    int expectedPaisa = 0;
    int collectedPaisa = 0;
    int overduePaisa = 0;

    int paidCount = 0;
    int partialCount = 0;
    int unpaidCount = 0;
    int overdueCount = 0;

    final now = DateTime.now();
    final alerts = <DashboardAlert>[];

    for (final v in vouchers) {
      expectedPaisa += v.totalDue.paisa;
      collectedPaisa += v.amountPaid.paisa;

      if (v.status == VoucherStatus.paid) {
        paidCount++;
      } else if (v.status == VoucherStatus.partial) {
        partialCount++;
        if (now.isAfter(v.dueDate)) {
          overduePaisa += v.balanceRemaining.paisa;
          overdueCount++;
        }
      } else if (v.status == VoucherStatus.overdue || now.isAfter(v.dueDate)) {
        overduePaisa += v.balanceRemaining.paisa;
        overdueCount++;
      } else {
        unpaidCount++;
      }

      // Check upcoming due date in next 3 days
      final diff = v.dueDate.difference(now).inDays;
      if (diff >= 0 && diff <= 3 && !v.isPaidInFull) {
        alerts.add(DashboardAlert(
          title: 'Upcoming Due Date',
          message: 'Voucher ${v.voucherNumber} is due in $diff day(s).',
          severity: 'warning',
        ));
      }
    }

    final pendingPaisa = (expectedPaisa - collectedPaisa);

    return Success(DashboardKpis(
      monthYear: monthYear,
      expectedTotal: Money.fromPaisa(expectedPaisa),
      collectedTotal: Money.fromPaisa(collectedPaisa),
      pendingTotal: Money.fromPaisa(pendingPaisa > 0 ? pendingPaisa : 0),
      overdueTotal: Money.fromPaisa(overduePaisa),
      studentsCount: studentsCount,
      coursesCount: coursesCount,
      batchesCount: batchesCount,
      paidCount: paidCount,
      partialCount: partialCount,
      unpaidCount: unpaidCount,
      overdueCount: overdueCount,
      alerts: alerts,
    ));
  }
}
