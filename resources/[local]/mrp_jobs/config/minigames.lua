--[[
  mrp_jobs — minigame adapterio profiliai (shared).
  Užduotys nurodo minigame per raktą; adapteris (client/minigame.lua) suriša
  tipą su tikru resursu (pvz. mrp_hacking) arba lengvu fallback variantu.

  Profilio laukai:
    type       — Constants.Minigame reikšmė
    difficulty — 1..3 (įtakoja trukmę / toleranciją)
    attempts   — kiek bandymų leidžiama
    duration   — (nebūtina) fallback trukmė ms
    label      — rodomas tekstas
]]

Config = Config or {}

Config.Minigames = {
    -- Naftos darbas
    oil_pump = { type = 'pressure', difficulty = 2, attempts = 2, duration = 6000, label = 'Stabilizuok slėgį' },
    oil_valve = { type = 'sequence', difficulty = 2, attempts = 2, duration = 5000, label = 'Nustatyk vožtuvus' },

    -- Burgerių kepimas
    burger_grill = { type = 'timing', difficulty = 2, attempts = 2, duration = 4500, label = 'Apversk mėsą laiku' },
    burger_temp  = { type = 'temperature', difficulty = 2, attempts = 2, duration = 5000, label = 'Išlaikyk temperatūrą' },
    burger_order = { type = 'ingredient_order', difficulty = 1, attempts = 2, duration = 6000, label = 'Sudėk ingredientus' },

    -- Valymas
    clean_generic = { type = 'hold', difficulty = 1, attempts = 3, duration = 3500, label = 'Valyk' },
    clean_scrub   = { type = 'mash', difficulty = 2, attempts = 3, duration = 4000, label = 'Šveisk' },

    -- Vaisiai
    fruit_pick   = { type = 'timing', difficulty = 1, attempts = 3, duration = 3500, label = 'Rink prinokusius' },
    fruit_ground = { type = 'sequence', difficulty = 1, attempts = 3, duration = 3800, label = 'Rink nuo žemės' },

    -- Vaisinis vape (koncentratas)
    concentrate_wash  = { type = 'hold', difficulty = 1, attempts = 2, duration = 4000, label = 'Plauk vaisius' },
    concentrate_press = { type = 'pressure', difficulty = 2, attempts = 2, duration = 6000, label = 'Spausk koncentratą' },
}

-- Grąžina profilį (kopiją, kad task'ai galėtų perrašyti difficulty ir pan.).
function Config.GetMinigame(key, overrides)
    local base = Config.Minigames[key]
    if not base then
        return { type = 'timing', difficulty = 1, attempts = 2, duration = 4000, label = 'Užduotis' }
    end
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    if overrides then
        for k, v in pairs(overrides) do out[k] = v end
    end
    return out
end
