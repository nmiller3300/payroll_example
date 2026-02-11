local QBCore = exports['qb-core']:GetCoreObject()
local uiOpen = false

local function setUiVisible(visible)
    uiOpen = visible
    SetNuiFocus(visible, visible)
    SendNUIMessage({
        action = 'setVisible',
        payload = { visible = visible }
    })
end

local function openPayrollUi(profile, summary, rows)
    SendNUIMessage({
        action = 'bootstrap',
        payload = {
            platform = Config.Platform,
            theme = Config.DefaultTheme,
            profile = profile,
            summary = summary,
            rows = rows
        }
    })

    setUiVisible(true)
end

RegisterCommand(Config.CommandName, function()
    QBCore.Functions.TriggerCallback('mybusiness_payroll:server:getDashboardPayload', function(response)
        if not response or not response.ok then
            QBCore.Functions.Notify('Unable to load payroll dashboard.', 'error')
            return
        end

        openPayrollUi(response.profile, response.summary, response.rows)
    end)
end, false)

RegisterNetEvent('mybusiness_payroll:client:openForCommandStaff', function(profile, summary, rows)
    openPayrollUi(profile, summary, rows)
end)

RegisterNUICallback('close', function(_, cb)
    setUiVisible(false)
    cb({ ok = true })
end)

RegisterNUICallback('saveTheme', function(payload, cb)
    TriggerServerEvent('mybusiness_payroll:server:saveTheme', payload)
    cb({ ok = true })
end)

RegisterNUICallback('requestRefresh', function(_, cb)
    QBCore.Functions.TriggerCallback('mybusiness_payroll:server:getDashboardPayload', function(response)
        cb(response or { ok = false })
    end)
end)

CreateThread(function()
    while true do
        if uiOpen and IsControlJustReleased(0, 322) then -- ESC
            setUiVisible(false)
        end
        Wait(0)
    end
end)
