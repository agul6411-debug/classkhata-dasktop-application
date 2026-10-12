# ClassKhata — Release & Deployment Guide

## 1. Prerequisites
- **Flutter SDK:** 3.24.0 or newer
- **Visual Studio 2022:** With "Desktop development with C++" workload
- **Inno Setup 6.x:** For packaging the Windows installer (.exe)

---

## 2. Compiling the Obfuscated Release Build

To produce a production Windows binary with Dart symbol obfuscation and stripped debug information:

```powershell
# Navigate to the project root
cd C:\classKhata-application\classkhata

# Clean and fetch dependencies
flutter clean
flutter pub get

# Compile obfuscated Windows binary
flutter build windows --release `
  --obfuscate `
  --split-debug-info=build\windows\symbols
```

### Key Build Flags:
- `--release`: Compiles ahead-of-time (AOT) machine code with optimizations enabled.
- `--obfuscate`: Scrambles class names, method names, and field identifiers to prevent reverse engineering.
- `--split-debug-info=build\windows\symbols`: Extracts symbols and stack traces to an external symbols directory so binaries do not contain readable symbols.

---

## 3. Packaging with Inno Setup

Once `flutter build windows --release` finishes, the executable bundle is located in:
`build\windows\x64\runner\Release\`

To package into a single-file installer:
1. Open `installer\classkhata.iss` in Inno Setup Compiler.
2. Click **Build -> Compile** (or run via command line):
   ```cmd
   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\classkhata.iss
   ```
3. The standalone setup installer will be generated in `installer\dist\ClassKhata_Windows_Setup_v1.0.0.exe`.

---

## 4. Release Verification Checklist

- [ ] All automated tests pass cleanly (`flutter test`).
- [ ] Static analyzer reports 0 errors and 0 warnings (`flutter analyze`).
- [ ] Machine ID generation produces stable identifier matching format `CK-XXXX-XXXX-XXXX`.
- [ ] Offline license generator (`tools/generate_license.dart`) remains strictly in developer repository and is NOT distributed to end users.
- [ ] SQLite PRAGMA integrity check and SHA-256 audit chain check pass on initial setup.
- [ ] Database encryption key is stored securely in Windows Credential Store (DPAPI).
- [ ] Formula-injection sanitization verified on all exported Excel files.
