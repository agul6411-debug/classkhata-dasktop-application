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

## Input Sanitization

- All Excel exports sanitize cells beginning with `=`, `+`, `-`, `@`
  (formula injection prevention).
- All Drift queries use parameterized statements — no string-concatenated SQL.
