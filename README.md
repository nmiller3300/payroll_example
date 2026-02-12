# MyBusiness Payroll (QBCore / FiveM)

Enterprise payroll resource with split boss/employee tablets, tax calculation, compensation controls, and city job/grade auto-sync.

## Core workflow

- `/payroll` opens the **Boss Command Tablet**.
- `/payrollemployee` opens the **Employee Payroll Tablet**.
- Boss side controls period, branding, compensation, and payroll processing.
- Employee side handles clocking and adjustment requests.

## New finance features

1. **Tax / SS / Medicare rates**
   - Admin command: `/settax [tax rate] [ss rate] [medicare rate]`
   - Stored globally in `mybusiness_payroll_tax`
   - Applied on payroll processing to compute gross, deductions, and net pay.

2. **Pay notifications on payroll process**
   - When boss clicks **Process Payroll**, each online employee in that job is paid to bank and receives:
     - hours worked
     - gross pay
     - tax/ss/medicare deduction amount
     - net paycheck
   - Boss also receives payroll summary.

3. **Compensation controls (works for every business job)**
   - Set job-grade hourly rate override.
   - Set individual employee hourly rate override.
   - Add employee bonus amount.
   - Rate resolution order:
     1) Employee override
     2) Grade override
     3) QBCore grade payment
     4) Job default hourly rate

4. **Adjustment approvals**
   - Employees can request minute adjustments (bounded by config).
   - Boss/command can approve/reject inside boss tablet.

## Branding

- Owner can set business logo URL (Discord, Imgur, CDN link).
- Employee login panel displays that logo.

## Auto city sync

On startup, script syncs:
- jobs from `QBCore.Shared.Jobs` -> `mybusiness_payroll_jobs`
- grades/payments -> `mybusiness_payroll_job_grades`

Use `/payrolljobs` to print current jobs and grades.

## Commands

- `/payroll`
- `/payrollemployee`
- `/settax [tax] [ss] [medicare]`
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
