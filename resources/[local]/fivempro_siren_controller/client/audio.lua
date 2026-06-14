--- Sirenos tonų garsas (WAIL / YELP / PRIORITY / AIRHORN / MANUAL)
local TRACKED = {}
local manualHeld = false
local airhornUntil = 0

local function resolveEntityFromBagName(bagName)
    bagName = tostring(bagName or '')
    if type(GetEntityFromStateBagName) == 'function' then
        local e = GetEntityFromStateBagName(bagName)
        if e and e ~= 0 and DoesEntityExist(e) then return e end
    end
    local nidStr = bagName:match('^entity:(%d+)$') or bagName:match('^%w+:(%d+)$')
    local nid = tonumber(nidStr)
    if nid and NetworkDoesNetworkIdExist(nid) then
        local ent = NetworkGetEntityFromNetworkId(nid)
        if ent ~= 0 and DoesEntityExist(ent) then return ent end
    end
    return 0
end

local function readMode(veh)
    local bag = Entity(veh).state
    local mode = bag.ltPdSirenMode or bag.ltEmsSirenMode or 'off'
    if type(mode) ~= 'string' then mode = 'off' end
    return mode:lower()
end

local function readTone(veh)
    local tone = Entity(veh).state.fpSirenTone or 'wail'
    if type(tone) ~= 'string' then tone = 'wail' end
    tone = tone:lower()
    if not Config.ToneSounds[tone] then tone = 'wail' end
    return tone
end

local function isMuted(veh)
    return Entity(veh).state.fpSirenMuted == true
end

local function vehicleNeedsScriptSound(veh, mode)
    if mode ~= 'sound' and mode ~= 'full' then return false end
    if mode == 'full' then
        local hash = GetEntityModel(veh)
        if GetVehicleClass(veh) == 18 then return false end
        for _, list in pairs(Config.FleetVehicles) do
            for _, m in ipairs(list) do
                if joaat(m) == hash then return false end
            end
        end
    end
    return true
end

local function stopSound(veh)
    local meta = TRACKED[veh]
    if not meta then return end
    if meta.sid and meta.sid ~= -1 then
        StopSound(meta.sid)
        ReleaseSoundId(meta.sid)
    end
    meta.sid = nil
end

local function playSoundOnVehicle(veh, soundName, loop)
    if not DoesEntityExist(veh) then return end
    local meta = TRACKED[veh]
    if not meta then
        meta = {}
        TRACKED[veh] = meta
    end
    if not meta.sid or meta.sid == -1 then
        meta.sid = GetSoundId()
    end
    if meta.sid == -1 then return end
    StopSound(meta.sid)
    pcall(function()
        PlaySoundFromEntity(meta.sid, soundName, veh, 0, loop == true, 0)
    end)
end

local function playBurst(veh, tone)
    local sound = Config.ToneSounds[tone] or Config.ToneSounds.wail
    local sid = GetSoundId()
    if sid == -1 then return end
    pcall(function()
        PlaySoundFromEntity(sid, sound, veh)
    end)
    SetTimeout(480, function()
        StopSound(sid)
        ReleaseSoundId(sid)
    end)
end

local function ingestVehicle(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) or not IsEntityAVehicle(veh) then return end
    local mode = readMode(veh)
    if mode == 'off' then
        stopSound(veh)
        TRACKED[veh] = nil
        return
    end
    TRACKED[veh] = TRACKED[veh] or {}
    TRACKED[veh].mode = mode
    TRACKED[veh].tone = readTone(veh)
    TRACKED[veh].muted = isMuted(veh)
end

local function onBagChange(_, bagName)
    Wait(20)
    local ent = resolveEntityFromBagName(bagName)
    if ent ~= 0 and IsEntityAVehicle(ent) then
        ingestVehicle(ent)
    end
end

AddStateBagChangeHandler('ltPdSirenMode', '', onBagChange)
AddStateBagChangeHandler('ltEmsSirenMode', '', onBagChange)
AddStateBagChangeHandler('fpSirenTone', '', onBagChange)
AddStateBagChangeHandler('fpSirenMuted', '', onBagChange)

RegisterNetEvent('fivempro_siren:client:playAirhorn', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
        playBurst(veh, 'airhorn')
        airhornUntil = GetGameTimer() + 600
    end
end)

RegisterNetEvent('fivempro_siren:client:manualHeld', function(held)
    manualHeld = held == true
end)

CreateThread(function()
    while true do
        Wait(380)
        local now = GetGameTimer()
        for veh, meta in pairs(TRACKED) do
            if not DoesEntityExist(veh) then
                stopSound(veh)
                TRACKED[veh] = nil
            else
                local mode = readMode(veh)
                local tone = readTone(veh)
                local muted = isMuted(veh)
                meta.mode = mode
                meta.tone = tone
                meta.muted = muted

                if mode == 'off' then
                    stopSound(veh)
                    TRACKED[veh] = nil
                elseif muted and mode ~= 'lights' then
                    stopSound(veh)
                elseif vehicleNeedsScriptSound(veh, mode) or mode == 'sound' then
                    local driverVeh = GetVehiclePedIsIn(PlayerPedId(), false)
                    local isDriver = driverVeh == veh and GetPedInVehicleSeat(veh, -1) == PlayerPedId()
                    local useManual = isDriver and manualHeld
                    if now < airhornUntil then
                        -- airhorn burst handles itself
                    elseif useManual or mode == 'sound' or mode == 'full' then
                        local activeTone = useManual and tone or tone
                        local interval = Config.ToneIntervals[activeTone] or 700
                        if not meta.lastBurst or (now - meta.lastBurst) >= interval then
                            playBurst(veh, activeTone)
                            meta.lastBurst = now
                        end
                    end
                else
                    stopSound(veh)
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh and veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            ingestVehicle(veh)
        end
    end
end)
