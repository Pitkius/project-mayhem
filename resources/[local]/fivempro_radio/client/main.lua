local QBCore = exports['qb-core']:GetCoreObject()

local radioOpen = false
local currentFreq = nil
local currentLabel = nil
local currentLock = nil
local voiceConnected = false
local radioAlias = ''
local members = {}
local soundOn = true
local talkingOnRadio = false
local radioTalkers = {}

local settings = {
    beepStart = true,
    beepEnd = true,
    channelChange = true,
    connect = true,
    disconnect = true,
    compactOverlay = true,
}

local KVP_SETTINGS = 'fivempro_radio:settings'
local KVP_ALIAS = 'fivempro_radio:alias'

local function loadSettings()
    local raw = GetResourceKvpString(KVP_SETTINGS)
    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok and type(decoded) == 'table' then
            for k, v in pairs(settings) do
                if decoded[k] ~= nil then settings[k] = decoded[k] end
            end
        end
    end
    radioAlias = GetResourceKvpString(KVP_ALIAS) or ''
end

local function saveSettings()
    SetResourceKvp(KVP_SETTINGS, json.encode(settings))
end

local function saveAlias()
    SetResourceKvp(KVP_ALIAS, radioAlias or '')
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
        sub = currentLock,
        alias = radioAlias,
        connected = voiceConnected,
        soundOn = soundOn,
        settings = settings,
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
        notify('Įdiek pma-voice ir atkomentuok cfg/25_voice.cfg (ensure pma-voice).', 'error')
        return false
    end
    exports['pma-voice']:setVoiceProperty('radioEnabled', true)
    exports['pma-voice']:setRadioChannel(freq)
    return true
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
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, cfg.flag or 49, 0.0, false, false, false)
    end
end

local function stopRadioAnim()
    local ped = PlayerPedId()
    local cfg = Config.RadioAnim or {}
    StopAnimTask(ped, cfg.dict or 'random@arrests', cfg.anim or 'generic_radio_chatter', 1.0)
end

RegisterNetEvent('fivempro_radio:client:open', function()
    openRadio()
end)

RegisterNetEvent('fivempro_radio:client:notify', function(msg, ntype)
    notify(msg, ntype)
    if string.find(msg or '', 'prisijungta', 1, true) then
        voiceConnected = true
    end
    if radioOpen then pushState() end
end)

RegisterNetEvent('fivempro_radio:client:freqDenied', function(msg)
    sendNui('freqResult', { ok = false, message = msg })
    notify(msg or 'Neturite prieigos.', 'error')
end)

RegisterNetEvent('fivempro_radio:client:freqOk', function(freq, label, lock, alias)
    currentFreq = tonumber(freq)
    currentLabel = label
    currentLock = lock
    if alias and alias ~= '' then
        radioAlias = alias
        saveAlias()
    end
    sendNui('freqResult', { ok = true, freq = currentFreq, label = label, lock = lock, alias = radioAlias })
    if settings.channelChange then playUiSound('channel') end
    pushState()
end)

RegisterNetEvent('fivempro_radio:client:setChannel', function(freq, label, lock, connected)
    currentFreq = freq and tonumber(freq) or nil
    currentLabel = label
    currentLock = lock
    voiceConnected = connected == true
    if not voiceConnected then
        members = {}
        radioTalkers = {}
    end
    if radioOpen then pushState() end
end)

RegisterNetEvent('fivempro_radio:client:channelUpdate', function(freq, list)
    if currentFreq and tonumber(freq) == currentFreq then
        members = list or {}
    end
end)

RegisterNetEvent('fivempro_radio:client:voiceJoin', function(freq)
    if voiceJoin(freq) then
        voiceConnected = true
        if settings.connect then playUiSound('connect') end
        if radioOpen then pushState() end
    end
end)

RegisterNetEvent('fivempro_radio:client:voiceLeave', function()
    voiceLeave()
    voiceConnected = false
    if settings.disconnect then playUiSound('disconnect') end
    if radioOpen then pushState() end
end)

RegisterNUICallback('close', function(_, cb)
    closeRadio()
    cb('ok')
end)

RegisterNUICallback('connect', function(data, cb)
    local freq = tonumber(data and data.freq) or currentFreq
    local alias = data and data.alias or radioAlias
    if not freq then
        notify('Pirmiausia nustatyk dažnį (mygtukas Dažnis).', 'error')
        cb('ok')
        return
    end
    if not alias or alias == '' then
        notify('Įrašyk savo vardą racijoje.', 'error')
        cb('ok')
        return
    end
    radioAlias = alias
    saveAlias()
    TriggerServerEvent('fivempro_radio:server:connect', freq, radioAlias)
    cb('ok')
end)

RegisterNUICallback('disconnect', function(_, cb)
    TriggerServerEvent('fivempro_radio:server:disconnect')
    currentFreq = nil
    currentLabel = nil
    currentLock = nil
    voiceConnected = false
    members = {}
    radioTalkers = {}
    if radioOpen then pushState() end
    cb('ok')
end)

RegisterNUICallback('validateFreq', function(data, cb)
    local freq = math.floor(tonumber(data and data.freq) or 0)
    local alias = tostring(data and data.alias or radioAlias or ''):sub(1, 32)
    if freq < 1 then
        sendNui('freqResult', { ok = false, message = 'Įveskite dažnį.' })
        cb('ok')
        return
    end
    if alias == '' then
        sendNui('freqResult', { ok = false, message = 'Įrašyk savo vardą racijoje.' })
        cb('ok')
        return
    end
    radioAlias = alias
    saveAlias()
    TriggerServerEvent('fivempro_radio:server:validateFrequency', freq, radioAlias)
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
    end
    pushState()
    cb('ok')
end)

--- Kas kalba per raciją
AddStateBagChangeHandler('radioActive', nil, function(bagName, _, value)
    local sid = tonumber(bagName:match('player:(%d+)'))
    if not sid then return end
    if sid == GetPlayerServerId(PlayerId()) then
        talkingOnRadio = value == true
        if talkingOnRadio then
            if settings.beepStart then playUiSound('beep') end
            startRadioAnim()
        else
            if settings.beepEnd then playUiSound('beep') end
            stopRadioAnim()
        end
        return
    end
    if voiceConnected and currentFreq then
        if value then
            for _, m in ipairs(members) do
                if m.src == sid then
                    radioTalkers[sid] = m.line or m.name
                    return
                end
            end
            radioTalkers[sid] = 'Kalbėtojas'
        else
            radioTalkers[sid] = nil
        end
    end
end)

local function drawTextRight(x, y, scale, text, r, g, b, a)
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

CreateThread(function()
    loadSettings()
    while true do
        local sleep = 400
        if voiceConnected and currentFreq then
            sleep = 0
            local cfgO = Config.Overlay or {}
            local ox = cfgO.x or 0.90
            local oy = cfgO.y or 0.08

            if settings.compactOverlay then
                drawTextRight(ox, oy, 0.34, ('Racija: %s'):format(tostring(currentFreq)), 167, 139, 250, 240)
                local line2
                if talkingOnRadio then
                    line2 = ('Kalba: %s'):format(radioAlias ~= '' and radioAlias or 'Tu')
                else
                    local talkName = nil
                    for sid, name in pairs(radioTalkers) do
                        if name then talkName = name break end
                    end
                    line2 = talkName and ('Kalba: %s'):format(talkName) or ('Prisijungę: %s'):format(#members)
                end
                drawTextRight(ox, oy + 0.028, 0.30, line2, 226, 232, 240, 225)
            end

            local cfgM = Config.MemberList or {}
            local mx = cfgM.x or 0.90
            local my = cfgM.y or 0.14
            local maxL = cfgM.maxLines or 10
            drawTextRight(mx, my, 0.32, ('Racija %s'):format(tostring(currentFreq)), 167, 139, 250, 235)
            if currentLabel then
                drawTextRight(mx, my + 0.024, 0.28, currentLabel, 200, 200, 210, 220)
            end
            drawTextRight(mx, my + 0.048, 0.27, 'Prisijungę:', 180, 180, 190, 210)
            for i = 1, math.min(#members, maxL) do
                local m = members[i]
                drawTextRight(mx, my + 0.048 + (i * 0.022), 0.26, ('- %s'):format(m.line or m.name or '?'), 235, 235, 240, 220)
            end
            if #members > maxL then
                drawTextRight(mx, my + 0.048 + ((maxL + 1) * 0.022), 0.24, ('ir dar %s...'):format(#members - maxL), 160, 160, 170, 200)
            end
        end
        Wait(sleep)
    end
end)

RegisterCommand('racija', function()
    openRadio()
end, false)

RegisterKeyMapping('racija', 'Atidaryti raciją', 'keyboard', '')
