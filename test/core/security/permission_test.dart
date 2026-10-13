import 'package:classkhata/core/errors/failures.dart';
import 'package:classkhata/core/security/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Permission Service', () {
    group('Admin', () {
      late Set<Permission> adminPerms;

      setUp(() => adminPerms = permissionsForRole(AppRole.admin));

      test('admin has all permissions', () {
        for (final p in Permission.values) {
          final result = checkPermission(userPermissions: adminPerms, required: p);
          expect(result.isSuccess, true, reason: 'Admin missing: ${p.name}');
        }
      });
    });

    group('Accountant', () {
      late Set<Permission> perms;

      setUp(() => perms = permissionsForRole(AppRole.accountant));

      test('can collect fees', () {
        final r = checkPermission(userPermissions: perms, required: Permission.feesCollect);
        expect(r.isSuccess, true);
      });

      test('cannot manage users', () {
        final r = checkPermission(userPermissions: perms, required: Permission.usersCreate);
        expect(r.isFailure, true);
        expect(r.fold(onSuccess: (_) => null, onFailure: (f) => f), isA<PermissionFailure>());
      });

      test('cannot change settings', () {
        final r = checkPermission(userPermissions: perms, required: Permission.settingsEdit);
        expect(r.isFailure, true);
      });

      test('can view and export reports', () {
        expect(checkPermission(userPermissions: perms, required: Permission.reportsView).isSuccess, true);
        expect(checkPermission(userPermissions: perms, required: Permission.reportsExport).isSuccess, true);
      });
    });

    group('Teacher', () {
      late Set<Permission> perms;

      setUp(() => perms = permissionsForRole(AppRole.teacher));

      test('can view students', () {
        expect(checkPermission(userPermissions: perms, required: Permission.studentsView).isSuccess, true);
      });

      test('cannot collect fees', () {
        expect(checkPermission(userPermissions: perms, required: Permission.feesCollect).isFailure, true);
      });

      test('cannot run payroll', () {
        expect(checkPermission(userPermissions: perms, required: Permission.payrollRun).isFailure, true);
      });
    });

    group('Viewer', () {
      late Set<Permission> perms;

      setUp(() => perms = permissionsForRole(AppRole.viewer));

      test('can view all modules', () {
        expect(checkPermission(userPermissions: perms, required: Permission.studentsView).isSuccess, true);
        expect(checkPermission(userPermissions: perms, required: Permission.feesView).isSuccess, true);
        expect(checkPermission(userPermissions: perms, required: Permission.payrollView).isSuccess, true);
        expect(checkPermission(userPermissions: perms, required: Permission.inventoryView).isSuccess, true);
        expect(checkPermission(userPermissions: perms, required: Permission.reportsView).isSuccess, true);
      });

      test('cannot create anything', () {
        expect(checkPermission(userPermissions: perms, required: Permission.studentsCreate).isFailure, true);
        expect(checkPermission(userPermissions: perms, required: Permission.feesCollect).isFailure, true);
        expect(checkPermission(userPermissions: perms, required: Permission.usersCreate).isFailure, true);
      });
    });

    test('PermissionFailure has descriptive message', () {
      final perms = permissionsForRole(AppRole.viewer);
      final result = checkPermission(userPermissions: perms, required: Permission.usersDelete);
      expect(result.isFailure, true);
      final failure = result.fold(onSuccess: (_) => null, onFailure: (f) => f)!;
      expect(failure.message, contains('permission'));
    });
  });
}
