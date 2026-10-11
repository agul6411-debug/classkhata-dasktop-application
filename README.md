# ClassKhata

Offline Windows desktop application for school/academy management.
Covers Fee Management, Payroll, and Inventory.

---

## Requirements

- **Flutter SDK** ≥ 3.44 (with Dart ≥ 3.12)
- **Windows** 10 or later (64-bit)
- **Visual Studio 2022** with "Desktop development with C++" workload
- **Git**

---

## Setup

```powershell
git clone <repo>
cd classkhata

# Install dependencies
flutter pub get

# Generate code (Drift DAOs + Riverpod providers)
flutter pub run build_runner build --delete-conflicting-outputs

# Generate localizations
flutter gen-l10n
```

> The Nunito font files must be placed in `assets/fonts/` before building.
> Download from [Google Fonts](https://fonts.google.com/specimen/Nunito).

---

## Run (Debug)

```powershell
flutter run -d windows
```

---

## Run Tests

```powershell
# Unit tests only (no device needed)
flutter test test/core/

# All tests
flutter test
```

---

## Build (Release)

```powershell
flutter build windows --release
```

The compiled app is at `build\windows\x64\runner\Release\`.

---

## Code Generation

Drift and Riverpod use code generation. Run after changing any table or
`@riverpod`-annotated file:

```powershell
flutter pub run build_runner build --delete-conflicting-outputs
```

Or watch mode during development:

```powershell
flutter pub run build_runner watch --delete-conflicting-outputs
```

---

## Project Structure

```
lib/
├── main.dart              # Entry point
├── app/                   # App shell, theme, router, global providers
├── core/                  # Cross-cutting: DB, security, money, errors, logging
├── shared/                # Reusable UI widgets, layout, localization ARBs
└── features/              # Feature slices (setup, auth, fees, payroll, etc.)

docs/
├── ARCHITECTURE.md
├── SECURITY.md
└── DEPENDENCIES.md

test/                      # Mirrors lib/ structure
installer/                 # Inno Setup script (Phase 7)
```

---

## First Run

On first launch the app shows the **Setup Wizard**:
1. Enter academy name and details.
2. Create the admin account (email + password).
3. **Save the recovery key** — it is shown once and cannot be recovered.

---

## Build Phases

| Phase | Status | Content |
|-------|--------|---------|
| 1 | ✅ | Foundation: DB, auth, security, setup wizard |
| 2 | ⏳ | Academics and Students |
| 3 | ⏳ | Fees (core) |
| 4 | ⏳ | Dashboard and Finance |
| 5 | ⏳ | Payroll |
| 6 | ⏳ | Inventory |
| 7 | ⏳ | Reports, licensing, installer |
