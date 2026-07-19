local QBCore = exports['qb-core']:GetCoreObject()

local session = nil
local bankTellerPeds = {}
local bagProp = nil

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

local function spawnBankTellers()
    for locId, def in pairs(Config.Robberies.BankTellers or {}) do
        if bankTellerPeds[locId] and DoesEntityExist(bankTellerPeds[locId]) then goto continue end
        local hash = loadModel(def.model or 'ig_bankman')
        if not hash then goto continue end
        local c = def.coords
        local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w or 0.0, false, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        bankTellerPeds[locId] = ped
        ::continue::
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

local function findFleecaLocByPed(entity)
    for locId, ped in pairs(bankTellerPeds) do
        if ped == entity then
            for _, loc in ipairs((Config.Robberies.Locations and Config.Robberies.Locations.bank_fleeca) or {}) do
                if loc.id == locId then return loc end
            end
        end
    end
    return nil
end

local function isAimingAt(entity)
    local ped = PlayerPedId()
    if not IsPlayerFreeAiming(PlayerId()) then return false end
    local ok, ent = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if ok and ent == entity then return true end
    --- fallback: close aim
    if IsControlPressed(0, 25) then -- aim
        local p = GetEntityCoords(ped)
        local t = GetEntityCoords(entity)
        if #(p - t) < 6.0 then
            local cam = GetGameplayCamCoord()
            local dir = GetEntityForwardVector(ped)
            local to = t - cam
            local len = #to
            if len > 0.1 then
                to = to / len
                local dot = dir.x * to.x + dir.y * to.y + dir.z * to.z
                if dot > 0.82 then return true end
            end
        end
    end
    return false
end

local function throwBagAtPed(fromPed)
    clearBag()
    local model = loadModel((Config.Robberies.Teller and Config.Robberies.Teller.bagProp) or 'prop_money_bag_01')
    if not model then return end
    local fc = GetEntityCoords(fromPed)
    local pc = GetEntityCoords(PlayerPedId())
    bagProp = CreateObject(model, fc.x, fc.y, fc.z + 0.4, true, true, false)
    local dx, dy = pc.x - fc.x, pc.y - fc.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.1 then len = 1.0 end
    local force = (Config.Robberies.Teller and Config.Robberies.Teller.bagThrowForce) or 2.5
    ApplyForceToEntity(bagProp, 1, (dx / len) * force, (dy / len) * force, 0.8, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
end

local function runTellerSession(kind, loc, entity)
    if session then return end
    if exports['mrp_hacking']:IsRobberySessionActive and exports['mrp_hacking']:IsRobberySessionActive() then
        return QBCore.Functions.Notify('Jau vyksta apiplėšimas.', 'error')
    end

    QBCore.Functions.TriggerCallback('mrp_hacking:server:tellerStart', function(res)
        if not res or not res.ok then
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
        if kind == 'store' then
            QBCore.Functions.Notify('Laikyk taikiklį — kasininkas krauna pinigus iš tikros kasos (ne Perlas).', 'primary', 7000)
        else
            QBCore.Functions.Notify('Laikyk taikiklį ant kasininko — jis krauna pinigus į maišą.', 'primary', 7000)
        end

        local fillMs = (Config.Robberies.Timings and Config.Robberies.Timings.tellerFill) or 12000
        local aimedMs = 0
        local last = GetGameTimer()

        CreateThread(function()
            while session and (session.phase == 'aim' or session.phase == 'bag' or session.phase == 'wait_release') do
                local now = GetGameTimer()
                local dt = now - last
                last = now
                local aiming = DoesEntityExist(entity) and isAimingAt(entity)

                if session.phase == 'wait_release' then
                    --- Po maišo: PD kai nustoja taikytis
                    if not aiming then
                        if not session.alerted then
                            session.alerted = true
                            TriggerServerEvent('mrp_hacking:server:tellerComplete', kind, session.locId, true, true)
                            QBCore.Functions.Notify('Nustojai taikytis — policija iškviesta.', 'error')
                        end
                        session = nil
                        break
                    end
                    BeginTextCommandPrint('STRING')
                    AddTextComponentSubstringPlayerName('Kai nustoji taikytis — PD gaus pranešimą…')
                    EndTextCommandPrint(200, true)
                elseif session.phase == 'bag' then
                    --- progressbar — nieko
                elseif aiming then
                    aimedMs = aimedMs + dt
                    local pct = math.min(100, math.floor(aimedMs / fillMs * 100))
                    BeginTextCommandPrint('STRING')
                    AddTextComponentSubstringPlayerName(('Kasininkas krauna maišą… %d%%'):format(pct))
                    EndTextCommandPrint(200, true)

                    if aimedMs >= fillMs and not session.filled then
                        session.filled = true
                        session.phase = 'bag'
                        TaskHandsUp(entity, 8000, PlayerPedId(), -1, true)
                        throwBagAtPed(entity)
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
                            if kind == 'store' then
                                --- Pinigus duodam dabar, PD — kai nustos taikytis
                                TriggerServerEvent('mrp_hacking:server:tellerComplete', kind, session.locId, true, false)
                                session.phase = 'wait_release'
                                QBCore.Functions.Notify('Maišas paimtas. Nustok taikytis — tada PD gaus pranešimą. Gali eiti prie Perlas / seifo.', 'primary', 9000)
                            else
                                TriggerServerEvent('mrp_hacking:server:tellerComplete', kind, session.locId, true, true)
                                session = nil
                            end
                        end, function()
                            TriggerServerEvent('mrp_hacking:server:tellerAbort', kind, session and session.locId)
                            clearBag()
                            session = nil
                        end)
                    end
                else
                    --- Nustojo taikytis prieš maišą
                    if session.filled then
                        --- progress vyksta
                    elseif aimedMs > 1500 then
                        TriggerServerEvent('mrp_hacking:server:tellerAbort', kind, session.locId)
                        QBCore.Functions.Notify('Nustojai taikytis — policija iškviesta.', 'error')
                        session = nil
                        break
                    end
                end
                Wait(0)
            end
        end)
    end, kind, loc and loc.id)
end

RegisterNetEvent('mrp_hacking:client:tellerUnlockBooth', function(locId)
    local door = (Config.Robberies.BoothDoors or {})[locId]
    if not door then return end
    local obj = GetClosestObjectOfType(door.coords.x, door.coords.y, door.coords.z, door.radius or 2.0, joaat(door.model), false, false, false)
    if obj and obj ~= 0 then
        NetworkRequestControlOfEntity(obj)
        FreezeEntityPosition(obj, false)
        SetEntityHeading(obj, GetEntityHeading(obj) + 90.0)
        QBCore.Functions.Notify('Kasininko būdelės durys atrakintos.', 'success')
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(400) end
    Wait(1500)
    spawnBankTellers()

    --- Store cashiers (existing shop peds)
    exports['qb-target']:AddTargetModel({ `mp_m_shopkeep_01`, `mp_m_shopkeep_01` }, {
        options = {
            {
                icon = 'fas fa-gun',
                label = 'Apiplėšti kasininką (tikra kasa)',
                canInteract = function(entity)
                    if session then return false end
                    local c = GetEntityCoords(entity)
                    return findNearestStoreLoc(c) ~= nil
                end,
                action = function(entity)
                    local loc = findNearestStoreLoc(GetEntityCoords(entity))
                    if loc then runTellerSession('store', loc, entity) end
                end,
            },
        },
        distance = 2.2,
    })

    --- Bank tellers
    for locId, ped in pairs(bankTellerPeds) do
        if DoesEntityExist(ped) then
            exports['qb-target']:AddTargetEntity(ped, {
                options = {
                    {
                        icon = 'fas fa-gun',
                        label = 'Apiplėšti kasininką (be seifo)',
                        canInteract = function()
                            return session == nil
                        end,
                        action = function(entity)
                            local loc = findFleecaLocByPed(entity)
                            if loc then runTellerSession('bank_fleeca', loc, entity) end
                        end,
                    },
                },
                distance = 2.4,
            })
        end
    end
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
