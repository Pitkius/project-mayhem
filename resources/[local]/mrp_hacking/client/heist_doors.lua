--- Heist durų užrakinimas / atrakinimas pagal fazę (Fleeca, Pacific, Federal, Casino)
local lockedDoors = {}
local doorStates = {}

local function doorKey(d)
    return ('%s:%.2f:%.2f:%.2f'):format(tostring(d.model), d.coords.x, d.coords.y, d.coords.z)
end

local function applyDoor(d, locked)
    if not d or not d.coords or not d.model then return end
    local model = type(d.model) == 'string' and joaat(d.model) or d.model
    local c = d.coords
    local key = doorKey(d)
    local hash = d.systemHash or joaat(('heist_door_%s'):format(key:gsub('[^%w]', '_')))

    pcall(function()
        AddDoorToSystem(hash, model, c.x, c.y, c.z, false, false, false)
        if locked then
            DoorSystemSetOpenRatio(hash, 0.0, false, false)
            DoorSystemSetDoorState(hash, 1, false, false)
        else
            DoorSystemSetDoorState(hash, 0, false, false)
            DoorSystemSetOpenRatio(hash, d.openRatio or 1.0, false, false)
        end
    end)

    local obj = GetClosestObjectOfType(c.x, c.y, c.z, d.radius or 3.0, model, false, false, false)
    if obj ~= 0 then
        FreezeEntityPosition(obj, locked)
        if not locked and d.openHeading then
            SetEntityHeading(obj, d.openHeading)
        elseif not locked and d.openDelta then
            SetEntityHeading(obj, (d.heading or GetEntityHeading(obj)) + d.openDelta)
        end
    end
    doorStates[key] = locked
end

local function getDoorSets(locId)
    local all = (Config.Robberies and Config.Robberies.HeistDoors) or {}
    return all[locId] or {}
end

function LockHeistDoors(locId)
    lockedDoors[locId] = true
    for _, group in ipairs(getDoorSets(locId)) do
        for _, door in ipairs(group.doors or {}) do
            applyDoor(door, true)
        end
    end
end

function UnlockHeistDoorsForPhase(locId, completedPhase)
    local sets = getDoorSets(locId)
    for _, group in ipairs(sets) do
        if group.unlockAfter == completedPhase then
            for _, door in ipairs(group.doors or {}) do
                applyDoor(door, false)
            end
        end
    end
end

function ReleaseHeistDoors(locId)
    lockedDoors[locId] = nil
    for _, group in ipairs(getDoorSets(locId)) do
        for _, door in ipairs(group.doors or {}) do
            applyDoor(door, false)
        end
    end
end

CreateThread(function()
    Wait(3000)
    local locations = Config.Robberies and Config.Robberies.Locations or {}
    for _, list in pairs(locations) do
        for _, loc in ipairs(list) do
            if loc.id and getDoorSets(loc.id)[1] then
                LockHeistDoors(loc.id)
            end
        end
    end
end)

exports('LockHeistDoors', LockHeistDoors)
exports('UnlockHeistDoorsForPhase', UnlockHeistDoorsForPhase)
exports('ReleaseHeistDoors', ReleaseHeistDoors)
