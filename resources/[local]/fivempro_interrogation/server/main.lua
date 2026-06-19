local QBCore = exports['qb-core']:GetCoreObject()

Sessions = {}
PendingConsent = {}

local function sessionKey(kind, id)
    return ('%s:%s'):format(tostring(kind), tostring(id))
end

function sessionOnKit(kitId)
    kitId = tonumber(kitId)
    for key, s in pairs(Sessions) do
        if s.locationKind == 'kit' and tonumber(s.locationId) == kitId then
            return true
        end
    end
    return false
end

local function stationById(id)
    for _, st in ipairs(Config.PoliceStations or {}) do
        if st.id == id then return st end
    end
end

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function nearCoords(src, center, radius)
    local c = playerCoords(src)
    if not c or not center then return false end
    return #(c - center) <= (radius or 8.0)
end

local function nearPlayer(src, otherSrc, maxDist)
    local c1 = playerCoords(src)
    local c2 = playerCoords(otherSrc)
    if not c1 or not c2 then return false end
    return #(c1 - c2) <= (maxDist or 6.0)
end

local function inStation(src, st)
    return nearCoords(src, st.center, st.radius or 14.0)
end

local function suspectInRange(leadSrc, suspectSrc, st)
    if inStation(suspectSrc, st) then return true end
    return nearPlayer(leadSrc, suspectSrc, math.max(6.0, (st.radius or 4.5) + 1.5))
end

local function inKitZone(src, kit)
    if not kit then return false end
    local r = (Config.GangKit and Config.GangKit.sessionRadius) or 7.0
    return nearCoords(src, vector3(kit.x, kit.y, kit.z), r)
end

local function personName(P)
    if not P or not P.PlayerData or not P.PlayerData.charinfo then return 'Nežinomas' end
    local ch = P.PlayerData.charinfo
    return ((ch.firstname or '') .. ' ' .. (ch.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
end

function adminLog(src, action, message, meta)
    if GetResourceState('fivempro_playerlog') ~= 'started' then return end
    pcall(function()
        exports['fivempro_playerlog']:LogPlayer(src, 'interrogation', action, message, meta, 'orange')
    end)
end

local function isPoliceOnDuty(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not P.PlayerData.job then return false end
    local j = P.PlayerData.job
    return j.name == Config.PoliceJob and j.onduty == true and (j.grade and j.grade.level or 0) >= (Config.PoliceMinGrade or 0)
end

local function isGangMember(citizenid)
    if not Config.CriminalRequiresGang then return true end
    local row = MySQL.scalar.await(
        'SELECT gang_id FROM fivempro_gang_members WHERE citizenid = ? LIMIT 1',
        { citizenid }
    )
    return row ~= nil
end

function canLeadCriminal(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    if QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god') then
        return true
    end
    return isGangMember(P.PlayerData.citizenid)
end

local function bumpPressure(s, amount)
    s.pressure = math.min(Config.MaxPressure or 100, (s.pressure or 0) + (amount or 5))
end

local function broadcastSession(key, eventName, ...)
    local s = Sessions[key]
    if not s then return end
    TriggerClientEvent(eventName, s.leadSrc, ...)
    if s.suspectSrc and s.suspectSrc ~= s.leadSrc then
        TriggerClientEvent(eventName, s.suspectSrc, ...)
    end
end

local function syncState(key)
    local s = Sessions[key]
    if not s then return end
    local payload = {
        locationKind = s.locationKind,
        locationId = s.locationId,
        mode = s.mode,
        seated = s.seated,
        intense = s.intense,
        suspectAnim = s.suspectAnim,
        spotlight = s.spotlight,
        pressure = s.pressure,
        animLead = s.pendingAnimLead,
        animSuspect = s.pendingAnimSuspect,
        noise = s.pendingNoise,
        kit = s.kitSnapshot,
        stationId = s.stationId,
    }
    s.pendingAnimLead = nil
    s.pendingAnimSuspect = nil
    s.pendingNoise = nil
    broadcastSession(key, 'fivempro_interrogation:client:syncState', payload)
end

local function endSessionInternal(key, reason)
    local s = Sessions[key]
    if not s then return end
    Sessions[key] = nil
    broadcastSession(key, 'fivempro_interrogation:client:sessionEnded')
    adminLog(s.leadSrc, 'session_end', ('Baigta %s: %s'):format(key, reason or ''), {
        suspect = s.suspectCitizenid,
        mode = s.mode,
    })
end

local function validateLocation(src, kind, id)
    if kind == 'station' then
        local st = stationById(id)
        if not st then return nil, 'Stotis nerasta.' end
        if not isPoliceOnDuty(src) then return nil, 'Tik pareigūnai tarnyboje.' end
        if not inStation(src, st) then return nil, 'Turite būti apklausos zonoje.' end
        return st
    end
    if kind == 'kit' then
        if not canLeadCriminal(src) then return nil, 'Reikia gaujos narystės.' end
        local kit = Kits and Kits.get(tonumber(id))
        if not kit then return nil, 'Įranga nerasta.' end
        if not inKitZone(src, kit) then return nil, 'Per toli nuo įrangos.' end
        return kit
    end
    return nil, 'Nežinoma vieta.'
end

RegisterNetEvent('fivempro_interrogation:server:requestStart', function(locationKind, locationId, suspectSrc)
    local src = source
    locationKind = tostring(locationKind or '')
    locationId = tostring(locationId or '')
    suspectSrc = tonumber(suspectSrc)
    local loc, err = validateLocation(src, locationKind, locationId)
    if not loc then
        return TriggerClientEvent('QBCore:Notify', src, err or 'Klaida.', 'error')
    end

    local key = sessionKey(locationKind, locationId)
    if Sessions[key] then
        return TriggerClientEvent('QBCore:Notify', src, 'Čia jau vyksta sesija.', 'error')
    end
    if not suspectSrc or suspectSrc == src then
        return TriggerClientEvent('QBCore:Notify', src, 'Pasirink kitą žaidėją.', 'error')
    end
    if not GetPlayerPed(suspectSrc) or GetPlayerPed(suspectSrc) == 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas neprisijungęs.', 'error')
    end

    local mode = locationKind == 'station' and 'police' or 'criminal'
    if locationKind == 'station' then
        if not suspectInRange(src, suspectSrc, loc) then
            return TriggerClientEvent('QBCore:Notify', src, 'Įtariamasis turi būti šalia tavęs kambaryje.', 'error')
        end
    else
        if not inKitZone(suspectSrc, loc) then
            return TriggerClientEvent('QBCore:Notify', src, 'Įtariamasis turi būti prie įrangos.', 'error')
        end
    end

    local Lead = QBCore.Functions.GetPlayer(src)
    local Suspect = QBCore.Functions.GetPlayer(suspectSrc)
    if not Lead or not Suspect then return end

    local label = locationKind == 'station' and loc.label or ('Gaujų įranga #' .. locationId)

    PendingConsent[suspectSrc] = {
        key = key,
        locationKind = locationKind,
        locationId = locationId,
        mode = mode,
        leadSrc = src,
        label = label,
        expires = os.time() + (Config.ConsentTimeoutSec or 90),
    }

    TriggerClientEvent('fivempro_interrogation:client:consentPrompt', suspectSrc, {
        leadName = personName(Lead),
        roomLabel = label,
        mode = mode,
    })
    TriggerClientEvent('QBCore:Notify', src, 'Laukiama sutikimo…', 'primary')
    adminLog(src, 'consent_request', label, { suspect = Suspect.PlayerData.citizenid, mode = mode })
end)

RegisterNetEvent('fivempro_interrogation:server:consent', function(accept)
    local src = source
    local pending = PendingConsent[src]
    PendingConsent[src] = nil
    if not pending then return end
    if os.time() > (pending.expires or 0) then
        TriggerClientEvent('QBCore:Notify', pending.leadSrc, 'Sutikimo laikas baigėsi.', 'error')
        return
    end
    if not accept then
        TriggerClientEvent('QBCore:Notify', pending.leadSrc, 'Atsisakė.', 'error')
        return
    end

    local loc, err = validateLocation(pending.leadSrc, pending.locationKind, pending.locationId)
    if not loc then
        TriggerClientEvent('QBCore:Notify', pending.leadSrc, err or 'Klaida.', 'error')
        return
    end
    if Sessions[pending.key] then return end
    if pending.locationKind == 'station' then
        local st = stationById(pending.locationId)
        if not st or not inStation(pending.leadSrc, st) then
            return TriggerClientEvent('QBCore:Notify', pending.leadSrc, 'Pareigūnas turi būti tardymo kambaryje.', 'error')
        end
        if not suspectInRange(pending.leadSrc, src, st) then
            return TriggerClientEvent('QBCore:Notify', pending.leadSrc, 'Įtariamasis turi būti šalia.', 'error')
        end
    else
        if not inKitZone(pending.leadSrc, loc) or not inKitZone(src, loc) then
            return TriggerClientEvent('QBCore:Notify', pending.leadSrc, 'Abu turi būti prie įrangos.', 'error')
        end
    end

    local Lead = QBCore.Functions.GetPlayer(pending.leadSrc)
    local Suspect = QBCore.Functions.GetPlayer(src)
    if not Lead or not Suspect then return end

    local session = {
        key = pending.key,
        locationKind = pending.locationKind,
        locationId = pending.locationId,
        stationId = pending.locationKind == 'station' and pending.locationId or nil,
        kitSnapshot = pending.locationKind == 'kit' and loc or nil,
        roomLabel = pending.label,
        mode = pending.mode,
        leadSrc = pending.leadSrc,
        suspectSrc = src,
        leadCitizenid = Lead.PlayerData.citizenid,
        suspectCitizenid = Suspect.PlayerData.citizenid,
        suspectName = personName(Suspect),
        leadName = personName(Lead),
        startedAt = os.time(),
        seated = false,
        intense = false,
        suspectAnim = 'suspectSitCalm',
        spotlight = false,
        pressure = 0,
        notes = {},
        consentAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }

    Sessions[pending.key] = session

    local startPayload = {
        role = 'lead',
        key = pending.key,
        locationKind = pending.locationKind,
        locationId = pending.locationId,
        roomLabel = pending.label,
        mode = pending.mode,
        suspectName = personName(Suspect),
    }

    TriggerClientEvent('fivempro_interrogation:client:sessionStarted', pending.leadSrc, startPayload)
    TriggerClientEvent('fivempro_interrogation:client:sessionStarted', src, {
        role = 'suspect',
        key = pending.key,
        locationKind = pending.locationKind,
        locationId = pending.locationId,
        roomLabel = pending.label,
        mode = pending.mode,
        leadName = personName(Lead),
    })

    adminLog(pending.leadSrc, 'session_start', pending.label, { suspect = Suspect.PlayerData.citizenid })
end)

RegisterNetEvent('fivempro_interrogation:server:action', function(action)
    local src = source
    action = tostring(action or '')

    for key, s in pairs(Sessions) do
        if s.leadSrc == src then
        local locOk = false
        if s.locationKind == 'station' then
            local st = stationById(s.locationId)
            locOk = st and inStation(src, st)
        elseif s.locationKind == 'kit' then
            locOk = inKitZone(src, s.kitSnapshot or Kits.get(tonumber(s.locationId)))
        end
        if not locOk then
            TriggerClientEvent('QBCore:Notify', src, 'Per toli.', 'error')
            return
        end

        if s.mode == 'police' then
            if action == 'seat' then
                s.seated = true
                s.intense = false
                s.suspectAnim = 'suspectSitCalm'
            elseif action == 'start_intense' then
                s.seated = true
                s.intense = true
                s.suspectAnim = 'suspectInterrogate'
                TriggerClientEvent('fivempro_interrogation:client:showPoliceControls', src, true)
            elseif action == 'spotlight' then
                s.spotlight = not s.spotlight
            elseif action == 'slap' then
                s.pendingAnimLead = 'officerSlapDesk'
                if s.intense then
                    s.pendingAnimSuspect = 'suspectInterrogate'
                end
                bumpPressure(s, 6)
            elseif action == 'door' then
                local st = stationById(s.locationId)
                if st and st.doorGroupId then
                    TriggerClientEvent('fivempro_interrogation:client:toggleDoor', src, st.doorGroupId)
                end
            end
        else
            if action == 'seat' then
                s.seated = true
                s.suspectAnim = 'gangVictimChair'
            elseif action == 'tooth' or action == 'gas' or action == 'electric' then
                for _, ta in ipairs(Config.GangTortureActions or {}) do
                    if ta.id == action then
                        s.seated = true
                        s.pendingAnimSuspect = ta.victim
                        s.pendingAnimLead = ta.lead
                        s.pendingNoise = true
                        bumpPressure(s, ta.pressure or 15)
                        break
                    end
                end
            end
        end

        syncState(key)
        end
    end
end)

RegisterNetEvent('fivempro_interrogation:server:endSession', function(payload)
    local src = source
    payload = type(payload) == 'table' and payload or {}

    for key, s in pairs(Sessions) do
        if s.leadSrc == src then
        if s.mode == 'police' then
            local result = tostring(payload.result or 'cooperative'):sub(1, 64)
            local summary = tostring(payload.summary or ''):sub(1, 800)
            local record = {
                citizenid = s.suspectCitizenid,
                suspect_name = s.suspectName,
                officer_citizenid = s.leadCitizenid,
                officer_name = s.leadName,
                mode = 'police',
                room_id = s.locationId,
                result = result,
                recorded = 0,
                pressure_max = s.pressure or 0,
                summary = summary,
                notes = s.notes or {},
                answers = {},
                categories = {},
                consent_at = s.consentAt,
                duration_sec = math.max(0, os.time() - (s.startedAt or os.time())),
            }
            local saved = false
            pcall(function()
                saved = exports['fivempro_ltpd']:SaveInterrogationRecord(src, record) == true
            end)
            if saved then
                TriggerClientEvent('QBCore:Notify', src, 'Įrašas MDT.', 'success')
            end
        else
            TriggerClientEvent('QBCore:Notify', src, 'RP sesija baigta.', 'success')
        end

        if s.suspectSrc then
            TriggerClientEvent('QBCore:Notify', s.suspectSrc, 'Sesija baigta.', 'primary')
        end
        endSessionInternal(key, 'saved')
        return
        end
    end
end)

RegisterNetEvent('fivempro_interrogation:server:cancelSession', function()
    local src = source
    for key, s in pairs(Sessions) do
        if s.leadSrc == src or s.suspectSrc == src then
            endSessionInternal(key, 'cancel')
            TriggerClientEvent('QBCore:Notify', src, 'Atšaukta.', 'primary')
            return
        end
    end
end)

RegisterNetEvent('fivempro_interrogation:server:buyTestKit', function()
    if not Config.EnableTestShop or not Config.TestShop then return end
    local src = source
    local cfg = Config.TestShop
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local pc = GetEntityCoords(ped)
    local sc = cfg.coords
    if sc and #(pc - vector3(sc.x, sc.y, sc.z)) > (cfg.interactDist or 2.8) + 2.0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo pardavėjo.', 'error')
    end

    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end

    if cfg.requireGang and not canLeadCriminal(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Reikia gaujos narystės.', 'error')
    end

    local item = (Config.GangKit and Config.GangKit.item) or 'gang_interrog_kit'
    local price = math.max(0, math.floor(tonumber(cfg.price) or 0))
    local account = (cfg.payAccount == 'bank') and 'bank' or 'cash'

    if price > 0 then
        local bal = P.Functions.GetMoney(account) or 0
        if bal < price then
            return TriggerClientEvent('QBCore:Notify', src, 'Nepakanka pinigų.', 'error')
        end
        if not P.Functions.RemoveMoney(account, price, 'gang-interrog-kit-test') then
            return TriggerClientEvent('QBCore:Notify', src, 'Mokėjimas nepavyko.', 'error')
        end
    end

    if not P.Functions.AddItem(item, 1) then
        if price > 0 then
            P.Functions.AddMoney(account, price, 'gang-interrog-kit-refund')
        end
        return TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas.', 'error')
    end

    TriggerClientEvent('QBCore:Notify', src, ('Nusipirkai %s.'):format(item), 'success')
    adminLog(src, 'test_shop_buy', ('Pirkta %s už %s'):format(item, price), { item = item, price = price })
end)

AddEventHandler('playerDropped', function()
    local src = source
    PendingConsent[src] = nil
    for key, s in pairs(Sessions) do
        if s.leadSrc == src or s.suspectSrc == src then
            endSessionInternal(key, 'disconnect')
        end
    end
end)
