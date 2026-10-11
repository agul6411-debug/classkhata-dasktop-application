# ClassKhata — Dependencies

All packages verified on pub.dev and confirmed to support Windows desktop.

## Runtime Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | ^3.4.3 | State management |
| `riverpod_annotation` | ^4.0.7 | Code-generation annotations for Riverpod |
| `drift` | ^2.35.1 | Type-safe SQLite ORM / reactive database |
| `sqlite3_flutter_libs` | ^0.5.0 | Ships native sqlite3 binaries for Windows |
| `flutter_secure_storage` | ^11.2.0 | DB key storage in Windows Credential Manager |
| `serverpod_argon2` | ^0.1.0 | Argon2id password hashing (prebuilt Windows DLLs) |
| `go_router` | ^18.0.1 | Declarative navigation with route guards |
| `pdf` | ^3.11.3 | PDF generation for receipts and reports |
| `printing` | ^5.14.2 | Print PDF to physical printer / preview |
| `excel` | ^4.0.6 | Read/write Excel files for import/export |
| `path_provider` | ^2.1.5 | Locate app support/documents directories |
| `path` | ^1.9.0 | File path utilities |
| `shared_preferences` | ^2.3.5 | UI preferences only (language, theme) |
| `url_launcher` | ^6.3.1 | Open `wa.me` WhatsApp links |
| `qr_flutter` | ^4.1.0 | QR codes on fee receipts |
| `crypto` | ^3.0.6 | SHA-256 for audit chain and backup checksums |
| `pointycastle` | ^3.9.1 | Cryptographic utilities (reserved for Phase 7 licensing) |
| `intl` | ^0.20.2 | Date/number formatting, locale support |
| `uuid` | ^4.5.1 | UUID generation |
| `collection` | ^1.19.1 | Additional collection utilities |
| `equatable` | ^2.0.7 | Value equality for domain entities |
| `flutter_localizations` | SDK | Flutter's built-in i18n delegates |

## Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_lints` | ^5.0.0 | Lint rules |
| `drift_dev` | ^2.35.1 | Drift code generation (`.g.dart` files) |
| `build_runner` | ^2.16.2 | Code generation runner |
| `riverpod_generator` | ^4.0.9 | Riverpod `@riverpod` annotation code gen |

## Build Hooks (pubspec.yaml)

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc   # Use SQLite3MultipleCiphers instead of plain SQLite
```

This replaces the deprecated `sqlcipher_flutter_libs` package and provides
full SQLCipher-compatible encryption without manual CMake changes.

## Explicitly NOT Used

| Package | Reason |
|---------|--------|
| `sqlcipher_flutter_libs` | EOL as of v0.7.0+eol; replaced by sqlite3mc hook |
| `freezed` | Not justified for Phase 1 entities; plain `final` classes used |
| `hive` / `isar` | Not chosen; Drift + SQLCipher provides ACID + encryption |
| `dartz` | Custom `Result<T>` sealed class used instead |
