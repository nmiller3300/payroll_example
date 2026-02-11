# MyBusiness Payroll (QBCore / FiveM)

This repository is a **FiveM QBCore script resource** with NUI assets and **database-backed payroll access control**.

## Repository Layout

- `fxmanifest.lua` - resource registration
- `config.lua` - command/platform/theme/access configuration
- `client/main.lua` - NUI focus/callback handling
- `server/main.lua` - command registration + payload callback/events + DB access logic
- `html/` - NUI front-end assets
- `sql/mybusiness_payroll.sql` - DB schema for access/jobs/theme persistence

## Install

1. Place this folder in your server resources (for example: `resources/[qb]/mybusiness_payroll`).
2. Ensure dependencies:
   - `qb-core`
   - `oxmysql`
3. Import `sql/mybusiness_payroll.sql` into your server database (optional because auto-create is built in, but recommended).
4. Add to `server.cfg`:

```cfg
ensure oxmysql
ensure mybusiness_payroll
```

## How server administration grants access

This resource now supports **DB-backed access grants** for business owners/department heads/employees.

### Pull city jobs
The script reads jobs from `QBCore.Shared.Jobs` and syncs them to `mybusiness_payroll_jobs` on startup.

Use command:

```txt
/payrolljobs
```

### Grant payroll access (Admin only)

```txt
/payrollgrant [id] [job] [role]
```

Examples:

```txt
/payrollgrant 12 police owner
/payrollgrant 34 mechanic head
/payrollgrant 22 taxi employee
```

### Revoke payroll access (Admin only)

```txt
/payrollrevoke [id] [job]
```

Example:

```txt
/payrollrevoke 22 taxi
```

## Usage

- Owners/department heads run `/payroll` to open the command dashboard.
- By default, player bosses can also access if `Config.AutoBossAccess = true`.
- Access is validated against `mybusiness_payroll_access` table plus optional ACE settings.

## Configuration

Edit `config.lua`:

- `Config.CommandName`
- `Config.AdminPermission` (for grant/revoke commands)
- `Config.UseAcePermission`, `Config.RequiredAce`
- `Config.AutoBossAccess`
- `Config.Platform`
- `Config.DefaultTheme`
- `Config.ThemePresets`
- `Config.BusinessProfiles`
- `Config.AccessRoles`

## Notes

- Payroll rows are still fallback/mock data in `buildFallbackRows`; replace with your payroll/timeclock DB query.
- Theme save is persisted per job in `mybusiness_payroll_theme`.
