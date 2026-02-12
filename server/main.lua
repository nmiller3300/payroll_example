local QBCore = exports['qb-core']:GetCoreObject()

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

local function writeAuditLog(jobName, actionType, actorCitizenId, actorName, targetCitizenId, details)
    MySQL.insert.await('INSERT INTO mybusiness_payroll_audit_log (job_name, action_type, actor_citizenid, actor_name, target_citizenid, details) VALUES (?, ?, ?, ?, ?, ?)', {
        jobName,
        actionType,
        actorCitizenId,
        actorName,
        targetCitizenId,
        json.encode(details or {})
    })
end

local function getTaxRates()
    local rows = MySQL.query.await('SELECT tax_rate, ss_rate, medicare_rate FROM mybusiness_payroll_tax WHERE id = 1 LIMIT 1')
    if rows and rows[1] then
        return {
            taxRate = tonumber(rows[1].tax_rate) or 0,
            ssRate = tonumber(rows[1].ss_rate) or 0,
            medicareRate = tonumber(rows[1].medicare_rate) or 0
        }
    end

    return { taxRate = 0, ssRate = 0, medicareRate = 0 }
end

local function getAccessRecord(citizenId, jobName)
    local rows = MySQL.query.await('SELECT min_grade, active FROM mybusiness_payroll_access WHERE citizenid = ? AND job_name = ? LIMIT 1', { citizenId, jobName })
    return rows and rows[1] or nil
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

    local access = getAccessRecord(getCitizenId(player), getJobName(player))
    if access and tonumber(access.active) == 1 and getJobGrade(player) >= (tonumber(access.min_grade) or Config.DefaultMinimumGrade) then
        return true
    end

    return Config.AutoBossAccess and player.PlayerData.job and player.PlayerData.job.isboss or false
end

local function canOpenEmployee(source)
    return getPlayer(source) ~= nil
end

local function ensureColumn(tableName, columnName, definition)
    local check = MySQL.query.await([[SELECT COUNT(*) AS total FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?]], { tableName, columnName })
    if check and check[1] and tonumber(check[1].total) == 0 then
        MySQL.query.await(('ALTER TABLE %s ADD COLUMN %s %s'):format(tableName, columnName, definition))
    end
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

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mybusiness_payroll_job_grades (
        id INT AUTO_INCREMENT PRIMARY KEY,
        job_name VARCHAR(50) NOT NULL,
        grade_level INT NOT NULL,
        grade_name VARCHAR(100) NULL,
        payment DECIMAL(10,2) NULL,
        synced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_job_grade (job_name, grade_level)
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
        business_logo_url VARCHAR(500) NULL,
        boss_primary_color VARCHAR(10) NULL,
        employee_primary_color VARCHAR(10) NULL,
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
        grade_level INT NOT NULL DEFAULT 0,
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

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mybusiness_payroll_adjustment_requests (
        id INT AUTO_INCREMENT PRIMARY KEY,
        job_name VARCHAR(50) NOT NULL,
        citizenid VARCHAR(50) NOT NULL,
        employee_name VARCHAR(120) NOT NULL,
        minutes_delta INT NOT NULL,
        reason VARCHAR(255) NOT NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'pending',
        reviewed_by VARCHAR(50) NULL,
        reviewed_name VARCHAR(120) NULL,
        reviewed_at TIMESTAMP NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_adj_job_status (job_name, status),
        INDEX idx_adj_citizen (citizenid)
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mybusiness_payroll_tax (
        id INT PRIMARY KEY,
        tax_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00,
        ss_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00,
        medicare_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00,
        updated_by VARCHAR(50) NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mybusiness_payroll_grade_comp (
        id INT AUTO_INCREMENT PRIMARY KEY,
        job_name VARCHAR(50) NOT NULL,
        grade_level INT NOT NULL,
        hourly_rate DECIMAL(10,2) NOT NULL,
        updated_by VARCHAR(50) NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_grade_comp (job_name, grade_level)
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mybusiness_payroll_employee_comp (
        id INT AUTO_INCREMENT PRIMARY KEY,
        job_name VARCHAR(50) NOT NULL,
        citizenid VARCHAR(50) NOT NULL,
        hourly_rate DECIMAL(10,2) NOT NULL,
        updated_by VARCHAR(50) NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_employee_comp (job_name, citizenid)
    )]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mybusiness_payroll_employee_bonus (
        id INT AUTO_INCREMENT PRIMARY KEY,
        job_name VARCHAR(50) NOT NULL,
        citizenid VARCHAR(50) NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        reason VARCHAR(255) NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'pending',
        granted_by VARCHAR(50) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        processed_at TIMESTAMP NULL,
        INDEX idx_bonus_job_status (job_name, status),
        INDEX idx_bonus_citizen (citizenid)
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

    ensureColumn('mybusiness_payroll_settings', 'business_logo_url', 'VARCHAR(500) NULL')
    ensureColumn('mybusiness_payroll_settings', 'boss_primary_color', 'VARCHAR(10) NULL')
    ensureColumn('mybusiness_payroll_settings', 'employee_primary_color', 'VARCHAR(10) NULL')
    ensureColumn('mybusiness_payroll_settings', 'hourly_rate', 'DECIMAL(10,2) NOT NULL DEFAULT 100.00')
    ensureColumn('mybusiness_payroll_shifts', 'grade_level', 'INT NOT NULL DEFAULT 0')

    MySQL.insert.await([[INSERT INTO mybusiness_payroll_tax (id, tax_rate, ss_rate, medicare_rate)
        VALUES (1, 0.00, 0.00, 0.00)
        ON DUPLICATE KEY UPDATE id = VALUES(id)]])
end

local function syncJobsToDatabase()
    local jobs = QBCore.Shared and QBCore.Shared.Jobs or {}

    for jobName, jobData in pairs(jobs) do
        MySQL.insert.await([[INSERT INTO mybusiness_payroll_jobs (job_name, job_label, is_active)
            VALUES (?, ?, 1)
            ON DUPLICATE KEY UPDATE job_label = VALUES(job_label), is_active = 1]], { jobName, jobData.label or jobName })

        for gradeLevel, gradeData in pairs(jobData.grades or {}) do
            local lvl = tonumber(gradeLevel) or tonumber(gradeData.level) or 0
            MySQL.insert.await([[INSERT INTO mybusiness_payroll_job_grades (job_name, grade_level, grade_name, payment)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE grade_name = VALUES(grade_name), payment = VALUES(payment)]], {
                jobName,
                lvl,
                gradeData.name or tostring(lvl),
                tonumber(gradeData.payment) or 0
            })
        end

        MySQL.insert.await([[INSERT INTO mybusiness_payroll_settings
            (job_name, period_days, period_anchor, login_domain, business_name_override, business_logo_url, boss_primary_color, employee_primary_color, hourly_rate)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE job_name = VALUES(job_name)]], {
            jobName,
            Config.Payroll.defaultPeriodDays,
            os.time(),
            (Config.BusinessProfiles.default and Config.BusinessProfiles.default.loginDomain) or 'business.org',
            nil,
            nil,
            Config.DefaultTheme.primaryColor,
            Config.DefaultTheme.primaryColor,
            Config.Payroll.defaultHourlyRate
        })
    end
end

local function getThemeForJob(jobName)
    local rows = MySQL.query.await('SELECT payload FROM mybusiness_payroll_theme WHERE job_name = ? LIMIT 1', { jobName })
    if not rows or not rows[1] then
        return Config.DefaultTheme
    end

    local ok, decoded = pcall(json.decode, rows[1].payload)
    if ok and type(decoded) == 'table' then
        return decoded
    end

    return Config.DefaultTheme
end

local function getPeriodSettings(jobName)
    local rows = MySQL.query.await([[SELECT period_days, period_anchor, login_domain, business_name_override, business_logo_url, boss_primary_color, employee_primary_color, hourly_rate
        FROM mybusiness_payroll_settings WHERE job_name = ? LIMIT 1]], { jobName })

    if rows and rows[1] then
        return rows[1]
    end

    return {
        period_days = Config.Payroll.defaultPeriodDays,
        period_anchor = os.time(),
        login_domain = (Config.BusinessProfiles.default and Config.BusinessProfiles.default.loginDomain) or 'business.org',
        business_name_override = nil,
        business_logo_url = nil,
        boss_primary_color = Config.DefaultTheme.primaryColor,
        employee_primary_color = Config.DefaultTheme.primaryColor,
        hourly_rate = Config.Payroll.defaultHourlyRate
    }
end

local function getPeriodRange(settings)
    local now = os.time()
    local periodDays = math.max(Config.Payroll.minPeriodDays, math.min(Config.Payroll.maxPeriodDays, tonumber(settings.period_days) or Config.Payroll.defaultPeriodDays))
    local anchor = tonumber(settings.period_anchor) or now
    local periodSeconds = periodDays * 86400
    local periodsSinceAnchor = math.floor((now - anchor) / periodSeconds)
    local periodStart = anchor + (periodsSinceAnchor * periodSeconds)
    local periodEnd = periodStart + periodSeconds
    return periodStart, periodEnd, periodDays
end

local function getCurrentShift(citizenId, jobName, anyJob)
    local rows
    if anyJob then
        rows = MySQL.query.await('SELECT id, job_name, clock_in_ts FROM mybusiness_payroll_shifts WHERE citizenid = ? AND clock_out_ts IS NULL ORDER BY clock_in_ts DESC LIMIT 1', { citizenId })
    else
        rows = MySQL.query.await('SELECT id, job_name, clock_in_ts FROM mybusiness_payroll_shifts WHERE citizenid = ? AND job_name = ? AND clock_out_ts IS NULL ORDER BY clock_in_ts DESC LIMIT 1', { citizenId, jobName })
    end
    return rows and rows[1] or nil
end

local function getEmployeePeriodSummary(citizenId, jobName, periodStart, periodEnd, hourlyRate)
    local rows = MySQL.query.await([[SELECT SUM(COALESCE(total_minutes,0)) AS total_minutes, COUNT(*) AS shifts
        FROM mybusiness_payroll_shifts WHERE citizenid = ? AND job_name = ? AND clock_in_ts >= ? AND clock_in_ts < ?]], {
        citizenId,
        jobName,
        periodStart,
        periodEnd
    })

    local totalMinutes = rows and rows[1] and tonumber(rows[1].total_minutes) or 0
    local hours = totalMinutes / 60
    return {
        totalHours = math.floor(hours * 100 + 0.5) / 100,
        shifts = rows and rows[1] and tonumber(rows[1].shifts) or 0,
        projectedPay = math.floor((hours * hourlyRate) * 100 + 0.5) / 100
    }
end

local function getPendingAdjustments(jobName)
    return MySQL.query.await([[SELECT id, employee_name, minutes_delta, reason, created_at
        FROM mybusiness_payroll_adjustment_requests
        WHERE job_name = ? AND status = 'pending'
        ORDER BY created_at ASC]], { jobName }) or {}
end

local function getEmployeeAdjustments(citizenId, jobName)
    return MySQL.query.await([[SELECT id, minutes_delta, reason, status, created_at
        FROM mybusiness_payroll_adjustment_requests
        WHERE citizenid = ? AND job_name = ?
        ORDER BY created_at DESC LIMIT 8]], { citizenId, jobName }) or {}
end

local function getAuditFlags(jobName, periodStart, periodEnd)
    local issues = {}

    local longShiftRows = MySQL.query.await('SELECT employee_name, total_minutes FROM mybusiness_payroll_shifts WHERE job_name = ? AND clock_in_ts >= ? AND clock_in_ts < ? AND total_minutes > ?', {
        jobName,
        periodStart,
        periodEnd,
        math.floor(Config.Payroll.maxHoursPerShiftForAudit * 60)
    })

    for _, row in ipairs(longShiftRows or {}) do
        issues[#issues + 1] = { employee = row.employee_name, type = 'Long Shift', detail = ('%.2f hours in one shift.'):format((tonumber(row.total_minutes) or 0) / 60), severity = 'warning' }
    end

    local nowTs = os.time()
    local graceSeconds = (tonumber(Config.Payroll.openShiftGraceMinutesForAudit) or 20) * 60
    local openRows = MySQL.query.await('SELECT employee_name, clock_in_ts FROM mybusiness_payroll_shifts WHERE job_name = ? AND clock_out_ts IS NULL AND clock_in_ts <= ?', { jobName, nowTs - graceSeconds })
    for _, row in ipairs(openRows or {}) do
        issues[#issues + 1] = { employee = row.employee_name, type = 'Open Shift', detail = ('Missing clock-out since %s'):format(os.date('%Y-%m-%d %H:%M', tonumber(row.clock_in_ts) or os.time())), severity = 'error' }
    end

    return issues
end

local function getJobGradeCatalog(jobName)
    return MySQL.query.await('SELECT grade_level, grade_name, payment FROM mybusiness_payroll_job_grades WHERE job_name = ? ORDER BY grade_level ASC', { jobName }) or {}
end

local function getCompSettings(jobName)
    return {
        employeeRates = MySQL.query.await('SELECT citizenid, hourly_rate FROM mybusiness_payroll_employee_comp WHERE job_name = ?', { jobName }) or {},
        gradeRates = MySQL.query.await('SELECT grade_level, hourly_rate FROM mybusiness_payroll_grade_comp WHERE job_name = ?', { jobName }) or {},
        bonuses = MySQL.query.await('SELECT citizenid, amount, reason FROM mybusiness_payroll_employee_bonus WHERE job_name = ? AND status = "pending"', { jobName }) or {}
    }
end

local function resolveRateForRow(jobName, row, defaultRate)
    local employeeRate = MySQL.query.await('SELECT hourly_rate FROM mybusiness_payroll_employee_comp WHERE job_name = ? AND citizenid = ? LIMIT 1', { jobName, row.citizenid })
    if employeeRate and employeeRate[1] then
        return tonumber(employeeRate[1].hourly_rate) or defaultRate
    end

    local gradeRate = MySQL.query.await('SELECT hourly_rate FROM mybusiness_payroll_grade_comp WHERE job_name = ? AND grade_level = ? LIMIT 1', { jobName, tonumber(row.grade_level) or 0 })
    if gradeRate and gradeRate[1] then
        return tonumber(gradeRate[1].hourly_rate) or defaultRate
    end

    local coreGradeRate = MySQL.query.await('SELECT payment FROM mybusiness_payroll_job_grades WHERE job_name = ? AND grade_level = ? LIMIT 1', { jobName, tonumber(row.grade_level) or 0 })
    if coreGradeRate and coreGradeRate[1] and tonumber(coreGradeRate[1].payment) then
        return tonumber(coreGradeRate[1].payment)
    end

    return defaultRate
end

local function getBossRows(jobName, periodStart, periodEnd, defaultRate)
    local rows = MySQL.query.await([[SELECT citizenid, employee_name, grade_level, SUM(COALESCE(total_minutes,0)) AS total_minutes
        FROM mybusiness_payroll_shifts
        WHERE job_name = ? AND clock_in_ts >= ? AND clock_in_ts < ?
        GROUP BY citizenid, employee_name, grade_level
        ORDER BY employee_name ASC]], { jobName, periodStart, periodEnd })

    local result = {}
    for _, row in ipairs(rows or {}) do
        local hours = (tonumber(row.total_minutes) or 0) / 60
        local rate = resolveRateForRow(jobName, row, defaultRate)
        local pendingBonusRows = MySQL.query.await('SELECT SUM(amount) AS total_bonus FROM mybusiness_payroll_employee_bonus WHERE job_name = ? AND citizenid = ? AND status = "pending"', { jobName, row.citizenid })
        local bonus = pendingBonusRows and pendingBonusRows[1] and tonumber(pendingBonusRows[1].total_bonus) or 0

        result[#result + 1] = {
            citizenid = row.citizenid,
            employee = row.employee_name,
            gradeLevel = tonumber(row.grade_level) or 0,
            hours = math.floor(hours * 100 + 0.5) / 100,
            hourlyRate = rate,
            bonus = bonus,
            grossPay = math.floor(((hours * rate) + bonus) * 100 + 0.5) / 100,
            status = 'Ready'
        }
    end

    return result
end

local function computePayrollBreakdown(rows)
    local taxes = getTaxRates()
    local out = {}
    local totalGross, totalNet = 0, 0
    local totalTax, totalSs, totalMedicare = 0, 0, 0

    for _, row in ipairs(rows) do
        local gross = tonumber(row.grossPay) or 0
        local taxAmount = gross * ((taxes.taxRate or 0) / 100)
        local ssAmount = gross * ((taxes.ssRate or 0) / 100)
        local medicareAmount = gross * ((taxes.medicareRate or 0) / 100)
        local totalDeductions = taxAmount + ssAmount + medicareAmount
        local net = math.max(0, gross - totalDeductions)

        out[#out + 1] = {
            citizenid = row.citizenid,
            employee = row.employee,
            hours = row.hours,
            hourlyRate = row.hourlyRate,
            bonus = row.bonus,
            gross = math.floor(gross * 100 + 0.5) / 100,
            tax = math.floor(taxAmount * 100 + 0.5) / 100,
            ss = math.floor(ssAmount * 100 + 0.5) / 100,
            medicare = math.floor(medicareAmount * 100 + 0.5) / 100,
            deductions = math.floor(totalDeductions * 100 + 0.5) / 100,
            net = math.floor(net * 100 + 0.5) / 100
        }

        totalGross = totalGross + gross
        totalNet = totalNet + net
        totalTax = totalTax + taxAmount
        totalSs = totalSs + ssAmount
        totalMedicare = totalMedicare + medicareAmount
    end

    return out, {
        gross = math.floor(totalGross * 100 + 0.5) / 100,
        net = math.floor(totalNet * 100 + 0.5) / 100,
        tax = math.floor(totalTax * 100 + 0.5) / 100,
        ss = math.floor(totalSs * 100 + 0.5) / 100,
        medicare = math.floor(totalMedicare * 100 + 0.5) / 100,
        rates = taxes
    }
end

local function buildBossPayload(source)
    local player = getPlayer(source)
    local jobName = getJobName(player)
    local settings = getPeriodSettings(jobName)
    local periodStart, periodEnd, periodDays = getPeriodRange(settings)
    local defaultRate = tonumber(settings.hourly_rate) or Config.Payroll.defaultHourlyRate
    local rows = getBossRows(jobName, periodStart, periodEnd, defaultRate)
    local breakdownRows, totals = computePayrollBreakdown(rows)

    local profile = Config.BusinessProfiles[jobName] or Config.BusinessProfiles.default
    local compensation = getCompSettings(jobName)

    return {
        ok = true,
        mode = 'boss',
        platform = Config.Platform,
        profile = profile,
        jobName = jobName,
        jobLabel = getJobLabel(player),
        theme = (function() local t=getThemeForJob(jobName); t.primaryColor=settings.boss_primary_color or t.primaryColor; return t end)(),
        rows = breakdownRows,
        auditIssues = getAuditFlags(jobName, periodStart, periodEnd),
        pendingAdjustments = getPendingAdjustments(jobName),
        jobGrades = getJobGradeCatalog(jobName),
        compensation = compensation,
        taxes = getTaxRates(),
        settings = {
            periodDays = periodDays,
            periodStart = periodStart,
            periodEnd = periodEnd,
            loginDomain = settings.login_domain,
            businessNameOverride = settings.business_name_override,
            businessLogoUrl = settings.business_logo_url,
            bossPrimaryColor = settings.boss_primary_color,
            employeePrimaryColor = settings.employee_primary_color,
            hourlyRate = defaultRate
        },
        summary = {
            employees = #rows,
            payrollTotal = totals.gross,
            payrollNet = totals.net,
            taxTotal = totals.tax + totals.ss + totals.medicare,
            pendingApprovals = #getPendingAdjustments(jobName)
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
    local loginIdentity = (fullName:gsub('%s+', '.'):lower()) .. '@' .. (settings.login_domain or 'business.org')
    local activeShift = getCurrentShift(citizenId, jobName)

    return {
        ok = true,
        mode = 'employee',
        platform = Config.Platform,
        profile = Config.BusinessProfiles[jobName] or Config.BusinessProfiles.default,
        theme = (function() local t=getThemeForJob(jobName); t.primaryColor=settings.employee_primary_color or t.primaryColor; return t end)(),
        employee = {
            fullName = fullName,
            loginIdentity = loginIdentity,
            businessName = settings.business_name_override or getJobLabel(player),
            businessLogoUrl = settings.business_logo_url,
            isClockedIn = activeShift ~= nil,
            clockInAt = activeShift and tonumber(activeShift.clock_in_ts) or nil
        },
        settings = {
            periodDays = periodDays,
            periodStart = periodStart,
            periodEnd = periodEnd,
            hourlyRate = hourlyRate,
            maxAdjustmentMinutes = Config.Payroll.maxAdjustmentMinutes
        },
        summary = getEmployeePeriodSummary(citizenId, jobName, periodStart, periodEnd, hourlyRate),
        adjustmentRequests = getEmployeeAdjustments(citizenId, jobName),
        taxes = getTaxRates()
    }
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
    local periodDays = math.floor(tonumber(payload and payload.periodDays) or Config.Payroll.defaultPeriodDays)
    periodDays = math.max(Config.Payroll.minPeriodDays, math.min(Config.Payroll.maxPeriodDays, periodDays))

    local loginDomain = tostring(payload and payload.loginDomain or 'business.org'):lower():gsub('[^%w%.%-]', '')
    if loginDomain == '' then
        loginDomain = 'business.org'
    end

    local businessNameOverride = tostring(payload and payload.businessNameOverride or '')
    if businessNameOverride == '' then
        businessNameOverride = nil
    end

    local businessLogoUrl = tostring(payload and payload.businessLogoUrl or '')
    if not businessLogoUrl:match('^https?://') then
        businessLogoUrl = nil
    end

    local bossPrimaryColor = tostring(payload and payload.bossPrimaryColor or '')
    if not bossPrimaryColor:match('^#%x%x%x%x%x%x$') then
        bossPrimaryColor = Config.DefaultTheme.primaryColor
    end

    local employeePrimaryColor = tostring(payload and payload.employeePrimaryColor or '')
    if not employeePrimaryColor:match('^#%x%x%x%x%x%x$') then
        employeePrimaryColor = bossPrimaryColor
    end

    local hourlyRate = tonumber(payload and payload.hourlyRate) or Config.Payroll.defaultHourlyRate
    if hourlyRate < 0 then
        hourlyRate = Config.Payroll.defaultHourlyRate
    end

    MySQL.insert.await([[INSERT INTO mybusiness_payroll_settings
        (job_name, period_days, period_anchor, login_domain, business_name_override, business_logo_url, boss_primary_color, employee_primary_color, hourly_rate, updated_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            period_days = VALUES(period_days),
            period_anchor = VALUES(period_anchor),
            login_domain = VALUES(login_domain),
            business_name_override = VALUES(business_name_override),
            business_logo_url = VALUES(business_logo_url),
            boss_primary_color = VALUES(boss_primary_color),
            employee_primary_color = VALUES(employee_primary_color),
            hourly_rate = VALUES(hourly_rate),
            updated_by = VALUES(updated_by)]], {
        jobName,
        periodDays,
        os.time(),
        loginDomain,
        businessNameOverride,
        businessLogoUrl,
        bossPrimaryColor,
        employeePrimaryColor,
        hourlyRate,
        getCitizenId(player)
    })

    writeAuditLog(jobName, 'SETTINGS_UPDATE', getCitizenId(player), getFullName(player), nil, {
        periodDays = periodDays,
        loginDomain = loginDomain,
        businessNameOverride = businessNameOverride,
        businessLogoUrl = businessLogoUrl,
        bossPrimaryColor = bossPrimaryColor,
        employeePrimaryColor = employeePrimaryColor,
        hourlyRate = hourlyRate
    })
end)

RegisterNetEvent('mybusiness_payroll:server:setGradeRate', function(payload)
    local src = source
    if not canOpenBoss(src) then
        return
    end

    local player = getPlayer(src)
    local jobName = getJobName(player)
    local gradeLevel = math.floor(tonumber(payload and payload.gradeLevel) or -1)
    local rate = tonumber(payload and payload.hourlyRate) or 0
    if gradeLevel < 0 or rate < 0 then
        return
    end

    MySQL.insert.await([[INSERT INTO mybusiness_payroll_grade_comp (job_name, grade_level, hourly_rate, updated_by)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE hourly_rate = VALUES(hourly_rate), updated_by = VALUES(updated_by)]], {
        jobName, gradeLevel, rate, getCitizenId(player)
    })

    writeAuditLog(jobName, 'SET_GRADE_RATE', getCitizenId(player), getFullName(player), nil, { gradeLevel = gradeLevel, rate = rate })
end)

RegisterNetEvent('mybusiness_payroll:server:setEmployeeRate', function(payload)
    local src = source
    if not canOpenBoss(src) then
        return
    end

    local player = getPlayer(src)
    local jobName = getJobName(player)
    local targetSource = tonumber(payload and payload.playerId) or 0
    local targetPlayer = getPlayer(targetSource)
    local citizenId = targetPlayer and getCitizenId(targetPlayer) or tostring(payload and payload.citizenid or '')
    local rate = tonumber(payload and payload.hourlyRate) or 0
    if citizenId == '' or rate < 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Target player must be online or provide valid citizen id.', 'error')
        return
    end

    MySQL.insert.await([[INSERT INTO mybusiness_payroll_employee_comp (job_name, citizenid, hourly_rate, updated_by)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE hourly_rate = VALUES(hourly_rate), updated_by = VALUES(updated_by)]], {
        jobName, citizenId, rate, getCitizenId(player)
    })

    writeAuditLog(jobName, 'SET_EMPLOYEE_RATE', getCitizenId(player), getFullName(player), citizenId, { rate = rate })
end)

RegisterNetEvent('mybusiness_payroll:server:addEmployeeBonus', function(payload)
    local src = source
    if not canOpenBoss(src) then
        return
    end

    local player = getPlayer(src)
    local jobName = getJobName(player)
    local targetSource = tonumber(payload and payload.playerId) or 0
    local targetPlayer = getPlayer(targetSource)
    local citizenId = targetPlayer and getCitizenId(targetPlayer) or tostring(payload and payload.citizenid or '')
    local amount = tonumber(payload and payload.amount) or 0
    local reason = tostring(payload and payload.reason or ''):sub(1, 255)
    if citizenId == '' or amount == 0 then
        return
    end

    MySQL.insert.await('INSERT INTO mybusiness_payroll_employee_bonus (job_name, citizenid, amount, reason, granted_by, status) VALUES (?, ?, ?, ?, ?, "pending")', {
        jobName, citizenId, amount, reason ~= '' and reason or nil, getCitizenId(player)
    })

    writeAuditLog(jobName, 'ADD_BONUS', getCitizenId(player), getFullName(player), citizenId, { amount = amount, reason = reason })
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
    local currentShift = getCurrentShift(citizenId, jobName)
    if currentShift then
        TriggerClientEvent('QBCore:Notify', src, 'You are already clocked in.', 'error')
        return
    end

    local otherShift = getCurrentShift(citizenId, nil, true)
    if otherShift then
        TriggerClientEvent('QBCore:Notify', src, ('You are already clocked in under %s. Clock out first.'):format(otherShift.job_name or 'another job'), 'error')
        return
    end

    MySQL.insert.await('INSERT INTO mybusiness_payroll_shifts (citizenid, employee_name, job_name, grade_level, clock_in_ts) VALUES (?, ?, ?, ?, ?)', {
        citizenId,
        getFullName(player),
        jobName,
        getJobGrade(player),
        os.time()
    })

    writeAuditLog(jobName, 'CLOCK_IN', citizenId, getFullName(player), citizenId, {})
    TriggerClientEvent('QBCore:Notify', src, 'Clocked in successfully.', 'success')
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
    local openShift = getCurrentShift(citizenId, jobName) or getCurrentShift(citizenId, nil, true)
    if not openShift then
        TriggerClientEvent('QBCore:Notify', src, 'No active shift found.', 'error')
        return
    end

    local nowTs = os.time()
    local totalMinutes = math.max(0, math.floor((nowTs - tonumber(openShift.clock_in_ts or nowTs)) / 60))
    MySQL.update.await('UPDATE mybusiness_payroll_shifts SET clock_out_ts = ?, total_minutes = ? WHERE id = ?', { nowTs, totalMinutes, openShift.id })
    writeAuditLog(openShift.job_name or jobName, 'CLOCK_OUT', citizenId, getFullName(player), citizenId, { totalMinutes = totalMinutes })
    TriggerClientEvent('QBCore:Notify', src, ('Clocked out successfully (%s minutes).'):format(totalMinutes), 'success')
end)

RegisterNetEvent('mybusiness_payroll:server:submitAdjustment', function(payload)
    local src = source
    if not canOpenEmployee(src) then
        return
    end

    local player = getPlayer(src)
    local minutesDelta = math.floor(tonumber(payload and payload.minutesDelta) or 0)
    local reason = tostring(payload and payload.reason or ''):sub(1, 255)

    if minutesDelta == 0 or math.abs(minutesDelta) > Config.Payroll.maxAdjustmentMinutes then
        TriggerClientEvent('QBCore:Notify', src, ('Adjustment must be within ±%s minutes.'):format(Config.Payroll.maxAdjustmentMinutes), 'error')
        return
    end

    if reason == '' then
        TriggerClientEvent('QBCore:Notify', src, 'Adjustment reason is required.', 'error')
        return
    end

    local citizenId = getCitizenId(player)
    local jobName = getJobName(player)
    local fullName = getFullName(player)

    MySQL.insert.await([[INSERT INTO mybusiness_payroll_adjustment_requests
        (job_name, citizenid, employee_name, minutes_delta, reason, status)
        VALUES (?, ?, ?, ?, ?, 'pending')]], { jobName, citizenId, fullName, minutesDelta, reason })

    writeAuditLog(jobName, 'ADJUSTMENT_REQUEST', citizenId, fullName, citizenId, { minutesDelta = minutesDelta, reason = reason })
    TriggerClientEvent('QBCore:Notify', src, 'Adjustment request submitted for approval.', 'success')
end)

RegisterNetEvent('mybusiness_payroll:server:reviewAdjustment', function(payload)
    local src = source
    if not canOpenBoss(src) then
        return
    end

    local player = getPlayer(src)
    if not player then
        return
    end

    local requestId = tonumber(payload and payload.requestId or 0)
    local decision = tostring(payload and payload.decision or ''):lower()
    if requestId <= 0 or (decision ~= 'approved' and decision ~= 'rejected') then
        return
    end

    local requestRows = MySQL.query.await('SELECT id, job_name, citizenid, employee_name, minutes_delta, status FROM mybusiness_payroll_adjustment_requests WHERE id = ? LIMIT 1', { requestId })
    local req = requestRows and requestRows[1]
    if not req or req.status ~= 'pending' then
        return
    end

    local reviewerCitizenId = getCitizenId(player)
    local reviewerName = getFullName(player)

    MySQL.update.await([[UPDATE mybusiness_payroll_adjustment_requests
        SET status = ?, reviewed_by = ?, reviewed_name = ?, reviewed_at = NOW()
        WHERE id = ?]], { decision, reviewerCitizenId, reviewerName, requestId })

    if decision == 'approved' then
        local targetShift = MySQL.query.await([[SELECT id, total_minutes
            FROM mybusiness_payroll_shifts
            WHERE citizenid = ? AND job_name = ? AND clock_out_ts IS NOT NULL
            ORDER BY clock_out_ts DESC LIMIT 1]], { req.citizenid, req.job_name })

        if targetShift and targetShift[1] then
            local currentMinutes = tonumber(targetShift[1].total_minutes) or 0
            local nextMinutes = math.max(0, currentMinutes + tonumber(req.minutes_delta))
            MySQL.update.await('UPDATE mybusiness_payroll_shifts SET total_minutes = ? WHERE id = ?', { nextMinutes, targetShift[1].id })
        end
    end

    writeAuditLog(req.job_name, 'ADJUSTMENT_' .. string.upper(decision), reviewerCitizenId, reviewerName, req.citizenid, {
        requestId = requestId,
        minutesDelta = req.minutes_delta,
        employeeName = req.employee_name
    })
end)

RegisterNetEvent('mybusiness_payroll:server:runPayroll', function()
    local src = source
    if not canOpenBoss(src) then
        return
    end

    local bossPlayer = getPlayer(src)
    local jobName = getJobName(bossPlayer)
    local settings = getPeriodSettings(jobName)
    local periodStart, periodEnd = getPeriodRange(settings)
    local defaultRate = tonumber(settings.hourly_rate) or Config.Payroll.defaultHourlyRate

    local rows = getBossRows(jobName, periodStart, periodEnd, defaultRate)
    local breakdownRows, totals = computePayrollBreakdown(rows)

    local paid = false
    if Config.Payroll.useSocietyPayout and GetResourceState(Config.Payroll.societyResource) == 'started' then
        local ok = pcall(function()
            exports[Config.Payroll.societyResource]:RemoveMoney(jobName, totals.net)
        end)
        paid = ok
    end

    for _, pay in ipairs(breakdownRows) do
        local targetPlayer
        for _, playerSource in ipairs(QBCore.Functions.GetPlayers()) do
            local online = getPlayer(playerSource)
            if online and getCitizenId(online) == pay.citizenid then
                targetPlayer = online
                break
            end
        end

        if targetPlayer then
            targetPlayer.Functions.AddMoney('bank', pay.net, ('Payroll %s'):format(jobName))
            TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, ('Payroll processed | Hours: %.2f | Gross: $%.2f | Taxes: $%.2f | Net: $%.2f'):format(pay.hours, pay.gross, pay.deductions, pay.net), 'success', 12000)
        end
    end

    MySQL.update.await('UPDATE mybusiness_payroll_employee_bonus SET status = "processed", processed_at = NOW() WHERE job_name = ? AND status = "pending"', { jobName })

    writeAuditLog(jobName, 'RUN_PAYROLL', getCitizenId(bossPlayer), getFullName(bossPlayer), nil, {
        gross = totals.gross,
        net = totals.net,
        tax = totals.tax,
        ss = totals.ss,
        medicare = totals.medicare,
        employeeCount = #breakdownRows,
        paidFromSociety = paid
    })

    TriggerClientEvent('QBCore:Notify', src, ('Payroll processed for %s employees | Gross $%.2f | Net $%.2f | Tax loss $%.2f'):format(#breakdownRows, totals.gross, totals.net, totals.tax + totals.ss + totals.medicare), paid and 'success' or 'primary', 12000)
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


QBCore.Functions.CreateCallback('mybusiness_payroll:server:getPlayerPreview', function(source, cb, playerId)
    if not canOpenBoss(source) then
        cb({ ok = false, message = 'unauthorized' })
        return
    end

    local target = getPlayer(tonumber(playerId) or 0)
    if not target then
        cb({ ok = false, message = 'not_found' })
        return
    end

    cb({
        ok = true,
        playerId = tonumber(playerId),
        citizenid = getCitizenId(target),
        fullName = getFullName(target),
        jobName = getJobName(target),
        gradeLevel = getJobGrade(target)
    })
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

QBCore.Commands.Add('settax', 'Set payroll taxes: /settax [tax] [ss] [medicare]', {
    { name = 'tax', help = 'Tax rate percentage' },
    { name = 'ss', help = 'Social Security percentage' },
    { name = 'medicare', help = 'Medicare percentage' }
}, true, function(source, args)
    if not hasServerPermission(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Admin permission required.', 'error')
        return
    end

    local taxRate = tonumber(args[1] or 0) or 0
    local ssRate = tonumber(args[2] or 0) or 0
    local medicareRate = tonumber(args[3] or 0) or 0

    if taxRate < 0 or ssRate < 0 or medicareRate < 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Rates cannot be negative.', 'error')
        return
    end

    local actor = getPlayer(source)
    MySQL.update.await('UPDATE mybusiness_payroll_tax SET tax_rate = ?, ss_rate = ?, medicare_rate = ?, updated_by = ? WHERE id = 1', {
        taxRate, ssRate, medicareRate, actor and getCitizenId(actor) or 'console'
    })

    writeAuditLog('global', 'SET_TAX', actor and getCitizenId(actor) or 'console', actor and getFullName(actor) or 'Console', nil, {
        taxRate = taxRate,
        ssRate = ssRate,
        medicareRate = medicareRate
    })

    if source > 0 then
        TriggerClientEvent('QBCore:Notify', source, ('Tax updated | Tax: %.2f%% SS: %.2f%% Medicare: %.2f%%'):format(taxRate, ssRate, medicareRate), 'success')
    else
        print(('[mybusiness_payroll] Tax updated: tax=%.2f ss=%.2f medicare=%.2f'):format(taxRate, ssRate, medicareRate))
    end
end, Config.AdminPermission)

QBCore.Commands.Add('payrollgrant', 'Grant payroll boss access by minimum job grade', {
    { name = 'id', help = 'Server ID' },
    { name = 'job', help = 'Job name' },
    { name = 'grade', help = 'Minimum job grade' }
}, true, function(source, args)
    if not hasServerPermission(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Admin permission required.', 'error')
        return
    end

    local target = getPlayer(tonumber(args[1] or 0))
    if not target then
        TriggerClientEvent('QBCore:Notify', source, 'Target player is not online.', 'error')
        return
    end

    local jobName = tostring(args[2] or ''):lower()
    if not (QBCore.Shared and QBCore.Shared.Jobs and QBCore.Shared.Jobs[jobName]) then
        TriggerClientEvent('QBCore:Notify', source, ('Unknown city job: %s'):format(jobName), 'error')
        return
    end

    local minGrade = tonumber(args[3] or Config.DefaultMinimumGrade)
    if not minGrade or minGrade < 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Invalid grade. Use number >= 0.', 'error')
        return
    end

    MySQL.insert.await([[INSERT INTO mybusiness_payroll_access (citizenid, job_name, min_grade, granted_by, active)
        VALUES (?, ?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE min_grade = VALUES(min_grade), granted_by = VALUES(granted_by), active = 1]], {
        getCitizenId(target),
        jobName,
        minGrade,
        getPlayer(source) and getCitizenId(getPlayer(source)) or 'console'
    })

    TriggerClientEvent('QBCore:Notify', source, ('Granted boss payroll access for %s (min grade %s).'):format(jobName, minGrade), 'success')
end, Config.AdminPermission)

QBCore.Commands.Add('payrollrevoke', 'Revoke payroll boss access', {
    { name = 'id', help = 'Server ID' },
    { name = 'job', help = 'Job name' }
}, true, function(source, args)
    if not hasServerPermission(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Admin permission required.', 'error')
        return
    end

    local target = getPlayer(tonumber(args[1] or 0))
    if not target then
        TriggerClientEvent('QBCore:Notify', source, 'Target player is not online.', 'error')
        return
    end

    MySQL.update.await('UPDATE mybusiness_payroll_access SET active = 0 WHERE citizenid = ? AND job_name = ?', {
        getCitizenId(target),
        tostring(args[2] or ''):lower()
    })

    TriggerClientEvent('QBCore:Notify', source, 'Boss payroll access revoked.', 'success')
end, Config.AdminPermission)

QBCore.Commands.Add('payrolljobs', 'Print city jobs and grades from QBCore', {}, false, function(source)
    if source > 0 and not hasServerPermission(source) then
        TriggerClientEvent('QBCore:Notify', source, 'Admin permission required.', 'error')
        return
    end

    print('[mybusiness_payroll] City jobs and grade map:')
    for jobName, jobData in pairs(QBCore.Shared and QBCore.Shared.Jobs or {}) do
        print(('- %s (%s)'):format(jobName, jobData.label or jobName))
        for gradeLevel, gradeData in pairs(jobData.grades or {}) do
            print(('   grade %s: %s | payment: %s'):format(gradeLevel, gradeData.name or 'N/A', gradeData.payment or 0))
        end
    end

    if source > 0 then
        TriggerClientEvent('QBCore:Notify', source, 'Printed city jobs + grades to console.', 'primary')
    end
end, 'user')

CreateThread(function()
    ensureDatabase()
    syncJobsToDatabase()
    print('[Aegis-Payroll] Aegis-Payroll Loaded Succesfully!')
end)
