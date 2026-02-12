local QBCore = exports['qb-core']:GetCoreObject()
local isOpen = false

local function setFocus(state)
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(state)
    isOpen = state
end

local function openPayload(mode)
    local callbackName = mode == 'boss' and 'mybusiness_payroll:server:getBossPayload' or 'mybusiness_payroll:server:getEmployeePayload'
    QBCore.Functions.TriggerCallback(callbackName, function(payload)
        if not payload or not payload.ok then
            local reason = payload and payload.message or 'unknown'
            QBCore.Functions.Notify(('Payroll tablet unavailable (%s).'):format(reason), 'error')
            return
        end

        setFocus(true)
        SendNUIMessage({ action = 'open', payload = payload, mode = mode })
    end)
end

RegisterNetEvent('mybusiness_payroll:client:openBoss', function()
    openPayload('boss')
end)

RegisterNetEvent('mybusiness_payroll:client:openEmployee', function()
    openPayload('employee')
end)

RegisterNUICallback('close', function(_, cb)
    setFocus(false)
    cb({ ok = true })
end)

RegisterNUICallback('saveTheme', function(data, cb)
    TriggerServerEvent('mybusiness_payroll:server:saveTheme', data)
    cb({ ok = true })
end)

RegisterNUICallback('saveSettings', function(data, cb)
    TriggerServerEvent('mybusiness_payroll:server:updateSettings', data)
    cb({ ok = true })
end)

RegisterNUICallback('clockIn', function(_, cb)
    TriggerServerEvent('mybusiness_payroll:server:clockIn')
    cb({ ok = true })
end)

RegisterNUICallback('clockOut', function(_, cb)
    TriggerServerEvent('mybusiness_payroll:server:clockOut')
    cb({ ok = true })
end)

RegisterNUICallback('runPayroll', function(_, cb)
    TriggerServerEvent('mybusiness_payroll:server:runPayroll')
    cb({ ok = true })
end)

RegisterNUICallback('submitAdjustment', function(data, cb)
    TriggerServerEvent('mybusiness_payroll:server:submitAdjustment', data)
    cb({ ok = true })
end)


RegisterNUICallback('setGradeRate', function(data, cb)
    TriggerServerEvent('mybusiness_payroll:server:setGradeRate', data)
    cb({ ok = true })
end)

RegisterNUICallback('setEmployeeRate', function(data, cb)
    TriggerServerEvent('mybusiness_payroll:server:setEmployeeRate', data)
    cb({ ok = true })
end)

RegisterNUICallback('addEmployeeBonus', function(data, cb)
    TriggerServerEvent('mybusiness_payroll:server:addEmployeeBonus', data)
    cb({ ok = true })
end)

RegisterNUICallback('reviewAdjustment', function(data, cb)
    TriggerServerEvent('mybusiness_payroll:server:reviewAdjustment', data)
    cb({ ok = true })
end)

RegisterNUICallback('requestRefresh', function(data, cb)
    openPayload(data and data.mode == 'employee' and 'employee' or 'boss')
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        Wait(0)
        if isOpen and (IsControlJustReleased(0, 322) or IsControlJustReleased(0, 73)) then
            setFocus(false)
            SendNUIMessage({ action = 'close' })
        end
    end
end)
