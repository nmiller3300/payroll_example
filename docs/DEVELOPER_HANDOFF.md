# Aegis Payroll — Developer Handoff

This document is a clean handoff for the next developer working on this resource.

## 1) Project Summary

A QBCore/FiveM payroll resource with split user experience:

- **Boss/Command tablet** (`/payroll`) for payroll operations and business settings.
- **Employee tablet** (`/payrollemployee`) for timeclock and personal payroll interactions.

Resource startup prints:

- `Aegis-Payroll Loaded Succesfully!`

---

## 2) Current Feature Set (Implemented)

### Access / Permissions

- Boss tablet access path with server-side checks.
- Admin commands for granting/revoking payroll access by job + min grade.
- Permission lookup supports QBCore permission, ACE, and identifier allow-list.

### Payroll + Tax

- Admin-only tax command:
  - `/settax [tax] [ss] [medicare]`
- Boss payload includes current tax rates for visibility.
- Payroll breakdown computes gross, deductions (tax/SS/Medicare), and net.

### Compensation Controls

- Grade-level pay override.
- Employee-specific pay override.
- Bonus entries for employees.
- UI flow uses **Player ID** preview callback for easier targeting.

### Timeclock + Adjustments

- Clock-in / clock-out endpoints and persistence.
- Adjustment request flow (employee submit, boss review approve/reject).
- Audit grace for open shifts (`openShiftGraceMinutesForAudit`) to reduce false positives.

### Branding / Theme

- Per-business settings include:
  - login domain
  - business name override
  - business logo URL
  - boss primary color
  - employee primary color
- Boss and employee tablets can have different primary colors.

### Data Layer

- Runtime table creation/migrations in `ensureDatabase()`.
- Job + grade sync from `QBCore.Shared.Jobs` into payroll tables.
- SQL install script included (`sql/mybusiness_payroll.sql`).

---

## 3) Command Reference

- `/payroll` — open boss tablet
- `/payrollemployee` — open employee tablet
- `/settax [tax] [ss] [medicare]` — set global tax rates (admin)
- `/payrollgrant [id] [job] [grade]` — grant boss access
- `/payrollrevoke [id] [job]` — revoke boss access
- `/payrolljobs` — print city jobs + grades to console

---

## 4) File Map (High Value)

- `server/main.lua`
  - DB bootstrap/migrations
  - job sync
  - payroll computation
  - tax command
  - access commands
  - clock/adjustment/audit events
- `client/main.lua`
  - open/close tablet events
  - NUI callbacks
  - input/camera lock while tablet is open
- `html/index.html`, `html/styles.css`, `html/app.js`
  - boss/employee tablet rendering and NUI interactions
- `config.lua`
  - command names, permissions, payroll tuning, default theme
- `permissions.lua`
  - identifier allow-list source
- `sql/mybusiness_payroll.sql`
  - DB schema + default tax seed

---

## 5) Known Operational Notes

- Re-running SQL imports can show informational `Table already exists` notes.
- Tax seed uses `INSERT IGNORE` to avoid duplicate/deprecation warning noise.
- If schema drifts on old installs, restart resource to run runtime migration guards.

---

## 6) Next Recommended Work (Priority)

### Priority A (Stability / Production)

1. **Offline paycheck queueing**
   - Queue payroll rows for offline players.
   - Auto-disburse on login + notify.
   - Add status tracking (`queued`, `paid`, optional `awaiting_funds`).

2. **Society shortfall handling**
   - If society has insufficient funds, mark payroll as pending liability rather than silent partial behavior.

3. **Idempotent payroll runs**
   - Prevent duplicate payouts in the same period (run ID + employee unique constraints).

### Priority B (UX / Operations)

4. **Boss payroll run history UI**
   - show each run totals, queued count, paid count, tax totals.

5. **Employee payslip history UI**
   - period list with gross/deductions/net and status.

6. **Export support**
   - CSV export for accounting workflows.

### Priority C (Structure)

7. **Service split in server code**
   - Extract modules for `access`, `payroll`, `theme`, `audit`, `repository` to reduce single-file complexity.

---

## 7) Quick Start for New Developer

1. Ensure dependencies in server cfg:
   - `oxmysql`, `qb-core`, `qb-management`, this resource.
2. Start server and verify startup log line.
3. Run `/payrolljobs` and verify city jobs/grades print.
4. Verify commands:
   - `/settax`
   - `/payrollgrant`
   - `/payroll`, `/payrollemployee`
5. Validate one full cycle:
   - clock-in -> clock-out -> payroll run.

---

## 8) Quality Expectations

- Keep UI enterprise/professional (no gamey/cyberpunk style).
- Maintain split experience: boss workflows must remain separate from employee workflows.
- Prefer additive migrations over destructive schema changes.
- Every permission-sensitive action must validate access server-side.
