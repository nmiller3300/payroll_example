Config = {}

Config.Debug = false

Config.CommandName = 'payroll'
Config.EmployeeCommandName = 'payrollemployee'
Config.AdminPermission = 'admin'
Config.UseAcePermission = true
Config.RequiredAce = 'payroll.command'
Config.AutoBossAccess = true
Config.DefaultMinimumGrade = 3

Config.PermissionLookup = {
    useQBCorePermission = true,
    qbPermission = 'admin',
    useAce = true,
    ace = 'payroll.command',
    useIdentifierAllowList = true
}

Config.Payroll = {
    defaultPeriodDays = 14,
    minPeriodDays = 1,
    maxPeriodDays = 90,
    defaultHourlyRate = 100,
    maxHoursPerShiftForAudit = 14,
    maxHoursPerPayPeriodForAudit = 120,
    useSocietyPayout = true,
    societyResource = 'qb-management'
}

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

Config.BusinessProfiles = {
    default = {
        businessName = 'Municipal Operations Group',
        dashboardTitle = 'Command Dashboard',
        dashboardSubtitle = 'Agency-wide payroll status and time intelligence',
        employeeSubtitle = 'Employee Payroll Tablet',
        loginDomain = 'business.org'
    }
}
