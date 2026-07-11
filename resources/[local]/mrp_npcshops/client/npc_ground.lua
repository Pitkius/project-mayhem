--- Parduotuvių NPC — pririšimas prie grindų (serverio ped dažnai spawnina ore)
NpcGround = NpcGround or {}

local snapped = {}

local function cfg()
    return Config.NpcGround or {}
end

function NpcGround.resolveZ(x, y, seedZ)
    seedZ = tonumber(seedZ) or 50.0
    local maxDelta = tonumber(cfg().maxGroundDelta) or 2.5
    local found, gz = GetGroundZFor_3dCoord(x + 0.0, y + 0.0, seedZ + 2.0, false)
    if not found then
        found, gz = GetGroundZFor_3dCoord(x, y, seedZ + 50.0, false)
    end
    if found and gz > -100.0 and math.abs(gz - seedZ) <= maxDelta then
        return gz + (tonumber(cfg().zOffset) or 0.0)
    end
    return seedZ + (tonumber(cfg().zOffset) or 0.0)
end

local function requestControl(ent, timeoutMs)
    if not ent or not NetworkGetEntityIsNetworked(ent) then return true end
    local deadline = GetGameTimer() + (timeoutMs or 2500)
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < deadline do
        Wait(0)
        NetworkRequestControlOfEntity(ent)
    end
    return NetworkHasControlOfEntity(ent)
end

function NpcGround.snapShopPed(ent, coords, onDone)
    if cfg().enabled == false then
        if onDone then onDone() end
        return
    end
    local skip = cfg().skipCategories
    if skip and type(skip) == 'table' then
        local meta = Entity(ent).state.npcShopMeta
        local category = meta and meta.category
        if category then
            for i = 1, #skip do
                if skip[i] == category then
                    if onDone then onDone() end
                    return
                end
            end
        end
    end
    if not ent or ent == 0 or not coords then
        if onDone then onDone() end
        return
    end
    if snapped[ent] then
        if onDone then onDone() end
        return
    end
    snapped[ent] = true

    local x = coords.x + 0.0
    local y = coords.y + 0.0
    local seedZ = coords.z + 0.0
    local heading = coords.w or coords.h or 0.0

    CreateThread(function()
        if not DoesEntityExist(ent) then
            snapped[ent] = nil
            return
        end

        local deadline = GetGameTimer() + (tonumber(cfg().retryMs) or 4500)
        local finalZ = seedZ

        while GetGameTimer() < deadline do
            if not DoesEntityExist(ent) then
                snapped[ent] = nil
                return
            end
            RequestCollisionAtCoord(x, y, seedZ)
            finalZ = NpcGround.resolveZ(x, y, seedZ)
            Wait(120)
            if HasCollisionLoadedAroundEntity(ent) then break end
        end

        if not DoesEntityExist(ent) then
            snapped[ent] = nil
            return
        end

        requestControl(ent, 2500)
        FreezeEntityPosition(ent, false)
        SetEntityCoordsNoOffset(ent, x, y, finalZ, false, false, false)
        SetEntityHeading(ent, heading)
        if type(PlaceEntityOnGroundProperly) == 'function' then
            PlaceEntityOnGroundProperly(ent)
        end

        local placed = GetEntityCoords(ent)
        local netId = NetworkGetNetworkIdFromEntity(ent)
        if netId and netId ~= 0 then
            TriggerServerEvent('mrp_npcshops:server:setPedPlacement', netId, placed.x, placed.y, placed.z, heading)
        else
            FreezeEntityPosition(ent, true)
        end

        if onDone then onDone() end
    end)
end

CreateThread(function()
    while true do
        Wait(8000)
        for ent in pairs(snapped) do
            if not DoesEntityExist(ent) then
                snapped[ent] = nil
            end
        end
    end
end)
