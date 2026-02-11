# MyBusiness Payroll (QBCore / FiveM)

This resource provides an enterprise-style payroll command dashboard for QBCore servers using NUI.

## Install

1. Place this folder in your server resources (for example: `resources/[qb]/mybusiness_payroll`).
2. Ensure dependencies:
   - `qb-core`
   - `oxmysql` (optional now, expected for production persistence)
3. Add to `server.cfg`:

```cfg
ensure mybusiness_payroll
```

## Usage

- Use `/payroll` in game to open the dashboard.
- Press `ESC` or **Return to Game** to close.

## Configuration

Edit `config.lua`:

- `Config.CommandName`
- `Config.UseAcePermission`, `Config.RequiredAce`
- `Config.Platform` (platform name/subtitle/logo text)
- `Config.DefaultTheme`
- `Config.ThemePresets`
- `Config.BusinessProfiles`

## Notes

- Current server data response uses fallback/mock payroll rows.
- Replace `buildFallbackRows` in `server/main.lua` with your own database-backed payroll logic.
- Theme save callback currently logs payload in debug mode and is ready for DB persistence.
