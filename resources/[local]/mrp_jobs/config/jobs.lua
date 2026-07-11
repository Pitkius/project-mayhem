--[[
  mrp_jobs — darbų registras (shared).
  Kiekvienas darbas aprašomas bendru modeliu. Naujam darbui pridėti — pakanka
  naujo įrašo čia + serverio/kliento handlerio (server/<job>.lua, client/<job>.lua).

  Laukai:
    label            — rodomas pavadinimas
    enabled          — ar darbas aktyvus
    needsRole        — ar prieš pradedant reikia pasirinkti poziciją
    roles            — pozicijų sąrašas (jei needsRole)
    handler          — serverio handlerio raktas (registruojamas per JobManager.registerHandler)
    cooldownKey      — cooldown raktas (nil = be cooldown)
    cooldownSeconds  — cooldown trukmė sekundėmis (0 = be cooldown)
    solo             — ar darbą gali dirbti vienas žaidėjas (be kitų pozicijų)
]]

Config = Config or {}

Config.Jobs = {

    -- 1) Naftos gavyba ir pristatymas
    oil = {
        label = 'Naftos gavyba',
        enabled = true,
        needsRole = false,
        handler = 'oil',
        cooldownKey = nil,
        cooldownSeconds = 0,
    },

    -- 2) Burger Joint (3 pozicijos)
    burger = {
        label = 'Burger Joint',
        enabled = true,
        needsRole = true,
        roles = {
            { id = 'cashier', label = 'Kasininkas' },
            { id = 'cook',    label = 'Burgerių kepėjas' },
            { id = 'cleaner', label = 'Valytojas' },
        },
        handler = 'burger',
        solo = true,
        -- Valytojo cooldown tvarkomas atskirai (2 val. po pilno maršruto).
        cooldownKey = 'burger_cleaner',
        cooldownSeconds = 2 * 60 * 60, -- 2 valandos (taikoma tik cleaner pozicijai)
    },

    -- 3) Vaisių rinkėjas
    fruit = {
        label = 'Vaisių rinkėjas',
        enabled = true,
        needsRole = false,
        handler = 'fruit',
        cooldownKey = nil,
        cooldownSeconds = 0,
    },
}

-- Grąžina darbo aprašą arba nil.
function Config.GetJob(jobType)
    return Config.Jobs[jobType]
end

-- Ar pozicija galioja konkrečiam darbui.
function Config.IsValidRole(jobType, role)
    local j = Config.Jobs[jobType]
    if not j then return false end
    if not j.needsRole then return role == nil end
    if not role then return false end
    for _, r in ipairs(j.roles or {}) do
        if r.id == role then return true end
    end
    return false
end
