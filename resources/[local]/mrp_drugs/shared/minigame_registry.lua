--- Unikalūs mini-žaidimai pagal narkotiko liniją ir veiksmą (harvest / prepare / process / dry / pack).
--- action: harvest | prepare | process | dry | pack

MinigameRegistry = MinigameRegistry or {}

local function p(drug, action, mode, title, steps, icon, difficulty)
    return {
        drug = drug,
        action = action,
        mode = mode,
        title = title,
        steps = steps or 3,
        icon = icon,
        difficulty = difficulty or 1,
    }
end

--- Stoties / grow profiliai (productId → profilis)
MinigameRegistry.Profiles = {
    -- L1 THC / vape / alkoholis
    thc_process = p('thc', 'process', 'thc_scrape', 'THC · dervos nuskynimas', 4, '🍃', 1),
    thc_pack = p('thc', 'pack', 'thc_cartridge', 'Vape kasetės pildymas', 3, '💨', 1),
    alcohol_process = p('alcohol', 'process', 'moonshine_still', 'Samagono distiliacija', 2, '🥃', 1),
    alcohol_pack = p('alcohol', 'pack', 'moonshine_jar', 'Stiklainio užkorkavimas', 3, '🍾', 1),
    vape_process = p('vape', 'process', 'vape_blend', 'Skysčio mišinio balansas', 2, '💨', 1),
    vape_pack = p('vape', 'pack', 'vape_dropper', 'Buteliuko lašinimas', 3, '🧴', 1),

    -- Kanapės (grow + dry + pack)
    weed_soil = p('weed', 'prepare', 'weed_soil', 'Žemės pylimas', 2, nil, 1),
    weed_seed = p('weed', 'prepare', 'weed_seed', 'Sėklų sodinimas', 3, nil, 1),
    weed_water = p('weed', 'prepare', 'weed_water', 'Augalo laistymas', 2, nil, 1),
    weed_harvest = p('weed', 'harvest', 'weed_harvest', 'Derliaus nuėmimas', 3, '🌿', 2),
    weed_process = p('weed', 'dry', 'weed_dry', 'Žolės džiovinimas', 3, '🍃', 2),
    weed_pack = p('weed', 'pack', 'weed_pack', 'Žolės supakavimas', 3, '🌿', 2),

    -- L2 heroinas / metas / tabletės
    heroin_process = p('heroin', 'process', 'heroin_cook', 'Heroino redukcija', 2, '⚗️', 2),
    heroin_pack = p('heroin', 'pack', 'heroin_fold', 'Heroino folijos pakavimas', 3, '💉', 2),
    meth_process = p('meth', 'process', 'meth_crystal', 'Meto kristalizacija', 4, '💎', 3),
    meth_pack = p('meth', 'pack', 'meth_crush_pack', 'Kristalų smulkinimas ir maišelis', 3, '❄️', 3),
    pills_process = p('pills', 'process', 'pills_press', 'Tablečių presavimas', 4, '💊', 2),
    pills_pack = p('pills', 'pack', 'pills_blister', 'Blisterio uždarymas', 3, '💊', 2),

    -- L2 grybai
    mushroom_process = p('mushroom', 'process', 'mushroom_brush', 'Grybų šepečio valymas', 4, '🍄', 2),
    mushroom_pack = p('mushroom', 'pack', 'mushroom_jar', 'Stiklainio užpildymas', 3, '🍄', 2),

    -- L3 kokainas
    cocaine_process = p('cocaine', 'process', 'cocaine_wash', 'Lapų cheminis plovimas', 4, '🍃', 3),
    cocaine_pack = p('cocaine', 'pack', 'cocaine_brick', 'Bloko presavimas', 3, '🧱', 3),

    -- L3 amfetaminas (pack tik schedule; process = quiz amp_lab)
    amp_pack = p('amp', 'pack', 'amp_stamp', 'Maišelio antspaudas', 3, '⚡', 3),
}

--- Lauko derliaus profiliai (mushroom / coca)
MinigameRegistry.Harvest = {
    mushroom = p('mushroom', 'harvest', 'mushroom_harvest', 'Grybų rinkimas', 5, '🍄', 1),
    coca = p('cocaine', 'harvest', 'coca_harvest', 'Kokainmedžio lapų nuėmimas', 5, '🍃', 2),
}

function MinigameRegistry.Apply()
    if not Config then return end
    Config.ScheduleMinigames = MinigameRegistry.Profiles

    function Config.GetScheduleMinigame(productId)
        return Config.ScheduleMinigames and Config.ScheduleMinigames[productId] or nil
    end

    function Config.GetHarvestMinigame(kind)
        return MinigameRegistry.Harvest and MinigameRegistry.Harvest[kind] or nil
    end

    function Config.GetHarvestMinigameForField(field)
        if not field then return nil end
        if field.item == 'cartel_raw' or (field.id and tostring(field.id):find('coca')) then
            return Config.GetHarvestMinigame('coca')
        end
        return Config.GetHarvestMinigame('mushroom')
    end
end

MinigameRegistry.Apply()
