local QBCore = exports['qb-core']:GetCoreObject()

local function debugLog(message)
    if Config.Debug then
        print(('[mybusiness_payroll] %s'):format(message))
    end
end

local function getPlayer(source)
    return QBCore.Functions.GetPlayer(source)
end

local function getCitizenId(player)
    return player and player.PlayerData and player.PlayerData.citizenid
end

local function getJobName(player)
    return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name or 'default'
end

local function getJobLabel(player)
    return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.label or 'Business'
end

local function getFullName(player)
    local char = player and player.PlayerData and player.PlayerData.charinfo
    if not char then
        return 'Employee'
    end
    return (('%s %s'):format(char.firstname or '', char.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
end

local function getJobGrade(player)
    if not player or not player.PlayerData or not player.PlayerData.job then
        return 0
    end

    local grade = player.PlayerData.job.grade
    if type(grade) == 'table' then
        return tonumber(grade.level) or tonumber(grade.grade) or 0
    end

    return tonumber(grade) or 0
end

local function fetchJobsFromCore()
    local jobs = QBCore.Shared and QBCore.Shared.Jobs or {}
    local list = {}
    for jobName, jobData in pairs(jobs) do
        list[#list + 1] = { name = jobName, label = jobData.label or jobName }
    end

    table.sort(list, function(a, b)
        return a.name < b.name
    end)

    return list
end

local function hasIdentifierAllow(source)
    if not (Config.PermissionLookup and Config.PermissionLookup.useIdentifierAllowList) then
        return false
    end

    local allow = Permissions and Permissions.IdentifierAllowList or {}
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if allow[identifier] then
            return true
        end
    end

    return false
end

local function hasServerPermission(source)
    if source == 0 then
        return true
    end

    if Config.PermissionLookup and Config.PermissionLookup.useQBCorePermission then
        local qbPerm = Config.PermissionLookup.qbPermission or Config.AdminPermission
        if qbPerm and QBCore.Functions.HasPermission(source, qbPerm) then
            return true
        end
    end

    if Config.PermissionLookup and Config.PermissionLookup.useAce then
        local ace = Config.PermissionLookup.ace or Config.RequiredAce
        if ace and IsPlayerAceAllowed(source, ace) then
            return true
        end
    end

    return hasIdentifierAllow(source)
end

local function getAccessRecord(citizenId, jobName)
    local rows = MySQL.query.await([[
        SELECT citizenid, job_name, min_grade, active
        FROM mybusiness_payroll_access
        WHERE citizenid = ? AND job_name = ?
        LIMIT 1
    ]], { citizenId, jobName })

    return rows and rows[1] or nil
end

local function isBossForJob(player)
    return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.isboss
end

local function canOpenBoss(source)
    local player = getPlayer(source)
    if not player then
        return false
    end

    if Config.UseAcePermission and IsPlayerAceAllowed(source, Config.RequiredAce) then
        return true
    end

    if hasIdentifierAllow(source) then
        return true
    end

    local citizenId = getCitizenId(player)
    local jobName = getJobName(player)
    local access = getAccessRecord(citizenId, jobName)
    local currentGrade = getJobGrade(player)

    if access and tonumber(access.active) == 1 and currentGrade >= (tonumber(access.min_grade) or Config.DefaultMinimumGrade) then
        return true
    end

    if Config.AutoBossAccess and isBossForJob(player) then
        return true
    end

    return false
end

local function canOpenEmployee(source)
    local player = getPlayer(source)
    return player ~= nil
end

local function getPeriodSettings(jobName)
    local rows = MySQL.query.await([[
        SELECT period_days, period_anchor, login_domain, business_name_override, hourly_rate
        FROM mybusiness_payroll_settings
        WHERE job_name = ?
        LIMIT 1
    ]], { jobName })

    if rows and rows[1] then
        return rows[1]
    end

    return {
        period_days = Config.Payroll.defaultPeriodDays,
        period_anchor = os.time(),
        login_domain = (Config.BusinessProfiles.default and Config.BusinessProfiles.default.loginDomain) or 'business.org',
        business_name_override = nil,
        hourly_rate = Config.Payroll.defaultHourlyRate
    }
end

local function getPeriodRange(settings)
    local now = os.time()
    local periodDays = math.max(Config.Payroll.minPeriodDays, math.min(Config.Payroll.maxPeriodDays, tonumber(settings.period_days) or Config.Payroll.defaultPeriodDays))
    local anchor = tonumber(settings.period_anchor) or now

    if anchor > now then
        anchor = now
    end

    local periodSeconds = periodDays * 86400
    local periodsSinceAnchor = math.floor((now - anchor) / periodSeconds)
    local periodStart = anchor + (periodsSinceAnchor * periodSeconds)
    local periodEnd = periodStart + periodSeconds

    return periodStart, periodEnd, periodDays
end

local function getThemeForJob(jobName)
    local rows = MySQL.query.await([[SELECT payload FROM mybusiness_payroll_theme WHERE job_name = ? LIMIT 1]], { jobName })
    if not rows or not rows[1] then
        return Config.DefaultTheme
    end

    local ok, decoded = pcall(json.decode, rows[1].payload)
    if ok and type(decoded) == 'table' then
        return decoded
    end

    return Config.DefaultTheme
end

local function getCurrentShift(citizenId, jobName)
    local rows = MySQL.query.await([[
        SELECT id, clock_in_ts
        FROM mybusiness_payroll_shifts
        WHERE citizenid = ? AND job_name = ? AND clock_out_ts IS NULL
        ORDER BY clock_in_ts DESC
        LIMIT 1
    ]], { citizenId, jobName })

    return rows and rows[1] or nil
end

local function getEmployeePeriodSummary(citizenId, jobName, periodStart, periodEnd, hourlyRate)
    local rows = MySQL.query.await([[
        SELECT
            SUM(COALESCE(total_minutes, 0)) AS total_minutes,
            COUNT(*) AS shifts
        FROM mybusiness_payroll_shifts
        WHERE citizenid = ?
          AND job_name = ?
          AND clock_in_ts >= ?
          AND clock_in_ts < ?
    ]], { citizenId, jobName, periodStart, periodEnd })

    local totalMinutes = rows and rows[1] and tonumber(rows[1].total_minutes) or 0
    local shifts = rows and rows[1] and tonumber(rows[1].shifts) or 0
    local hours = totalMinutes / 60

    return {
        totalMinutes = totalMinutes,
        totalHours = math.floor(hours * 100 + 0.5) / 100,
        shifts = shifts,
        projectedPay = math.floor((hours * hourlyRate) * 100 + 0.5) / 100
    }
end

local function getBossRows(jobName, periodStart, periodEnd, hourlyRate)
    local rows = MySQL.query.await([[
        SELECT citizenid, employee_name, SUM(COALESCE(total_minutes, 0)) AS total_minutes
        FROM mybusiness_payroll_shifts
        WHERE job_name = ?
          AND clock_in_ts >= ?
          AND clock_in_ts < ?
        GROUP BY citizenid, employee_name
        ORDER BY employee_name ASC
    ]], { jobName, periodStart, periodEnd })

    local result = {}
    for _, row in ipairs(rows or {}) do
        local hours = (tonumber(row.total_minutes) or 0) / 60
        result[#result + 1] = {
            citizenid = row.citizenid,
            employee = row.employee_name,
            hours = math.floor(hours * 100 + 0.5) / 100,
            pay = math.floor((hours * hourlyRate) * 100 + 0.5) / 100,
            status = 'Ready'
        }
    end

    return result
end

local function getAuditFlags(jobName, periodStart, periodEnd)
    local overShiftHours = Config.Payroll.maxHoursPerShiftForAudit
    local overPeriodHours = Config.Payroll.maxHoursPerPayPeriodForAudit

    local issues = {}

    local longShiftRows = MySQL.query.await([[
        SELECT employee_name, citizenid, total_minutes, clock_in_ts, clock_out_ts
        FROM mybusiness_payroll_shifts
        WHERE job_name = ?
          AND clock_in_ts >= ?
          AND clock_in_ts < ?
          AND total_minutes IS NOT NULL
          AND total_minutes > ?
    ]], { jobName, periodStart, periodEnd, math.floor(overShiftHours * 60) })

    for _, row in ipairs(longShiftRows or {}) do
        issues[#issues + 1] = {
            employee = row.employee_name,
            type = 'Long Shift',
            detail = ('%.2f hours in one shift.'):format((tonumber(row.total_minutes) or 0) / 60),
            severity = 'warning'
        }
    end

    local noClockOutRows = MySQL.query.await([[
        SELECT employee_name, citizenid, clock_in_ts
        FROM mybusiness_payroll_shifts
        WHERE job_name = ?
          AND clock_out_ts IS NULL
    ]], { jobName })

    for _, row in ipairs(noClockOutRows or {}) do
        issues[#issues + 1] = {
            employee = row.employee_name,
            type = 'Open Shift',
            detail = ('Missing clock-out (started %s).'):format(os.date('%Y-%m-%d %H:%M', tonumber(row.clock_in_ts) or os.time())),
            severity = 'error'
        }
    end

    local periodTotals = MySQL.query.await([[
        SELECT employee_name, citizenid, SUM(COALESCE(total_minutes, 0)) AS total_minutes
        FROM mybusiness_payroll_shifts
        WHERE job_name = ?
          AND clock_in_ts >= ?
          AND clock_in_ts < ?
        GROUP BY citizenid, employee_name
        HAVING SUM(COALESCE(total_minutes, 0)) > ?
    ]], { jobName, periodStart, periodEnd, math.floor(overPeriodHours * 60) })

    for _, row in ipairs(periodTotals or {}) do
        issues[#issues + 1] = {
            employee = row.employee_name,
            type = 'High Period Hours',
            detail = ('%.2f hours in current pay period.'):format((tonumber(row.total_minutes) or 0) / 60),
            severity = 'warning'
        }
    end

    return issues
end

local function writeAuditLog(jobName, actionType, actorCitizenId, actorName, targetCitizenId, details)
    MySQL.insert.await([[
        INSERT INTO mybusiness_payroll_audit_log
            (job_name, action_type, actor_citizenid, actor_name, target_citizenid, details)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { jobName, actionType, actorCitizenId, actorName, targetCitizenId, json.encode(details or {}) })
end

local function buildBossPayload(source)
    local player = getPlayer(source)
    local jobName = getJobName(player)
    local settings = getPeriodSettings(jobName)
    local periodStart, periodEnd, periodDays = getPeriodRange(settings)
    local hourlyRate = tonumber(settings.hourly_rate) or Config.Payroll.defaultHourlyRate

    local profile = Config.BusinessProfiles[jobName] or Config.BusinessProfiles.default
    local rows = getBossRows(jobName, periodStart, periodEnd, hourlyRate)
    local auditIssues = getAuditFlags(jobName, periodStart, periodEnd)

    local totalPay = 0
    for _, row in ipairs(rows) do
        totalPay = totalPay + (tonumber(row.pay) or 0)
    end

    return {
        ok = true,
        mode = 'boss',
        profile = profile,
        platform = Config.Platform,
        jobName = jobName,
        jobLabel = getJobLabel(player),
        rows = rows,
        auditIssues = auditIssues,
        theme = getThemeForJob(jobName),
        settings = {
            periodDays = periodDays,
            periodStart = periodStart,
            periodEnd = periodEnd,
            loginDomain = settings.login_domain,
            businessNameOverride = settings.business_name_override,
            hourlyRate = hourlyRate
        },
        summary = {
            employees = #rows,
            payrollTotal = math.floor(totalPay * 100 + 0.5) / 100,
            pendingApprovals = #auditIssues
        }
    }
end

local function buildEmployeePayload(source)
    local player = getPlayer(source)
    local citizenId = getCitizenId(player)
    local jobName = getJobName(player)
    local settings = getPeriodSettings(jobName)
    local periodStart, periodEnd, periodDays = getPeriodRange(settings)
    local hourlyRate = tonumber(settings.hourly_rate) or Config.Payroll.defaultHourlyRate

    local fullName = getFullName(player)
    local businessName = settings.business_name_override or getJobLabel(player)
    local loginDomain = settings.login_domain or (Config.BusinessProfiles.default and Config.BusinessProfiles.default.loginDomain) or 'business.org'
    local loginIdentity = (fullName:gsub('%s+', '.'):lower()) .. '@' .. loginDomain

    local activeShift = getCurrentShift(citizenId, jobName)
    local periodSummary = getEmployeePeriodSummary(citizenId, jobName, periodStart, periodEnd, hourlyRate)

    return {
        ok = true,
        mode = 'employee',
        platform = Config.Platform,
        profile = Config.BusinessProfiles[jobName] or Config.BusinessProfiles.default,
        theme = getThemeForJob(jobName),
        jobName = jobName,
        employee = {
            fullName = fullName,
            loginIdentity = loginIdentity,
            businessName = businessName,
            isClockedIn = activeShift ~= nil,
            clockInAt = activeShift and tonumber(activeShift.clock_in_ts) or nil
        },
        settings = {
            periodDays = periodDays,
            periodStart = periodStart,
            periodEnd = periodEnd,
            hourlyRate = hourlyRate
        },
        summary = periodSummary
    }
end

local function ensureDatabase()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mybusiness_payroll_access (
        id INT AUTO_INCREMENT PRIMARY KEY,
        citizenid VARCHAR(50) NOT NULL,
        job_name VARCHAR(50) NOT NULL,
        min_grade INT NOT NULL DEFAULT 3,
        granted_by VARCHAR(50) NULL,
        active TINYINT(1) NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_citizen_job (citizenid, job_name)
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mybusiness_payroll_jobs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        job_name VARCHAR(50) NOT NULL,
        job_label VARCHAR(100) NOT NULL,
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        synced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_job (job_name)
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mybusiness_payroll_theme (
        id INT AUTO_INCREMENT PRIMARY KEY,
        job_name VARCHAR(50) NOT NULL,
        payload LONGTEXT NOT NULL,
        updated_by VARCHAR(50) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_job_theme (job_name)
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mybusiness_payroll_settings (
        id INT AUTO_INCREMENT PRIMARY KEY,
        job_name VARCHAR(50) NOT NULL,
        period_days INT NOT NULL DEFAULT 14,
        period_anchor BIGINT NOT NULL,
        login_domain VARCHAR(120) NOT NULL DEFAULT 'business.org',
        business_name_override VARCHAR(120) NULL,
        hourly_rate DECIMAL(10,2) NOT NULL DEFAULT 100.00,
        updated_by VARCHAR(50) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_job_settings (job_name)
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mybusiness_payroll_shifts (
        id INT AUTO_INCREMENT PRIMARY KEY,
        citizenid VARCHAR(50) NOT NULL,
        employee_name VARCHAR(120) NOT NULL,
        job_name VARCHAR(50) NOT NULL,
        clock_in_ts BIGINT NOT NULL,
        clock_out_ts BIGINT NULL,
        total_minutes INT NULL,
        approved TINYINT(1) NOT NULL DEFAULT 0,
        notes VARCHAR(255) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_shift_job_period (job_name, clock_in_ts),
        INDEX idx_shift_open (citizenid, job_name, clock_out_ts)
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mybusiness_payroll_audit_log (
        id INT AUTO_INCREMENT PRIMARY KEY,
        job_name VARCHAR(50) NOT NULL,
        action_type VARCHAR(80) NOT NULL,
        actor_citizenid VARCHAR(50) NULL,
        actor_name VARCHAR(120) NULL,
        target_citizenid VARCHAR(50) NULL,
        details LONGTEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_audit_job_time (job_name, created_at)
    )]])
end

local function syncJobsToDatabase()
    local jobs = fetchJobsFromCore()
    for _, job in ipairs(jobs) do
        MySQL.insert.await([[INSERT INTO mybusiness_payroll_jobs (job_name, job_label, is_active)
            VALUES (?, ?, 1)
            ON DUPLICATE KEY UPDATE job_label = VALUES(job_label), is_active = 1]], { job.name, job.label })

        MySQL.insert.await([[INSERT INTO mybusiness_payroll_settings
            (job_name, period_days, period_anchor, login_domain, business_name_override, hourly_rate)
            VALUES (?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE job_name = VALUES(job_name)]], {
            job.name,
            Config.Payroll.defaultPeriodDays,
            os.time(),
            (Config.BusinessProfiles.default and Config.BusinessProfiles.default.loginDomain) or 'business.org',
            nil,
            Config.Payroll.defaultHourlyRate
        })
    end

    debugLog(('Synced %s jobs to mybusiness_payroll_jobs'):format(#jobs))
end

RegisterNetEvent('mybusiness_payroll:server:saveTheme', function(payload)
    local src = source
    if not canOpenBoss(src) then
        return
    end

    local player = getPlayer(src)
    if not player then
        return
    end

    MySQL.insert.await([[INSERT INTO mybusiness_payroll_theme (job_name, payload, updated_by)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE payload = VALUES(payload), updated_by = VALUES(updated_by)]], {
        getJobName(player),
        json.encode(payload or {}),
        getCitizenId(player)
    })
end)

RegisterNetEvent('mybusiness_payroll:server:updateSettings', function(payload)
    local src = source
    if not canOpenBoss(src) then
        return
    end

    local player = getPlayer(src)
    if not player then
        return
    end

    local jobName = getJobName(player)
    local periodDays = tonumber(payload and payload.periodDays) or Config.Payroll.defaultPeriodDays
    periodDays = math.floor(math.max(Config.Payroll.minPeriodDays, math.min(Config.Payroll.maxPeriodDays, periodDays)))

    local loginDomain = tostring(payload and payload.loginDomain or 'business.org'):lower():gsub('[^%w%.%-]', '')
    if loginDomain == '' then
        loginDomain = 'business.org'
    end

    local businessNameOverride = tostring(payload and payload.businessNameOverride or '')
    if businessNameOverride == '' then
        businessNameOverride = nil
    end

    local hourlyRate = tonumber(payload and payload.hourlyRate) or Config.Payroll.defaultHourlyRate
    if hourlyRate < 0 then
        hourlyRate = Config.Payroll.defaultHourlyRate
    end

    MySQL.insert.await([[INSERT INTO mybusiness_payroll_settings
        (job_name, period_days, period_anchor, login_domain, business_name_override, hourly_rate, updated_by)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            period_days = VALUES(period_days),
            login_domain = VALUES(login_domain),
            business_name_override = VALUES(business_name_override),
            hourly_rate = VALUES(hourly_rate),
            updated_by = VALUES(updated_by)]], {
        jobName,
        periodDays,
        os.time(),
        loginDomain,
        businessNameOverride,
        hourlyRate,
        getCitizenId(player)
    })

    writeAuditLog(jobName, 'SETTINGS_UPDATE', getCitizenId(player), getFullName(player), nil, {
        periodDays = periodDays,
        loginDomain = loginDomain,
        businessNameOverride = businessNameOverride,
        hourlyRate = hourlyRate
    })
end)

RegisterNetEvent('mybusiness_payroll:server:clockIn', function()
    local src = source
    if not canOpenEmployee(src) then
        return
    end

    local player = getPlayer(src)
    if not player then
        return
    end

    local citizenId = getCitizenId(player)
    local jobName = getJobName(player)
    local openShift = getCurrentShift(citizenId, jobName)
    if openShift then
        TriggerClientEvent('QBCore:Notify', src, 'You are already clocked in.', 'error')
        return
    end

    MySQL.insert.await([[INSERT INTO mybusiness_payroll_shifts
        (citizenid, employee_name, job_name, clock_in_ts)
        VALUES (?, ?, ?, ?)]], { citizenId, getFullName(player), jobName, os.time() })

    writeAuditLog(jobName, 'CLOCK_IN', citizenId, getFullName(player), citizenId, {})
    TriggerClientEvent('QBCore:Notify', src, 'Clock-in successful.', 'success')
end)

RegisterNetEvent('mybusiness_payroll:server:clockOut', function()
    local src = source
    if not canOpenEmployee(src) then
        return
    end

    local player = getPlayer(src)
    if not player then
        return
    end

    local citizenId = getCitizenId(player)
    local jobName = getJobName(player)
    local openShift = getCurrentShift(citizenId, jobName)
    if not openShift then
        TriggerClientEvent('QBCore:Notify', src, 'No active shift found.', 'error')
        return
    end

    local nowTs = os.time()
    local totalMinutes = math.max(0, math.floor((nowTs - tonumber(openShift.clock_in_ts or nowTs)) / 60))
    MySQL.update.await([[UPDATE mybusiness_payroll_shifts
        SET clock_out_ts = ?, total_minutes = ?
        WHERE id = ?]], { nowTs, totalMinutes, openShift.id })

    writeAuditLog(jobName, 'CLOCK_OUT', citizenId, getFullName(player), citizenId, { totalMinutes = totalMinutes })
    TriggerClientEvent('QBCore:Notify', src, ('Clock-out successful (%s mins).'):format(totalMinutes), 'success')
end)

RegisterNetEvent('mybusiness_payroll:server:runPayroll', function()
    local src = source
    if not canOpenBoss(src) then
        return
    end

    local player = getPlayer(src)
    local jobName = getJobName(player)
    local settings = getPeriodSettings(jobName)
    local periodStart, periodEnd = getPeriodRange(settings)
    local hourlyRate = tonumber(settings.hourly_rate) or Config.Payroll.defaultHourlyRate
    local rows = getBossRows(jobName, periodStart, periodEnd, hourlyRate)

    local total = 0
    for _, row in ipairs(rows) do
        total = total + (tonumber(row.pay) or 0)
    end

    local paid = false
    if Config.Payroll.useSocietyPayout and GetResourceState(Config.Payroll.societyResource) == 'started' then
        local ok = pcall(function()
            exports[Config.Payroll.societyResource]:RemoveMoney(jobName, total)
        end)

        if ok then
            paid = true
        end
    end

    writeAuditLog(jobName, 'RUN_PAYROLL', getCitizenId(player), getFullName(player), nil, {
        total = total,
        employeeCount = #rows,
        paidFromSociety = paid
    })

    if paid then
        TriggerClientEvent('QBCore:Notify', src, ('Payroll run complete: $%.2f taken from society.'):format(total), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, ('Payroll prepared: $%.2f (society debit unavailable).'):format(total), 'primary')
    end
end)

QBCore.Functions.CreateCallback('mybusiness_payroll:server:getBossPayload', function(source, cb)
    if not canOpenBoss(source) then
        cb({ ok = false, message = 'unauthorized' })
        return
    end

    cb(buildBossPayload(source))
end)

QBCore.Functions.CreateCallback('mybusiness_payroll:server:getEmployeePayload', function(source, cb)
    if not canOpenEmployee(source) then
        cb({ ok = false, message = 'unauthorized' })
        return
    end

    cb(buildEmployeePayload(source))
end)

QBCore.Commands.Add(Config.CommandName, 'Open boss payroll command tablet', {}, false, function(source)
    if not canOpenBoss(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Boss payroll access denied.', 'error')
        return
    end

    TriggerClientEvent('mybusiness_payroll:client:openBoss', source)
end, 'user')

QBCore.Commands.Add(Config.EmployeeCommandName, 'Open employee payroll tablet', {}, false, function(source)
    if not canOpenEmployee(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Employee payroll access denied.', 'error')
        return
    end

    TriggerClientEvent('mybusiness_payroll:client:openEmployee', source)
end, 'user')

QBCore.Commands.Add('payrollgrant', 'Grant payroll boss access by minimum job grade', {
    { name = 'id', help = 'Server ID' },
    { name = 'job', help = 'Job name (example: police)' },
    { name = 'grade', help = 'Minimum job grade (example: 3)' }
}, true, function(source, args)
    if not hasServerPermission(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Admin permission required.', 'error')
        return
    end

    local targetSource = tonumber(args[1] or 0)
    local targetPlayer = getPlayer(targetSource)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', source, 'Target player is not online.', 'error')
        return
    end

    local jobName = tostring(args[2] or ''):lower()
    local cityJobs = QBCore.Shared and QBCore.Shared.Jobs or {}
    if not cityJobs[jobName] then
        TriggerClientEvent('QBCore:Notify', source, ('Unknown city job: %s'):format(jobName), 'error')
        return
    end

    local minGrade = tonumber(args[3] or Config.DefaultMinimumGrade)
    if not minGrade or minGrade < 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Invalid grade. Use number >= 0.', 'error')
        return
    end

    local targetCitizenId = getCitizenId(targetPlayer)
    local actor = getPlayer(source)
    local actorCitizenId = actor and getCitizenId(actor) or 'console'

    MySQL.insert.await([[INSERT INTO mybusiness_payroll_access (citizenid, job_name, min_grade, granted_by, active)
        VALUES (?, ?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE min_grade = VALUES(min_grade), granted_by = VALUES(granted_by), active = 1]], {
        targetCitizenId,
        jobName,
        minGrade,
        actorCitizenId
    })

    writeAuditLog(jobName, 'ACCESS_GRANT', actorCitizenId, actor and getFullName(actor) or 'Console', targetCitizenId, { minGrade = minGrade })
    TriggerClientEvent('QBCore:Notify', source, ('Granted boss payroll access (%s >= grade %s).'):format(jobName, minGrade), 'success')
end, Config.AdminPermission)

QBCore.Commands.Add('payrollrevoke', 'Revoke payroll boss access', {
    { name = 'id', help = 'Server ID' },
    { name = 'job', help = 'Job name' }
}, true, function(source, args)
    if not hasServerPermission(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Admin permission required.', 'error')
        return
    end

    local targetSource = tonumber(args[1] or 0)
    local targetPlayer = getPlayer(targetSource)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', source, 'Target player is not online.', 'error')
        return
    end

    local jobName = tostring(args[2] or ''):lower()
    local targetCitizenId = getCitizenId(targetPlayer)
    MySQL.update.await('UPDATE mybusiness_payroll_access SET active = 0 WHERE citizenid = ? AND job_name = ?', { targetCitizenId, jobName })

    local actor = getPlayer(source)
    writeAuditLog(jobName, 'ACCESS_REVOKE', actor and getCitizenId(actor) or 'console', actor and getFullName(actor) or 'Console', targetCitizenId, {})
    TriggerClientEvent('QBCore:Notify', source, ('Revoked boss payroll access for %s.'):format(jobName), 'success')
end, Config.AdminPermission)

QBCore.Commands.Add('payrolljobs', 'List city jobs available for payroll assignment', {}, false, function(source)
    if source > 0 and not hasServerPermission(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Admin permission required.', 'error')
        return
    end

    local jobs = fetchJobsFromCore()
    print('[mybusiness_payroll] City jobs available:')
    for _, job in ipairs(jobs) do
        print((' - %s (%s)'):format(job.name, job.label))
    end

    if source > 0 then
        TriggerClientEvent('QBCore:Notify', source, ('Printed %s jobs to server console.'):format(#jobs), 'primary')
    end
end, 'user')

CreateThread(function()
    ensureDatabase()
    syncJobsToDatabase()
end)
