Config = Config or {}

Config.TerritoryRules = {
    ownershipLockSec = 72 * 60 * 60,
    defenderPreparationSec = 24 * 60 * 60,
    baseStability = 50,
    captureStability = 65,
    maxOwnedBase = 4,
    maxOwnedByType = { gang = 4, pvp = 2, racket = 3 },
    racketIncomeIntervalMin = 60,
    drugBaseMultiplier = 1.0,
    pvpDrugMultiplier = 1.18,
    minVerticesRecommended = 12,
}

Config.DrugTerritoryItems = {
    weed = { weed_skunk = true, weed_og_kush = true, weed_bag = true, thc_cart = true },
    cocaine = { cokebaggy = true, cartel_pack = true },
    meth = { meth = true, meth_bag = true, amphetamine_bag = true },
    pills = { pills_pack = true },
    heroin = { heroin_bag = true },
    mushrooms = { mushroom_pack = true },
}

--[[
  Territory meta only. Geometry lives in Config.TerritoryPolygons
  (config/territory_polygons.lua) and is merged below.
]]
Config.Territories = {
    -- GANG
    davis_hood = {
        label = 'Davis',
        type = 'gang',
        drugProduct = 'pills',
        allowsDrugSales = true,
        bonuses = { reputation = 1.06, npcDemand = 1.10 },
    },
    chamberlain_hills = {
        label = 'Chamberlain Hills',
        type = 'gang',
        drugProduct = 'weed',
        allowsDrugSales = true,
        bonuses = { reputation = 1.08, graffiti = 1.15 },
    },
    grove_forum = {
        label = 'Grove Street / Forum',
        type = 'gang',
        drugProduct = 'weed',
        allowsDrugSales = true,
        bonuses = { reputation = 1.08, missionCooldown = 0.95 },
    },
    strawberry_ave = {
        label = 'Strawberry',
        type = 'gang',
        drugProduct = 'cocaine',
        allowsDrugSales = true,
        bonuses = { reputation = 1.05, npcDemand = 1.08 },
    },
    rancho_flats = {
        label = 'Rancho',
        type = 'gang',
        drugProduct = 'meth',
        allowsDrugSales = true,
        bonuses = { reputation = 1.07, crafting = 1.05 },
    },
    jamestown = {
        label = 'Jamestown',
        type = 'gang',
        drugProduct = 'heroin',
        allowsDrugSales = true,
        bonuses = { reputation = 1.06, npcDemand = 1.06 },
    },
    east_los_santos = {
        label = 'East Los Santos',
        type = 'gang',
        drugProduct = 'meth',
        allowsDrugSales = true,
        bonuses = { reputation = 1.07, crafting = 1.06 },
    },
    mirror_park = {
        label = 'Mirror Park',
        type = 'gang',
        drugProduct = 'pills',
        allowsDrugSales = true,
        bonuses = { reputation = 1.05, policeHeat = 0.92 },
    },
    vespucci_beach = {
        label = 'Vespucci Beach',
        type = 'gang',
        drugProduct = 'pills',
        allowsDrugSales = true,
        bonuses = { reputation = 1.05, policeHeat = 0.94 },
    },
    sandy_shores = {
        label = 'Sandy Shores',
        type = 'gang',
        drugProduct = 'meth',
        allowsDrugSales = true,
        bonuses = { reputation = 1.07, crafting = 1.08 },
    },
    grapeseed_farm = {
        label = 'Grapeseed',
        type = 'gang',
        drugProduct = 'mushrooms',
        allowsDrugSales = true,
        bonuses = { reputation = 1.06, supply = 1.10 },
    },
    la_puerta = {
        label = 'La Puerta',
        type = 'gang',
        drugProduct = 'cocaine',
        allowsDrugSales = true,
        bonuses = { reputation = 1.06, smuggling = 1.08 },
    },

    -- PVP
    port_of_ls = {
        label = 'Port of Los Santos',
        type = 'pvp',
        drugProduct = 'cocaine',
        allowsDrugSales = true,
        bonuses = { drugPrice = 1.18, supplyDropWeight = 1.25 },
    },
    la_mesa_industrial = {
        label = 'La Mesa Industrial',
        type = 'pvp',
        drugProduct = 'meth',
        allowsDrugSales = true,
        bonuses = { drugPrice = 1.18, crafting = 1.10 },
    },
    eureka_airfield = {
        label = 'Sandy Airfield',
        type = 'pvp',
        drugProduct = 'cocaine',
        allowsDrugSales = true,
        bonuses = { drugPrice = 1.18, supplyDropWeight = 1.30 },
    },
    murrieta_heights = {
        label = 'Murrieta Heights',
        type = 'pvp',
        drugProduct = 'heroin',
        allowsDrugSales = true,
        bonuses = { drugPrice = 1.18, policeHeat = 0.90 },
    },
    lsia_freight = {
        label = 'LSIA Freight',
        type = 'pvp',
        drugProduct = 'cocaine',
        allowsDrugSales = true,
        bonuses = { drugPrice = 1.18, smuggling = 1.15 },
    },

    -- RACKET
    downtown_pillbox = {
        label = 'Downtown / Pillbox',
        type = 'racket',
        allowsDrugSales = false,
        bonuses = { hourlyIncome = 1000, laundering = 1.08 },
    },
    rockford_hills = {
        label = 'Rockford Hills',
        type = 'racket',
        allowsDrugSales = false,
        bonuses = { hourlyIncome = 1200, laundering = 1.12 },
    },
    del_perro_pier = {
        label = 'Del Perro pakrantė',
        type = 'racket',
        allowsDrugSales = false,
        bonuses = { hourlyIncome = 950, smuggling = 1.08 },
    },
    vinewood_blvd = {
        label = 'Vinewood Blvd',
        type = 'racket',
        allowsDrugSales = false,
        bonuses = { hourlyIncome = 1250, missionPayout = 1.05 },
    },
    little_seoul = {
        label = 'Little Seoul verslai',
        type = 'racket',
        allowsDrugSales = false,
        bonuses = { hourlyIncome = 850, laundering = 1.10 },
    },
    textile_city = {
        label = 'Textile City',
        type = 'racket',
        allowsDrugSales = false,
        bonuses = { hourlyIncome = 750, crafting = 1.06 },
    },
    paleto_logistics = {
        label = 'Paleto logistika',
        type = 'racket',
        allowsDrugSales = false,
        bonuses = { hourlyIncome = 700, supply = 1.12 },
    },
}

-- Merge street polygons + optional map anchors (visual markers / GPS).
for territoryId, definition in pairs(Config.Territories) do
    local poly = Config.TerritoryPolygons and Config.TerritoryPolygons[territoryId]
    definition.vertices = poly
    definition.runtime = false
    if poly and #poly > 0 and not definition.anchor then
        local sx, sy = 0.0, 0.0
        for i = 1, #poly do
            sx = sx + (poly[i].x or 0.0)
            sy = sy + (poly[i].y or 0.0)
        end
        definition.anchor = { x = sx / #poly, y = sy / #poly }
    end
end

--- Stock territory IDs shipped in config (admin may override geometry, but not hard-delete).
Config.StockTerritoryIds = {}
for territoryId in pairs(Config.Territories) do
    Config.StockTerritoryIds[territoryId] = true
end
