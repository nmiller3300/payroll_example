# MyBusiness Payroll (QBCore / FiveM)

Enterprise payroll resource with split boss/employee tablets, tax calculation, compensation controls, and city job/grade auto-sync.

## Core workflow

- `/payroll` opens the **Boss Command Tablet**.
- `/payrollemployee` opens the **Employee Payroll Tablet**.
- Boss side controls period, branding, compensation, and payroll processing.
- Employee side handles clocking and adjustment requests.

## Key updates in this variation

1. **Admin-only tax control + clear feedback**
   - `/settax [tax] [ss] [medicare]` stays admin-only.
   - Successful updates send a confirmation notify with current rates.

2. **Boss can always see current tax rates**
   - Boss panel displays live tax preview from server tax table.

3. **Tablet-style UI (not full-screen takeover)**
   - UI is rendered as an iPad-style centered tablet window with transparent world visibility behind it.

4. **Compensation controls use Player ID**
   - Boss enters server Player ID (not citizen id).
   - UI auto-fetches player details (name, citizenid, grade) so manager can confirm target.

5. **Open-shift audit grace period**
   - Fresh clock-ins are no longer instantly flagged as missing clock-out.
   - Open-shift audit only flags shifts older than configured grace window.

6. **Company color theming split**
   - Boss can set separate boss-tablet and employee-tablet primary colors.

7. **Startup log + safer DB bootstrap**
   - Resource now prints `Aegis-Payroll Loaded Succesfully!` during startup.
   - Database bootstrap now ensures `hourly_rate` exists in settings and inserts default rows with the full column set.

8. **Clock-in/out reliability improvements**
   - Successful clock-in and clock-out now notify the employee.
   - Clock-out can resolve an active open shift even if the player changed jobs before clocking out.

## Commands

- `/payroll`
- `/payrollemployee`
- `/settax [tax] [ss] [medicare]` (admin)
- `/payrollgrant [id] [job] [grade]`
- `/payrollrevoke [id] [job]`
- `/payrolljobs`

## Database tables

- `mybusiness_payroll_access`
- `mybusiness_payroll_jobs`
- `mybusiness_payroll_job_grades`
- `mybusiness_payroll_theme`
- `mybusiness_payroll_settings`
- `mybusiness_payroll_shifts`
- `mybusiness_payroll_adjustment_requests`
- `mybusiness_payroll_tax`
- `mybusiness_payroll_grade_comp`
- `mybusiness_payroll_employee_comp`
- `mybusiness_payroll_employee_bonus`
- `mybusiness_payroll_audit_log`

## Install

```cfg
ensure oxmysql
ensure qb-core
ensure qb-management
ensure mybusiness_payroll
```

## Troubleshooting

- If you see MySQL errors around `mybusiness_payroll_settings` (for example `Column 'hourly_rate' cannot be null`), restart the resource after updating so the bootstrap migration can add missing columns.
- Importing `sql/mybusiness_payroll.sql` is recommended for fresh installs, but runtime bootstrap also creates/updates required tables and columns.
- SQL import can show `Table already exists` notes when re-running on an existing DB; those are informational. The seed now uses `INSERT IGNORE` for tax defaults to avoid duplicate/deprecation warnings on modern MySQL versions.
