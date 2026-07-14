--- Modernus performance dalių UI + automobilio peržiūros kamera.
local QBCore = exports['qb-core']:GetCoreObject()

local perfUiOpen = false
local perfUiVeh = nil
local perfBayIndex = nil
local perfPlate = nil
local vehWasFrozen = false
local vehEngineWasOn = false

local perfCam = nil
local camAngle = 45.0
local camDist = 5.5
local camHeight = 1.15
local camTargetHeight = 0.35
local camPresetAngle = 45.0
local camPresetDist = 5.5
local camPresetHeight = 1.15
local camPresetTargetH = 0.35

local CAM_PRESETS = {
    [11] = { dist = 4.6, height = 1.25, targetH = 0.45, angle = 38.0 },
    [12] = { dist = 3.4, height = 0.55, targetH = 0.15, angle = 28.0 },
    [13] = { dist = 4.2, height = 0.85, targetH = 0.25, angle = 52.0 },
    [15] = { dist = 5.0, height = 0.65, targetH = 0.05, angle = 18.0 },
    [16] = { dist = 5.2, height = 1.05, targetH = 0.55, angle = 62.0 },
    [18] = { dist = 3.8, height = 1.05, targetH = 0.55, angle = 42.0 },
}

local PERF_CATEGORIES = {
    { modType = 11, id = 'engine', label = 'Variklis', statKeys = { 'acceleration', 'topSpeed' } },
    { modType = 12, id = 'brakes', label = 'Stabdžiai', statKeys = { 'braking' } },
    { modType = 13, id = 'transmission', label = 'Pavarų dėžė', statKeys = { 'acceleration', 'handling' } },
    { modType = 15, id = 'suspension', label = 'Pakaba', statKeys = { 'handling', 'traction' } },
    { modType = 16, id = 'armor', label = 'Šarvai', statKeys = { 'braking' } },
    { modType = 18, id = 'turbo', label = 'Turbo', statKeys = { 'acceleration', 'topSpeed' }, isToggle = true },
}

local STAT_LABELS = {
    acceleration = 'Pagreitis',
    topSpeed = 'Max. greitis',
    braking = 'Stabdymas',
    handling = 'Valdymas',
    traction = 'Trauka',
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

local function getBayVehicle()
    local bay = perfBayIndex and Config.RepairBays and Config.RepairBays[perfBayIndex]
    if not bay then return 0 end
    return getVehicleInBay(bay)
end

local function ensureModKit(veh)
    if veh == 0 then return end
    SetVehicleModKit(veh, 0)
end

local function requiredItemForLevel(modType, idx)
    modType = tonumber(modType)
    idx = tonumber(idx)
    if idx == nil or idx < 0 then return nil end
    local tiered = Config.TuningUpgradeItems and Config.TuningUpgradeItems[modType]
    if tiered then
        if tiered.item then return tiered.item end
        if tiered.prefix and tiered.maxLevel then
            local lvl = idx + 1
            if lvl >= 1 and lvl <= tiered.maxLevel then
                return ('%s_%d'):format(tiered.prefix, lvl)
            end
        end
    end
    local legacy = { [11] = 'engine_kit', [12] = 'brakes_kit', [13] = 'transmission_kit', [15] = 'suspension_kit', [16] = 'armor_kit' }
    if legacy[modType] then return legacy[modType] end
    if modType == 18 then return 'turbo_kit' end
    return nil
end

local function relativeStatScore(level, maxLevel)
    maxLevel = math.max(1, tonumber(maxLevel) or 1)
    level = tonumber(level)
    if level == nil or level < 0 then return 38 end
    return math.floor(38 + ((level + 1) / maxLevel) * 62 + 0.5)
end

local function buildStatsForLevel(modType, level, maxLevel)
    local score = relativeStatScore(level, maxLevel)
    local cat = nil
    for _, c in ipairs(PERF_CATEGORIES) do
        if c.modType == modType then cat = c break end
    end
    local keys = cat and cat.statKeys or { 'acceleration' }
    local out = {}
    for _, k in ipairs(keys) do
        out[k] = score
    end
    return out
end

local function destroyPerfCam()
    if perfCam and DoesCamExist(perfCam) then
        RenderScriptCams(false, true, 350, true, true)
        DestroyCam(perfCam, false)
    end
    perfCam = nil
end

local function updatePerfCam()
    if not perfUiVeh or not DoesEntityExist(perfUiVeh) or not perfCam or not DoesCamExist(perfCam) then return end
    local vc = GetEntityCoords(perfUiVeh)
    local rad = math.rad(camAngle)
    local cx = vc.x + math.cos(rad) * camDist
    local cy = vc.y + math.sin(rad) * camDist
    local cz = vc.z + camHeight
    SetCamCoord(perfCam, cx, cy, cz)
    PointCamAtCoord(perfCam, vc.x, vc.y, vc.z + camTargetHeight)
end

local function createPerfCam()
    destroyPerfCam()
    if not perfUiVeh or not DoesEntityExist(perfUiVeh) then return end
    perfCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(perfCam, 48.0)
    updatePerfCam()
    SetCamActive(perfCam, true)
    RenderScriptCams(true, true, 450, true, true)
end

local function applyCamPreset(modType)
    local p = CAM_PRESETS[modType] or { dist = 5.5, height = 1.15, targetH = 0.35, angle = 45.0 }
    camPresetDist = p.dist
    camPresetHeight = p.height
    camPresetTargetH = p.targetH
    camPresetAngle = p.angle
    camDist = p.dist
    camHeight = p.height
    camTargetHeight = p.targetH
    camAngle = p.angle
    updatePerfCam()
end

local function restoreVehicleState()
    if perfUiVeh and DoesEntityExist(perfUiVeh) then
        FreezeEntityPosition(perfUiVeh, vehWasFrozen)
        SetVehicleEngineOn(perfUiVeh, vehEngineWasOn, true, false)
    end
    vehWasFrozen = false
    vehEngineWasOn = false
end

local function closePerformanceUi()
    if not perfUiOpen then return end
    perfUiOpen = false
    destroyPerfCam()
    restoreVehicleState()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closePerformanceUI' })
    perfUiVeh = nil
    perfBayIndex = nil
    perfPlate = nil
end

local function buildCategoryPayload(veh, inventory, labels)
    ensureModKit(veh)
    local categories = {}
    for _, cat in ipairs(PERF_CATEGORIES) do
        local modType = cat.modType
        local tiered = Config.TuningUpgradeItems and Config.TuningUpgradeItems[modType]
        local maxLevel = tiered and tiered.maxLevel or GetNumVehicleMods(veh, modType)
        if cat.isToggle then
            maxLevel = 1
        elseif maxLevel <= 0 then
            goto continue
        end

        local installedLevel = -1
        if cat.isToggle then
            installedLevel = IsToggleModOn(veh, 18) and 0 or -1
        else
            installedLevel = GetVehicleMod(veh, modType)
        end

        local parts = {}
        if cat.isToggle then
            local itemName = 'turbo_kit'
            local meta = labels[itemName] or {}
            parts[#parts + 1] = {
                idx = 0,
                level = 1,
                itemName = itemName,
                label = meta.label or 'Turbo',
                image = meta.image or 'veh_turbo.png',
                inventoryCount = inventory[itemName] or 0,
                installed = installedLevel >= 0,
            }
        else
            for idx = 0, maxLevel - 1 do
                local itemName = requiredItemForLevel(modType, idx)
                local meta = itemName and (labels[itemName] or {}) or {}
                local lvl = idx + 1
                parts[#parts + 1] = {
                    idx = idx,
                    level = lvl,
                    itemName = itemName,
                    label = meta.label or ('Lygis %d'):format(lvl),
                    image = meta.image or 'box.png',
                    inventoryCount = itemName and (inventory[itemName] or 0) or 0,
                    installed = installedLevel == idx,
                }
            end
            parts[#parts + 1] = {
                idx = -1,
                level = 0,
                itemName = nil,
                label = 'Gamyklinis',
                image = 'box.png',
                inventoryCount = -1,
                installed = installedLevel < 0,
            }
        end

        categories[#categories + 1] = {
            id = cat.id,
            modType = modType,
            label = cat.label,
            isToggle = cat.isToggle == true,
            installedLevel = installedLevel,
            maxLevel = maxLevel,
            statKeys = cat.statKeys,
            hasInventory = (function()
                for _, p in ipairs(parts) do
                    if p.itemName and (inventory[p.itemName] or 0) > 0 then return true end
                end
                return false
            end)(),
            parts = parts,
            currentStats = buildStatsForLevel(modType, installedLevel, maxLevel),
        }
        ::continue::
    end
    return categories
end

local function openPerformanceUi(bayIndex, veh, plate, uiData)
    perfUiOpen = true
    perfUiVeh = veh
    perfBayIndex = bayIndex
    perfPlate = plate

    if DoesEntityExist(veh) then
        vehWasFrozen = IsEntityPositionFrozen(veh)
        vehEngineWasOn = GetIsVehicleEngineRunning(veh)
        FreezeEntityPosition(veh, true)
        SetVehicleEngineOn(veh, false, true, true)
    end

    camAngle = 45.0
    camDist = 5.5
    camHeight = 1.15
    camTargetHeight = 0.35
    createPerfCam()

    local model = GetEntityModel(veh)
    local displayName = GetLabelText(GetDisplayNameFromVehicleModel(model))
    if not displayName or displayName == 'NULL' then
        displayName = GetDisplayNameFromVehicleModel(model)
    end

    local categories = buildCategoryPayload(veh, uiData.inventory or {}, uiData.labels or {})

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openPerformanceUI',
        vehicle = {
            networkId = NetworkGetNetworkIdFromEntity(veh),
            model = displayName,
            plate = plate,
        },
        categories = categories,
        statLabels = STAT_LABELS,
        bayIndex = bayIndex,
    })
end

RegisterNetEvent('mrp_mechanic:client:openPerformanceWorkshop', function(data)
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    if perfUiOpen then return end

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

    QBCore.Functions.TriggerCallback('mrp_mechanic:server:getPerformanceUiData', function(uiData)
        if not uiData then
            return QBCore.Functions.Notify('Nepavyko gauti inventoriaus duomenų.', 'error')
        end
        openPerformanceUi(bayIndex, veh, plate, uiData)
    end, bayIndex)
end)

local function runInstallProgress(label, onDone)
    local ped = PlayerPedId()
    QBCore.Functions.Progressbar('mrp_mech_perf_install', label or 'Montuojama…', 6500, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableCombat = true,
    }, {
        animDict = 'mini@repair',
        anim = 'fixing_a_player',
        flags = 49,
    }, {}, {}, function()
        if onDone then onDone(true) end
    end, function()
        ClearPedTasks(ped)
        if onDone then onDone(false) end
    end)
end

local function applyPerformanceMod(veh, modType, idx, isToggle)
    ensureModKit(veh)
    modType = tonumber(modType)
    idx = tonumber(idx)
    if isToggle then
        ToggleVehicleMod(veh, 18, true)
        return
    end
    if idx == nil then return end
    if idx < 0 then
        SetVehicleMod(veh, modType, -1, false)
    else
        SetVehicleMod(veh, modType, idx, false)
    end
end

local function performInstall(modType, idx, itemName, isToggle, partLabel)
    local veh = getBayVehicle()
    if veh == 0 or not perfBayIndex then
        return QBCore.Functions.Notify('Transportas nebėra zonoje.', 'error')
    end
    local plateNow = QBCore.Functions.GetPlate(veh)
    if plateNow ~= perfPlate then
        return QBCore.Functions.Notify('Kita mašina zonoje.', 'error')
    end

    local savedBay = perfBayIndex
    local savedPlate = perfPlate
    closePerformanceUi()

    local targetLevel = isToggle and 0 or idx
    QBCore.Functions.TriggerCallback('mrp_mechanic:server:canInstallUpgrade', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.reason) or 'Negalima montuoti.', 'error')
        end
        runInstallProgress(('Montuojama: %s'):format(partLabel or 'detalė'), function(ok)
            if not ok then
                return QBCore.Functions.Notify('Montavimas atšauktas.', 'error')
            end
            local v = getBayVehicle()
            if v == 0 then
                -- getBayVehicle uses perfBayIndex which was cleared — use saved bay
                local bay = savedBay and Config.RepairBays and Config.RepairBays[savedBay]
                v = bay and getVehicleInBay(bay) or 0
            end
            if v == 0 then
                return QBCore.Functions.Notify('Transportas dingo montavimo metu.', 'error')
            end
            local plateNow = QBCore.Functions.GetPlate(v)
            if plateNow ~= savedPlate then
                return QBCore.Functions.Notify('Kita mašina zonoje.', 'error')
            end
            applyPerformanceMod(v, modType, idx, isToggle)
            if res.requiredItem then
                TriggerServerEvent('mrp_mechanic:server:consumeUpgradeItem', res.requiredItem)
            end
            QBCore.Functions.Notify(('Sumontuota: %s'):format(partLabel or 'detalė'), 'success')
        end)
    end, modType, targetLevel, savedBay)
end

RegisterNUICallback('perfClose', function(_, cb)
    closePerformanceUi()
    cb('ok')
end)

RegisterNUICallback('perfSelectCategory', function(data, cb)
    local modType = tonumber(data and data.modType)
    if modType then applyCamPreset(modType) end
    cb('ok')
end)

RegisterNUICallback('perfCameraOrbit', function(data, cb)
    camAngle = camAngle + (tonumber(data and data.deltaX) or 0) * 0.35
    camHeight = math.max(0.15, math.min(2.8, camHeight - (tonumber(data and data.deltaY) or 0) * 0.012))
    updatePerfCam()
    cb('ok')
end)

RegisterNUICallback('perfCameraZoom', function(data, cb)
    local delta = tonumber(data and data.delta) or 0
    camDist = math.max(2.2, math.min(9.5, camDist + delta * 0.35))
    updatePerfCam()
    cb('ok')
end)

RegisterNUICallback('perfCameraReset', function(_, cb)
    camAngle = camPresetAngle
    camDist = camPresetDist
    camHeight = camPresetHeight
    camTargetHeight = camPresetTargetH
    updatePerfCam()
    cb('ok')
end)

RegisterNUICallback('perfInstallPart', function(data, cb)
    local modType = tonumber(data and data.modType)
    local idx = tonumber(data and data.idx)
    local itemName = data and data.itemName
    local isToggle = data and data.isToggle == true
    local label = data and data.label or 'Detalė'
    if not modType then return cb('ok') end

    if isToggle then
        performInstall(modType, 0, itemName, true, label)
    elseif idx == -1 then
        performInstall(modType, -1, nil, false, 'Gamyklinis variantas')
    else
        performInstall(modType, idx, itemName, false, label)
    end
    cb('ok')
end)

RegisterNUICallback('perfSave', function(_, cb)
    local vNow = getBayVehicle()
    if vNow == 0 then
        QBCore.Functions.Notify('Remonto zonoje nebėra transporto.', 'error')
        return cb('ok')
    end
    local plateNow = QBCore.Functions.GetPlate(vNow)
    if not plateNow or plateNow ~= perfPlate then
        QBCore.Functions.Notify('Kita mašina zonoje.', 'error')
        return cb('ok')
    end
    ensureModKit(vNow)
    local props = QBCore.Functions.GetVehicleProperties(vNow)
    if props then props.plate = perfPlate end
    TriggerServerEvent('mrp_mechanic:server:saveBayVehicleTune', perfBayIndex, props)
    QBCore.Functions.Notify('Modifikacijos išsaugotos duomenų bazėje.', 'success')
    closePerformanceUi()
    cb('ok')
end)

CreateThread(function()
    while true do
        if perfUiOpen and perfUiVeh and DoesEntityExist(perfUiVeh) then
            FreezeEntityPosition(perfUiVeh, true)
            DisableControlAction(0, 71, true)
            DisableControlAction(0, 72, true)
            DisableControlAction(0, 63, true)
            DisableControlAction(0, 64, true)
            DisableControlAction(0, 75, true)
            updatePerfCam()
            Wait(0)
        else
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        if perfUiOpen then
            Wait(500)
            local veh = getBayVehicle()
            if veh == 0 or not DoesEntityExist(perfUiVeh) then
                closePerformanceUi()
                QBCore.Functions.Notify('Performance UI uždarytas — transportas nebepasiekiamas.', 'error')
            else
                local ped = PlayerPedId()
                local pCoords = GetEntityCoords(ped)
                local vCoords = GetEntityCoords(veh)
                if #(pCoords - vCoords) > 18.0 or IsEntityDead(ped) then
                    closePerformanceUi()
                end
            end
        else
            Wait(1200)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if perfUiOpen then closePerformanceUi() end
end)
