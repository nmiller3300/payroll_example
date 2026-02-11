local QBCore = exports['qb-core']:GetCoreObject()

local function hasAccess(src)
    if not Config.UseAcePermission then
        return true
    end

    return IsPlayerAceAllowed(src, Config.RequiredAce)
end

local function buildFallbackRows(Player)
    local citizenId = Player and Player.PlayerData and Player.PlayerData.citizenid or 'Unknown'
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
            role = Player and Player.PlayerData.job and Player.PlayerData.job.label or 'Staff',
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

local function buildPayload(src)
    local Player = QBCore.Functions.GetPlayer(src)
    local jobName = Player and Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name or 'default'
    local profile = Config.BusinessProfiles[jobName] or Config.BusinessProfiles.default

    -- If you have a payroll table, replace this fallback with a SQL query.
    local rows = buildFallbackRows(Player)
    local summary = buildSummary(rows)

    return {
        ok = true,
        profile = profile,
        summary = summary,
        rows = rows,
        theme = Config.DefaultTheme,
        platform = Config.Platform
    }
end

QBCore.Functions.CreateCallback('mybusiness_payroll:server:getDashboardPayload', function(source, cb)
    if not hasAccess(source) then
        cb({ ok = false, message = 'unauthorized' })
        return
    end

    cb(buildPayload(source))
end)

RegisterNetEvent('mybusiness_payroll:server:saveTheme', function(payload)
    local src = source
    if not hasAccess(src) then
        return
    end

    if Config.Debug then
        print(('[mybusiness_payroll] Theme update from %s: %s'):format(src, json.encode(payload)))
    end

    -- Persist payload to DB based on tenant/business rules when integrating in production.
end)

QBCore.Commands.Add(
    Config.CommandName,
    'Open the MyBusiness Payroll command dashboard',
    {},
    false,
    function(source)
        if not hasAccess(source) then
            TriggerClientEvent('QBCore:Notify', source, 'Insufficient permissions for payroll console.', 'error')
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
