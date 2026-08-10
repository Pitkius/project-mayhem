--- Performance dalių crafting NUI (pakeičia qb-menu).
local QBCore = exports['qb-core']:GetCoreObject()

local craftOpen = false
local craftKind = 'tuning'

local function isMechanicOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty
end

local function closeCraftUi()
    if not craftOpen then return end
    craftOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeCraft' })
end

local function openCraftUi(kind)
    if craftOpen then return end
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    craftKind = tostring(kind or 'tuning')
    QBCore.Functions.TriggerCallback('mrp_mechanic:server:getCraftUiData', function(data)
        if not data or not data.ok then
            return QBCore.Functions.Notify(data and data.message or 'Nepavyko atidaryti crafting meniu.', 'error')
        end
        craftOpen = true
        SetNuiFocus(true, true)
        if PushPlayerThemeToNui then PushPlayerThemeToNui() end
        SendNUIMessage({ action = 'openCraft', payload = data })
    end, craftKind)
end

RegisterNetEvent('mrp_mechanic:client:openCraftMenu', function(data)
    openCraftUi(data and data.craftKind or 'tuning')
end)

RegisterNUICallback('craftClose', function(_, cb)
    closeCraftUi()
    cb({ ok = true })
end)

RegisterNUICallback('craftRefresh', function(_, cb)
    if not isMechanicOnDuty() then
        closeCraftUi()
        return cb({ ok = false })
    end
    QBCore.Functions.TriggerCallback('mrp_mechanic:server:getCraftUiData', function(data)
        cb(data or { ok = false })
    end, craftKind)
end)

RegisterNUICallback('craftStart', function(data, cb)
    if not isMechanicOnDuty() then
        closeCraftUi()
        return cb({ ok = false, message = 'Tik mechanikams tarnyboje.' })
    end
    local key = data and data.recipeKey
    local amount = tonumber(data and data.amount) or 1
    if not key or key == '' then
        return cb({ ok = false, message = 'Nepasirinktas receptas.' })
    end
    QBCore.Functions.TriggerCallback('mrp_mechanic:server:craftPart', function(res)
        cb(res or { ok = false, message = 'Nepavyko pagaminti.' })
    end, key, amount)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    closeCraftUi()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closeCraftUi()
end)

CreateThread(function()
    while true do
        if craftOpen then
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                closeCraftUi()
            end
            Wait(500)
        else
            Wait(1200)
        end
    end
end)
