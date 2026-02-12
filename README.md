# MyBusiness Payroll (QBCore / FiveM)

Enterprise payroll resource with split boss/employee tablets, city job+grade auto-sync, shift tracking, adjustment approvals, and audit visibility.

## Core workflow

- `/payroll` opens the **Boss Command Tablet** (leadership/supervisor/command side).
- `/payrollemployee` opens the **Employee Payroll Tablet** (clock + personal payroll side).
- Boss side controls period length, business login domain, business name, business logo URL, and payroll run.
- Employee side allows clocking and **time adjustment requests** that require supervisor/command approval.

## What was added

1. **Time adjustment approvals**
   - Employees can submit minute adjustments (within configured range).
   - Boss/command panel shows pending requests.
   - Supervisors/managers/command can approve or reject from boss tablet.
   - Approved request updates latest closed shift minutes and is audit logged.

2. **Business logo URL branding**
   - Boss can set a logo URL (Discord CDN, Imgur, etc.).
   - Employee tablet displays that logo on login panel.

3. **Automatic job + grade sync from city**
   - Script reads `QBCore.Shared.Jobs` on startup.
   - Syncs jobs to `mybusiness_payroll_jobs`.
   - Syncs job grades/pay to `mybusiness_payroll_job_grades`.
   - `/payrolljobs` prints jobs and grades currently available.

## Commands

- `/payroll`
- `/payrollemployee`
- `/payrollgrant [id] [job] [grade]`
- `/payrollrevoke [id] [job]`
- `/payrolljobs`

## Permissions

Boss access is granted by any of:
- ACE (`Config.RequiredAce`)
- Identifier allow-list in `permissions.lua` (`license:`, `fivem:`, etc.)
- DB access grant with `min_grade`
- `Config.AutoBossAccess` boss fallback (`PlayerData.job.isboss`)

## Database tables

- `mybusiness_payroll_access`
- `mybusiness_payroll_jobs`
- `mybusiness_payroll_job_grades`
- `mybusiness_payroll_theme`
- `mybusiness_payroll_settings`
- `mybusiness_payroll_shifts`
- `mybusiness_payroll_adjustment_requests`
- `mybusiness_payroll_audit_log`

## Install

```cfg
ensure oxmysql
ensure qb-core
ensure qb-management
ensure mybusiness_payroll
```

Then restart:

```txt
restart oxmysql
restart mybusiness_payroll
```
