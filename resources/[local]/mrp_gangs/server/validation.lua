GangSystem = GangSystem or {}

local validPhaseTypes = {
    approach = true,
    enter = true,
    interact = true,
    eliminate = true,
    defend = true,
    exit = true,
    extract = true,
    checkpoint_run = true,
    vehicle = true,
    breach = true,
    search = true,
    collect = true,
    sabotage = true,
    rescue = true,
    capture = true,
}

local function validateContent()
    local errors = {}
    local count = 0
    local categories = { universal = 0, street = 0, cartel = 0, mafia = 0, biker = 0, racing = 0 }

    for key, mission in pairs(Config.Missions or {}) do
        count = count + 1
        categories[mission.category] = (categories[mission.category] or 0) + 1
        if mission.id ~= key then errors[#errors + 1] = key .. ': id mismatch' end
        if not mission.label or mission.label == '' then errors[#errors + 1] = key .. ': label missing' end
        if not Config.MissionWorldSites[mission.sitePool] then errors[#errors + 1] = key .. ': invalid site pool' end
        if mission.interior and not Config.MissionInteriors[mission.interior] then
            errors[#errors + 1] = key .. ': invalid interior'
        end
        if (tonumber(mission.baseReward) or 0) <= 0 then errors[#errors + 1] = key .. ': invalid reward' end
        if (tonumber(mission.baseReputation) or 0) <= 0 then errors[#errors + 1] = key .. ': invalid reputation' end
        if not mission.phases or #mission.phases < 3 then errors[#errors + 1] = key .. ': too few phases' end
        for index, phase in ipairs(mission.phases or {}) do
            if not validPhaseTypes[phase.type] then
                errors[#errors + 1] = ('%s: invalid phase %s at %s'):format(key, tostring(phase.type), index)
            end
            if phase.objectiveIndex and not mission.interior then
                errors[#errors + 1] = ('%s: interior objective without interior at %s'):format(key, index)
            end
        end
        for _, difficulty in ipairs(mission.allowedDifficulties or {}) do
            if not Config.Difficulties[difficulty] then
                errors[#errors + 1] = ('%s: invalid difficulty %s'):format(key, tostring(difficulty))
            end
        end
    end

    if count ~= 30 then errors[#errors + 1] = ('expected 30 mission families, got %s'):format(count) end
    for category, expected in pairs(categories) do
        if expected ~= 5 then
            errors[#errors + 1] = ('category %s expected 5 missions, got %s'):format(category, expected)
        end
    end

    local territoryCount = 0
    local territoryTypes = { gang = 0, pvp = 0, racket = 0 }
    for territoryId, territory in pairs(Config.Territories or {}) do
        territoryCount = territoryCount + 1
        if territoryTypes[territory.type] == nil then
            errors[#errors + 1] = territoryId .. ': invalid territory type'
        else
            territoryTypes[territory.type] = territoryTypes[territory.type] + 1
        end
        if not territory.label or territory.label == '' then
            errors[#errors + 1] = territoryId .. ': territory label missing'
        end
        if type(territory.vertices) ~= 'table' or #territory.vertices < 3 then
            errors[#errors + 1] = territoryId .. ': polygon needs at least 3 vertices'
        end
        for index, vertex in ipairs(territory.vertices or {}) do
            if type(vertex.x) ~= 'number' or type(vertex.y) ~= 'number' then
                errors[#errors + 1] = ('%s: invalid vertex %s'):format(territoryId, index)
            end
        end
        if territory.allowsDrugSales and not Config.DrugTerritoryItems[territory.drugProduct] then
            errors[#errors + 1] = territoryId .. ': invalid drug product'
        end
    end
    if territoryCount ~= 18 then errors[#errors + 1] = ('expected 18 territories, got %s'):format(territoryCount) end
    local expectedTerritoryTypes = { gang = 8, pvp = 4, racket = 6 }
    for territoryType, expected in pairs(expectedTerritoryTypes) do
        if territoryTypes[territoryType] ~= expected then
            errors[#errors + 1] = ('territory type %s expected %s, got %s'):format(
                territoryType,
                expected,
                territoryTypes[territoryType] or 0
            )
        end
    end

    local treatyCount = 0
    for treatyType, treaty in pairs(Config.TreatyTypes or {}) do
        treatyCount = treatyCount + 1
        if not treaty.label or treaty.label == '' then errors[#errors + 1] = treatyType .. ': treaty label missing' end
    end
    if treatyCount ~= 8 then errors[#errors + 1] = ('expected 8 treaty types, got %s'):format(treatyCount) end

    if #errors > 0 then
        for _, message in ipairs(errors) do print('[mrp_gangs] CONTENT ERROR: ' .. message) end
        return false
    end
    print(('[mrp_gangs] validated %s missions, %s territories and %s treaty types.'):format(
        count,
        territoryCount,
        treatyCount
    ))
    return true
end

GangSystem.ContentValid = validateContent()
