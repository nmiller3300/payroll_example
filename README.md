# MyBusiness Payroll (QBCore / FiveM)

This repository is a **FiveM QBCore script resource** with NUI assets.

## Repository Layout

- `fxmanifest.lua` - resource registration
- `config.lua` - command/platform/theme configuration
- `client/main.lua` - NUI focus/callback handling
- `server/main.lua` - command registration + payload callback/events
- `html/` - NUI front-end assets

## Install

1. Place this folder in your server resources (for example: `resources/[qb]/mybusiness_payroll`).
2. Ensure dependency:
   - `qb-core`
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
