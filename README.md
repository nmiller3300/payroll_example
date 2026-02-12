# MyBusiness Payroll (QBCore / FiveM)

MyBusiness Payroll is a **QBCore payroll tablet resource** with an enterprise NUI, server-side access control, and database-backed grants.

---

## What this script does

- Gives authorized staff a payroll dashboard (`/payroll`).
- Lets admins grant/revoke payroll access by **job + minimum job grade**.
- Pulls city jobs from `QBCore.Shared.Jobs` and syncs them to DB.
- Persists per-job UI theme settings.

---

## Features

- Professional NUI payroll dashboard (dark Command Yellow default)
- Grade-based access (`min_grade` threshold)
- Admin commands to manage access in-game
- Optional ACE override support
- Boss auto-access option
- Automatic DB table creation on script start

---

## Requirements

- FiveM server
- QBCore
- oxmysql

---

## Installation (Complete)

1. Put this resource in your server resources folder:
   - Example: `resources/[qb]/mybusiness_payroll`

2. Ensure dependencies and this script in `server.cfg`:

```cfg
ensure oxmysql
ensure qb-core
ensure mybusiness_payroll
```

3. Import SQL (recommended):
   - File: `sql/mybusiness_payroll.sql`
   - Note: the script also auto-creates missing tables on startup.

4. Restart server or run:

```txt
restart oxmysql
restart mybusiness_payroll
```

5. Check console for startup errors.

---

## File Structure

- `fxmanifest.lua` - resource manifest
- `config.lua` - script settings
- `server/main.lua` - access logic, commands, DB sync
- `client/main.lua` - NUI open/close callbacks
- `html/` - NUI files
- `sql/mybusiness_payroll.sql` - DB schema

---

## How Access Works

A player can open `/payroll` when one of these is true:

1. They have ACE permission (if enabled).
2. They have a DB access record for their current job and their current job grade is **>= `min_grade`**.
3. Boss fallback is enabled and they are job boss (`Config.AutoBossAccess = true`).

### Grade-based behavior

- Access is no longer role text (`owner/head/employee`).
- Access is now strictly by **job grade threshold**.
- Example: if `min_grade = 3`, only employees with grade 3+ for that job can open the payroll dashboard.

---

## Admin Setup Workflow (Recommended)

### Step 1: Verify jobs loaded from city

Run:

```txt
/payrolljobs
```

This prints jobs sourced from `QBCore.Shared.Jobs` and synced to DB.

### Step 2: Grant payroll access by minimum grade

Use:

```txt
/payrollgrant [id] [job] [grade]
```

Examples:

```txt
/payrollgrant 12 police 4
/payrollgrant 34 mechanic 3
/payrollgrant 22 taxi 2
```

### Step 3: Revoke access if needed

```txt
/payrollrevoke [id] [job]
```

Example:

```txt
/payrollrevoke 22 taxi
```

---

## Commands (Full Reference)

### `/payroll`
Open payroll dashboard for authorized users.

### `/payrolljobs`
Lists city jobs available for payroll assignment.

### `/payrollgrant [id] [job] [grade]`
Grant payroll access for player server ID + job with minimum required job grade.

- `grade` must be a number `0` or higher.

### `/payrollrevoke [id] [job]`
Marks payroll access inactive for that player/job.

---

## Permissions

### QBCore admin permission for grant/revoke

`Config.AdminPermission = 'admin'`

This controls who can run `payrollgrant` and `payrollrevoke`.

### Optional ACE override

If enabled:

```lua
Config.UseAcePermission = true
Config.RequiredAce = 'payroll.command'
```

Any player with that ACE can open payroll dashboard.

---

## Configuration (`config.lua`)

- `Config.CommandName`
  - Dashboard command name (default `payroll`)

- `Config.AdminPermission`
  - QBCore permission used for admin management commands

- `Config.UseAcePermission`
  - Enable ACE override for dashboard access

- `Config.RequiredAce`
  - ACE node used when ACE override is enabled

- `Config.AutoBossAccess`
  - If true, job bosses get dashboard access automatically

- `Config.DefaultMinimumGrade`
  - Default minimum job grade used when grant command grade is omitted

- `Config.Platform`
  - Branding info (name/subtitle/logo text)

- `Config.DefaultTheme`
  - Default visual theme values

- `Config.ThemePresets`
  - Additional presets

- `Config.BusinessProfiles`
  - Per-job profile text display (fallback to `default`)

---

## Database Tables

### `mybusiness_payroll_access`
Stores user payroll access by `citizenid + job_name` and required `min_grade`.

### `mybusiness_payroll_jobs`
Stores jobs synced from QBCore shared jobs.

### `mybusiness_payroll_theme`
Stores serialized theme payload by job.

---

## Typical Real Server Flow

1. Admin ensures job list with `/payrolljobs`.
2. Admin grants payroll access with minimum grade for department leadership.
3. Authorized leadership opens `/payroll`.
4. They use dashboard + save theme.
5. Theme persists per job in DB.

---

## Troubleshooting

### “Target player is not online.”
`/payrollgrant` and `/payrollrevoke` require an online target ID.

### “Unknown city job”
The job must exist in `QBCore.Shared.Jobs`.

### “Admin permission required.”
Your account lacks `Config.AdminPermission` in QBCore permissions.

### Dashboard does not open
Check:
- `ensure oxmysql` and `ensure mybusiness_payroll`
- DB connection health
- access grant exists for that citizen/job
- player grade meets `min_grade`
- ACE setting if enabled

### Theme not saving
Check DB table `mybusiness_payroll_theme` and console errors from oxmysql.

---

## Important Notes

- Current payroll rows are placeholder data in server code (`buildFallbackRows`).
- Replace with your actual payroll/time clock DB queries.
- This resource now uses job grade thresholds instead of text roles for access control.
