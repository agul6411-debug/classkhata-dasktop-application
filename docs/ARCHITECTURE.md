# ClassKhata — Architecture

## Feature-Sliced Structure

Each feature under `lib/features/` is a self-contained vertical slice:

```
features/<name>/
├── data/          ← Drift DAOs, model mappers, repository implementations
├── domain/        ← Pure Dart: entities, repository interfaces, use cases
└── presentation/  ← Riverpod providers, pages, feature widgets
```

## Strict Dependency Rules

| From | Can import | Cannot import |
|------|-----------|---------------|
| `domain` | `core/`, other `domain` interfaces | `data/`, `presentation/`, Flutter, Drift |
| `data` | `domain/`, `core/database`, `core/security` | Other features' `data/` |
| `presentation` | `domain/usecases`, `core/`, `shared/` | Other features' `data/` or `presentation/` |
| `shared/` | `core/`, `app/theme` | Any `features/` |
| `core/` | Nothing from `features/` | — |

## Data Flow (Fee Payment Example)

```
UI (CollectFeeButton)
  → reads authSessionProvider (Riverpod)
  → calls CollectFeeUseCase(repository, auditChain, permissionService)
      → checkPermission(feesCollect)
      → db.transaction {
            update voucher status
            insert payment
            insert receipt (sequential number)
            insert cash_book_entry
            insert audit_log (with hash chain)
         }
  → Success → UI shows receipt
```

## Money Rule

All monetary values are `int` in paisa. The `Money` value type in
`core/money/money.dart` is the only allowed representation. Never use
`double` for money, ever.

## Transaction Rule

Any operation touching multiple tables must be wrapped in
`db.transaction(...)`. The transaction either commits fully or rolls back
entirely — no partial writes.

## Audit Log

Every financial action writes a hash-chained audit entry inside the same
transaction. The chain can be verified via `verifyAuditChain()`.
