local QBCore = exports['qb-core']:GetCoreObject()

--- source -> jail runtime state
local Active = {}
--- citizenid -> stripped inventory snapshot (also mirrored in metadata)
local StashByCitizen = {}
--- prevent double restore
local Restoring = {}

local function notify(src, msg, typ)
    if not src or src <= 0 then return end
    TriggerClientEvent('QBCore:Notify', src, msg, typ or 'primary', 7000)
end

local function isAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
end

local function isPoliceOnDuty(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local j = Player.PlayerData.job
    return j and j.name == Config.PoliceJob and j.onduty == true
end

local function deepCopyItems(items)
    local out = {}
    if type(items) ~= 'table' then return out end
    for slot, item in pairs(items) do
        if type(item) == 'table' and item.name then
            local info = {}
            if type(item.info) == 'table' then
                for k, v in pairs(item.info) do
                    info[k] = v
                end
            end
            out[tostring(slot)] = {
                name = item.name,
                amount = tonumber(item.amount) or 1,
                info = info,
                type = item.type,
                slot = tonumber(item.slot) or tonumber(slot),
            }
        end
    end
    return out
end

local function remainingMinutes(sec)
    sec = math.max(0, tonumber(sec) or 0)
    return math.max(0, math.ceil(sec / 60))
end

local function isWorkSentence(state)
    return state and (state.requireWork == true or state.byType == 'admin')
end

local function syncMeta(Player, state)
    if not Player then return end
    local sec = state and state.remainingSeconds or 0
    Player.Functions.SetMetaData('injail', remainingMinutes(sec))
    Player.Functions.SetMetaData('jail_reason', state and state.reason or '')
    Player.Functions.SetMetaData('jail_active', state ~= nil)
    Player.Functions.SetMetaData('jail_ends_at', state and state.endsAt or 0)
    Player.Functions.SetMetaData('jail_require_work', state and isWorkSentence(state) or false)
    Player.Functions.SetMetaData('jail_by_type', state and state.byType or '')
end

local function pushHud(src, state)
    if not state then
        TriggerClientEvent('mrp_jail:client:clearJail', src)
        return
    end
    TriggerClientEvent('mrp_jail:client:setJail', src, {
        remainingSeconds = math.max(0, state.remainingSeconds or 0),
        reason = state.reason or Config.Defaults.noReason,
        endsAt = state.endsAt,
        requireWork = isWorkSentence(state),
        byType = state.byType or 'police',
    })
end

local function giveStarterFood(src)
    for _, row in ipairs(Config.StarterFood or {}) do
        if row.name and (tonumber(row.amount) or 0) > 0 then
            exports['qb-inventory']:AddItem(src, row.name, row.amount, false, false, 'mrp_jail:starter')
        end
    end
end

local function stripInventory(src, Player)
    local citizenid = Player.PlayerData.citizenid
    local existing = Player.Functions.GetMetaData('jailitems')
    if type(existing) == 'table' and next(existing) then
        StashByCitizen[citizenid] = deepCopyItems(existing)
        Player.Functions.ClearInventory()
        notify(src, Config.Notify.stripped, 'primary')
        return true
    end

    local snapshot = deepCopyItems(Player.PlayerData.items)
    StashByCitizen[citizenid] = snapshot
    Player.Functions.SetMetaData('jailitems', snapshot)
    Player.Functions.ClearInventory()
    notify(src, Config.Notify.stripped, 'primary')
    return true
end

local function restoreInventory(src, Player)
    local citizenid = Player.PlayerData.citizenid
    if Restoring[citizenid] then return false end
    Restoring[citizenid] = true

    local saved = StashByCitizen[citizenid]
    if type(saved) ~= 'table' or not next(saved) then
        saved = Player.Functions.GetMetaData('jailitems')
    end
    if type(saved) ~= 'table' then saved = {} end

    Player.Functions.ClearInventory()

    local ordered = {}
    for _, item in pairs(saved) do
        ordered[#ordered + 1] = item
    end
    table.sort(ordered, function(a, b)
        return (tonumber(a.slot) or 0) < (tonumber(b.slot) or 0)
    end)

    for _, item in ipairs(ordered) do
        if item.name and (tonumber(item.amount) or 0) > 0 then
            exports['qb-inventory']:AddItem(
                src,
                item.name,
                item.amount,
                item.slot or false,
                item.info or {},
                'mrp_jail:restore'
            )
        end
    end

    StashByCitizen[citizenid] = nil
    Player.Functions.SetMetaData('jailitems', {})
    Player.Functions.SetMetaData('injail', 0)
    Player.Functions.SetMetaData('jail_reason', '')
    Player.Functions.SetMetaData('jail_active', false)
    Player.Functions.SetMetaData('jail_ends_at', 0)
    Player.Functions.SetMetaData('jail_require_work', false)
    Player.Functions.SetMetaData('jail_by_type', '')

    Restoring[citizenid] = nil
    notify(src, Config.Notify.restored, 'success')
    return true
end

local function teleportToCarrier(src)
    TriggerClientEvent('mrp_jail:client:teleport', src, Config.Carrier.spawn)
end

local function teleportToRelease(src)
    TriggerClientEvent('mrp_jail:client:teleport', src, Config.Release)
end

local function endJail(src, opts)
    opts = opts or {}
    local state = Active[src]
    local Player = QBCore.Functions.GetPlayer(src)
    Active[src] = nil

    if Player then
        restoreInventory(src, Player)
        syncMeta(Player, nil)
    end

    pushHud(src, nil)
    if opts.teleport ~= false then
        teleportToRelease(src)
    end
    notify(src, Config.Notify.unjailed, 'success')
end

local function applyJail(targetSrc, minutes, reason, actorSrc, byType)
    local Target = QBCore.Functions.GetPlayer(targetSrc)
    if not Target then
        if actorSrc then notify(actorSrc, Config.Notify.invalidTarget, 'error') end
        return false
    end

    minutes = math.floor(tonumber(minutes) or 0)
    if minutes < Config.MinMinutes or minutes > Config.MaxMinutes then
        if actorSrc then notify(actorSrc, Config.Notify.invalidMinutes, 'error') end
        return false
    end

    reason = tostring(reason or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if reason == '' then
        if byType == 'police' then
            reason = Config.Defaults.policeReason
        else
            reason = Config.Defaults.adminReason
        end
    end
    if #reason > 180 then reason = reason:sub(1, 180) end

    if Active[targetSrc] then
        if actorSrc then notify(actorSrc, Config.Notify.alreadyJailed, 'error') end
        return false
    end

    local jailType = byType or 'admin'
    local requireWork = jailType == 'admin'
    local remainingSeconds = minutes * 60
    --- Admin: no passive countdown — only work reduces remainingSeconds.
    local endsAt = requireWork and 0 or (os.time() + remainingSeconds)

    stripInventory(targetSrc, Target)
    giveStarterFood(targetSrc)

    local state = {
        citizenid = Target.PlayerData.citizenid,
        remainingSeconds = remainingSeconds,
        endsAt = endsAt,
        reason = reason,
        byType = jailType,
        requireWork = requireWork,
        actor = actorSrc,
    }
    Active[targetSrc] = state
    syncMeta(Target, state)
    teleportToCarrier(targetSrc)
    pushHud(targetSrc, state)

    if requireWork then
        notify(targetSrc, Config.Notify.jailedAdmin:format(minutes, reason), 'error')
    else
        notify(targetSrc, Config.Notify.jailed:format(minutes, reason), 'error')
    end
    if actorSrc and actorSrc ~= targetSrc then
        notify(actorSrc, Config.Notify.jailedOfficer:format(targetSrc, minutes, reason), 'success')
    end

    if GetResourceState('server_logs') == 'started' then
        TriggerEvent('server_logs:policeJail', targetSrc, minutes, reason)
    end

    return true
end

local function reduceSentence(src, seconds, fromWork)
    local state = Active[src]
    if not state then return false end
    seconds = math.floor(tonumber(seconds) or 0)
    if seconds <= 0 then return false end

    state.remainingSeconds = math.max(0, (state.remainingSeconds or 0) - seconds)
    if isWorkSentence(state) then
        state.endsAt = 0
    else
        state.endsAt = os.time() + state.remainingSeconds
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if Player then syncMeta(Player, state) end
    pushHud(src, state)

    if fromWork then
        local left = remainingMinutes(state.remainingSeconds)
        local label = isWorkSentence(state) and (('%s darb.'):format(left)) or (('%s min.'):format(left))
        notify(src, Config.Notify.workDone:format(label), 'success')
    end

    if state.remainingSeconds <= 0 then
        endJail(src)
    end
    return true
end

local function registerCanteenShop()
    local cfg = Config.CanteenShop
    if not cfg or not cfg.name then return end
    local items = {}
    for i, row in ipairs(cfg.items or {}) do
        items[#items + 1] = {
            name = row.name,
            price = row.price,
            amount = row.amount or 50,
            slot = i,
        }
    end
    exports['qb-inventory']:CreateShop({
        name = cfg.name,
        label = cfg.label or 'Valgykla',
        slots = #items,
        items = items,
    })
end

CreateThread(function()
    Wait(500)
    registerCanteenShop()
end)

--- Sentence ticker (1s) — police time sentences only (admin = work-only)
CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        for src, state in pairs(Active) do
            if not QBCore.Functions.GetPlayer(src) then
                Active[src] = nil
            elseif isWorkSentence(state) then
                --- Admin / work sentence: no automatic time drain.
            else
                local left = math.max(0, (state.endsAt or now) - now)
                if left ~= state.remainingSeconds then
                    state.remainingSeconds = left
                    local Player = QBCore.Functions.GetPlayer(src)
                    if Player and (left % 15 == 0 or left <= 0) then
                        syncMeta(Player, state)
                    end
                    if left % 5 == 0 then
                        pushHud(src, state)
                    end
                end
                if left <= 0 then
                    endJail(src)
                end
            end
        end
    end
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not Player or not Player.PlayerData then return end
    local src = Player.PlayerData.source
    local meta = Player.PlayerData.metadata or {}
    if not meta.jail_active and (tonumber(meta.injail) or 0) <= 0 then return end

    local byType = tostring(meta.jail_by_type or '')
    if byType == '' then
        byType = meta.jail_require_work and 'admin' or 'police'
    end
    local requireWork = meta.jail_require_work == true or byType == 'admin'
    local endsAt = tonumber(meta.jail_ends_at) or 0
    local now = os.time()
    local remaining = 0

    if requireWork then
        --- Work sentences persist as remaining minutes (jobs), not wall-clock endsAt.
        remaining = math.max(0, (tonumber(meta.injail) or 0) * 60)
        endsAt = 0
    elseif endsAt > now then
        remaining = endsAt - now
    else
        remaining = math.max(0, (tonumber(meta.injail) or 0) * 60)
        endsAt = now + remaining
    end

    if remaining <= 0 then
        restoreInventory(src, Player)
        syncMeta(Player, nil)
        pushHud(src, nil)
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local saved = meta.jailitems
    if type(saved) == 'table' and next(saved) then
        StashByCitizen[citizenid] = deepCopyItems(saved)
    end

    Active[src] = {
        citizenid = citizenid,
        remainingSeconds = remaining,
        endsAt = endsAt,
        reason = meta.jail_reason ~= '' and meta.jail_reason or Config.Defaults.noReason,
        byType = byType,
        requireWork = requireWork,
    }
    syncMeta(Player, Active[src])
    SetTimeout(1500, function()
        if Active[src] then
            teleportToCarrier(src)
            pushHud(src, Active[src])
            local mins = remainingMinutes(remaining)
            if requireWork then
                notify(src, Config.Notify.jailedAdmin:format(mins, Active[src].reason), 'error')
            else
                notify(src, Config.Notify.jailed:format(mins, Active[src].reason), 'error')
            end
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local state = Active[src]
    if not state then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        syncMeta(Player, state)
        if StashByCitizen[state.citizenid] then
            Player.Functions.SetMetaData('jailitems', StashByCitizen[state.citizenid])
        end
    end
    Active[src] = nil
end)

--- Admin commands only
QBCore.Commands.Add('jail', 'Įkalinti žaidėją (admin)', {
    { name = 'id', help = 'Server ID' },
    { name = 'minutes', help = 'Minutės' },
    { name = 'reason', help = 'Priežastis (nebūtina)' },
}, false, function(source, args)
    if source > 0 and not isAdmin(source) then
        notify(source, Config.Notify.noPermission, 'error')
        return
    end
    local targetId = tonumber(args[1])
    local minutes = tonumber(args[2])
    if not targetId or not minutes then
        notify(source, 'Naudojimas: /jail [id] [minutės] [priežastis...]', 'error')
        return
    end
    local reasonParts = {}
    for i = 3, #args do
        reasonParts[#reasonParts + 1] = args[i]
    end
    local reason = table.concat(reasonParts, ' ')
    applyJail(targetId, minutes, reason, source > 0 and source or nil, 'admin')
end, 'admin')

QBCore.Commands.Add('unjail', 'Paleisti iš kalėjimo (admin)', {
    { name = 'id', help = 'Server ID' },
}, false, function(source, args)
    if source > 0 and not isAdmin(source) then
        notify(source, Config.Notify.noPermission, 'error')
        return
    end
    local targetId = tonumber(args[1])
    if not targetId then
        notify(source, 'Naudojimas: /unjail [id]', 'error')
        return
    end
    if not Active[targetId] then
        local T = QBCore.Functions.GetPlayer(targetId)
        if T and (T.PlayerData.metadata.jail_active or (tonumber(T.PlayerData.metadata.injail) or 0) > 0) then
            Active[targetId] = {
                citizenid = T.PlayerData.citizenid,
                remainingSeconds = (tonumber(T.PlayerData.metadata.injail) or 1) * 60,
                endsAt = os.time(),
                reason = T.PlayerData.metadata.jail_reason or '',
            }
        else
            notify(source, Config.Notify.notJailed, 'error')
            return
        end
    end
    endJail(targetId)
    if source > 0 then
        notify(source, Config.Notify.unjailedOfficer:format(targetId), 'success')
    end
end, 'admin')

RegisterNetEvent('mrp_jail:server:policeJail', function(targetId, minutes, reason)
    local src = source
    if not isPoliceOnDuty(src) then
        notify(src, Config.Notify.noPermission, 'error')
        return
    end
    targetId = tonumber(targetId)
    if not targetId or targetId == src then
        notify(src, Config.Notify.invalidTarget, 'error')
        return
    end

    local oPed = GetPlayerPed(src)
    local tPed = GetPlayerPed(targetId)
    if not oPed or not tPed or oPed == 0 or tPed == 0 then
        notify(src, Config.Notify.invalidTarget, 'error')
        return
    end
    if #(GetEntityCoords(oPed) - GetEntityCoords(tPed)) > 5.0 then
        notify(src, 'Per toli nuo žaidėjo.', 'error')
        return
    end

    applyJail(targetId, minutes, reason, src, 'police')
end)

RegisterNetEvent('mrp_jail:server:policeUnjail', function(targetId)
    local src = source
    if not isPoliceOnDuty(src) and not isAdmin(src) then
        notify(src, Config.Notify.noPermission, 'error')
        return
    end
    targetId = tonumber(targetId)
    if not targetId or not Active[targetId] then
        notify(src, Config.Notify.notJailed, 'error')
        return
    end
    endJail(targetId)
    notify(src, Config.Notify.unjailedOfficer:format(targetId), 'success')
end)

RegisterNetEvent('mrp_jail:server:completeWork', function()
    local src = source
    if not Active[src] then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    local near = false
    for _, spot in ipairs(Config.WorkSpots or {}) do
        if #(coords - spot) <= (Config.WorkInteractDistance + 2.0) then
            near = true
            break
        end
    end
    if not near then return end
    reduceSentence(src, 60, true)
end)

RegisterNetEvent('mrp_jail:server:openCanteen', function()
    local src = source
    if not Active[src] then
        notify(src, Config.Notify.canteenDenied, 'error')
        return
    end
    registerCanteenShop()
    exports['qb-inventory']:OpenShop(src, Config.CanteenShop.name)
end)

RegisterNetEvent('mrp_jail:server:requestSync', function()
    local src = source
    pushHud(src, Active[src])
end)

QBCore.Functions.CreateCallback('mrp_jail:server:isJailed', function(source, cb, targetId)
    targetId = tonumber(targetId) or source
    cb(Active[targetId] ~= nil)
end)

QBCore.Functions.CreateCallback('mrp_jail:server:canPoliceJail', function(source, cb)
    cb(isPoliceOnDuty(source))
end)

exports('IsJailed', function(src)
    return Active[src] ~= nil
end)

exports('JailPlayer', function(targetSrc, minutes, reason, actorSrc)
    return applyJail(targetSrc, minutes, reason, actorSrc, 'admin')
end)

exports('UnjailPlayer', function(targetSrc)
    if not Active[targetSrc] then return false end
    endJail(targetSrc)
    return true
end)
