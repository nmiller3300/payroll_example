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
   - UI is now rendered as an iPad-style centered tablet window with transparent world visibility behind it.

4. **Compensation controls use Player ID**
   - Boss enters server Player ID (not citizen id).
   - UI auto-fetches player details (name, citizenid, grade) so manager can confirm target.

5. **Open-shift audit grace period**
   - Fresh clock-ins are no longer instantly flagged as missing clock-out.
   - Open-shift audit only flags shifts older than configured grace window.

6. **Company color theming split**
   - Boss can set separate boss-tablet and employee-tablet primary colors.

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
