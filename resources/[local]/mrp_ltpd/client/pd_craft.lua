local QBCore = exports['qb-core']:GetCoreObject()

local crafting = false
local craftToken = 0
local currentStationKey = nil

local function cfg()
    return Config.PdWeaponCraft or {}
end

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function nui(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

local function closeCraftUi()
    SetNuiFocus(false, false)
    nui('pdCraftClose')
    currentStationKey = nil
    crafting = false
    craftToken = craftToken + 1
    nui('pdCraftProgressHide')
end

local function runCraftProgress(durationMs, label, onDone, onCancel)
    craftToken = craftToken + 1
    local token = craftToken
    local started = GetGameTimer()
    durationMs = tonumber(durationMs) or 10000
    nui('pdCraftProgress', { label = label, totalMs = durationMs })

    CreateThread(function()
        while token == craftToken do
            local elapsed = GetGameTimer() - started
            local pct = math.min(100, (elapsed / durationMs) * 100)
            local remaining = math.max(0, durationMs - elapsed)
            nui('pdCraftProgressUpdate', { pct = pct, remainingMs = remaining })
            if elapsed >= durationMs then break end
            if IsControlJustPressed(0, 73) then
                craftToken = craftToken + 1
                nui('pdCraftProgressHide')
                if onCancel then onCancel() end
                return
            end
            Wait(50)
        end
        if token ~= craftToken then return end
        nui('pdCraftProgressHide')
        if onDone then onDone() end
    end)
end

local function openCraftUi(stationKey)
    if crafting then return end
    QBCore.Functions.TriggerCallback('mrp_ltpd:server:getPdCraftUi', function(data)
        if not data or not data.ok then
            return notify((data and data.reason) or 'Ginklų gamyba neprieinama.', 'error')
        end
        currentStationKey = stationKey
        SetNuiFocus(true, true)
        nui('pdCraftOpen', {
            stationKey = stationKey,
            stationLabel = data.stationLabel,
            craftLevel = data.craftLevel,
            craftsAtLevel = data.craftsAtLevel,
            craftsNeeded = data.craftsNeeded,
            maxLevel = data.maxLevel,
            products = data.products,
        })
    end, stationKey)
end

RegisterNetEvent('mrp_ltpd:client:openPdWeaponCraft', function(data)
    local key = data and data.stationKey
    if not key then return end
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= (Config.JobName or 'police') or not P.job.onduty then
        return notify('Tik policijai tarnyboje.', 'error')
    end
    openCraftUi(key)
end)

RegisterNUICallback('pdCraftClose', function(_, cb)
    closeCraftUi()
    cb({ ok = true })
end)

RegisterNUICallback('pdCraftStart', function(data, cb)
    cb({ ok = true })
    if crafting then return end
    local stationKey = data and data.stationKey or currentStationKey
    local recipeId = data and data.recipeId
    if not stationKey or not recipeId then return end

    local recipe = (cfg().recipes or {})[tostring(recipeId)]
    if not recipe then return end

    crafting = true
    local duration = tonumber(recipe.timeMs) or 10000
    local label = ('Gaminama: %s'):format(recipe.label or recipeId)

    runCraftProgress(duration, label, function()
        TriggerServerEvent('mrp_ltpd:server:pdWeaponCraft', stationKey, recipeId)
        crafting = false
        QBCore.Functions.TriggerCallback('mrp_ltpd:server:getPdCraftUi', function(res)
            if res and res.ok and currentStationKey then
                nui('pdCraftRefresh', {
                    products = res.products,
                    craftLevel = res.craftLevel,
                    craftsAtLevel = res.craftsAtLevel,
                    craftsNeeded = res.craftsNeeded,
                    maxLevel = res.maxLevel,
                })
            end
        end, stationKey)
    end, function()
        crafting = false
        notify('Gamyba atšaukta.', 'error')
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closeCraftUi()
end)
