/// Permission service: maps roles to allowed actions.
///
/// Business rules for permissions live here in the domain layer.
/// UI widgets must NOT make security decisions — they call this service.
library;

import '../errors/failures.dart';

// ---------------------------------------------------------------------------
// Permission identifiers
// ---------------------------------------------------------------------------

/// All permissions in the system, organized by module.
enum Permission {
  // Students
  studentsView,
  studentsCreate,
  studentsEdit,
  studentsDelete,

  // Fees
  feesView,
  feesCollect,
  feesVoucherGenerate,
  feesDiscount,
  feesRefund,
  feesWaiver,

  // Payroll
  payrollView,
  payrollRun,
  payrollEdit,

  // Inventory
  inventoryView,
  inventoryStockIn,
  inventoryStockOut,
  inventoryEdit,

  // Finance
  financeView,
  financeExpenseCreate,
  financeDayClose,

  // Reports
  reportsView,
  reportsExport,

  // Users & Settings
  usersView,
  usersCreate,
  usersEdit,
  usersDelete,
  settingsEdit,

  // Approvals
  approvalsApprove,
  approvalsReject,

  // Audit
  auditView,
  auditVerify,

  // Backup
  backupCreate,
  backupRestore,
}

// ---------------------------------------------------------------------------
// Role → Permission mapping
// ---------------------------------------------------------------------------

/// Predefined role names.
enum AppRole { admin, accountant, teacher, viewer }

/// Returns the set of permissions granted to [role].
Set<Permission> permissionsForRole(AppRole role) {
  return switch (role) {
    AppRole.admin => Permission.values.toSet(), // all permissions
    AppRole.accountant => {
        Permission.studentsView,
        Permission.studentsCreate,
        Permission.studentsEdit,
        Permission.feesView,
        Permission.feesCollect,
        Permission.feesVoucherGenerate,
        Permission.feesDiscount,
        Permission.feesRefund,
        Permission.feesWaiver,
        Permission.payrollView,
        Permission.payrollRun,
        Permission.inventoryView,
        Permission.inventoryStockIn,
        Permission.inventoryStockOut,
        Permission.inventoryEdit,
        Permission.financeView,
        Permission.financeExpenseCreate,
        Permission.financeDayClose,
        Permission.reportsView,
        Permission.reportsExport,
        Permission.auditView,
        Permission.backupCreate,
      },
    AppRole.teacher => {
        Permission.studentsView,
        Permission.feesView,
        Permission.inventoryView,
        Permission.reportsView,
      },
    AppRole.viewer => {
        Permission.studentsView,
        Permission.feesView,
        Permission.payrollView,
        Permission.inventoryView,
        Permission.reportsView,
      },
  };
}

// ---------------------------------------------------------------------------
// Permission check service
// ---------------------------------------------------------------------------

/// Checks whether [userPermissions] includes [required].
///
/// Returns [Success(null)] if allowed, [Failure(PermissionFailure)] if denied.
/// Call this in every use case before executing any sensitive action.
Result<void> checkPermission({
  required Set<Permission> userPermissions,
  required Permission required,
}) {
  if (userPermissions.contains(required)) {
    return const Success(null);
  }
  return Failure(
    PermissionFailure(
      'You do not have permission to perform this action.',
      technicalDetail: 'Missing permission: ${required.name}',
    ),
  );
}
