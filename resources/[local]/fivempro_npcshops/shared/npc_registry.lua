--- Visų parduotuvių / tarnybinių NPC sąrašas (vanilla koordinačiai iš config)
NpcRegistry = NpcRegistry or {}

local function push(entries, category, list, defaults)
    defaults = defaults or {}
    for i, row in ipairs(list or {}) do
        entries[#entries + 1] = {
            category = category,
            index = i,
            model = row.model,
            coords = row.coords,
            scenario = row.scenario or defaults.scenario,
            blip = row.blip ~= false and (row.blip or defaults.blip) or nil,
            chair = row.chair,
            job = row.job,
            stationId = row.stationId,
            role = row.role,
            label = row.label,
        }
    end
end

function NpcRegistry.collect()
    local entries = {}

    push(entries, 'barber', Config.BarberPeds, {
        blip = { sprite = 71, color = 0, label = 'Kirpykla', scale = 0.75 },
    })

    push(entries, 'clothing', Config.ClothingPeds, {
        scenario = 'WORLD_HUMAN_STAND_MOBILE',
        blip = { sprite = 366, color = 47, label = 'Rūbų parduotuvė', scale = 0.75 },
    })

    push(entries, 'food', Config.FoodPeds, {
        scenario = 'WORLD_HUMAN_STAND_MOBILE',
        blip = { sprite = 52, color = 2, label = '24/7', scale = 0.75 },
    })

    push(entries, 'tattoo', Config.TattooPeds, {
        scenario = 'WORLD_HUMAN_STAND_MOBILE',
        blip = { sprite = 75, color = 1, label = 'Tatuiruotės', scale = 0.75 },
    })

    push(entries, 'pharmacy', Config.PharmacyPeds, {
        scenario = 'WORLD_HUMAN_STAND_MOBILE',
        blip = { sprite = 51, color = 2, label = 'Vaistinė', scale = 0.75 },
    })

    for i, row in ipairs(Config.JobStationNpcs or {}) do
        if row.role ~= 'garage' and row.role ~= 'stash' and row.role ~= 'locker' and row.role ~= 'supply' and row.role ~= 'boss' then
            entries[#entries + 1] = {
                category = 'job',
                index = i,
                model = row.model,
                coords = row.coords,
                scenario = row.scenario,
                blip = row.blip,
                job = row.job,
                stationId = row.stationId,
                role = row.role,
                label = row.label,
            }
        end
    end

    return entries
end
