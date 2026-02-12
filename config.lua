Config = {}

Config.Debug = false

Config.CommandName = 'payroll'
Config.AdminPermission = 'admin'
Config.UseAcePermission = false
Config.RequiredAce = 'payroll.command'
Config.AutoBossAccess = true
Config.DefaultMinimumGrade = 3

Config.Platform = {
    name = 'MyBusiness Payroll',
    subtitle = 'Workforce Compensation & Time Management',
    logoText = 'MB'
}

Config.DefaultTheme = {
    mode = 'dark',
    spacing = 'comfortable',
    hexEnabled = true,
    hexOpacity = 4,
    primaryColor = '#FFC72C',
    accentColor = '#DBA500',
    backgroundStyle = 'solid'
}

Config.ThemePresets = {
    commandYellow = {
        mode = 'dark',
        spacing = 'comfortable',
        hexEnabled = true,
        hexOpacity = 4,
        primaryColor = '#FFC72C',
        accentColor = '#DBA500',
        backgroundStyle = 'solid'
    },
    commandSlate = {
        mode = 'dark',
        spacing = 'compact',
        hexEnabled = false,
        hexOpacity = 2,
        primaryColor = '#B4BDC8',
        accentColor = '#7A8795',
        backgroundStyle = 'soft-gradient'
    }
}

-- Placeholder business profile map for future multi-tenant/white-label expansion.
-- key can be a job name, society account id, or owner identifier depending on your server logic.
Config.BusinessProfiles = {
    default = {
        businessName = 'Municipal Operations Group',
        dashboardTitle = 'Command Dashboard',
        dashboardSubtitle = 'Agency-wide payroll status and time intelligence'
    }
}
