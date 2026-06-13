--- PD: šviestuvų ir sirenos režimai masinoje + laikina sirena ant civilinės mašinos (statebag ltPd*)
local QBCore = exports['qb-core']:GetCoreObject()

local TRACKED = {} --- [vehicle] = { supportsNative }

local Ec = Config.EmergencyVehicle or {}
local RESET_ON_EXIT = Ec.resetWhenLeaveDriverSeat ~= false

local function isPdJobName(name)
    return name == Config.JobName
end

local function pdOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and isPdJobName(P.job.name) and P.job.onduty
end

local function hasGradePerm(minGrade)
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job then return false end
    local g = tonumber(P.job.grade and P.job.grade.level or 0) or 0
    return g >= minGrade
end

local function canPdSirenMenu()
    if not pdOnDuty() then return false end
    local need = (Config.Permissions and Config.Permissions.pd_siren_controller) or 0
    return hasGradePerm(need)
end

local function canPdEmergencyKit()
    if not pdOnDuty() then return false end
    local need = (Config.Permissions and Config.Permissions.pd_emergency_kit) or 0
    return hasGradePerm(need)
end

local function modelIsFleet(hash)
    if Config.FleetVehicles then
        for _, v in ipairs(Config.FleetVehicles) do
            if v and v.model and joaat(v.model) == hash then return true end
        end
    end
    if Config.FleetHelicopters then
        for _, v in ipairs(Config.FleetHelicopters) do
            if v and v.model and joaat(v.model) == hash then return true end
        end
    end
    return false
end

local function vehicleSupportsNativeEmergency(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local hash = GetEntityModel(vehicle)
    -- Kai kuriuose artefaktuose native neeksportuotas – nekrentam į nil call.
    for _, name in ipairs({ 'IsThisModelEmergencyVehicle', 'IsThisModelAnEmergencyVehicle' }) do
        local fn = rawget(_G, name)
        if type(fn) == 'function' then
            local ok, r = pcall(fn, hash)
            if ok and r then return true end
        end
    end
    if GetVehicleClass(vehicle) == 18 then return true end
    return modelIsFleet(hash)
end

local function getDriverVehicleLocal()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return nil end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return veh
end

local function stopNativeSirenVisual(vehicle)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleSiren(vehicle, false)
    SetVehicleHasMutedSirens(vehicle, false)
end

local soundIds = {}

local function stopScriptSound(vehicle)
    local sid = soundIds[vehicle]
    if sid and sid ~= -1 then
        StopSound(sid)
        ReleaseSoundId(sid)
    end
    soundIds[vehicle] = nil
end

local function playShortSirenBurst(vehicle)
    if not DoesEntityExist(vehicle) then return end
    local sid = soundIds[vehicle]
    if not sid then
        sid = GetSoundId()
        if sid == -1 then return end
        soundIds[vehicle] = sid
    end
    StopSound(sid)
    pcall(function()
        PlaySoundFromEntity(sid, 'VEHICLES_HORNS_SIREN_1', vehicle)
    end)
end

local function drawScriptFlash(vehicle)
    if not DoesEntityExist(vehicle) then return end
    local mn, mx = GetModelDimensions(GetEntityModel(vehicle))
    local z = (mx.z * 1.06) + 0.06
    local yBias = mn.y + 0.45
    local c = GetEntityCoords(vehicle)
    local fwd = GetEntityForwardVector(vehicle)
    --- „Stogo“ taškai iš šonų — raudona / mėlyna vilktis
    local side = math.sin(GetGameTimer() / 150.0) > 0 and 1.0 or -1.0
    local rightVec = vector3(-fwd.y, fwd.x, 0.0)
    local wx = rightVec.x * side * 0.85
    local wy = rightVec.y * side * 0.85
    local x = (c.x + wx * 0.4) + (fwd.x * yBias)
    local yy = (c.y + wy * 0.4) + (fwd.y * yBias)
    local zz = c.z + z
    if side > 0 then
        DrawLightWithRange(x, yy, zz, 220, 20, 20, 9.5, 32.0)
    else
        DrawLightWithRange(x, yy, zz, 20, 40, 255, 9.5, 32.0)
    end
end

local function safeVehicleNetId(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end
    return NetworkGetNetworkIdFromEntity(vehicle)
end

local function readVehicleStateBag(vehicle)
    local bag = Entity(vehicle).state
    if bag == nil then return 'off', false end
    local mode = bag.ltPdSirenMode or 'off'
    if type(mode) ~= 'string' then mode = 'off' end
    mode = mode:lower()
    local kit = bag.ltPdKit == true
    return mode, kit
end

local function applyNativeForEveryone(vehicle, mode)
    if not DoesEntityExist(vehicle) then return end
    if not vehicleSupportsNativeEmergency(vehicle) then return end
    mode = mode or 'off'
    if mode == 'off' then
        stopNativeSirenVisual(vehicle)
        return
    end
    if mode == 'sound' then
        stopNativeSirenVisual(vehicle)
        return
    end
    --- lights ir full naudoja GTA sirenos šviesas
    SetVehicleSiren(vehicle, true)
    if mode == 'lights' then
        SetVehicleHasMutedSirens(vehicle, true)
    elseif mode == 'full' then
        SetVehicleHasMutedSirens(vehicle, false)
    end
end

local function ingestFromEntity(vehicle)
    if not vehicle or vehicle == 0 or not IsEntityAVehicle(vehicle) or not DoesEntityExist(vehicle) then return end
    local mode, _kit = readVehicleStateBag(vehicle)
    TRACKED[vehicle] = TRACKED[vehicle] or {}
    TRACKED[vehicle].supportsNative = vehicleSupportsNativeEmergency(vehicle)

    --- visada bandome nuimti / perstatyti natyvią sirena pagal būseną
    if mode == 'off' then
        stopNativeSirenVisual(vehicle)
        TRACKED[vehicle] = nil
        stopScriptSound(vehicle)
        return
    elseif mode == 'lights' then
        stopScriptSound(vehicle)
        applyNativeForEveryone(vehicle, mode)
    elseif mode == 'sound' then
        --- Tik garsas – natyvus „siren“ išjungtas, nesinaudoja automatinėmis šviesomis (sceninė sirena žemiau).
        stopNativeSirenVisual(vehicle)
    elseif mode == 'full' then
        if TRACKED[vehicle].supportsNative then
            stopScriptSound(vehicle)
            applyNativeForEveryone(vehicle, 'full')
        end
    end
end

local function resolveEntityFromBagName(bagName)
    bagName = tostring(bagName or '')
    if type(GetEntityFromStateBagName) == 'function' then
        local e = GetEntityFromStateBagName(bagName)
        if e and e ~= 0 and DoesEntityExist(e) then
            return e
        end
    end
    local nidStr = bagName:match('^entity:(%d+)$') or bagName:match('^%w+:(%d+)$')
    local nid = tonumber(nidStr)
    if nid and NetworkDoesNetworkIdExist(nid) then
        local ent = NetworkGetEntityFromNetworkId(nid)
        if ent ~= 0 and DoesEntityExist(ent) then return ent end
    end
    return 0
end

local function onAnyPdBag(_, bagName)
    Wait(25)
    local ent = resolveEntityFromBagName(bagName)
    if ent ~= 0 and IsEntityAVehicle(ent) then
        ingestFromEntity(ent)
    end
end

AddStateBagChangeHandler('ltPdSirenMode', '', onAnyPdBag)

AddStateBagChangeHandler('ltPdKit', '', onAnyPdBag)

CreateThread(function()
    --- Laikinai palaiko natyvias sirenas užrakinant „lights/full“ prieš GTA resetą
    while true do
        Wait(360)
        for veh, meta in pairs(TRACKED) do
            if not DoesEntityExist(veh) then
                stopScriptSound(veh)
                TRACKED[veh] = nil
            else
                local mode = select(1, readVehicleStateBag(veh))
                if mode ~= 'off' and meta.supportsNative then
                    if mode == 'lights' then
                        SetVehicleSiren(veh, true)
                        SetVehicleHasMutedSirens(veh, true)
                    elseif mode == 'full' then
                        SetVehicleSiren(veh, true)
                        SetVehicleHasMutedSirens(veh, false)
                    elseif mode == 'sound' then
                        stopNativeSirenVisual(veh)
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(42)
        local drew = false
        for veh, meta in pairs(TRACKED) do
            if not DoesEntityExist(veh) then
                stopScriptSound(veh)
                TRACKED[veh] = nil
            else
                local mode = select(1, readVehicleStateBag(veh))
                local nat = meta.supportsNative
                if (mode == 'lights' or mode == 'full') and (not nat) then
                    drawScriptFlash(veh)
                    drew = true
                end
            end
        end
        if not drew then Wait(200) end
    end
end)

--- Sceninė sirena („garsas tik“ civilinei TP arba tarnybinei kai pasirinkta tik sirena).
CreateThread(function()
    while true do
        Wait(780)
        for veh, meta in pairs(TRACKED) do
            if not DoesEntityExist(veh) then
                stopScriptSound(veh)
                TRACKED[veh] = nil
            else
                local mode = select(1, readVehicleStateBag(veh))
                local nat = meta.supportsNative
                local needSound = (mode == 'sound') or (mode == 'full' and (not nat))
                if mode == 'off' then
                    stopScriptSound(veh)
                elseif needSound then
                    playShortSirenBurst(veh)
                else
                    stopScriptSound(veh)
                end
            end
        end
    end
end)

CreateThread(function()
    local lastVehAsDriver = 0
    while true do
        Wait(275)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            lastVehAsDriver = veh
            if pdOnDuty() then ingestFromEntity(veh) end
        elseif lastVehAsDriver ~= 0 then
            if RESET_ON_EXIT and pdOnDuty() and DoesEntityExist(lastVehAsDriver) then
                local netId = safeVehicleNetId(lastVehAsDriver)
                if netId ~= 0 then
                    TriggerServerEvent('fivempro_ltpd:server:clearPdEmergencyOnExit', netId)
                end
            end
            if DoesEntityExist(lastVehAsDriver) then ingestFromEntity(lastVehAsDriver) end
            lastVehAsDriver = 0
        end
    end
end)

local function openSirenModesMenu()
    if not canPdSirenMenu() then
        return QBCore.Functions.Notify('Šis meniu – tik tarnybiniu policininkų.', 'error')
    end
    local veh = getDriverVehicleLocal()
    if not veh then
        return QBCore.Functions.Notify('Turi būti vairo vietoje.', 'error')
    end
    local _, kit = readVehicleStateBag(veh)
    if (not vehicleSupportsNativeEmergency(veh)) and kit ~= true then
        return QBCore.Functions.Notify(
            'Ant įprastos TP pirmiau įjunk laikinas sirenas (komanda /pdiranga).',
            'error'
        )
    end
    ingestFromEntity(veh)
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local menu = {
        { header = 'PD šviestuvai ir sirenos', txt = 'Iškvietimo kodas veikia kol perjungi į off', isMenuHeader = true },
        {
            header = '① Tik žibintai (silent)',
            txt = 'Mirksinčios tarnybinės šviesos – be garso.',
            params = { event = 'fivempro_ltpd:client:setPdEmergencyMode', args = { mode = 'lights' } },
        },
        {
            header = '② Tik sirena (garsas)',
            txt = 'Garsinė sirena — civilinėje mašinoje kartu žibinti scenoje.',
            params = { event = 'fivempro_ltpd:client:setPdEmergencyMode', args = { mode = 'sound' } },
        },
        {
            header = '③ Šviesos + sirena (pilnas)',
            txt = 'Pilnas režimas (tarnybinei mašinai – GTA sirenos).',
            params = { event = 'fivempro_ltpd:client:setPdEmergencyMode', args = { mode = 'full' } },
        },
        {
            header = 'Išjungti',
            txt = 'Visi kodai išjungiami.',
            params = { event = 'fivempro_ltpd:client:setPdEmergencyMode', args = { mode = 'off' } },
        },
        { header = '< Užverti meniu', params = { event = 'qb-menu:client:closeMenu' } },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

RegisterNetEvent('fivempro_ltpd:client:setPdEmergencyMode', function(data)
    local mode = data and data.mode or 'off'
    TriggerServerEvent('fivempro_ltpd:server:setPdEmergencyMode', mode)
    SetTimeout(200, function()
        local veh = getDriverVehicleLocal()
        if veh then ingestFromEntity(veh) end
    end)
end)

local function openKitMenu()
    if not canPdEmergencyKit() then
        return QBCore.Functions.Notify('Neturi teisės montuoti įrangos.', 'error')
    end
    local veh = getDriverVehicleLocal()
    if not veh then
        return QBCore.Functions.Notify('Turi būti vairo vietoje.', 'error')
    end
    if vehicleSupportsNativeEmergency(veh) then
        return QBCore.Functions.Notify('Šiai mašinai nereikia – jau tarnybinė arba turi sirenas.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local menu = {
        { header = 'PD laikinos sirenos civilinei TP', txt = 'Iki nuėmimo statebag išlieka tame pačiame TA', isMenuHeader = true },
        {
            header = 'Įmontuoti sirenas ir lempas',
            txt = 'Leidžia naudoti meniu kodą tame pačiame auto.',
            params = { event = 'fivempro_ltpd:client:setPdEmergencyKit', args = { equip = true } },
        },
        {
            header = 'Nuimti įrangą',
            txt = 'Pasiekiama tame pačiame vairuojamame TA.',
            params = { event = 'fivempro_ltpd:client:setPdEmergencyKit', args = { equip = false } },
        },
        { header = '< Užverti meniu', params = { event = 'qb-menu:client:closeMenu' } },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

RegisterNetEvent('fivempro_ltpd:client:setPdEmergencyKit', function(data)
    local equip = data and data.equip == true
    TriggerServerEvent('fivempro_ltpd:server:setPdEmergencyKit', equip)
    SetTimeout(240, function()
        local veh = getDriverVehicleLocal()
        if veh then ingestFromEntity(veh) end
    end)
end)

local cmdLights = Ec.sirenMenuCommand or 'pdsirenai'
local cmdKit = Ec.kitMenuCommand or 'pdiranga'

RegisterCommand(cmdLights, openSirenModesMenu, false)
RegisterCommand(cmdKit, openKitMenu, false)
