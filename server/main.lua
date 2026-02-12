local QBCore = exports['qb-core']:GetCoreObject()

local function debugLog(message)
    if Config.Debug then
        print(('[mybusiness_payroll] %s'):format(message))
    end
end

local function fetchJobsFromCore()
    local jobs = QBCore.Shared and QBCore.Shared.Jobs or {}
    local list = {}

    for jobName, jobData in pairs(jobs) do
        list[#list + 1] = {
            name = jobName,
            label = jobData.label or jobName
        }
    end

    table.sort(list, function(a, b)
        return a.name < b.name
    end)

    return list
end

local function ensureDatabase()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS mybusiness_payroll_access (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            job_name VARCHAR(50) NOT NULL,
            min_grade INT NOT NULL DEFAULT 3,
            granted_by VARCHAR(50) NULL,
            active TINYINT(1) NOT NULL DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_citizen_job (citizenid, job_name)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS mybusiness_payroll_jobs (
            id INT AUTO_INCREMENT PRIMARY KEY,
            job_name VARCHAR(50) NOT NULL,
            job_label VARCHAR(100) NOT NULL,
            is_active TINYINT(1) NOT NULL DEFAULT 1,
            synced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_job (job_name)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS mybusiness_payroll_theme (
            id INT AUTO_INCREMENT PRIMARY KEY,
            job_name VARCHAR(50) NOT NULL,
            payload LONGTEXT NOT NULL,
            updated_by VARCHAR(50) NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY uniq_job_theme (job_name)
        )
    ]])

    local hasMinGrade = MySQL.query.await([[
        SELECT COUNT(*) AS total
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'mybusiness_payroll_access'
          AND COLUMN_NAME = 'min_grade'
    ]])

    if hasMinGrade and hasMinGrade[1] and tonumber(hasMinGrade[1].total) == 0 then
        MySQL.query.await([[ALTER TABLE mybusiness_payroll_access ADD COLUMN min_grade INT NOT NULL DEFAULT 3]])
    end
end

local function syncJobsToDatabase()
    local jobs = fetchJobsFromCore()

    for _, job in ipairs(jobs) do
        MySQL.insert.await([[
            INSERT INTO mybusiness_payroll_jobs (job_name, job_label, is_active)
            VALUES (?, ?, 1)
            ON DUPLICATE KEY UPDATE job_label = VALUES(job_label), is_active = 1
        ]], { job.name, job.label })
    end

    debugLog(('Synced %s jobs to mybusiness_payroll_jobs'):format(#jobs))
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

local function getAccessRecord(citizenId, jobName)
    local rows = MySQL.query.await([[
        SELECT citizenid, job_name, min_grade, active
        FROM mybusiness_payroll_access
        WHERE citizenid = ? AND job_name = ?
        LIMIT 1
    ]], { citizenId, jobName })

    return rows and rows[1] or nil
end

local function canOpenPayroll(source)
    if Config.UseAcePermission and IsPlayerAceAllowed(source, Config.RequiredAce) then
        return true
    end

    local player = getPlayer(source)
    if not player then
        return false
    end

    local citizenId = getCitizenId(player)
    local jobName = getJobName(player)
    local access = getAccessRecord(citizenId, jobName)
    local currentGrade = getJobGrade(player)

    if access and tonumber(access.active) == 1 and currentGrade >= (tonumber(access.min_grade) or Config.DefaultMinimumGrade) then
        return true
    end

    if Config.AutoBossAccess and player.PlayerData.job and player.PlayerData.job.isboss then
        return true
    end

    return false
end

local function buildFallbackRows(player)
    local citizenId = getCitizenId(player) or 'Unknown'
    return {
        {
            employee = 'Danielle Brooks',
            role = 'Operations Lead',
            hours = 86.5,
            status = 'Approved',
            pay = 4780
        },
        {
            employee = 'Marco Salazar',
            role = 'Field Supervisor',
            hours = 81.0,
            status = 'Pending',
            pay = 4116
        },
        {
            employee = ('Player %s'):format(citizenId),
            role = player and player.PlayerData.job and player.PlayerData.job.label or 'Staff',
            hours = 79.5,
            status = 'Issue',
            pay = 3965
        }
    }
end

local function buildSummary(rows)
    local pendingApprovals = 0
    local payrollTotal = 0

    for _, row in ipairs(rows) do
        payrollTotal = payrollTotal + (tonumber(row.pay) or 0)
        if row.status == 'Pending' then
            pendingApprovals = pendingApprovals + 1
        end
    end

    return {
        pendingApprovals = pendingApprovals,
        payrollTotal = payrollTotal,
        clockedIn = #rows
    }
end

local function getThemeForJob(jobName)
    local rows = MySQL.query.await([[
        SELECT payload
        FROM mybusiness_payroll_theme
        WHERE job_name = ?
        LIMIT 1
    ]], { jobName })

    if not rows or not rows[1] then
        return Config.DefaultTheme
    end

    local ok, decoded = pcall(json.decode, rows[1].payload)
    if ok and type(decoded) == 'table' then
        return decoded
    end

    return Config.DefaultTheme
end

local function buildPayload(source)
    local player = getPlayer(source)
    local jobName = getJobName(player)
    local profile = Config.BusinessProfiles[jobName] or Config.BusinessProfiles.default

    local rows = buildFallbackRows(player)
    local summary = buildSummary(rows)

    return {
        ok = true,
        profile = profile,
        summary = summary,
        rows = rows,
        theme = getThemeForJob(jobName),
        platform = Config.Platform,
        jobName = jobName
    }
end

QBCore.Functions.CreateCallback('mybusiness_payroll:server:getDashboardPayload', function(source, cb)
    if not canOpenPayroll(source) then
        cb({ ok = false, message = 'unauthorized' })
        return
    end

    cb(buildPayload(source))
end)

RegisterNetEvent('mybusiness_payroll:server:saveTheme', function(payload)
    local sourcePlayer = source
    if not canOpenPayroll(sourcePlayer) then
        return
    end

    local player = getPlayer(sourcePlayer)
    if not player then
        return
    end

    local citizenId = getCitizenId(player)
    local jobName = getJobName(player)
    local encoded = json.encode(payload or {})

    MySQL.insert.await([[
        INSERT INTO mybusiness_payroll_theme (job_name, payload, updated_by)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE payload = VALUES(payload), updated_by = VALUES(updated_by)
    ]], { jobName, encoded, citizenId })

    debugLog(('Theme saved for job %s by %s'):format(jobName, citizenId))
end)

QBCore.Commands.Add(
    Config.CommandName,
    'Open the MyBusiness Payroll command dashboard',
    {},
    false,
    function(source)
        if not canOpenPayroll(source) then
            TriggerClientEvent('QBCore:Notify', source, 'Payroll access denied for your current job grade.', 'error')
            return
        end

        local payload = buildPayload(source)
        TriggerClientEvent(
            'mybusiness_payroll:client:openForCommandStaff',
            source,
            payload.profile,
            payload.summary,
            payload.rows,
            payload.theme,
            payload.platform
        )
    end,
    'user'
)

QBCore.Commands.Add(
    'payrollgrant',
    'Grant payroll access by minimum job grade (Admin only)',
    {
        { name = 'id', help = 'Server ID' },
        { name = 'job', help = 'Job name from city jobs (example: police)' },
        { name = 'grade', help = 'Minimum job grade required (example: 3)' }
    },
    true,
    function(source, args)
        if source > 0 and not QBCore.Functions.HasPermission(source, Config.AdminPermission) then
            TriggerClientEvent('QBCore:Notify', source, 'Admin permission required.', 'error')
            return
        end

        local targetSource = tonumber(args[1] or 0)
        local targetPlayer = getPlayer(targetSource)
        if not targetPlayer then
            if source > 0 then
                TriggerClientEvent('QBCore:Notify', source, 'Target player is not online.', 'error')
            end
            return
        end

        local jobName = tostring(args[2] or ''):lower()
        if jobName == '' then
            TriggerClientEvent('QBCore:Notify', source, 'Job name is required.', 'error')
            return
        end

        local cityJobs = QBCore.Shared and QBCore.Shared.Jobs or {}
        if not cityJobs[jobName] then
            TriggerClientEvent('QBCore:Notify', source, ('Unknown city job: %s'):format(jobName), 'error')
            return
        end

        local minGrade = tonumber(args[3] or Config.DefaultMinimumGrade)
        if not minGrade or minGrade < 0 then
            TriggerClientEvent('QBCore:Notify', source, 'Invalid grade. Use a number 0 or higher.', 'error')
            return
        end

        local citizenId = getCitizenId(targetPlayer)
        local adminPlayer = getPlayer(source)
        local grantedBy = adminPlayer and getCitizenId(adminPlayer) or 'console'

        MySQL.insert.await([[
            INSERT INTO mybusiness_payroll_access (citizenid, job_name, min_grade, granted_by, active)
            VALUES (?, ?, ?, ?, 1)
            ON DUPLICATE KEY UPDATE min_grade = VALUES(min_grade), granted_by = VALUES(granted_by), active = 1
        ]], { citizenId, jobName, minGrade, grantedBy })

        if source > 0 then
            TriggerClientEvent('QBCore:Notify', source, ('Granted payroll access for %s (min grade %s).'):format(jobName, minGrade), 'success')
        end

        TriggerClientEvent('QBCore:Notify', targetSource, ('Payroll access granted for %s (min grade %s).'):format(jobName, minGrade), 'success')
    end,
    Config.AdminPermission
)

QBCore.Commands.Add(
    'payrollrevoke',
    'Revoke payroll access for a player job (Admin only)',
    {
        { name = 'id', help = 'Server ID' },
        { name = 'job', help = 'Job name to revoke' }
    },
    true,
    function(source, args)
        if source > 0 and not QBCore.Functions.HasPermission(source, Config.AdminPermission) then
            TriggerClientEvent('QBCore:Notify', source, 'Admin permission required.', 'error')
            return
        end

        local targetSource = tonumber(args[1] or 0)
        local targetPlayer = getPlayer(targetSource)
        if not targetPlayer then
            if source > 0 then
                TriggerClientEvent('QBCore:Notify', source, 'Target player is not online.', 'error')
            end
            return
        end

        local jobName = tostring(args[2] or ''):lower()
        if jobName == '' then
            TriggerClientEvent('QBCore:Notify', source, 'Job name is required.', 'error')
            return
        end

        local citizenId = getCitizenId(targetPlayer)
        MySQL.update.await([[
            UPDATE mybusiness_payroll_access
            SET active = 0
            WHERE citizenid = ? AND job_name = ?
        ]], { citizenId, jobName })

        if source > 0 then
            TriggerClientEvent('QBCore:Notify', source, ('Revoked payroll access for %s.'):format(jobName), 'success')
        end

        TriggerClientEvent('QBCore:Notify', targetSource, ('Payroll access revoked for %s.'):format(jobName), 'error')
    end,
    Config.AdminPermission
)

QBCore.Commands.Add(
    'payrolljobs',
    'List city jobs available for payroll access assignment',
    {},
    false,
    function(source)
        local jobs = fetchJobsFromCore()
        if #jobs == 0 then
            if source > 0 then
                TriggerClientEvent('QBCore:Notify', source, 'No jobs loaded from QBCore.Shared.Jobs.', 'error')
            else
                print('[mybusiness_payroll] No jobs loaded from QBCore.Shared.Jobs.')
            end
            return
        end

        if source > 0 then
            TriggerClientEvent('QBCore:Notify', source, ('Loaded %s city jobs. See server console for list.'):format(#jobs), 'primary')
        end

        print('[mybusiness_payroll] City jobs available for payroll grant:')
        for _, job in ipairs(jobs) do
            print((' - %s (%s)'):format(job.name, job.label))
        end
    end,
    'user'
)

CreateThread(function()
    ensureDatabase()
    syncJobsToDatabase()
end)
