import 'package:flutter_test/flutter_test.dart';
import 'package:classkhata/core/money/money.dart';
import 'package:classkhata/core/security/permission_service.dart';
import 'package:classkhata/features/payroll/domain/entities/payroll_entities.dart';
import 'package:classkhata/features/payroll/domain/repositories/payroll_repository.dart';
import 'package:classkhata/features/payroll/domain/usecases/payroll_usecases.dart';

void main() {
  group('Payroll Calculation & Domain Logic', () {
    test('Calculates gross and net salary with allowances and deductions', () {
      const structure = SalaryStructure(
        id: 1,
        staffId: 10,
        structureType: 'fixed',
        baseAmount: Money(3500000), // 35,000 PKR
        allowances: Money(500000), // 5,000 PKR
        deductions: Money(200000), // 2,000 PKR
        isActive: true,
      );

      expect(structure.grossSalary.inRupees, 40000.0);
      expect(structure.netSalary.inRupees, 38000.0);
    });

    test('CalculateSalaryEngine computes net pay factoring advance recovery', () {
      final base = Money.fromRupees(50000);
      final allowances = Money.fromRupees(10000);
      final deductions = Money.fromRupees(3000);
      final advanceRecovery = Money.fromRupees(5000);

      final net = CalculateSalaryEngine.calculateNetSalary(
        baseSalary: base,
        allowances: allowances,
        deductions: deductions,
        advanceRecovery: advanceRecovery,
      );

      // (50000 + 10000) - 3000 - 5000 = 52,000
      expect(net.inRupees, 52000.0);
    });

    test('CalculateSalaryEngine clamps negative net salary to zero', () {
      final base = Money.fromRupees(10000);
      final allowances = const Money(0);
      final deductions = Money.fromRupees(5000);
      final advanceRecovery = Money.fromRupees(15000);

      final net = CalculateSalaryEngine.calculateNetSalary(
        baseSalary: base,
        allowances: allowances,
        deductions: deductions,
        advanceRecovery: advanceRecovery,
      );

      expect(net.isZero, true);
    });

    test('StaffAdvance tracks remaining balance and recovery status', () {
      final advance = StaffAdvance(
        id: 1,
        staffId: 5,
        amount: Money.fromRupees(20000),
        recovered: Money.fromRupees(15000),
        remaining: Money.fromRupees(5000),
        reason: 'Emergency advance',
        issueDate: DateTime.now(),
      );

      expect(advance.isFullyRecovered, false);
      expect(advance.remaining.inRupees, 5000.0);

      final completedAdvance = StaffAdvance(
        id: 2,
        staffId: 5,
        amount: Money.fromRupees(20000),
        recovered: Money.fromRupees(20000),
        remaining: const Money(0),
        issueDate: DateTime.now(),
      );

      expect(completedAdvance.isFullyRecovered, true);
    });

    test('RunMonthlyPayrollUseCase enforces permission check', () async {
      final useCase = RunMonthlyPayrollUseCase(_MockPayrollRepo());
      final res = await useCase(
        userPermissions: {Permission.feesCollect}, // Missing Permission.payrollRun
        monthYear: '2026-10',
        createdBy: 1,
      );

      expect(res.isFailure, true);
    });

    test('PaySalaryUseCase enforces permission check', () async {
      final useCase = PaySalaryUseCase(_MockPayrollRepo());
      final res = await useCase(
        userPermissions: {Permission.feesCollect}, // Missing Permission.payrollRun
        payrollRunId: 1,
        paymentMode: 'cash',
        paidBy: 1,
      );

      expect(res.isFailure, true);
    });
  });
}

class _MockPayrollRepo implements PayrollRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
