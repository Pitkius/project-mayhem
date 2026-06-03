local QBCore = exports['qb-core']:GetCoreObject()

local radioOpen = false
local currentFreq = nil
local currentLabel = nil
local currentLock = nil
local members = {}
local soundOn = true
local talkingOnRadio = false

local settings = {
    beepStart = true,
    beepEnd = true,
    channelChange = true,
    connect = true,
    disconnect = true,
    compactOverlay = true,
    memberDisplay = 'callsign_name', -- callsign_name | callsign | fullname | hidden
}

local KVP_KEY = 'fivempro_radio:settings'

local function loadSettings()
    local raw = GetResourceKvpString(KVP_KEY)
    if not raw or raw == '' then return end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then
        for k, v in pairs(settings) do
            if decoded[k] ~= nil then settings[k] = decoded[k] end
        end
    end
end

local function saveSettings()
    SetResourceKvp(KVP_KEY, json.encode(settings))
end

local function playUiSound(kind)
    if not soundOn then return end
    local map = {
        connect = { 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        disconnect = { 'NAV_LEFT_RIGHT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        channel = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        beep = { 'Beep_Green', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    }
    local s = map[kind]
    if s then PlaySoundFrontend(-1, s[1], s[2], true) end
end

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary')
end

local function sendNui(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

local function pushState()
    sendNui('state', {
        open = radioOpen,
        freq = currentFreq,
        label = currentLabel,
        lock = currentLock,
        connected = currentFreq ~= nil,
        soundOn = soundOn,
        settings = settings,
        members = members,
        talking = talkingOnRadio,
    })
end

local function openRadio()
    if radioOpen then return end
    radioOpen = true
    SetNuiFocus(true, true)
    pushState()
end

local function closeRadio()
    if not radioOpen then return end
    radioOpen = false
    SetNuiFocus(false, false)
    sendNui('close', {})
end

local function voiceJoin(freq)
    if GetResourceState('pma-voice') ~= 'started' then
        notify('pma-voice nerastas — įdiekite balso resursą.', 'error')
        return
    end
    exports['pma-voice']:setVoiceProperty('radioEnabled', true)
    exports['pma-voice']:setRadioChannel(freq)
end

local function voiceLeave()
    if GetResourceState('pma-voice') == 'started' then
        exports['pma-voice']:removePlayerFromRadio()
        exports['pma-voice']:setVoiceProperty('radioEnabled', false)
    end
end

local function startRadioAnim()
    local ped = PlayerPedId()
    local cfg = Config.RadioAnim or {}
    local dict = cfg.dict or 'random@arrests'
    local anim = cfg.anim or 'generic_radio_chatter'
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    if HasAnimDictLoaded(dict) and not IsEntityPlayingAnim(ped, dict, anim, 3) then
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, cfg.flag or 49, 0.0, false, false, false)
    end
end

local function stopRadioAnim()
    local ped = PlayerPedId()
    local cfg = Config.RadioAnim or {}
    if IsEntityPlayingAnim(ped, cfg.dict or 'random@arrests', cfg.anim or 'generic_radio_chatter', 3) then
        StopAnimTask(ped, cfg.dict or 'random@arrests', cfg.anim or 'generic_radio_chatter', 1.0)
    end
end

RegisterNetEvent('fivempro_radio:client:open', function()
    openRadio()
end)

RegisterNetEvent('fivempro_radio:client:notify', function(msg, ntype)
    notify(msg, ntype)
    if radioOpen then pushState() end
end)

RegisterNetEvent('fivempro_radio:client:freqDenied', function(msg)
    sendNui('freqResult', { ok = false, message = msg })
    notify(msg or 'Neturite prieigos.', 'error')
end)

RegisterNetEvent('fivempro_radio:client:freqOk', function(freq, label, lock)
    currentFreq = tonumber(freq)
    currentLabel = label
    currentLock = lock
    sendNui('freqResult', { ok = true, freq = currentFreq, label = label, lock = lock })
    if settings.channelChange then playUiSound('channel') end
    pushState()
end)

RegisterNetEvent('fivempro_radio:client:setChannel', function(freq, label, lock)
    currentFreq = freq and tonumber(freq) or nil
    currentLabel = label
    currentLock = lock
    members = {}
    if radioOpen then pushState() end
end)

RegisterNetEvent('fivempro_radio:client:channelUpdate', function(freq, list)
    if currentFreq and tonumber(freq) == currentFreq then
        members = list or {}
    end
end)

RegisterNetEvent('fivempro_radio:client:voiceJoin', function(freq)
    voiceJoin(freq)
    if settings.connect then playUiSound('connect') end
    if radioOpen then pushState() end
end)

RegisterNetEvent('fivempro_radio:client:voiceLeave', function()
    voiceLeave()
    if settings.disconnect then playUiSound('disconnect') end
end)

RegisterNUICallback('close', function(_, cb)
    closeRadio()
    cb('ok')
end)

RegisterNUICallback('connect', function(data, cb)
    local freq = tonumber(data and data.freq) or currentFreq
    if not freq then
        notify('Pirmiausia nustatykite dažnį.', 'error')
        cb('ok')
        return
    end
    TriggerServerEvent('fivempro_radio:server:connect', freq, settings.memberDisplay)
    cb('ok')
end)

RegisterNUICallback('disconnect', function(_, cb)
    TriggerServerEvent('fivempro_radio:server:disconnect')
    currentFreq = nil
    currentLabel = nil
    currentLock = nil
    members = {}
    pushState()
    cb('ok')
end)

RegisterNUICallback('validateFreq', function(data, cb)
    local freq = math.floor(tonumber(data and data.freq) or 0)
    if freq < 1 then
        sendNui('freqResult', { ok = false, message = 'Įveskite dažnį.' })
        cb('ok')
        return
    end
    TriggerServerEvent('fivempro_radio:server:validateFrequency', freq)
    cb('ok')
end)

RegisterNUICallback('toggleSound', function(_, cb)
    soundOn = not soundOn
    pushState()
    notify(soundOn and 'Racijos garsas įjungtas.' or 'Racijos garsas išjungtas.', 'primary')
    cb('ok')
end)

RegisterNUICallback('saveSettings', function(data, cb)
    if type(data) == 'table' then
        for k, v in pairs(data) do
            if settings[k] ~= nil then settings[k] = v end
        end
        saveSettings()
        TriggerServerEvent('fivempro_radio:server:updateDisplayMode', settings.memberDisplay)
    end
    pushState()
    cb('ok')
end)

--- Kas kalba per raciją (pma-voice state)
AddStateBagChangeHandler('radioActive', nil, function(bagName, _, value)
    local myBag = ('player:%s'):format(GetPlayerServerId(PlayerId()))
    if bagName ~= myBag then return end
    talkingOnRadio = value == true
    if talkingOnRadio then
        if settings.beepStart then playUiSound('beep') end
        startRadioAnim()
    else
        if settings.beepEnd then playUiSound('beep') end
        stopRadioAnim()
    end
end)

CreateThread(function()
    loadSettings()
    while true do
        if currentFreq and settings.compactOverlay then
            Wait(0)
        else
            Wait(500)
        end
    end
end)

--- Kompaktinis overlay + prisijungusių sąrašas (GTA tekstas)
CreateThread(function()
    local function drawText(x, y, scale, text, r, g, b, a)
        SetTextFont(4)
        SetTextScale(scale, scale)
        SetTextColour(r, g, b, a)
        SetTextOutline()
        SetTextRightJustify(true)
        SetTextWrap(0.0, x)
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandDisplayText(x, y)
    end

    while true do
        local sleep = 400
        if currentFreq then
            sleep = 0
            local cfgO = Config.Overlay or {}
            local ox = cfgO.x or 0.88
            local oy = cfgO.y or 0.72

            if settings.compactOverlay then
                local line1 = ('Racija: %s'):format(tostring(currentFreq))
                local line2
                if talkingOnRadio then
                    local P = QBCore.Functions.GetPlayerData()
                    local cs = ''
                    if P and P.metadata and P.metadata.callsign then cs = P.metadata.callsign .. ' ' end
                    local ci = P and P.charinfo or {}
                    line2 = ('Kalba: %s%s'):format(cs, (ci.firstname or '') .. ' ' .. (ci.lastname or ''))
                else
                    line2 = ('Prisijungę: %s'):format(#members)
                end
                drawText(ox, oy, 0.32, line1, 167, 139, 250, 230)
                drawText(ox, oy + 0.028, 0.28, line2, 226, 232, 240, 220)
            end

            if settings.memberDisplay ~= 'hidden' and #members > 0 and not radioOpen then
                local cfgM = Config.MemberList or {}
                local mx = cfgM.x or 0.86
                local my = cfgM.y or 0.38
                local maxL = cfgM.maxLines or 8
                drawText(mx, my, 0.34, ('Racija %s'):format(tostring(currentFreq)), 167, 139, 250, 240)
                if currentLabel then
                    drawText(mx, my + 0.026, 0.30, currentLabel, 200, 200, 210, 220)
                end
                drawText(mx, my + 0.052, 0.28, 'Prisijungę:', 180, 180, 190, 210)
                for i = 1, math.min(#members, maxL) do
                    local m = members[i]
                    drawText(mx, my + 0.052 + (i * 0.024), 0.26, ('- %s'):format(m.line or m.name or '?'), 230, 230, 235, 215)
                end
                if #members > maxL then
                    drawText(mx, my + 0.052 + ((maxL + 1) * 0.024), 0.24, ('ir dar %s...'):format(#members - maxL), 160, 160, 170, 200)
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterCommand('racija', function()
    openRadio()
end, false)

RegisterKeyMapping('racija', 'Atidaryti raciją', 'keyboard', '')
