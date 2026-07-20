local QBCore = exports['qb-core']:GetCoreObject()

local session = nil
local starting = false
local bankTellerPeds = {}
local bagProp = nil
local intimidateUntil = 0

local STORE_MODELS = {
    `mp_m_shopkeep_01`,
    `s_m_y_shop_mask`,
    `s_f_y_shop_low`,
    `s_f_y_shop_mid`,
    `s_m_m_linecook`,
}

local HANDSUP_DICT = 'random@mugging3'
local HANDSUP_CLIP = 'handsup_standing_base'

local function clearBag()
    if bagProp and DoesEntityExist(bagProp) then DeleteEntity(bagProp) end
    bagProp = nil
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function camForward()
    local rot = GetGameplayCamRot(2)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function requestPedControl(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if not NetworkGetEntityIsNetworked(ped) then return true end
    if NetworkHasControlOfEntity(ped) then return true end
    NetworkRequestControlOfEntity(ped)
    local t = GetGameTimer() + 800
    while not NetworkHasControlOfEntity(ped) and GetGameTimer() < t do
        NetworkRequestControlOfEntity(ped)
        Wait(0)
    end
    return NetworkHasControlOfEntity(ped)
end

local function intimidatePed(ped, force)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    local now = GetGameTimer()
    if not force and now < intimidateUntil then return end
    intimidateUntil = now + 2500
    requestPedControl(ped)
    FreezeEntityPosition(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)
    ClearPedTasksImmediately(ped)
    if loadAnimDict(HANDSUP_DICT) then
        TaskPlayAnim(ped, HANDSUP_DICT, HANDSUP_CLIP, 8.0, -8.0, -1, 49, 0.0, false, false, false)
    else
        TaskHandsUp(ped, 120000, PlayerPedId(), -1, true)
    end
end

local function restorePedIdle(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    requestPedControl(ped)
    if loadAnimDict(HANDSUP_DICT) then
        ClearPedTasksImmediately(ped)
        TaskPlayAnim(ped, HANDSUP_DICT, HANDSUP_CLIP, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
end

local function unlockBoothDoor(locId)
    local door = (Config.Robberies.BoothDoors or {})[locId]
    if not door then return end
    local obj = GetClosestObjectOfType(door.coords.x, door.coords.y, door.coords.z, door.radius or 2.0, joaat(door.model), false, false, false)
    if obj and obj ~= 0 then
        NetworkRequestControlOfEntity(obj)
        FreezeEntityPosition(obj, false)
        SetEntityHeading(obj, GetEntityHeading(obj) + 90.0)
        QBCore.Functions.Notify('Kasininko būdelės durys atrakintos.', 'success')
    end
end

local function findNearestStoreLoc(coords)
    local best, bestD = nil, 4.0
    for _, loc in ipairs((Config.Robberies.Locations and Config.Robberies.Locations.store) or {}) do
        local tc = loc.tellerCoords
        if tc then
            local d = #(coords - vector3(tc.x, tc.y, tc.z))
            if d < bestD then bestD = d; best = loc end
        end
    end
    return best
end

local function findBankLocByPed(entity)
    for locId, ped in pairs(bankTellerPeds) do
        if ped == entity then
            for _, tier in ipairs({ 'bank_fleeca', 'bank_main' }) do
                for _, loc in ipairs((Config.Robberies.Locations and Config.Robberies.Locations[tier]) or {}) do
                    if loc.id == locId then return loc, tier end
                end
            end
            return { id = locId, label = locId }, (locId == 'pacific_main' and 'bank_main' or 'bank_fleeca')
        end
    end
    if entity and DoesEntityExist(entity) then
        local ec = GetEntityCoords(entity)
        local bestId, bestD = nil, 2.8
        for locId, def in pairs(Config.Robberies.BankTellers or {}) do
            local c = def.coords
            local d = #(ec - vector3(c.x, c.y, c.z))
            if d < bestD then bestD = d; bestId = locId end
        end
        if bestId then
            for _, tier in ipairs({ 'bank_fleeca', 'bank_main' }) do
                for _, loc in ipairs((Config.Robberies.Locations and Config.Robberies.Locations[tier]) or {}) do
                    if loc.id == bestId then return loc, tier end
                end
            end
            return { id = bestId, label = bestId }, (bestId == 'pacific_main' and 'bank_main' or 'bank_fleeca')
        end
    end
    return nil
end

local function isWeaponAimed()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return false end
    local weapon = GetSelectedPedWeapon(ped)
    if not weapon or weapon == `WEAPON_UNARMED` or weapon == 0 then return false end
    if IsPlayerFreeAiming(PlayerId()) then return true end
    if IsControlPressed(0, 25) then return true end
    return false
end

local function freeAimEntity()
    local a, b = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if type(a) == 'boolean' then
        if a and b and b ~= 0 and DoesEntityExist(b) then return b end
        return nil
    end
    if type(a) == 'number' and a ~= 0 and DoesEntityExist(a) then return a end
    if type(b) == 'number' and b ~= 0 and DoesEntityExist(b) then return b end
    return nil
end

local function isAimingAt(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if not isWeaponAimed() then return false end

    local aimed = freeAimEntity()
    if aimed == entity then return true end

    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local t = GetEntityCoords(entity)
    local dist = #(p - t)
    if dist > 9.0 then return false end

    local cam = GetGameplayCamCoord()
    local dir = camForward()
    local to = t - cam
    local len = #to
    if len < 0.15 then return true end
    to = to / len
    local dot = dir.x * to.x + dir.y * to.y + dir.z * to.z
    if dist < 5.0 and dot > 0.62 then return true end
    if dist < 8.0 and dot > 0.78 then return true end
    return false
end

local function isStoreCashierModel(entity)
    if not DoesEntityExist(entity) then return false end
    local model = GetEntityModel(entity)
    for i = 1, #STORE_MODELS do
        if model == STORE_MODELS[i] then return true end
    end
    return false
end

local function resolveAimTarget()
    local aimed = freeAimEntity()
    if aimed and IsEntityAPed(aimed) and not IsPedAPlayer(aimed) then
        local bankLoc, kind = findBankLocByPed(aimed)
        if bankLoc then
            return kind or 'bank_fleeca', bankLoc, aimed
        end
        if isStoreCashierModel(aimed) then
            local loc = findNearestStoreLoc(GetEntityCoords(aimed))
            if loc then return 'store', loc, aimed end
        end
    end

    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local cam = GetGameplayCamCoord()
    local dir = camForward()

    for _, teller in pairs(bankTellerPeds) do
        if DoesEntityExist(teller) and isAimingAt(teller) then
            local loc, kind = findBankLocByPed(teller)
            if loc then return kind or 'bank_fleeca', loc, teller end
        end
    end

    local handle, ent = FindFirstPed()
    local success = true
    local best, bestScore, bestLoc = nil, 0.0, nil
    while success do
        if DoesEntityExist(ent) and not IsPedAPlayer(ent) and not IsPedDeadOrDying(ent, true)
            and isStoreCashierModel(ent) then
            local t = GetEntityCoords(ent)
            local dist = #(p - t)
            if dist < 7.5 then
                local to = t - cam
                local len = #to
                if len > 0.1 then
                    to = to / len
                    local dot = dir.x * to.x + dir.y * to.y + dir.z * to.z
                    if dot > 0.70 then
                        local loc = findNearestStoreLoc(t)
                        if loc then
                            local score = dot * (8.0 - dist)
                            if score > bestScore then
                                bestScore, best, bestLoc = score, ent, loc
                            end
                        end
                    end
                end
            end
        end
        success, ent = FindNextPed(handle)
    end
    EndFindPed(handle)

    if best and bestLoc then
        return 'store', bestLoc, best
    end
    return nil
end

local function placeBagOnCounter(fromPed)
    clearBag()
    local model = loadModel((Config.Robberies.Teller and Config.Robberies.Teller.bagProp) or 'prop_money_bag_01')
    if not model then return end
    local cfg = Config.Robberies.Teller or {}
    local forward = tonumber(cfg.counterForward) or 0.55
    local up = tonumber(cfg.counterUp) or 0.95
    local force = tonumber(cfg.bagThrowForce) or 0.0
    local fc = GetEntityCoords(fromPed)
    local fwd = GetEntityForwardVector(fromPed)
    local px = fc.x + fwd.x * forward
    local py = fc.y + fwd.y * forward
    local pz = fc.z + up
    bagProp = CreateObject(model, px, py, pz, true, true, false)
    SetEntityCoordsNoOffset(bagProp, px, py, pz, false, false, false)
    if force > 0.1 then
        local pc = GetEntityCoords(PlayerPedId())
        local dx, dy = pc.x - px, pc.y - py
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 0.1 then len = 1.0 end
        ApplyForceToEntity(bagProp, 1, (dx / len) * force, (dy / len) * force, 0.35, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
    else
        FreezeEntityPosition(bagProp, true)
    end
end

local runTellerSession

local function addTellerTarget(ped)
    if not ped or not DoesEntityExist(ped) then return end
    if GetResourceState('qb-target') ~= 'started' then return end
    pcall(function()
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = 'fas fa-gun',
                    label = 'Apiplėšti kasininką (be seifo)',
                    canInteract = function()
                        if session or starting then return false end
                        local weapon = GetSelectedPedWeapon(PlayerPedId())
                        return weapon and weapon ~= `WEAPON_UNARMED`
                    end,
                    action = function(entity)
                        local loc, kind = findBankLocByPed(entity)
                        if loc then runTellerSession(kind or 'bank_fleeca', loc, entity) end
                    end,
                },
            },
            distance = 2.6,
        })
    end)
end

local function deleteTeller(locId)
    local ped = bankTellerPeds[locId]
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    bankTellerPeds[locId] = nil
end

local function spawnOneTeller(locId, def)
    if bankTellerPeds[locId] and DoesEntityExist(bankTellerPeds[locId]) then
        return bankTellerPeds[locId]
    end
    local hash = loadModel(def.model or 'ig_bankman')
    if not hash then hash = loadModel('a_m_m_business_01') end
    if not hash then return nil end

    local c = def.coords
    --- Lokalus ped — networked CreatePed interjere dažnai dingsta
    local ped = CreatePed(4, hash, c.x, c.y, c.z, c.w or 0.0, false, true)
    if not ped or ped == 0 then
        SetModelAsNoLongerNeeded(hash)
        return nil
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetPedCanRagdoll(ped, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanBeTargetted(ped, true)
    --- NENAUDOJAM GetGroundZ — banko interjere nukiša po grindimis
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, c.w or 0.0)
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    SetModelAsNoLongerNeeded(hash)

    bankTellerPeds[locId] = ped
    addTellerTarget(ped)
    return ped
end

local function spawnBankTellersNear(playerCoords, radius)
    radius = radius or 90.0
    for locId, def in pairs(Config.Robberies.BankTellers or {}) do
        local c = def.coords
        local d = #(playerCoords - vector3(c.x, c.y, c.z))
        if d <= radius then
            spawnOneTeller(locId, def)
        elseif d > radius + 50.0 then
            deleteTeller(locId)
        end
    end
end

runTellerSession = function(kind, loc, entity)
    if session or starting then return end
    if not entity or not DoesEntityExist(entity) then return end
    if exports['mrp_hacking']:IsRobberySessionActive and exports['mrp_hacking']:IsRobberySessionActive() then
        return QBCore.Functions.Notify('Jau vyksta apiplėšimas.', 'error')
    end

    starting = true
    intimidatePed(entity, true)

    QBCore.Functions.TriggerCallback('mrp_hacking:server:tellerStart', function(res)
        starting = false
        if not res or not res.ok then
            restorePedIdle(entity)
            return QBCore.Functions.Notify((res and res.msg) or 'Negalima.', 'error')
        end
        session = {
            kind = kind,
            locId = loc and loc.id,
            entity = entity,
            phase = 'aim',
            filled = false,
            bagTaken = false,
            alerted = false,
        }
        intimidatePed(entity, true)
        if kind == 'store' then
            QBCore.Functions.Notify('Laikyk taikiklį — kasininkas krauna pinigus iš tikros kasos (ne Perlas).', 'primary', 7000)
        else
            QBCore.Functions.Notify('Laikyk taikiklį ant kasininko — jis krauna pinigus į maišą.', 'primary', 7000)
        end

        local fillMs = (Config.Robberies.Timings and Config.Robberies.Timings.tellerFill)
            or (((Config.Robberies.Teller and Config.Robberies.Teller.aimSeconds) or 12) * 1000)
        local aimedMs = 0
        local last = GetGameTimer()

        CreateThread(function()
            while session and (session.phase == 'aim' or session.phase == 'bag' or session.phase == 'wait_release') do
                local now = GetGameTimer()
                local dt = now - last
                last = now
                local alive = DoesEntityExist(entity)
                local aiming = alive and isAimingAt(entity)

                if alive and (aiming or session.phase == 'bag' or session.phase == 'wait_release') then
                    intimidatePed(entity, false)
                end

                if session.phase == 'wait_release' then
                    if not aiming then
                        if not session.alerted then
                            session.alerted = true
                            TriggerServerEvent('mrp_hacking:server:tellerComplete', kind, session.locId, true, true)
                            QBCore.Functions.Notify('Nustojai taikytis — policija iškviesta.', 'error')
                        end
                        restorePedIdle(entity)
                        session = nil
                        break
                    end
                    BeginTextCommandPrint('STRING')
                    AddTextComponentSubstringPlayerName('Kai nustoji taikytis — PD gaus pranešimą…')
                    EndTextCommandPrint(200, true)
                elseif session.phase == 'bag' then
                    --- progressbar
                elseif aiming then
                    aimedMs = aimedMs + dt
                    local pct = math.min(100, math.floor(aimedMs / fillMs * 100))
                    BeginTextCommandPrint('STRING')
                    AddTextComponentSubstringPlayerName(('Kasininkas krauna maišą… %d%%'):format(pct))
                    EndTextCommandPrint(200, true)

                    if aimedMs >= fillMs and not session.filled then
                        session.filled = true
                        session.phase = 'bag'
                        intimidatePed(entity, true)
                        placeBagOnCounter(entity)
                        if kind ~= 'store' and session.locId then
                            unlockBoothDoor(session.locId)
                        end
                        QBCore.Functions.Progressbar('teller_grab_bag', 'Imamas maišas…', 3500, false, true, {
                            disableMovement = true,
                            disableCarMovement = true,
                            disableMouse = false,
                            disableCombat = true,
                        }, {
                            animDict = 'anim@heists@ornate_bank@grab_cash',
                            anim = 'grab',
                            flags = 49,
                        }, {}, {}, function()
                            clearBag()
                            if not session then return end
                            session.bagTaken = true
                            TriggerServerEvent('mrp_hacking:server:tellerComplete', kind, session.locId, true, false)
                            session.phase = 'wait_release'
                            if kind == 'store' then
                                QBCore.Functions.Notify('Maišas paimtas. Nustok taikytis — PD. Seifą gali gręžti be kasininko.', 'primary', 9000)
                            else
                                QBCore.Functions.Notify('Maišas paimtas, būdelė atrakinta. Nustok taikytis — tada PD gaus pranešimą.', 'primary', 9000)
                            end
                        end, function()
                            TriggerServerEvent('mrp_hacking:server:tellerAbort', kind, session and session.locId)
                            clearBag()
                            restorePedIdle(entity)
                            session = nil
                        end)
                    end
                else
                    if session.filled then
                        --- progress
                    elseif aimedMs > 1500 then
                        TriggerServerEvent('mrp_hacking:server:tellerAbort', kind, session.locId)
                        QBCore.Functions.Notify('Nustojai taikytis — policija iškviesta.', 'error')
                        restorePedIdle(entity)
                        session = nil
                        break
                    end
                end
                Wait(0)
            end
        end)
    end, kind, loc and loc.id)
end

CreateThread(function()
    while true do
        local sleep = 400
        if not session and not starting and isWeaponAimed() then
            sleep = 120
            local kind, loc, entity = resolveAimTarget()
            if kind and loc and entity then
                sleep = 0
                intimidatePed(entity, false)
                if isAimingAt(entity) then
                    runTellerSession(kind, loc, entity)
                    Wait(800)
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('mrp_hacking:client:tellerUnlockBooth', function(locId)
    unlockBoothDoor(locId)
end)

--- Spawn kai priartėji prie banko
CreateThread(function()
    while true do
        spawnBankTellersNear(GetEntityCoords(PlayerPedId()), 100.0)
        Wait(2500)
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(400) end
    Wait(1000)
    exports['qb-target']:AddTargetModel(STORE_MODELS, {
        options = {
            {
                icon = 'fas fa-gun',
                label = 'Apiplėšti kasininką (tikra kasa)',
                canInteract = function(entity)
                    if session or starting then return false end
                    local weapon = GetSelectedPedWeapon(PlayerPedId())
                    if not weapon or weapon == `WEAPON_UNARMED` then return false end
                    return findNearestStoreLoc(GetEntityCoords(entity)) ~= nil
                end,
                action = function(entity)
                    local loc = findNearestStoreLoc(GetEntityCoords(entity))
                    if loc then runTellerSession('store', loc, entity) end
                end,
            },
        },
        distance = 2.2,
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBag()
    for _, ped in pairs(bankTellerPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    bankTellerPeds = {}
    session = nil
end)
