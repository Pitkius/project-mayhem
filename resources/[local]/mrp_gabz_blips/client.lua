--- Blip tik tada, kai atitinkantis MLO resursas užsikrovęs — blokuojame paraleliai ir laukiame iki ~120 s.

local spawned = {}

local function isTargetResourceStarted(entry)
    if entry.resource and GetResourceState(entry.resource) == 'started' then
        return true
    end
    if type(entry.resources) == 'table' then
        for _, resName in ipairs(entry.resources) do
            if GetResourceState(resName) == 'started' then
                return true
            end
        end
    end
    return entry.resource == nil and type(entry.resources) ~= 'table'
end

local function createBlip(entry)
    local c = entry.coords
    local b = AddBlipForCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    SetBlipSprite(b, entry.sprite or 1)
    SetBlipDisplay(b, 4)
    SetBlipScale(b, entry.scale or Config.DefaultScale or 0.75)
    SetBlipColour(b, entry.color or 0)
    SetBlipAsShortRange(b, entry.shortRange ~= false and Config.ShortRange ~= false)
    exports['mrp_fonts']:SetBlipName(b, entry.label or entry.resource or 'MLO')
end

CreateThread(function()
    Wait(800)
    for i, entry in ipairs(Config.Blips or {}) do
        CreateThread(function()
            local deadline = GetGameTimer() + 120000
            while not isTargetResourceStarted(entry) do
                if GetGameTimer() > deadline then
                    return
                end
                Wait(400)
            end
            if spawned[i] then return end
            spawned[i] = true
            if entry.coords then
                createBlip(entry)
            end
        end)
    end
end)
