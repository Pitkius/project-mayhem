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

local function deepCopy(tbl)
    local out = {}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then out[k] = deepCopy(v) else out[k] = v end
    end
    return out
end

local DEFAULT_PRESET = {
    style = 'dots',
    color = 'violet',
    alpha = 0.55,
    show = {
        health = true,
        hunger = true,
        thirst = true,
        armor = false,
        stamina = false,
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

local function getNeeds()
    local metadata = PlayerData.metadata or {}
    local hunger = metadata.hunger or 100
    local thirst = metadata.thirst or 100
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

local function sendHudTheme()
    local s = currentSettings()
    local c = COLOR_THEMES[s.color] or COLOR_THEMES.violet
    SendNUIMessage({
        action = 'theme',
        preset = hudPreset,
        style = s.style,
        alpha = s.alpha,
        color = s.color,
        fillColor = c.fill,
        glowColor = c.glow,
        show = s.show,
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

    if inVehicle then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then
            inVehicle = false
        else
            speed = clamp(math.floor(GetEntitySpeed(veh) * 3.6 + 0.5), 0, 450)
            fuel = clamp(math.floor(GetVehicleFuelLevel(veh) + 0.5), 0, 100)
        end
    else
        seatbeltOn = false
    end

    local s = currentSettings()
    SendNUIMessage({
        action = 'update',
        show = show,
        hudPreset = hudPreset,
        health = health,
        armor = armor,
        stamina = clamp(math.floor(GetPlayerSprintStaminaRemaining(PlayerId()) + 0.5), 0, 100),
        hunger = hunger,
        thirst = thirst,
        inVehicle = inVehicle,
        speed = speed,
        fuel = fuel,
        seatbelt = seatbeltOn,
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
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMenu' })
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

RegisterCommand('fivempro_seatbelt', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    seatbeltOn = not seatbeltOn
    local msg = seatbeltOn and 'Dirzas: ijungtas' or 'Dirzas: isjungtas'
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end, false)

RegisterKeyMapping('fivempro_seatbelt', 'Toggle seatbelt', 'keyboard', 'B')

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

