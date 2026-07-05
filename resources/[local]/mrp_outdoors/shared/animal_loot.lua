AnimalLoot = AnimalLoot or {}

local function buildLookup()
    local map = {}
    if Config.AnimalLoot then
        for model, row in pairs(Config.AnimalLoot) do
            map[model] = row
        end
    end
    if Config.AnimalSpawn and Config.AnimalSpawn.models then
        for _, row in ipairs(Config.AnimalSpawn.models) do
            if row.model and not map[row.model] then
                map[row.model] = { meat = row.meat, extra = row.extra }
            end
        end
    end
    return map
end

function AnimalLoot.resolve(modelHash)
    if not modelHash then return nil end
    local lookup = buildLookup()
    return lookup[modelHash]
end

function AnimalLoot.meatItem(modelHash)
    local row = AnimalLoot.resolve(modelHash)
    return row and row.meat or nil
end

function AnimalLoot.extraItem(modelHash)
    local row = AnimalLoot.resolve(modelHash)
    return row and row.extra or nil
end
