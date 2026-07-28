--[[
  mrp_jobs — Burger Joint klientų NPC config (shared).
  NPC modeliai, užsakymų meniu, voice-over (su privalomu teksto fallback), eilės limitai.
]]

Config = Config or {}
Config.BurgerNpc = Config.BurgerNpc or {}

-- Baziniai GTA V civilių modeliai (lengva keisti/pildyti).
Config.BurgerNpc.models = {
    'a_m_y_business_01', 'a_f_y_business_02', 'a_m_m_business_01',
    'a_m_y_hipster_01', 'a_f_y_hipster_02', 'a_m_y_skater_01',
    'a_f_y_tourist_01', 'a_m_y_tourist_01', 'a_m_y_genstreet_01',
    'a_f_m_business_02', 'a_m_y_vinewood_01', 'a_f_y_vinewood_04',
}

-- Eilės / generavimo parametrai.
Config.BurgerNpc.queue = {
    maxActive = 5,                 -- ne daugiau kaip 5 NPC vienoje burgerinėje
    spawnIntervalMs = { min = 12000, max = 26000 }, -- kaip dažnai bandoma sukurti naują
    patienceSec = 90,              -- kiek NPC laukia užsakymo iki išeidamas
    walkSpeed = 1.0,
    -- NPC generuojami tik jei dirba kasininkas ARBA įjungtas self-service NPC pardavimas.
    requireCashier = true,
}

-- Užsakymų meniu — ką NPC gali užsakyti. items = itemai, kuriuos privalo pagaminti kepėjas.
Config.BurgerNpc.menu = {
    { id = 'single',   label = 'Paprastas burgeris',                 items = { burger_basic = 1 } },
    { id = 'double',   label = 'Dvigubas burgeris',                  items = { burger_double = 1 } },
    { id = 'chicken',  label = 'Vištienos burgeris',                 items = { burger_chicken = 1 } },
    { id = 'combo1',   label = 'Burgeris su bulvytėmis',             items = { burger_basic = 1, burger_fries = 1 } },
    { id = 'combo2',   label = 'Burgeris, bulvytės ir gėrimas',      items = { burger_basic = 1, burger_fries = 1, burger_softdrink = 1 } },
    { id = 'meal',     label = 'Burgerio meniu',                     items = { burger_meal = 1 } },
    { id = 'fries',    label = 'Tik bulvytės',                       items = { burger_fries = 1 } },
    { id = 'drink',    label = 'Tik gėrimas',                        items = { burger_softdrink = 1 } },
}

-- Voice-over: iš anksto įrašyti audio (leidžiami tik netoliese). Jei failo nėra —
-- rodomas tekstas virš NPC + kasos UI. FALLBACK TEKSTAS VEIKIA VISADA.
Config.BurgerNpc.voice = {
    enabled = true,
    -- Audio failų šaknis resurse (html/audio/<orderId>_<n>.ogg). Jei nerasta — tekstas.
    audioPath = 'html/audio/',
    variationsPerOrder = 2,        -- kiek balso variacijų vienam užsakymui
    maxDistance = 12.0,            -- girdimumo atstumas
    -- Teksto frazės kiekvienam meniu punktui (fallback + kasos UI).
    lines = {
        single = 'Norėčiau paprasto burgerio.',
        double = 'Duokite dvigubą burgerį.',
        chicken = 'Man vištienos burgerį, prašau.',
        combo1 = 'Burgerį su bulvytėmis.',
        combo2 = 'Burgerį, bulvytes ir didelį gėrimą.',
        meal = 'Vieną burgerio meniu, prašau.',
        fries = 'Tik bulvytes.',
        drink = 'Tik gėrimą, prašau.',
    },
}

-- Grąžina atsitiktinį meniu punktą.
function Config.RandomBurgerOrder()
    local m = Config.BurgerNpc.menu
    return m[math.random(1, #m)]
end
