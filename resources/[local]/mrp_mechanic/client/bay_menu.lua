local QBCore = exports['qb-core']:GetCoreObject()

local mechanicUiOpen = false
local mechanicUiVeh = nil
local mechanicBayIndex = nil
local mechanicPlate = nil
local vehWasFrozen = false

local PAINT_TYPES = {
    { paintType = 0, label = 'Klasikinės', txt = 'Standartinis korpusinis dažymas' },
    { paintType = 1, label = 'Metinės', txt = 'Metalizuotas blizgesys' },
    { paintType = 2, label = 'Perlmutrinės', txt = 'Perlų / multicoat efektas' },
    { paintType = 3, label = 'Matinės', txt = 'Nebliškantis matinis' },
    { paintType = 4, label = 'Metalas', txt = 'Šiurkštus anoduotas metalas' },
    { paintType = 5, label = 'Chromas', txt = 'Veidrodinis chromas' },
}

local WINDOW_TINTS = {
    { idx = -1, label = 'Gamyklinis (be tamsinimo)' },
    { idx = 0, label = 'Skaidrus' },
    { idx = 1, label = 'Visiškai juodas' },
    { idx = 2, label = 'Tamsus dūmas' },
    { idx = 3, label = 'Šviesus dūmas' },
    { idx = 4, label = 'Gamyklinis' },
    { idx = 5, label = 'Limuzinas' },
    { idx = 6, label = 'Žalias' },
}

local BODY_MODS = {
    { id = 0, label = 'Spoileriai' },
    { id = 1, label = 'Priekinis buferis' },
    { id = 2, label = 'Galinis buferis' },
    { id = 3, label = 'Šonai (sijonai)' },
    { id = 4, label = 'Išmetimas' },
    { id = 5, label = 'Rėmas / kėbulas' },
    { id = 6, label = 'Grotelės' },
    { id = 7, label = 'Gaubtas' },
    { id = 8, label = 'Sparnai (priek.)' },
    { id = 9, label = 'Sparnai (gal.)' },
    { id = 10, label = 'Stogas' },
}

local PERF_MODS = {
    { id = 11, label = 'Variklis' },
    { id = 12, label = 'Stabdžiai' },
    { id = 13, label = 'Pavarų dėžė' },
    { id = 15, label = 'Pakaba' },
    { id = 16, label = 'Šarvai' },
}

local function isMechanicOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty
end

local function getVehicleInBay(bay)
    if not bay or not bay.coords then return 0 end
    local c = bay.coords
    local cx, cy, cz = c.x, c.y, c.z
    local maxR = (math.max(tonumber(bay.length) or 6, tonumber(bay.width) or 6) * 0.45) + 1.2
    local best, bestD = 0, maxR + 1.0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            local p = GetEntityCoords(veh)
            local d = #(vector3(p.x, p.y, p.z) - vector3(cx, cy, cz))
            if d <= maxR and d < bestD then
                best, bestD = veh, d
            end
        end
    end
    return best
end

local function ensureModKit(veh)
    if veh == 0 then return end
    SetVehicleModKit(veh, 0)
end

local function applyUniformPaint(veh, paintType, colorIndex)
    if veh == 0 or not DoesEntityExist(veh) then return end
    ensureModKit(veh)
    ClearVehicleCustomPrimaryColour(veh)
    ClearVehicleCustomSecondaryColour(veh)
    local pearl, wheelCol = GetVehicleExtraColours(veh)
    pearl = pearl or 0
    SetVehicleColours(veh, colorIndex, colorIndex)
    SetVehicleModColor_1(veh, paintType, colorIndex, pearl)
    SetVehicleModColor_2(veh, paintType, colorIndex)
    SetVehicleExtraColours(veh, pearl, wheelCol)
end

local function doQuickRepair(veh)
    if veh == 0 or not DoesEntityExist(veh) then return end
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    QBCore.Functions.Notify('Transportas suremontuotas.', 'success')
end

local function getModCategories(veh, defs)
    ensureModKit(veh)
    local out = {}
    for _, g in ipairs(defs) do
        out[#out + 1] = {
            id = g.id,
            label = g.label,
            count = GetNumVehicleMods(veh, g.id),
        }
    end
    return out
end

local function getBayVehicle()
    local bay = mechanicBayIndex and Config.RepairBays and Config.RepairBays[mechanicBayIndex]
    if not bay then return 0 end
    return getVehicleInBay(bay)
end

local function closeMechanicUi()
    if mechanicUiVeh and DoesEntityExist(mechanicUiVeh) and vehWasFrozen then
        FreezeEntityPosition(mechanicUiVeh, false)
    end
    vehWasFrozen = false
    mechanicUiOpen = false
    mechanicUiVeh = nil
    mechanicBayIndex = nil
    mechanicPlate = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function saveTune()
    local vNow = getBayVehicle()
    if vNow == 0 then
        QBCore.Functions.Notify('Remonto zonoje nebėra transporto — neišsaugota.', 'error')
        return false
    end
    local plateNow = QBCore.Functions.GetPlate(vNow)
    if not plateNow or plateNow ~= mechanicPlate then
        QBCore.Functions.Notify('Kita mašina zonoje — patikrink numerius ir bandyk dar kartą.', 'error')
        return false
    end
    ensureModKit(vNow)
    local props = QBCore.Functions.GetVehicleProperties(vNow)
    if props then props.plate = mechanicPlate end
    TriggerServerEvent('mrp_mechanic:server:saveBayVehicleTune', mechanicBayIndex, props)
    QBCore.Functions.Notify('Pakeitimai užfiksuoti — klientas gaus atnaujintą mašiną iš garažo.', 'success')
    return true
end

local function openWorkshopNui(bayIndex, veh, plate)
    mechanicUiOpen = true
    mechanicUiVeh = veh
    mechanicBayIndex = bayIndex
    mechanicPlate = plate

    if DoesEntityExist(veh) then
        vehWasFrozen = IsEntityPositionFrozen(veh)
        FreezeEntityPosition(veh, true)
        SetVehicleEngineOn(veh, false, true, true)
    end

    ensureModKit(veh)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        bayIndex = bayIndex,
        plate = plate,
        paintTypes = PAINT_TYPES,
        windowTints = WINDOW_TINTS,
        bodyMods = getModCategories(veh, BODY_MODS),
        perfMods = getModCategories(veh, PERF_MODS),
        turboOn = IsToggleModOn(veh, 18),
    })
end

RegisterNetEvent('mrp_mechanic:client:openBayWorkshop', function(data)
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end

    local bayIndex = data and tonumber(data.bayIndex)
    local bay = bayIndex and Config.RepairBays and Config.RepairBays[bayIndex]
    if not bay then return end

    local veh = getVehicleInBay(bay)
    if veh == 0 then
        return QBCore.Functions.Notify('Remonto zonoje nėra transporto.', 'error')
    end

    local plate = QBCore.Functions.GetPlate(veh)
    if not plate or plate == '' then
        return QBCore.Functions.Notify('Nerasta valstybinė numeracija.', 'error')
    end

    openWorkshopNui(bayIndex, veh, plate)
end)

-- Seni įvykiai paliekami suderinamumui — atidaro tą patį NUI.
RegisterNetEvent('mrp_mechanic:client:openPerformanceWorkshop', function(data)
    TriggerEvent('mrp_mechanic:client:openBayWorkshop', data)
end)

RegisterNetEvent('mrp_mechanic:client:openBodyWorkshop', function(data)
    TriggerEvent('mrp_mechanic:client:openBayWorkshop', data)
end)

RegisterNUICallback('close', function(_, cb)
    closeMechanicUi()
    cb('ok')
end)

RegisterNUICallback('save', function(_, cb)
    if saveTune() then closeMechanicUi() end
    cb('ok')
end)

RegisterNUICallback('repair', function(_, cb)
    local veh = getBayVehicle()
    if veh ~= 0 then doQuickRepair(veh) end
    cb('ok')
end)

RegisterNUICallback('applyPaint', function(data, cb)
    local veh = getBayVehicle()
    if veh == 0 then return cb('ok') end
    local pt = tonumber(data.paintType) or 0
    local ci = tonumber(data.colorIndex) or 0
    applyUniformPaint(veh, pt, ci)
    cb('ok')
end)

RegisterNUICallback('applyTint', function(data, cb)
    local veh = getBayVehicle()
    if veh == 0 then return cb('ok') end
    SetVehicleWindowTint(veh, tonumber(data.idx) or 0)
    cb('ok')
end)

RegisterNUICallback('requestVariants', function(data, cb)
    local veh = getBayVehicle()
    local modType = tonumber(data.modType)
    local label = tostring(data.label or 'Mod')
    local returnTab = tostring(data.returnTab or 'body')
    if veh == 0 or not modType then return cb('ok') end

    ensureModKit(veh)
    local n = GetNumVehicleMods(veh, modType)
    local variants = {}
    for i = 0, n - 1 do
        variants[#variants + 1] = { idx = i, label = ('Variantas %s / %s'):format(i + 1, n) }
    end
    SendNUIMessage({
        action = 'variants',
        modType = modType,
        label = label,
        returnTab = returnTab,
        variants = variants,
    })
    cb('ok')
end)

RegisterNUICallback('installMod', function(data, cb)
    local veh = getBayVehicle()
    local modType = tonumber(data.modType)
    local idx = tonumber(data.idx)
    local label = tostring(data.label or 'Detalė')
    if veh == 0 or not modType or idx == nil then return cb('ok') end

    if idx < 0 then
        SetVehicleMod(veh, modType, -1, false)
        QBCore.Functions.Notify('Gamyklinis variantas.', 'primary')
        return cb('ok')
    end

    QBCore.Functions.TriggerCallback('mrp_mechanic:server:canInstallUpgrade', function(res)
        if not res or not res.ok then
            QBCore.Functions.Notify((res and res.reason) or 'Negalima įdiegti detalės.', 'error')
            return
        end
        SetVehicleMod(veh, modType, idx, false)
        if res.requiredItem then
            TriggerServerEvent('mrp_mechanic:server:consumeUpgradeItem', res.requiredItem)
        end
        QBCore.Functions.Notify(('Įdiegta: %s #%s'):format(label, idx + 1), 'success')
    end, modType, idx, mechanicBayIndex)
    cb('ok')
end)

RegisterNUICallback('toggleTurbo', function(_, cb)
    local veh = getBayVehicle()
    if veh == 0 then return cb('ok') end
    ensureModKit(veh)
    local on = IsToggleModOn(veh, 18)
    local nextState = not on

    if nextState then
        QBCore.Functions.TriggerCallback('mrp_mechanic:server:canInstallUpgrade', function(res)
            if not res or not res.ok then
                QBCore.Functions.Notify((res and res.reason) or 'Negalima įdiegti turbo.', 'error')
                return
            end
            ToggleVehicleMod(veh, 18, true)
            if res.requiredItem then
                TriggerServerEvent('mrp_mechanic:server:consumeUpgradeItem', res.requiredItem)
            end
            QBCore.Functions.Notify('Turbo įdiegtas.', 'success')
            SendNUIMessage({ action = 'turboState', on = true })
        end, 18, 0, mechanicBayIndex)
    else
        ToggleVehicleMod(veh, 18, false)
        QBCore.Functions.Notify('Turbo nuimtas.', 'primary')
        SendNUIMessage({ action = 'turboState', on = false })
    end
    cb('ok')
end)

-- Toninimo metu: užšaldytas transportas, išjungti vairavimo valdikliai (A/D ir kt.).
CreateThread(function()
    while true do
        if mechanicUiOpen and mechanicUiVeh and DoesEntityExist(mechanicUiVeh) then
            FreezeEntityPosition(mechanicUiVeh, true)
            DisableControlAction(0, 34, true)  -- A / kairė
            DisableControlAction(0, 35, true)  -- D / dešinė
            DisableControlAction(0, 174, true) -- kairė (alternatyva)
            DisableControlAction(0, 175, true) -- dešinė (alternatyva)
            DisableControlAction(0, 59, true)  -- vairavimas transporte
            DisableControlAction(0, 60, true)
            DisableControlAction(0, 71, true)  -- akseleratorius
            DisableControlAction(0, 72, true)  -- stabdis
            DisableControlAction(0, 63, true)
            DisableControlAction(0, 64, true)
            DisableControlAction(0, 75, true)  -- išlipti
            Wait(0)
        else
            Wait(400)
        end
    end
end)
