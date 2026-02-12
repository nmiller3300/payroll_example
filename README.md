# MyBusiness Payroll (QBCore / FiveM)

Enterprise payroll tablet with **separate boss and employee experiences**, configurable pay periods, society-funded payroll runs, and audit tooling.

## What changed in this build

- **Boss tablet (`/payroll`)** is now separated from **Employee tablet (`/payrollemployee`)**.
- Business owners can set **pay period length**, **employee login domain**, **business display name**, and **hourly rate** from the boss tablet.
- Employees see a premium fake login identity in tablet format: `firstname.lastname@business.org`.
- Added real clock endpoints and shift storage (`clock in/out`) for employee-side use.
- Added audit checks for long shifts, missing clock-outs, and extreme period totals for theft/time abuse review.
- Added optional permission file (`permissions.lua`) for `license:`, `fivem:`, and other identifiers.

---

## Commands

- `/payroll` → Boss/command dashboard (requires boss-level access).
- `/payrollemployee` → Employee payroll tablet and clock controls.
- `/payrollgrant [id] [job] [grade]` → grant boss dashboard access by job + minimum grade.
- `/payrollrevoke [id] [job]` → revoke boss dashboard access.
- `/payrolljobs` → print synced city jobs to server console.

---

## Access model

Boss access is granted when **any** of these pass:

1. ACE node (if enabled): `Config.RequiredAce`
2. Identifier allow-list (`permissions.lua`) if enabled
3. DB grant in `mybusiness_payroll_access` with `grade >= min_grade`
4. Auto-boss fallback (`Config.AutoBossAccess = true` and `PlayerData.job.isboss = true`)

Employee tablet is open to all logged-in players and always job-scoped.

---

## Permission file (`permissions.lua`)

Use this if you want to avoid manual grant command usage for trusted IDs.

```lua
Permissions.IdentifierAllowList = {
  ['license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'] = true,
  ['fivem:123456'] = true,
}
```

`server/main.lua` checks these identifiers with `GetPlayerIdentifiers(source)`.

---

## Pay period and society payout

Boss tablet settings write to `mybusiness_payroll_settings`.

Config limits:
- `Config.Payroll.minPeriodDays`
- `Config.Payroll.maxPeriodDays`

When boss clicks **Run Payroll (Society)**:
- system totals current pay-period payroll
- attempts to debit society account through `qb-management` (`RemoveMoney(jobName, amount)`)
- logs run in audit table even if society resource is unavailable

---

## Employee tablet behavior

Employee tablet shows:
- Fake login identity (`firstname.lastname@configured-domain`)
- Business name override from boss settings
- Clocked-in status
- Hours this period
- Projected pay
- Clock In / Clock Out actions

---

## Database tables

- `mybusiness_payroll_access` → boss access grants by grade threshold
- `mybusiness_payroll_jobs` → city job sync map
- `mybusiness_payroll_theme` → per-job theme payload
- `mybusiness_payroll_settings` → period + branding + rate config per job
- `mybusiness_payroll_shifts` → raw employee clock events
- `mybusiness_payroll_audit_log` → immutable action/audit trail

You can import `sql/mybusiness_payroll.sql` manually; script also auto-creates on startup.

---

## Installation

1. Put resource in server resources folder.
2. Ensure in `server.cfg`:

```cfg
ensure oxmysql
ensure qb-core
ensure qb-management
ensure mybusiness_payroll
```

3. Restart:

```txt
restart oxmysql
restart mybusiness_payroll
```

---

## Extra ideas to add next (recommended)

Boss-side:
- Shift approval queue with reason-required reject flow
- Grade-specific overtime multipliers and holiday rates
- CSV export (accounting, finance handoff)
- Department-based filters and delegated approvers

Employee-side:
- Missed punch correction requests
- PTO request workflow
- Payslip history screen
- Alert feed when payroll is approved/paid
