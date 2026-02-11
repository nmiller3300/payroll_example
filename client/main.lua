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

local function openPayrollUi(profile, summary, rows, theme, platform)
    SendNUIMessage({
        action = 'bootstrap',
        payload = {
            platform = platform or Config.Platform,
            theme = theme or Config.DefaultTheme,
            profile = profile,
            summary = summary,
            rows = rows
        }
    })

    setUiVisible(true)
end

RegisterNetEvent('mybusiness_payroll:client:openForCommandStaff', function(profile, summary, rows, theme, platform)
    openPayrollUi(profile, summary, rows, theme, platform)
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
