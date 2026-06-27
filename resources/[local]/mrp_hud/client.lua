local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local seatbeltOn = false
local hudPreset = 1
local HUD_PRESET_COUNT = 3
local hudMenuOpen = false
local hudMenuProp = 0
local hudMenuAnimToken = 0

local HUD_MENU_TABLET_MODEL = `prop_cs_tablet`

local COLOR_THEMES = {
    cyan = { fill = '#22d3ee', glow = 'rgba(34,211,238,0.5)' },
    violet = { fill = '#a78bfa', glow = 'rgba(167,139,250,0.5)' },
    red = { fill = '#f87171', glow = 'rgba(248,113,113,0.5)' },
    green = { fill = '#4ade80', glow = 'rgba(74,222,128,0.5)' },
    amber = { fill = '#fbbf24', glow = 'rgba(251,191,36,0.5)' },
}

--- Kvadratinių vitalų spalvos pagal temą (NUI `--tile-*`).
local TILE_COLORS = {
    violet = { health = '#f43f5e', armor = '#a78bfa', hunger = '#fb923c', thirst = '#38bdf8', stamina = '#e879f9', voice = '#c4b5fd' },
    cyan = { health = '#fb7185', armor = '#22d3ee', hunger = '#fdba74', thirst = '#67e8f9', stamina = '#a5f3fc', voice = '#a5f3fc' },
    red = { health = '#fca5a5', armor = '#c084fc', hunger = '#fdba74', thirst = '#7dd3fc', stamina = '#f9a8d4', voice = '#e9d5ff' },
    green = { health = '#f87171', armor = '#86efac', hunger = '#fcd34d', thirst = '#6ee7b7', stamina = '#bbf7d0', voice = '#d9f99d' },
    amber = { health = '#ef4444', armor = '#d8b4fe', hunger = '#fbbf24', thirst = '#38bdf8', stamina = '#fbcfe8', voice = '#fde68a' },
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
--- Rida pagal numerius (metrai, client-side)
local vehicleMileageByPlate = {}
local mileageTrackVeh = 0
local mileageTrackPos = nil
local displaySpeedKmh = 0.0
local displayRpmPct = 0.0

local VEHICLE_CLASS_LT = {
    [0] = 'Kompaktinis',
    [1] = 'Sedanas',
    [2] = 'SUV',
    [3] = 'Kupė',
    [4] = 'Muscle automobilis',
    [5] = 'Sportinis',
    [6] = 'Sportinis',
    [7] = 'Super',
    [8] = 'Motociklas',
    [9] = 'Visureigis',
    [10] = 'Industrinis',
    [11] = 'Paslaugų transportas',
    [12] = 'Furgonas',
    [13] = 'Dviratis',
    [14] = 'Laivas',
    [15] = 'Helikopteris',
    [16] = 'Lėktuvas',
    [17] = 'Paslaugų',
    [18] = 'Skubios pagalbos',
    [19] = 'Karinis',
    [20] = 'Komercinis',
    [21] = 'Traukinys',
}

local function vehicleClassLabel(classId)
    return VEHICLE_CLASS_LT[tonumber(classId)] or 'Transportas'
end

local function getVehicleGearDisplay(veh)
    if veh == 0 or not DoesEntityExist(veh) then return 'N' end
    if not GetIsVehicleEngineRunning(veh) then return 'P' end

    local speedMs = GetEntitySpeed(veh)
    local gear = GetVehicleCurrentGear(veh) or 0

    if speedMs < 0.6 then
        if gear <= 0 then return 'N' end
    end

    local fwd = GetEntityForwardVector(veh)
    local vel = GetEntityVelocity(veh)
    local longitudinal = vel.x * fwd.x + vel.y * fwd.y + vel.z * fwd.z
    if longitudinal < -0.45 or (gear == 0 and speedMs > 0.45) then
        return 'R'
    end

    if gear <= 0 then return 'N' end
    return tostring(gear)
end

local function trackVehicleMileage(veh, plate)
    if veh == 0 or not plate or plate == '' then return end
    local pos = GetEntityCoords(veh)
    if mileageTrackVeh == veh and mileageTrackPos then
        local dist = #(pos - mileageTrackPos)
        if dist > 0.4 and dist < 400.0 then
            vehicleMileageByPlate[plate] = (vehicleMileageByPlate[plate] or 0.0) + dist
        end
    end
    mileageTrackVeh = veh
    mileageTrackPos = pos
end

local function getPlateMileageKm(plate)
    if not plate or plate == '' then return 0 end
    return math.floor((vehicleMileageByPlate[plate] or 0.0) / 1000.0 + 0.5)
end

local function toggleVehicleDoor(veh, idx)
    local r = GetVehicleDoorAngleRatio(veh, idx) or 0.0
    local open = r <= 0.12
    if open then
        SetVehicleDoorOpen(veh, idx, false, false)
    else
        SetVehicleDoorShut(veh, idx, false)
    end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    if netId and netId > 0 then
        TriggerServerEvent('mrp_hud:server:setVehicleDoor', netId, idx, open)
    end
end

local function deepCopy(tbl)
    local out = {}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then out[k] = deepCopy(v) else out[k] = v end
    end
    return out
end

local DEFAULT_PRESET = {
    --- Numatytasis: rutuliukai (žiedai) — violetinė tema
    style = 'dots',
    color = 'violet',
    alpha = 0.58,
    scale = 1.0,
    compact = false,
    anim = true,
    show = {
        health = true,
        armor = true,
        stamina = false,
        hunger = true,
        thirst = true,
        voice = true,
        speed = false,
        fuel = false,
        seatbelt = false
    }
}

local presetSettings = {}

--- GetVehicleLightsState grąžina: lightState (0/1/2), lightsOn, highbeamsOn — neimti antro return kaip lightsOn be pirmo.
local function areVehicleExteriorLightsOn(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local lightState, lightsOn, highbeamsOn = GetVehicleLightsState(veh)
    if lightsOn == true or lightsOn == 1 then return true end
    if highbeamsOn == true or highbeamsOn == 1 then return true end
    local st = tonumber(lightState)
    return st ~= nil and st > 0
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function getVehicleFuelPercent(veh)
    if not veh or veh == 0 then return 0 end
    if GetResourceState('mrp_fuel') == 'started' then
        local ok, fuel = pcall(function()
            return exports['mrp_fuel']:GetFuel(veh)
        end)
        if ok and fuel ~= nil then
            return clamp(math.floor(fuel + 0.5), 0, 100)
        end
    end
    return clamp(math.floor(GetVehicleFuelLevel(veh) + 0.5), 0, 100)
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

local function getVoiceHud()
    local talking = NetworkIsPlayerTalking(PlayerId())
    local level = 35
    if talking then
        level = 100
    elseif GetResourceState('pma-voice') == 'started' then
        local ok, prox = pcall(function()
            return LocalPlayer.state.proximity
        end)
        if ok and type(prox) == 'table' and prox.index then
            local idx = tonumber(prox.index) or 2
            if idx == 1 then level = 45
            elseif idx == 2 then level = 62
            elseif idx >= 3 then level = 88
            end
        end
    end
    return talking, clamp(level, 0, 100)
end

local function loadPresetSettings()
    for i = 1, HUD_PRESET_COUNT do
        local raw = GetResourceKvpString(('mrp_hud:preset:%s'):format(i))
        if raw and raw ~= '' then
            local ok, decoded = pcall(json.decode, raw)
            if ok and type(decoded) == 'table' and type(decoded.show) == 'table' then
                local p = deepCopy(DEFAULT_PRESET)
                p.style = tostring(decoded.style or p.style)
                p.color = tostring(decoded.color or p.color)
                p.alpha = tonumber(decoded.alpha) or p.alpha
                p.scale = clamp(tonumber(decoded.scale) or p.scale or 1.0, 0.75, 1.25)
                p.compact = decoded.compact == true
                p.anim = decoded.anim ~= false
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
    SetResourceKvp(('mrp_hud:preset:%s'):format(idx), json.encode(p))
end

--- NUI naudoja 1-based string raktus — kitaip `json.encode` gali tapti 0-based masyvu.
local function presetsForNui()
    local out = {}
    for i = 1, HUD_PRESET_COUNT do
        out[tostring(i)] = presetSettings[i] or deepCopy(DEFAULT_PRESET)
    end
    return out
end

local function currentSettings()
    return presetSettings[hudPreset] or DEFAULT_PRESET
end

--- qb-smallresources turi tikrą diržą; kitaip – vietinis `mrp_seatbelt`.
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
                SetPedConfigFlag(ped, 32, true)
            else
                local belt = seatbeltDisplayActive()
                --- CPED 32: true = negali išlėkti pro stiklą (diržas užsegtas).
                SetPedConfigFlag(ped, 32, belt == true)
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
        scale = s.scale or 1.0,
        compact = s.compact == true,
        anim = s.anim ~= false,
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
    local voiceTalking, voiceLevel = getVoiceHud()
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
    local gearLabel = 'N'
    local handbrake = false
    local indicators = 0
    local speedExact = 0.0
    if inVehicle then
        veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then
            inVehicle = false
        else
            speedExact = clamp(GetEntitySpeed(veh) * 3.6, 0.0, 450.0)
            local speedLerp = 0.32
            displaySpeedKmh = displaySpeedKmh + (speedExact - displaySpeedKmh) * speedLerp
            speed = clamp(math.floor(displaySpeedKmh + 0.5), 0, 450)
            fuel = getVehicleFuelPercent(veh)
            local rpm = GetVehicleCurrentRpm(veh) or 0.0
            local rpmTarget = clamp((rpm or 0.0) * 100.0, 0.0, 100.0)
            displayRpmPct = displayRpmPct + (rpmTarget - displayRpmPct) * speedLerp
            rpmPct = clamp(math.floor(displayRpmPct + 0.5), 0, 100)
            local eh = GetVehicleEngineHealth(veh) or 1000.0
            engineHealth = eh
            engineTemp = clamp(math.floor((eh / 1000.0) * 42.0 + 58.0 + 0.5), 55, 115)
            engineOn = GetIsVehicleEngineRunning(veh)
            gearLabel = getVehicleGearDisplay(veh)
            handbrake = GetVehicleHandbrake(veh) == true or GetVehicleHandbrake(veh) == 1
            indicators = GetVehicleIndicatorLights(veh) or 0
            local p = (QBCore.Functions.GetPlate(veh) or GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
            trackVehicleMileage(veh, p)
            if p ~= '' and lockStateByPlate[p] ~= nil then
                doorsLocked = lockStateByPlate[p]
            else
                local st = GetVehicleDoorLockStatus(veh)
                doorsLocked = st == 2 or st == 3 or st == 4
            end
            lightsOn = areVehicleExteriorLightsOn(veh)
        end
    else
        seatbeltOn = false
        displaySpeedKmh = 0.0
        displayRpmPct = 0.0
        mileageTrackVeh = 0
        mileageTrackPos = nil
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
        voice = voiceLevel,
        voiceTalking = voiceTalking,
        inVehicle = inVehicle,
        speed = speed,
        speedExact = speedExact,
        fuel = fuel,
        seatbelt = seatbeltDisplayActive(),
        rpm = rpmPct,
        engineTemp = engineTemp,
        engineOn = engineOn,
        doorsLocked = doorsLocked,
        lightsOn = lightsOn,
        engineHealth = engineHealth,
        gear = gearLabel,
        handbrake = handbrake,
        indicators = indicators,
        settings = s
    })
end

local function saveHudPreset()
    SetResourceKvpInt('mrp_hud:preset', hudPreset)
end

local function setHudPreset(newPreset, silent)
    local p = tonumber(newPreset) or 1
    p = math.floor(p)
    if p < 1 then p = HUD_PRESET_COUNT end
    if p > HUD_PRESET_COUNT then p = 1 end
    hudPreset = p
    saveHudPreset()
    sendHudTheme()
    if not silent then
        QBCore.Functions.Notify(('HUD stilius: %s/%s'):format(hudPreset, HUD_PRESET_COUNT), 'primary')
    end
end

local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function deleteHudMenuProp()
    if hudMenuProp ~= 0 and DoesEntityExist(hudMenuProp) then
        DetachEntity(hudMenuProp, true, true)
        DeleteEntity(hudMenuProp)
    end
    hudMenuProp = 0
end

local function preparePedForHudAnim(ped)
    if not ped or ped == 0 then return false end
    if IsPedInAnyVehicle(ped, false) then return false end
    if IsEntityDead(ped) or IsPedRagdoll(ped) then return false end
    if IsPedFalling(ped) or IsPedSwimming(ped) or IsPedClimbing(ped) then return false end
    if IsPedArmed(ped, 7) then
        SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
    end
    ClearPedSecondaryTask(ped)
    return true
end

local function canPlayHudMenuAnim()
    return preparePedForHudAnim(PlayerPedId())
end

local function attachHudTablet(ped)
    deleteHudMenuProp()
    RequestModel(HUD_MENU_TABLET_MODEL)
    local deadline = GetGameTimer() + 3000
    while not HasModelLoaded(HUD_MENU_TABLET_MODEL) and GetGameTimer() < deadline do
        Wait(10)
    end
    if not HasModelLoaded(HUD_MENU_TABLET_MODEL) then return end

    local c = GetEntityCoords(ped)
    hudMenuProp = CreateObject(HUD_MENU_TABLET_MODEL, c.x, c.y, c.z + 0.2, true, true, false)
    SetEntityCollision(hudMenuProp, false, false)
    AttachEntityToEntity(
        hudMenuProp,
        ped,
        GetPedBoneIndex(ped, 60309),
        0.03, 0.002, -0.02,
        10.0, 160.0, 0.0,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(HUD_MENU_TABLET_MODEL)
end

local function playHudMenuOpenAnim()
    if not canPlayHudMenuAnim() then return end

    local token = hudMenuAnimToken + 1
    hudMenuAnimToken = token
    local ped = PlayerPedId()

    CreateThread(function()
        if not preparePedForHudAnim(ped) then return end

        local pickupDict, pickupAnim = 'pickup_object', 'pickup_low'
        if not loadAnimDict(pickupDict) then
            pickupDict, pickupAnim = 'random@domestic', 'pickup_low'
            if not loadAnimDict(pickupDict) then
                pickupDict, pickupAnim = 'cellphone@', 'cellphone_text_in'
                if not loadAnimDict(pickupDict) then return end
            end
        end

        TaskPlayAnim(ped, pickupDict, pickupAnim, 8.0, -8.0, 1100, 0, 0.0, false, false, false)
        Wait(850)
        if hudMenuAnimToken ~= token or not hudMenuOpen then return end

        local holdDict, holdAnim = 'amb@code_human_in_bus_passenger_idles@female@tablet@idle_a', 'idle_a'
        if loadAnimDict(holdDict) then
            TaskPlayAnim(ped, holdDict, holdAnim, 8.0, -8.0, -1, 49, 0.0, false, false, false)
            attachHudTablet(ped)
        end
    end)
end

local function playHudMenuCloseAnim()
    local token = hudMenuAnimToken + 1
    hudMenuAnimToken = token

    if not canPlayHudMenuAnim() then
        deleteHudMenuProp()
        ClearPedSecondaryTask(PlayerPedId())
        return
    end

    local ped = PlayerPedId()
    deleteHudMenuProp()
    ClearPedSecondaryTask(ped)

    CreateThread(function()
        local putDict, putAnim = 'pickup_object', 'putdown_low'
        if not loadAnimDict(putDict) then
            putDict, putAnim = 'random@domestic', 'putdown_low'
            if not loadAnimDict(putDict) then return end
        end

        TaskPlayAnim(ped, putDict, putAnim, 8.0, -8.0, 1000, 0, 0.0, false, false, false)
        Wait(900)
        if hudMenuAnimToken ~= token then return end
        ClearPedSecondaryTask(ped)
    end)
end

local function openHudMenu()
    if listMenuOpen then
        listMenuOpen = false
        listMenuVeh = 0
        SendNUIMessage({ action = 'vehicleList', open = false })
    end
    hudMenuOpen = true
    playHudMenuOpenAnim()
    SetNuiFocus(true, true)
    local payload = {
        action = 'openMenu',
        activePreset = hudPreset,
        presets = presetsForNui(),
        presetCount = HUD_PRESET_COUNT,
    }
    SendNUIMessage(payload)
end

local function closeHudMenu()
    if not hudMenuOpen then return end
    hudMenuOpen = false
    hudMenuAnimToken = hudMenuAnimToken + 1
    listMenuOpen = false
    listMenuVeh = 0
    SendNUIMessage({ action = 'vehicleList', open = false })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'closeMenu' })
    playHudMenuCloseAnim()
    sendHudTheme()
end

RegisterNetEvent('mrp_hud:client:forceClose', function()
    closeHudMenu()
end)

RegisterNetEvent('mrp_hud:client:inventoryFocus', function(active)
    SendNUIMessage({
        action = 'inventoryFocus',
        active = active == true,
    })
end)

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

--- QB / consumables / mrp_basics siunčia po `hunger`/`thirst` pakeitimo (nebūtina klausytis argumentų – imam iš `GetPlayerData`).
RegisterNetEvent('hud:client:UpdateNeeds', function()
    syncPlayerDataFromCore()
    pushHud()
end)

RegisterCommand('mrp_seatbelt', function()
    if GetResourceState('qb-smallresources') == 'started' then
        ExecuteCommand('toggleseatbelt')
        return
    end
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    seatbeltOn = not seatbeltOn
    local msg = seatbeltOn and 'Diržas: įjungtas' or 'Diržas: išjungtas'
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
    setHudPreset(idx, data and data.silent == true)
    cb({ ok = true })
end)

RegisterNUICallback('hud:savePreset', function(data, cb)
    local idx = tonumber(data and data.preset) or hudPreset
    idx = math.max(1, math.min(HUD_PRESET_COUNT, idx))
    local p = presetSettings[idx] or deepCopy(DEFAULT_PRESET)
    p.style = tostring(data and data.style or p.style)
    p.color = tostring(data and data.color or p.color)
    p.alpha = clamp(tonumber(data and data.alpha) or p.alpha, 0.2, 1.0)
    p.scale = clamp(tonumber(data and data.scale) or p.scale or 1.0, 0.75, 1.25)
    p.compact = data and data.compact == true
    p.anim = not (data and data.anim == false)
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
    if rain > 0.12 then return 'Lietus' end
    return 'Giedra'
end

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

local function syncVehicleLockToServer(veh, locked)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    if netId and netId > 0 then
        TriggerServerEvent('mrp_hud:server:setVehicleLock', netId, locked == true)
    end
end

local function playerHasVehicleKeys(veh)
    if not veh or veh == 0 then return false end
    local plate = QBCore.Functions.GetPlate(veh) or GetVehicleNumberPlateText(veh)
    if GetResourceState('qb-vehiclekeys') == 'started' then
        local ok, has = pcall(function()
            return exports['qb-vehiclekeys']:HasKeys(plate)
        end)
        if ok then return has == true end
    end
    return true
end

local function toggleVehicleLockMenu(veh)
    if GetResourceState('mrp_basics') == 'started' then
        local ok, isNpc = pcall(function()
            return exports['mrp_basics']:IsNaturalNpcVehicle(veh)
        end)
        if ok and isNpc then
            QBCore.Functions.Notify('NPC transportą atrakink visraktu.', 'error')
            return
        end
    end
    if not playerHasVehicleKeys(veh) then
        QBCore.Functions.Notify('Neturite raktų nuo šio transporto.', 'error')
        return
    end
    local nextLocked = not isVehicleLocked(veh)
    setVehicleLocked(veh, nextLocked)
    syncVehicleLockToServer(veh, nextLocked)
    QBCore.Functions.Notify(nextLocked and 'Transportas užrakintas.' or 'Transportas atrakintas.', 'primary')
end

local function getEngineStartBlockSecondsLeft(veh)
    if GetResourceState('mrp_vehiclemenu') ~= 'started' then return 0.0 end
    local ok, sec = pcall(function()
        return exports['mrp_vehiclemenu']:GetEngineStartBlockSecondsLeft(veh)
    end)
    if ok and tonumber(sec) then return tonumber(sec) end
    return 0.0
end

local function tryToggleEngineMenu(veh)
    if engineStartBusy then return end
    local on = GetIsVehicleEngineRunning(veh)
    if on then
        SetVehicleEngineOn(veh, false, true, true)
        QBCore.Functions.Notify('Variklis išjungtas.', 'primary')
        return
    end

    local blockSec = getEngineStartBlockSecondsLeft(veh)
    if blockSec > 0 then
        QBCore.Functions.Notify('Variklis užgeso.', 'error')
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

    local locked = isVehicleLocked(veh)

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

    local lightState, lo, hi = GetVehicleLightsState(veh)
    local highBeams = hi == true or hi == 1 or tonumber(lightState) == 2
    local lightsOn = areVehicleExteriorLightsOn(veh)

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

    local fuel = getVehicleFuelPercent(veh)
    local vehModel = GetEntityModel(veh)
    local dispHash = GetDisplayNameFromVehicleModel(vehModel)
    local vehLabel = dispHash and dispHash ~= '' and GetLabelText(dispHash) or 'Transportas'
    if vehLabel == 'NULL' or vehLabel == '' then vehLabel = 'Transportas' end
    local modelSpawn = dispHash and string.lower(dispHash) or 'default'
    local spawnModel = modelSpawn
    if QBCore.Shared and QBCore.Shared.Vehicles then
        for _, v in pairs(QBCore.Shared.Vehicles) do
            if v.model and joaat(v.model) == vehModel then
                spawnModel = string.lower(v.model)
                break
            end
        end
    end
    local vehicleClass = GetVehicleClass(veh)
    local plate = (QBCore.Functions.GetPlate(veh) or GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
    local motorPct = clamp(math.floor((eh / 1000.0) * 100.0 + 0.5), 0, 100)
    local bh = GetVehicleBodyHealth(veh) or 1000.0
    local bodyPct = clamp(math.floor((bh / 1000.0) * 100.0 + 0.5), 0, 100)
    local mileageKm = getPlateMileageKm(plate)
    local hasKeys = playerHasVehicleKeys(veh)

    local windowList = {}
    local nid = NetworkGetNetworkIdFromEntity(veh)
    for i = 0, 3 do
        local key = ('%s:%s'):format(nid, i)
        windowList[#windowList + 1] = { idx = i, open = vehicleWindowDown[key] == true }
    end

    SendNUIMessage({
        action = 'vehiclePanel',
        open = true,
        locked = locked,
        modelSpawn = modelSpawn,
        spawnModel = spawnModel,
        vehicleClass = vehicleClass,
        vehicleClassLabel = vehicleClassLabel(vehicleClass),
        hasKeys = hasKeys,
        doors = doorList,
        windows = windowList,
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
        bodyPct = bodyPct,
        mileageKm = mileageKm,
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
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return end
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        QBCore.Functions.Notify('Turi būti vairuotojo vietoje.', 'error')
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

RegisterCommand('mrp_vehicle_hud', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            toggleVehiclePanel()
            return
        end
    end
    TriggerEvent('mrp_basics:client:openClothingMenu')
end, false)

RegisterKeyMapping('mrp_vehicle_hud', 'Drabužiai (U) / transporto panelė (vairuotojas)', 'keyboard', 'U')

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
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        QBCore.Functions.Notify('Turi būti vairuotojo vietoje.', 'error')
        cb({ ok = false })
        return
    end

    local action = data and data.action or ''
    if action == 'close' then
        closeVehiclePanel()
    elseif action == 'lock' then
        toggleVehicleLockMenu(veh)
    elseif action == 'engine' then
        if not playerHasVehicleKeys(veh) then
            QBCore.Functions.Notify('Neturite raktų nuo šio transporto.', 'error')
            cb({ ok = false })
            return
        end
        tryToggleEngineMenu(veh)
    elseif action == 'lights' then
        if not playerHasVehicleKeys(veh) then
            QBCore.Functions.Notify('Neturite raktų nuo šio transporto.', 'error')
            cb({ ok = false })
            return
        end
        local on = areVehicleExteriorLightsOn(veh)
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
        if not playerHasVehicleKeys(veh) then
            QBCore.Functions.Notify('Neturite raktų nuo šio transporto.', 'error')
            cb({ ok = false })
            return
        end
        hazardEnabled = not hazardEnabled
        if not hazardEnabled then
            clearHazardLights(veh)
        end
    elseif action == 'door' then
        if not playerHasVehicleKeys(veh) then
            QBCore.Functions.Notify('Neturite raktų nuo šio transporto.', 'error')
            cb({ ok = false })
            return
        end
        local idx = tonumber(data.doorIndex)
        if idx == nil or idx < 0 or idx > 5 then
            cb({ ok = false })
            return
        end
        toggleVehicleDoor(veh, idx)
    elseif action == 'hood' then
        if not playerHasVehicleKeys(veh) then
            QBCore.Functions.Notify('Neturite raktų nuo šio transporto.', 'error')
            cb({ ok = false })
            return
        end
        toggleVehicleDoor(veh, 4)
    elseif action == 'trunk' then
        if not playerHasVehicleKeys(veh) then
            QBCore.Functions.Notify('Neturite raktų nuo šio transporto.', 'error')
            cb({ ok = false })
            return
        end
        toggleVehicleDoor(veh, 5)
    elseif action == 'gps' then
        local cx, cy, cz = table.unpack(GetEntityCoords(veh))
        SetNewWaypoint(cx + 0.0, cy + 0.0)
        QBCore.Functions.Notify('GPS taškas nustatytas prie transporto.', 'success')
    elseif action == 'window' then
        if not playerHasVehicleKeys(veh) then
            QBCore.Functions.Notify('Neturite raktų nuo šio transporto.', 'error')
            cb({ ok = false })
            return
        end
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

RegisterNetEvent('mrp_hud:client:syncVehicleDoor', function(netId, doorIndex, open)
    netId = tonumber(netId)
    doorIndex = tonumber(doorIndex)
    if not netId or doorIndex == nil then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if open then
        SetVehicleDoorOpen(veh, doorIndex, false, false)
    else
        SetVehicleDoorShut(veh, doorIndex, false)
    end
end)

RegisterNetEvent('mrp_hud:client:syncVehicleLock', function(netId, locked)
    netId = tonumber(netId)
    if not netId then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        setVehicleLocked(veh, locked == true)
    end
end)

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
    --- Vienkartinė migracija: senas numatytasis „frame“ → rutuliukai (šablonas 1)
    if GetResourceKvpInt('mrp_hud:dots_default_v') < 1 then
        local p1 = presetSettings[1]
        if p1 and p1.style == 'frame' then
            p1.style = 'dots'
            savePresetSettings(1)
        end
        SetResourceKvpInt('mrp_hud:dots_default_v', 1)
    end
    hudPreset = GetResourceKvpInt('mrp_hud:preset')
    if hudPreset < 1 or hudPreset > HUD_PRESET_COUNT then
        hudPreset = 1
    end
    sendHudTheme()

    while true do
        if not LocalPlayer.state.inv_busy then
            pushHud()
        end
        local waitMs = 700
        if hudMenuOpen then
            waitMs = 180
        elseif IsPedInAnyVehicle(PlayerPedId(), false) then
            waitMs = 100
        end
        Wait(waitMs)
    end
end)

CreateThread(function()
    while true do
        if hudMenuOpen and not canPlayHudMenuAnim() then
            hudMenuAnimToken = hudMenuAnimToken + 1
            deleteHudMenuProp()
            ClearPedSecondaryTask(PlayerPedId())
        end
        Wait(400)
    end
end)

CreateThread(function()
    while true do
        local waitMs = 450
        if hudMenuOpen or vehiclePanelOpen or listMenuOpen then
            waitMs = 0
            if hudMenuOpen and (IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322)) then
                closeHudMenu()
            elseif vehiclePanelOpen and (IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322)) then
                closeVehiclePanel()
            elseif listMenuOpen and (IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322)) then
                closeVehicleListMenu()
            end
        end
        Wait(waitMs)
    end
end)

-- GTA minimap + default HUD slėpimas viename cikle (mažiau per-frame thread).
CreateThread(function()
    DisplayRadar(true)
    SetRadarBigmapEnabled(false, false)

    local minimap = RequestScaleformMovie('minimap')
    while not HasScaleformMovieLoaded(minimap) do
        Wait(0)
    end

    while true do
        HideHudComponentThisFrame(2)
        HideHudComponentThisFrame(7)
        HideHudComponentThisFrame(9)
        HideHudComponentThisFrame(19)
        HideHudComponentThisFrame(20)
        HideHudComponentThisFrame(22)

        if IsBigmapActive() or IsBigmapFull() then
            SetRadarBigmapEnabled(false, false)
        end
        BeginScaleformMovieMethod(minimap, 'SETUP_HEALTH_ARMOUR')
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()
        Wait(0)
    end
end)

