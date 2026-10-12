# ClassKhata — Security Design

## Threat Model

ClassKhata is a **single-PC, fully offline** application. The threat
model focuses on:

1. **Physical access** — a non-admin user sitting at the computer.
2. **Local data theft** — someone copying the database file.
3. **Insider misuse** — a lower-privileged user trying to exceed their access.
4. **Audit tampering** — someone editing the audit log to cover tracks.
5. **Password recovery** — the only admin forgetting their password.

Out of scope: network attacks, remote exploitation (no network surface).

## Database Encryption

- SQLite database encrypted with **SQLite3MultipleCiphers** (SQLCipher-compatible).
- Encryption key: 256-bit random, stored in the **Windows Credential Manager**
  via `flutter_secure_storage`. The key is never written to disk, config, logs, or code.
- WAL mode and foreign keys enforced on every connection open.
- Integrity check (`PRAGMA integrity_check`) runs on every startup.

## Password Security

- Passwords hashed with **Argon2id** via `serverpod_argon2`.
- The Argon2 encoded string includes the random salt and all parameters.
- Plaintext passwords are never stored, logged, or transmitted.
- Minimum password length: 8 characters.

## Login Security

- **5 failed attempts** → account locked for **15 minutes**.
- **10 minutes of inactivity** → session auto-locked; re-authentication required.
- First login after admin creation requires no forced password change unless
  the admin explicitly sets `mustChangePassword = true` for sub-users.

## Recovery Key

- A one-time **20-character recovery key** (format: `XXXX-XXXX-XXXX-XXXX-XXXX`)
  is generated at first-run setup.
- Only the **SHA-256 hash** of the key is stored in the database.
- The plaintext key is shown once and never stored — if lost, recovery is impossible.
- The key is single-use; after use it is marked `isUsed = true`.

## Permissions

- Four roles: **Admin, Accountant, Teacher, Viewer**.
- Permission checks live in `domain/usecases` — hiding a UI button is **not** security.
- Every sensitive use case calls `checkPermission()` before executing.

## Maker-Checker (Approval Workflow)

- Discounts, refunds, fee waivers and cancellations above a configurable
  threshold require a second approver.
- The `approval_requests` table records: who requested, what, when, payload,
  and who approved/rejected with their note.
- The approver cannot be the same person who requested.

## Audit Log Chain

- Every financial event writes a row to `audit_log`.
- Each row stores the **SHA-256 hash of the previous row's content** (`previousHash`),
  forming a tamper-evident chain.
- Verification: `verifyAuditChain()` re-computes every hash and checks the
  `previousHash` links. Any modification, insertion, or deletion breaks the chain.
- The genesis entry uses the constant string `GENESIS` as its `previousHash`.

## Backup Security

- Backups are file-copies of the encrypted database file — they are encrypted
  at rest by SQLite3MultipleCiphers automatically.
- Each backup has a SHA-256 checksum verified before any restore.
- Pre-migration backups are created automatically before any schema upgrade.

## No Telemetry

The app makes zero network calls. There is no analytics, crash reporting,
or license server. License validation is done offline with public-key
cryptography (Phase 7).

## Offline Cryptographic Licensing (Phase 7)

- **Asymmetric Signature Verification:** Licenses are signed using an RSA-2048 private key
  retained exclusively on internal vendor workstations in `tools/generate_license.dart`.
- **Public-Key Embedded Only:** The client application contains ONLY the public exponent
  and modulus (`LicensingPublicKey.key`). No private keys are ever distributed in client binaries.
- **Hardware Machine Binding:** Machine IDs are derived from stable Windows hardware attributes
  (`COMPUTERNAME`, `PROCESSOR_IDENTIFIER`, `SystemDrive`) and hashed via SHA-256 (`CK-XXXX-XXXX-XXXX`).
  License keys are cryptographically bound to the target machine ID.
- **Trial & Clock Rollback Tamper Resistance:**
  - 7-day trial start is signed and persisted across dual independent storage locations.
  - Heartbeat checks compare current system time with monotonic `last_seen_epoch` records.
  - Clock rollback attempts immediately place the system in non-destructive read-only mode.

## Startup Integrity & Self-Healing (Phase 7)

- Every launch executes:
  1. SQLite storage engine validation via `PRAGMA integrity_check;`.
  2. Cryptographic audit chain verification (`verifyAuditChain`) from genesis to head.
  3. Automatic backup directory accessibility and write permissions test.
- Any integrity failure displays clear, user-friendly non-technical alerts with
  guidance to restore from backup or contact support.

## Input Sanitization

- All Excel exports sanitize cells beginning with `=`, `+`, `-`, `@`
  (formula injection prevention).
- All Drift queries use parameterized statements — no string-concatenated SQL.

## Final Security Review Checklist

| Security Control | Verification Standard | Implementation Status |
|---|---|---|
| **Database Encryption** | AES-256 via SQLite3MultipleCiphers, key in Windows Credential Store (DPAPI) | Verified & Tested |
| **Password Storage** | Argon2id with per-user cryptographic salt | Verified & Tested |
| **Recovery System** | 20-character single-use recovery key, only SHA-256 stored | Verified & Tested |
| **Audit Ledger** | SHA-256 hash-chained immutable audit records with genesis verification | Verified & Tested |
| **Maker-Checker** | Independent dual-authorization on transactions > threshold | Verified & Tested |
| **Backup Integrity** | SHA-256 checksum verification, pre-migration backups, test restore sandbox | Verified & Tested |
| **Offline Licensing** | RSA-2048 offline signature verification, public key only in client | Verified & Tested |
| **Clock Rollback Protection** | Monotonic epoch validation, dual-storage trial anchor | Verified & Tested |
| **Formula Injection** | Strict sanitization of `=`, `+`, `-`, `@` prefixes on Excel export | Verified & Tested |
| **Zero Telemetry** | 100% offline desktop runtime, zero external network calls | Verified & Tested |
