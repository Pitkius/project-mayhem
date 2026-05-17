local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local seatbeltOn = false
local hudPreset = 1
local HUD_PRESET_COUNT = 3
local hudMenuOpen = false

local COLOR_THEMES = {
    cyan = { fill = '#22d3ee', glow = 'rgba(34,211,238,0.5)' },
    violet = { fill = '#a78bfa', glow = 'rgba(167,139,250,0.5)' },
    red = { fill = '#f87171', glow = 'rgba(248,113,113,0.5)' },
    green = { fill = '#4ade80', glow = 'rgba(74,222,128,0.5)' },
    amber = { fill = '#fbbf24', glow = 'rgba(251,191,36,0.5)' },
}

--- Kvadratinių vitalų spalvos pagal temą (NUI `--tile-*`).
local TILE_COLORS = {
    violet = { health = '#f43f5e', armor = '#a78bfa', hunger = '#fb923c', thirst = '#38bdf8', stamina = '#e879f9' },
    cyan = { health = '#fb7185', armor = '#22d3ee', hunger = '#fdba74', thirst = '#67e8f9', stamina = '#a5f3fc' },
    red = { health = '#fca5a5', armor = '#c084fc', hunger = '#fdba74', thirst = '#7dd3fc', stamina = '#f9a8d4' },
    green = { health = '#f87171', armor = '#86efac', hunger = '#fcd34d', thirst = '#6ee7b7', stamina = '#bbf7d0' },
    amber = { health = '#ef4444', armor = '#d8b4fe', hunger = '#fbbf24', thirst = '#38bdf8', stamina = '#fbcfe8' },
}

--- Transporto valdymo panelė (NUI) – iOS stiliaus violetinis akcentas.
local VEHICLE_PANEL_ACCENT = '#a78bfa'

local vehiclePanelOpen = false
local interiorLightByNetId = {}
local listMenuOpen = false
local listMenuVeh = 0
local lockStateByPlate = {}
local engineStartBusy = false
local displayStamina = 100.0
local hazardEnabled = false
--- Langų būsena transporto panelei (RollDown / RollUp)
local vehicleWindowDown = {}

local function deepCopy(tbl)
    local out = {}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then out[k] = deepCopy(v) else out[k] = v end
    end
    return out
end

local DEFAULT_PRESET = {
    --- Vertikalūs kvadratai (refs. nuotr.) – kairėje virš mini-map
    style = 'tiles',
    color = 'violet',
    alpha = 0.55,
    show = {
        health = true,
        armor = true,
        stamina = true,
        hunger = true,
        thirst = true,
        speed = false,
        fuel = false,
        seatbelt = false
    }
}

local presetSettings = {}

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

--- QB dažnai atnaujina `metadata` per `QBCore:Player:UpdatePlayerDataField`, ne per pilną `SetPlayerData` — todėl visada skaitom iš `GetPlayerData()`.
local function getNeeds()
    local pd = QBCore.Functions.GetPlayerData() or {}
    local metadata = pd.metadata or {}
    local hunger = tonumber(metadata.hunger)
    local thirst = tonumber(metadata.thirst)
    if hunger == nil then hunger = 100 end
    if thirst == nil then thirst = 100 end
    return clamp(hunger, 0, 100), clamp(thirst, 0, 100)
end

local function loadPresetSettings()
    for i = 1, HUD_PRESET_COUNT do
        local raw = GetResourceKvpString(('fivempro_hud:preset:%s'):format(i))
        if raw and raw ~= '' then
            local ok, decoded = pcall(json.decode, raw)
            if ok and type(decoded) == 'table' and type(decoded.show) == 'table' then
                local p = deepCopy(DEFAULT_PRESET)
                p.style = tostring(decoded.style or p.style)
                p.color = tostring(decoded.color or p.color)
                p.alpha = tonumber(decoded.alpha) or p.alpha
                for k, v in pairs(p.show) do
                    p.show[k] = decoded.show[k] == nil and v or (decoded.show[k] == true)
                end
                presetSettings[i] = p
            else
                presetSettings[i] = deepCopy(DEFAULT_PRESET)
            end
        else
            presetSettings[i] = deepCopy(DEFAULT_PRESET)
        end
    end
end

local function savePresetSettings(idx)
    local p = presetSettings[idx]
    if not p then return end
    SetResourceKvp(('fivempro_hud:preset:%s'):format(idx), json.encode(p))
end

local function currentSettings()
    return presetSettings[hudPreset] or DEFAULT_PRESET
end

--- qb-smallresources turi tikrą diržą; kitaip – vietinis `fivempro_seatbelt`.
local function seatbeltDisplayActive()
    if GetResourceState('qb-smallresources') == 'started' then
        local ok, r = pcall(function()
            return exports['qb-smallresources']:HasSeatbeltOn()
        end)
        if ok and r then return true end
        if ok and r == false then return false end
    end
    return seatbeltOn
end

AddEventHandler('seatbelt:client:ToggleSeatbelt', function(state)
    seatbeltOn = state == true
end)

CreateThread(function()
    while true do
        Wait(180)
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then
            Wait(500)
            goto belt_wait_cont
        end
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            local cls = GetVehicleClass(veh)
            local exempt = cls == 8 or cls == 13 or cls == 14 --- dviračiai / valtys etc.
            if exempt then
                SetPedCanFlyThroughWindscreen(ped, false)
            else
                local belt = seatbeltDisplayActive()
                --- Su diržu – neproti pro priekį (mažiau smūgio žalos be išmetimo iš QB logikos).
                SetPedCanFlyThroughWindscreen(ped, not belt)
            end
        end
        ::belt_wait_cont::
    end
end)

local function sendHudTheme()
    local s = currentSettings()
    local c = COLOR_THEMES[s.color] or COLOR_THEMES.violet
    local tiles = TILE_COLORS[s.color] or TILE_COLORS.violet
    SendNUIMessage({
        action = 'theme',
        preset = hudPreset,
        style = s.style,
        alpha = s.alpha,
        color = s.color,
        fillColor = c.fill,
        glowColor = c.glow,
        show = s.show,
        tileColors = tiles,
        vehicleUiAccent = VEHICLE_PANEL_ACCENT,
    })
end

local function pushHud()
    local ped = PlayerPedId()
    local health = clamp(GetEntityHealth(ped) - 100, 0, 100)
    local armor = clamp(GetPedArmour(ped), 0, 100)
    local hunger, thirst = getNeeds()
    local show = not IsPauseMenuActive()
    local inVehicle = IsPedInAnyVehicle(ped, false)
    local speed, fuel = 0, 0

    local rpmPct = 0
    local engineTemp = 0
    local veh = 0
    local engineOn = false
    local doorsLocked = true
    local lightsOn = false
    local engineHealth = 1000.0
    if inVehicle then
        veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then
            inVehicle = false
        else
            speed = clamp(math.floor(GetEntitySpeed(veh) * 3.6 + 0.5), 0, 450)
            fuel = clamp(math.floor(GetVehicleFuelLevel(veh) + 0.5), 0, 100)
            local rpm = GetVehicleCurrentRpm(veh)
            rpmPct = clamp(math.floor((rpm or 0.0) * 100.0 + 0.5), 0, 100)
            local eh = GetVehicleEngineHealth(veh) or 1000.0
            engineHealth = eh
            engineTemp = clamp(math.floor((eh / 1000.0) * 42.0 + 58.0 + 0.5), 55, 115)
            engineOn = GetIsVehicleEngineRunning(veh)
            local st = GetVehicleDoorLockStatus(veh)
            doorsLocked = st == 2 or st == 3 or st == 4
            local _, lo = GetVehicleLightsState(veh)
            lightsOn = lo == true or lo == 1
        end
    else
        seatbeltOn = false
        if hazardEnabled then
            hazardEnabled = false
        end
        if listMenuOpen then
            listMenuOpen = false
            listMenuVeh = 0
            if not hudMenuOpen and not vehiclePanelOpen then
                SetNuiFocus(false, false)
            end
            SendNUIMessage({ action = 'vehicleList', open = false })
        end
    end

    local rawStam = GetPlayerSprintStaminaRemaining(PlayerId())
    if type(rawStam) ~= 'number' then rawStam = 0.0 end
    if rawStam >= 0.0 and rawStam <= 1.0 then
        rawStam = rawStam * 100.0
    end
    rawStam = clamp(rawStam, 0.0, 100.0)
    local staminaRemaining = 100.0 - rawStam
    displayStamina = displayStamina + (staminaRemaining - displayStamina) * 0.14
    local staminaSmooth = clamp(math.floor(displayStamina + 0.5), 0, 100)

    local s = currentSettings()
    SendNUIMessage({
        action = 'update',
        show = show,
        hudPreset = hudPreset,
        health = health,
        armor = armor,
        stamina = staminaSmooth,
        hunger = hunger,
        thirst = thirst,
        inVehicle = inVehicle,
        speed = speed,
        fuel = fuel,
        seatbelt = seatbeltDisplayActive(),
        rpm = rpmPct,
        engineTemp = engineTemp,
        engineOn = engineOn,
        doorsLocked = doorsLocked,
        lightsOn = lightsOn,
        engineHealth = engineHealth,
        settings = s
    })
end

local function saveHudPreset()
    SetResourceKvpInt('fivempro_hud:preset', hudPreset)
end

local function setHudPreset(newPreset)
    local p = tonumber(newPreset) or 1
    p = math.floor(p)
    if p < 1 then p = HUD_PRESET_COUNT end
    if p > HUD_PRESET_COUNT then p = 1 end
    hudPreset = p
    saveHudPreset()
    sendHudTheme()
    QBCore.Functions.Notify(('HUD stilius: %s/%s'):format(hudPreset, HUD_PRESET_COUNT), 'primary')
end

local function openHudMenu()
    if listMenuOpen then
        listMenuOpen = false
        listMenuVeh = 0
        SendNUIMessage({ action = 'vehicleList', open = false })
    end
    hudMenuOpen = true
    SetNuiFocus(true, true)
    local payload = {
        action = 'openMenu',
        activePreset = hudPreset,
        presets = presetSettings,
        presetCount = HUD_PRESET_COUNT,
    }
    SendNUIMessage(payload)
end

local function closeHudMenu()
    hudMenuOpen = false
    listMenuOpen = false
    listMenuVeh = 0
    SendNUIMessage({ action = 'vehicleList', open = false })
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMenu' })
end

local function syncPlayerDataFromCore()
    PlayerData = QBCore.Functions.GetPlayerData() or {}
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    syncPlayerDataFromCore()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val or QBCore.Functions.GetPlayerData() or {}
end)

RegisterNetEvent('QBCore:Player:UpdatePlayerDataField', function(_, _)
    syncPlayerDataFromCore()
end)

--- QB / consumables / fivempro_basics siunčia po `hunger`/`thirst` pakeitimo (nebūtina klausytis argumentų – imam iš `GetPlayerData`).
RegisterNetEvent('hud:client:UpdateNeeds', function()
    syncPlayerDataFromCore()
    pushHud()
end)

RegisterCommand('fivempro_seatbelt', function()
    if GetResourceState('qb-smallresources') == 'started' then
        ExecuteCommand('toggleseatbelt')
        return
    end
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    seatbeltOn = not seatbeltOn
    local msg = seatbeltOn and 'Dirzas: ijungtas' or 'Dirzas: isjungtas'
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end, false)

RegisterCommand('hud', function(_, args)
    local arg = args and args[1] and tostring(args[1]) or ''
    if arg == '+' then
        setHudPreset(hudPreset + 1)
        return
    end
    if arg == '-' then
        setHudPreset(hudPreset - 1)
        return
    end
    local asNum = tonumber(arg)
    if asNum then
        setHudPreset(asNum)
        return
    end
    openHudMenu()
end, false)

RegisterNUICallback('hud:close', function(_, cb)
    closeHudMenu()
    cb({ ok = true })
end)

RegisterNUICallback('hud:applyPreset', function(data, cb)
    local idx = tonumber(data and data.preset) or 1
    setHudPreset(idx)
    cb({ ok = true })
end)

RegisterNUICallback('hud:savePreset', function(data, cb)
    local idx = tonumber(data and data.preset) or hudPreset
    idx = math.max(1, math.min(HUD_PRESET_COUNT, idx))
    local p = presetSettings[idx] or deepCopy(DEFAULT_PRESET)
    p.style = tostring(data and data.style or p.style)
    p.color = tostring(data and data.color or p.color)
    p.alpha = clamp(tonumber(data and data.alpha) or p.alpha, 0.2, 1.0)
    p.show = p.show or deepCopy(DEFAULT_PRESET.show)
    local show = data and data.show or {}
    for k, defaultValue in pairs(DEFAULT_PRESET.show) do
        if show[k] ~= nil then
            p.show[k] = show[k] == true
        elseif p.show[k] == nil then
            p.show[k] = defaultValue
        end
    end
    presetSettings[idx] = p
    savePresetSettings(idx)
    if idx == hudPreset then
        sendHudTheme()
    end
    cb({ ok = true })
end)

local function clearHazardLights(veh)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        SetVehicleIndicatorLights(veh, 0, false)
        SetVehicleIndicatorLights(veh, 1, false)
    end
end

local function closeVehiclePanel()
    if not vehiclePanelOpen then return end
    vehiclePanelOpen = false
    if not hudMenuOpen and not listMenuOpen then
        SetNuiFocus(false, false)
    end
    SendNUIMessage({ action = 'vehiclePanel', open = false })
end

local function vehicleWeatherLabel()
    local rain = 0.0
    if GetRainLevel then rain = GetRainLevel() end
    if rain > 0.12 then return 'RAIN' end
    return 'CLEAR'
end

local function pushVehiclePanelState()
    if not vehiclePanelOpen then return end
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        closeVehiclePanel()
        return
    end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        closeVehiclePanel()
        return
    end

    local lockSt = GetVehicleDoorLockStatus(veh)
    local locked = lockSt == 2 or lockSt == 3 or lockSt == 4

    local doorList = {}
    for i = 0, 5 do
        local r = GetVehicleDoorAngleRatio(veh, i) or 0.0
        doorList[#doorList + 1] = { idx = i, open = r > 0.12 }
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    local interiorOn = interiorLightByNetId[netId] == true

    local engineOn = GetIsVehicleEngineRunning(veh)
    local eh = GetVehicleEngineHealth(veh) or 1000.0
    local engineTemp = clamp(math.floor((eh / 1000.0) * 42.0 + 58.0 + 0.5), 55, 115)

    local lightsOn = false
    local highBeams = false
    local _, lo, hi = GetVehicleLightsState(veh)
    lightsOn = lo == true or lo == 1
    highBeams = hi == true or hi == 1

    local cx, cy, cz = table.unpack(GetEntityCoords(veh))
    local sh1 = GetStreetNameAtCoord(cx, cy, cz)
    local streetName = GetStreetNameFromHashKey(sh1 or 0)

    local waypointM = nil
    local bl = GetFirstBlipInfoId(8)
    if bl ~= 0 and DoesBlipExist(bl) then
        local bc = GetBlipInfoIdCoord(bl)
        if bc then
            waypointM = math.floor(#(vector3(cx, cy, cz) - vector3(bc.x, bc.y, bc.z)) + 0.5)
        end
    end

    local fuel = clamp(math.floor(GetVehicleFuelLevel(veh) + 0.5), 0, 100)
    local vehModel = GetEntityModel(veh)
    local dispHash = GetDisplayNameFromVehicleModel(vehModel)
    local vehLabel = dispHash and dispHash ~= '' and GetLabelText(dispHash) or 'Vehicle'
    if vehLabel == 'NULL' or vehLabel == '' then vehLabel = 'Vehicle' end
    local plate = (QBCore.Functions.GetPlate(veh) or GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
    local motorPct = clamp(math.floor((eh / 1000.0) * 100.0 + 0.5), 0, 100)

    SendNUIMessage({
        action = 'vehiclePanel',
        open = true,
        locked = locked,
        doors = doorList,
        engineOn = engineOn,
        weather = vehicleWeatherLabel(),
        street = streetName,
        waypointM = waypointM,
        engineTemp = engineTemp,
        hazard = hazardEnabled,
        interiorLight = interiorOn,
        headlightsOn = lightsOn,
        highBeams = highBeams,
        fuel = fuel,
        motorPct = motorPct,
        vehicleName = vehLabel,
        plate = plate,
        timeStr = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
    })
end

local function openVehiclePanel()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        QBCore.Functions.Notify('Transporto panelė: turi būti automobilyje.', 'error')
        return
    end
    if listMenuOpen then
        listMenuOpen = false
        listMenuVeh = 0
        SendNUIMessage({ action = 'vehicleList', open = false })
    end
    vehiclePanelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'vehiclePanel', open = true })
    pushVehiclePanelState()
end

local function toggleVehiclePanel()
    if vehiclePanelOpen then
        closeVehiclePanel()
    else
        openVehiclePanel()
    end
end

RegisterCommand('fivempro_vehicle_hud', function()
    toggleVehiclePanel()
end, false)

RegisterKeyMapping('fivempro_vehicle_hud', 'Fivempro: transporto valdymo panelė', 'keyboard', 'U')

RegisterNUICallback('vehiclePanel:action', function(data, cb)
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        cb({ ok = false })
        return
    end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        cb({ ok = false })
        return
    end

    local action = data and data.action or ''
    if action == 'close' then
        closeVehiclePanel()
    elseif action == 'lock' then
        local st = GetVehicleDoorLockStatus(veh)
        if st == 2 or st == 3 or st == 4 then
            SetVehicleDoorsLocked(veh, 1)
        else
            SetVehicleDoorsLocked(veh, 2)
        end
    elseif action == 'engine' then
        local running = GetIsVehicleEngineRunning(veh)
        SetVehicleEngineOn(veh, not running, false, true)
    elseif action == 'lights' then
        local _, lo = GetVehicleLightsState(veh)
        local on = lo == true or lo == 1
        if on then
            SetVehicleLights(veh, 1)
        else
            SetVehicleLights(veh, 2)
        end
    elseif action == 'interior' then
        local nid = NetworkGetNetworkIdFromEntity(veh)
        local on = interiorLightByNetId[nid] == true
        interiorLightByNetId[nid] = not on
        pcall(SetVehicleInteriorlight, veh, not on)
    elseif action == 'hazard' then
        hazardEnabled = not hazardEnabled
        if not hazardEnabled then
            clearHazardLights(veh)
        end
    elseif action == 'door' then
        local idx = tonumber(data.doorIndex)
        if idx == nil or idx < 0 or idx > 5 then
            cb({ ok = false })
            return
        end
        local r = GetVehicleDoorAngleRatio(veh, idx) or 0.0
        if r > 0.12 then
            SetVehicleDoorShut(veh, idx, false)
        else
            SetVehicleDoorOpen(veh, idx, false, false)
        end
    elseif action == 'window' then
        local win = tonumber(data.windowIndex)
        if win == nil or win < 0 or win > 7 then
            cb({ ok = false })
            return
        end
        local nid = NetworkGetNetworkIdFromEntity(veh)
        local key = ('%s:%s'):format(nid, win)
        local down = vehicleWindowDown[key] == true
        vehicleWindowDown[key] = not down
        if vehicleWindowDown[key] then
            pcall(RollDownWindow, veh, win)
        else
            pcall(RollUpWindow, veh, win)
        end
    elseif action == 'seat' then
        TaskShuffleToNextVehicleSeat(ped)
    elseif action == 'keys' then
        QBCore.Functions.Notify('Raktai: naudok savo serverio raktų sistemą (QB vehiclekeys ir pan.).', 'primary', 4500)
    end

    if vehiclePanelOpen then
        pushVehiclePanelState()
    end
    cb({ ok = true })
end)

local function plateOfV(veh)
    return (QBCore.Functions.GetPlate(veh) or GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
end

local function isVehicleLocked(veh)
    local p = plateOfV(veh)
    if p ~= '' and lockStateByPlate[p] ~= nil then
        return lockStateByPlate[p]
    end
    local st = GetVehicleDoorLockStatus(veh)
    return st == 2 or st == 4
end

local function setVehicleLocked(veh, locked)
    local p = plateOfV(veh)
    if p ~= '' then lockStateByPlate[p] = locked and true or false end
    SetVehicleDoorsLocked(veh, locked and 2 or 1)
    SetVehicleDoorsLockedForAllPlayers(veh, locked and true or false)
    SetVehicleAlarm(veh, false)
    SetVehicleAlarmTimeLeft(veh, 0)
end

local function toggleVehicleLockMenu(veh)
    local nextLocked = not isVehicleLocked(veh)
    setVehicleLocked(veh, nextLocked)
    QBCore.Functions.Notify(nextLocked and 'Transportas užrakintas.' or 'Transportas atrakintas.', 'primary')
end

local function toggleVehicleDoorMenu(veh, doorIdx, label)
    local ratio = GetVehicleDoorAngleRatio(veh, doorIdx)
    if ratio > 0.05 then
        SetVehicleDoorShut(veh, doorIdx, false)
        QBCore.Functions.Notify(label .. ' uždaryta.', 'primary')
    else
        SetVehicleDoorOpen(veh, doorIdx, false, false)
        QBCore.Functions.Notify(label .. ' atidaryta.', 'primary')
    end
end

local function tryToggleEngineMenu(veh)
    if engineStartBusy then return end
    local on = GetIsVehicleEngineRunning(veh)
    if on then
        SetVehicleEngineOn(veh, false, true, true)
        QBCore.Functions.Notify('Variklis išjungtas.', 'primary')
        return
    end

    local hp = GetVehicleEngineHealth(veh)
    local delay = 350
    if hp < 700.0 then
        delay = delay + math.floor((700.0 - hp) * 2.2)
    end
    delay = math.min(delay, 3500)
    local failChance = 0.0
    if hp < 800.0 then
        failChance = math.min(0.85, (800.0 - hp) / 1000.0)
    end

    engineStartBusy = true
    QBCore.Functions.Notify('Bandoma užvesti...', 'primary')
    SetTimeout(delay, function()
        engineStartBusy = false
        if math.random() < failChance then
            SetVehicleEngineOn(veh, false, true, true)
            QBCore.Functions.Notify('Variklis neužsivedė. Pabandyk dar kartą.', 'error')
            return
        end
        SetVehicleEngineOn(veh, true, false, true)
        QBCore.Functions.Notify('Variklis užvestas.', 'success')
    end)
end

local function closeVehicleListMenu()
    if not listMenuOpen then return end
    listMenuOpen = false
    listMenuVeh = 0
    if not hudMenuOpen and not vehiclePanelOpen then
        SetNuiFocus(false, false)
    end
    SendNUIMessage({ action = 'vehicleList', open = false })
end

local function openVehicleQuickMenu(veh)
    if veh == 0 or not DoesEntityExist(veh) then return false end
    if GetPedInVehicleSeat(veh, -1) ~= PlayerPedId() then return false end
    if vehiclePanelOpen then
        vehiclePanelOpen = false
        SendNUIMessage({ action = 'vehiclePanel', open = false })
    end

    local doors = 4
    if type(GetNumberOfVehicleDoors) == 'function' then
        local ok, n = pcall(GetNumberOfVehicleDoors, veh)
        if ok and tonumber(n) then doors = tonumber(n) end
    end
    local plate = QBCore.Functions.GetPlate(veh) or 'N/A'
    local model = string.upper(GetDisplayNameFromVehicleModel(GetEntityModel(veh)) or 'AUTO')
    local title = ('%s [%s]'):format(model, plate)
    local sub = ('Durų skaičius: %s'):format(doors)

    local rows = {
        { id = 'lock', label = 'Užrakinti / atrakinti' },
        { id = 'engine', label = 'Variklis ON/OFF' },
        { id = 'door', doorIndex = 4, label = 'Kapotas' },
        { id = 'door', doorIndex = 5, label = 'Bagažinė' },
    }
    local maxDoor = math.max(1, math.min(4, doors))
    for i = 0, maxDoor - 1 do
        rows[#rows + 1] = { id = 'door', doorIndex = i, label = ('Durys #%s'):format(i + 1) }
    end
    rows[#rows + 1] = { id = 'close', label = 'Uždaryti' }

    listMenuVeh = veh
    listMenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'vehicleList',
        open = true,
        title = title,
        subtitle = sub,
        rows = rows,
    })
    return true
end

exports('OpenVehicleQuickMenu', openVehicleQuickMenu)
--- M klavišui: ta pati valdymo panelė kaip „U“ (vp-ios), ne šoninis quick list.
exports('ToggleVehicleControlPanel', toggleVehiclePanel)

RegisterNUICallback('vehicleList:action', function(data, cb)
    local action = data and data.action or ''
    if action == 'close' then
        closeVehicleListMenu()
        cb({ ok = true })
        return
    end

    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        closeVehicleListMenu()
        cb({ ok = false })
        return
    end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or veh ~= listMenuVeh or not listMenuOpen then
        closeVehicleListMenu()
        cb({ ok = false })
        return
    end

    if action == 'lock' then
        toggleVehicleLockMenu(veh)
    elseif action == 'engine' then
        tryToggleEngineMenu(veh)
    elseif action == 'door' then
        local idx = tonumber(data.doorIndex)
        if idx == nil or idx < 0 or idx > 5 then
            cb({ ok = false })
            return
        end
        local label = tostring(data and data.label or ('Durys #' .. tostring(idx + 1)))
        toggleVehicleDoorMenu(veh, idx, label)
    end

    cb({ ok = true })
end)

CreateThread(function()
    local blink = false
    while true do
        Wait(420)
        if hazardEnabled and IsPedInAnyVehicle(PlayerPedId(), false) then
            local v = GetVehiclePedIsIn(PlayerPedId(), false)
            if v ~= 0 then
                blink = not blink
                SetVehicleIndicatorLights(v, 0, blink)
                SetVehicleIndicatorLights(v, 1, blink)
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(vehiclePanelOpen and 160 or 650)
        if vehiclePanelOpen then
            pushVehiclePanelState()
        end
    end
end)

CreateThread(function()
    Wait(1000)
    PlayerData = QBCore.Functions.GetPlayerData()
    loadPresetSettings()
    hudPreset = GetResourceKvpInt('fivempro_hud:preset')
    if hudPreset < 1 or hudPreset > HUD_PRESET_COUNT then
        hudPreset = 1
    end
    sendHudTheme()

    while true do
        pushHud()
        Wait(700)
    end
end)

CreateThread(function()
    while true do
        if hudMenuOpen and (IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322)) then
            closeHudMenu()
        elseif vehiclePanelOpen and (IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322)) then
            closeVehiclePanel()
        elseif listMenuOpen and (IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322)) then
            closeVehicleListMenu()
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        -- Remove GTA default weapon/ammo HUD and keep only custom indicators.
        HideHudComponentThisFrame(2)
        HideHudComponentThisFrame(7)
        HideHudComponentThisFrame(9)
        HideHudComponentThisFrame(19)
        HideHudComponentThisFrame(20)
        HideHudComponentThisFrame(22)
        Wait(0)
    end
end)

-- Sveikatos / šarvų juostos po minimap scaleform — tipas 3 = paslėpti juostas, pats radaras lieka.
CreateThread(function()
    local minimap = RequestScaleformMovie("minimap")
    while not HasScaleformMovieLoaded(minimap) do
        Wait(0)
    end
    SetRadarBigmapEnabled(true, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)

    while true do
        BeginScaleformMovieMethod(minimap, "SETUP_HEALTH_ARMOUR")
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()
        Wait(0)
    end
end)

