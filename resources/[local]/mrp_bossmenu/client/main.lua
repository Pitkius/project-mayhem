local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local activeJob = nil

local function setFocus(open)
    SetNuiFocus(open, open)
    SetNuiFocusKeepInput(false)
end

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    activeJob = nil
    setFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function openUi(jobName)
    if uiOpen then closeUi() end
    activeJob = jobName
    uiOpen = true
    setFocus(true)
    QBCore.Functions.TriggerCallback('mrp_bossmenu:server:getDashboard', function(data)
        if not data then
            closeUi()
            return QBCore.Functions.Notify('Neturi teisės atidaryti vadovybės meniu.', 'error')
        end
        SendNUIMessage({ action = 'open', data = data })
    end, jobName)
end

local function refreshUi()
    if not uiOpen or not activeJob then return end
    QBCore.Functions.TriggerCallback('mrp_bossmenu:server:getDashboard', function(data)
        if data then SendNUIMessage({ action = 'sync', data = data }) end
    end, activeJob)
end

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    refreshUi()
    cb('ok')
end)

RegisterNUICallback('fundDeposit', function(data, cb)
    if activeJob then TriggerServerEvent('mrp_bossmenu:server:fundDeposit', activeJob, data.amount) end
    SetTimeout(300, refreshUi)
    cb('ok')
end)

RegisterNUICallback('fundWithdraw', function(data, cb)
    if activeJob then TriggerServerEvent('mrp_bossmenu:server:fundWithdraw', activeJob, data.amount) end
    SetTimeout(300, refreshUi)
    cb('ok')
end)

RegisterNUICallback('setSalarySettings', function(data, cb)
    if activeJob then
        TriggerServerEvent('mrp_bossmenu:server:setSalarySettings', activeJob, data.enabled)
    end
    SetTimeout(300, refreshUi)
    cb('ok')
end)

RegisterNUICallback('saveGrade', function(data, cb)
    if activeJob then TriggerServerEvent('mrp_bossmenu:server:saveGrade', activeJob, data) end
    SetTimeout(350, refreshUi)
    cb('ok')
end)

RegisterNUICallback('addGrade', function(_, cb)
    if activeJob then TriggerServerEvent('mrp_bossmenu:server:addGrade', activeJob) end
    SetTimeout(350, refreshUi)
    cb('ok')
end)

RegisterNUICallback('deleteGrade', function(data, cb)
    if activeJob then TriggerServerEvent('mrp_bossmenu:server:deleteGrade', activeJob, data.level) end
    SetTimeout(350, refreshUi)
    cb('ok')
end)

RegisterNUICallback('saveDivision', function(data, cb)
    if activeJob then TriggerServerEvent('mrp_bossmenu:server:saveDivision', activeJob, data) end
    SetTimeout(350, refreshUi)
    cb('ok')
end)

RegisterNUICallback('hire', function(data, cb)
    if activeJob then TriggerServerEvent('mrp_bossmenu:server:hire', activeJob, data.targetId, data.grade, data.divisionId) end
    SetTimeout(400, refreshUi)
    cb('ok')
end)

RegisterNUICallback('fire', function(data, cb)
    if activeJob then TriggerServerEvent('mrp_bossmenu:server:fire', activeJob, data.targetId, data.citizenid) end
    SetTimeout(400, refreshUi)
    cb('ok')
end)

RegisterNUICallback('setGrade', function(data, cb)
    if activeJob then TriggerServerEvent('mrp_bossmenu:server:setGrade', activeJob, data.targetId, data.grade, data.citizenid) end
    SetTimeout(400, refreshUi)
    cb('ok')
end)

RegisterNUICallback('setMemberDivision', function(data, cb)
    if activeJob then TriggerServerEvent('mrp_bossmenu:server:setMemberDivision', activeJob, data.targetId, data.divisionId, data.citizenid) end
    SetTimeout(400, refreshUi)
    cb('ok')
end)

RegisterNUICallback('deleteDivision', function(data, cb)
    if activeJob then TriggerServerEvent('mrp_bossmenu:server:deleteDivision', activeJob, data.id) end
    SetTimeout(350, refreshUi)
    cb('ok')
end)

RegisterNUICallback('toggleDuty', function(_, cb)
    TriggerServerEvent('QBCore:ToggleDuty')
    cb('ok')
end)

RegisterNUICallback('setFleetDivisionLock', function(data, cb)
    if activeJob then
        TriggerServerEvent('mrp_bossmenu:server:setFleetDivisionLock', activeJob, data.enabled == true)
    end
    SetTimeout(300, refreshUi)
    cb('ok')
end)

RegisterNUICallback('saveFleetVehicle', function(data, cb)
    if activeJob then
        TriggerServerEvent('mrp_bossmenu:server:saveFleetVehicle', activeJob, data)
    end
    SetTimeout(350, refreshUi)
    cb('ok')
end)

exports('OpenBossMenu', openUi)
exports('CloseBossMenu', closeUi)
exports('IsBossMenuOpen', function() return uiOpen end)

RegisterNetEvent('mrp_bossmenu:client:open', function(jobName)
    openUi(jobName)
end)

RegisterCommand('bossmenu', function()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job then return end
    if Config.Jobs[P.job.name] then openUi(P.job.name) end
end, false)
