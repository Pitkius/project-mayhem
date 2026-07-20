--[[
  ═══════════════════════════════════════════════════════════════════
  mrp_drugs — Dark Net, progresija ir pasaulio žaliavų šaltiniai
  ═══════════════════════════════════════════════════════════════════

  Šiame faile laikoma VISA konfigūracija naujai žaliavų ekonomikai:
    · Config.DrugProgression — L1/L2/L3 pardavimų progresas ir lygių atrakinimas
    · Config.DarkNet         — nelegalus telefonas, užsakymai, dead drop, naktis, PIN
    · Config.IntroMission    — civilio įvadinė misija (vienkartinė)
    · Config.WorldSources    — aguonų laukas, alkoholio/vape/tablečių NPC

  Principas:
    ŽALIAVA → PASAULIS / NPC / DARK NET
    REIKMENYS → MATERIALSHOP
    GAMYBA → LABORATORIJA + ESAMI MINIGAME
    PARDAVIMAS → ESAMI NPC SUPIRKĖJAI
    PROGRESIJA → REALUS PARDUOTŲ GALUTINIŲ ITEMŲ KIEKIS
]]

-- ═══════════════════════════════════════════════════════════════════
--  EKONOMIKA (balansavimas + kainų svyravimai)
-- ═══════════════════════════════════════════════════════════════════
--[[
  Tikslinis bendras pelnas už PILNĄ ciklą (žaliava → gamyba → supakavimas → pardavimas),
  suderintas su supirkėjų kainomis (config.lua Config.ProductBuyerNPCs) ir žaliavų
  kaštais (Dark Net + NPC šaltiniai):

    L1 (THC, alkoholis, vape)          ≈ $500 – $1000
    L2 (žolė, heroinas, metas, tab., grybai) ≈ $1500 – $3000
    L3 (kokainas, amfetaminas)         ≈ $4000 – $7000

  Pastaba: receptuose nurodyta „įranga" (scale, lab_kit, burner, pill_press) NĖRA
  sunaudojama — ji tik turi būti šalia (pastatyta). Sunaudojami tik reikmenys ir žaliavos.
]]
Config.Economy = {
    --- Supirkimo kainų svyravimai (taikoma serverio pusėje pardavimo metu).
    priceFluctuation = {
        enabled = true,
        --- Atsitiktinis daugiklis intervale [minPct, maxPct] procentais nuo bazinės kainos.
        minPct = 90,
        maxPct = 115,
        --- Suapvalinti iki artimiausio cento (1) ar dešimtuko (10).
        roundTo = 1,
    },
}

-- ═══════════════════════════════════════════════════════════════════
--  PROGRESIJA
-- ═══════════════════════════════════════════════════════════════════
Config.DrugProgression = {
    enabled = true,

    --- Galutiniai (supakuoti) produktai priskirti lygiams.
    --- Progresas skaičiuojamas pagal REALŲ parduotų vienetų kiekį NPC supirkėjams.
    levelProducts = {
        [1] = { 'thc_cart', 'illegal_alcohol', 'vape_liquid' },
        [2] = { 'weed_bag', 'heroin_bag', 'meth_bag', 'pills_pack', 'mushroom_pack' },
        [3] = { 'cocaine_bag', 'amphetamine_bag' },
    },

    --- Kiek bendrai parduotų žemesnio lygio galutinių produktų reikia kitam lygiui.
    --- L1 visada atrakintas. L2 reikalauja X parduotų L1. L3 reikalauja Y parduotų L2.
    unlockRequirements = {
        [2] = 100, -- parduoti 100 L1 galutinių produktų → atrakina L2
        [3] = 250, -- parduoti 250 L2 galutinių produktų → atrakina L3
    },

    --- SMS iš nežinomo kontakto, kai atrakinamas naujas lygis (ne techninis pranešimas).
    unlockSms = {
        [2] = 'Apie tave pradėjo kalbėti. Atsirado žmonių, kurie turi rimtesnių pasiūlymų.',
        [3] = 'Įrodei, kad moki laikyti burną užčiauptą. Patikrink telefoną. Atsirado naujų galimybių.',
    },
}

-- ═══════════════════════════════════════════════════════════════════
--  DARK NET
-- ═══════════════════════════════════════════════════════════════════
Config.DarkNet = {
    enabled = true,

    --- Nelegalaus telefono itemas (naudojamas atidaryti Dark Net UI).
    phoneItem = 'darknet_phone',

    --- Kiek kainuoja nusipirkti telefoną (nešvarūs pinigai / markedbills).
    phonePrice = 3500,

    --- Telefono pardavėjas (juodosios rinkos kontaktas). Prieinamas TIK turintiems prieigą.
    phoneVendor = {
        enabled = true,
        model = 'g_m_m_armboss_01',
        coords = vector4(482.13, -1314.02, 29.24, 118.0),
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        label = 'Juodosios rinkos kontaktas',
        blip = { enabled = false }, -- slaptas, be blipo
    },

    --- Nešvarių pinigų mokėjimo item (turi sutapti su Config.Sell.payoutItem logika).
    payItem = 'markedbills',

    --- Naktinio pristatymo langas GTA žaidimo laiku (val.). 20:00–08:00.
    nightStartHour = 20,
    nightEndHour = 8,

    --- Kas kiek REALIŲ sekundžių serveris tikrina GTA laiką (NE 0ms loop).
    schedulerIntervalSec = 30,

    --- Dead drop paieškos zona (metrais) — žemėlapyje rodoma tik zona, ne taškas.
    searchRadius = 70.0,

    --- PIN kodo ilgis (skaitmenys).
    pinLength = 4,

    --- Dead drop propas.
    dropProp = 'prop_cs_package_01',

    --- Dead drop paėmimo animacijos / progreso trukmė (ms).
    pickupDurationMs = 6000,

    --- Interakcijos atstumas prie dead drop.
    interactDist = 2.0,

    --- Dead drop galimos vietos. Naktį serveris parenka atsitiktinę.
    --- Kiekviena: coords (tikslus dead drop taškas) — žaidėjui rodoma tik apytikslė zona.
    deadDropLocations = {
        vector3(1971.32, 5169.61, 47.83),   -- Grapeseed sandėliai
        vector3(96.44, 3750.16, 39.77),     -- Sandy Shores kelias
        vector3(-451.98, 6013.42, 31.49),   -- Paleto krūmai
        vector3(1401.55, 3597.30, 34.90),   -- Sandy pakraštys
        vector3(2564.71, 4680.09, 33.99),   -- Grapeseed laukai
        vector3(-1580.22, 5194.60, 19.40),  -- Šiaurės pakrantė
        vector3(1728.44, 6408.66, 34.79),   -- Grapeseed miestelis
        vector3(-95.10, 1913.44, 196.90),   -- Kalvos
        vector3(2878.55, 5906.11, 368.60),  -- Chiliad viršus
        vector3(-708.44, 5352.68, 74.32),   -- Miško keliukas
    },

    --- SMS tekstai (nežinomas numeris).
    sms = {
        fromNumber = '000000', -- „nežinomas" numeris (rodomas UI)
        orderAcceptedDay = 'Užsakymas priimtas. Kai sutems, gausi daugiau informacijos.',
        dropReady = 'Siunta palikta. Patikrink pažymėtą teritoriją. Iki saulėtekio jos ten nebebus. PIN: %s',
        orderExpired = 'Siunta pradingo. Kitą kartą būk greitesnis.',
        orderCollected = 'Malonu dirbti. Grįžk, kai prireiks daugiau.',
    },

    --- Dark Net asortimentas — TIK specifinės žaliavos, kurių negalima gauti pasaulyje.
    --- Kaina = nešvarūs pinigai už 1 vnt. Užsakymo suma skaičiuojama serverio pusėje.
    products = {
        {
            id = 'hemp_trim',
            item = 'hemp_trim',
            label = 'Techninės kanapės trim (THC bazė)',
            level = 1,
            pricePerUnit = 8,
            minAmount = 10,
            maxAmount = 100,
            defaultAmount = 30,
        },
        {
            id = 'chemical_mix',
            item = 'chemical_mix',
            label = 'Cheminis mišinys (reagentas)',
            level = 2,
            pricePerUnit = 25,
            minAmount = 5,
            maxAmount = 60,
            defaultAmount = 15,
        },
        {
            id = 'meth_ingredient',
            item = 'meth_ingredient',
            label = 'Meto precursorius',
            level = 2,
            pricePerUnit = 30,
            minAmount = 5,
            maxAmount = 60,
            defaultAmount = 16,
        },
        {
            id = 'amp_cold_meds',
            item = 'amp_cold_meds',
            label = 'Šaltųjų vaistų pakuotė (amp žaliava)',
            level = 3,
            pricePerUnit = 45,
            minAmount = 3,
            maxAmount = 40,
            defaultAmount = 9,
        },
        {
            id = 'amp_solvent',
            item = 'amp_solvent',
            label = 'Pramoninis tirpiklis (amp)',
            level = 3,
            pricePerUnit = 35,
            minAmount = 2,
            maxAmount = 40,
            defaultAmount = 8,
        },
        {
            id = 'amp_reactor',
            item = 'amp_reactor',
            label = 'Reaktoriaus modulis (Journey 1/3)',
            level = 3,
            pricePerUnit = 8500,
            minAmount = 1,
            maxAmount = 2,
            defaultAmount = 1,
        },
        {
            id = 'amp_cooler',
            item = 'amp_cooler',
            label = 'Aušinimo blokas (Journey 2/3)',
            level = 3,
            pricePerUnit = 6200,
            minAmount = 1,
            maxAmount = 2,
            defaultAmount = 1,
        },
        {
            id = 'amp_vent',
            item = 'amp_vent',
            label = 'Ventiliacijos rinkinys (Journey 3/3)',
            level = 3,
            pricePerUnit = 4800,
            minAmount = 1,
            maxAmount = 2,
            defaultAmount = 1,
        },
    },

    --- Maksimali vieno užsakymo suma (apsauga nuo klaidų / exploitų).
    maxOrderValue = 250000,
}

-- ═══════════════════════════════════════════════════════════════════
--  CIVILIO ĮVADINĖ MISIJA
-- ═══════════════════════════════════════════════════════════════════
Config.IntroMission = {
    enabled = true,

    --- Aktyvavimas: SMS siunčiama NE iškart prisijungus.
    --- 'drug_activity' = po pirmo sėkmingo narkotikų pardavimo (natūralus RP trigeris).
    activation = {
        mode = 'drug_activity',
        afterSales = 1, -- po tiek parduotų galutinių produktų (bet koks lygis)
    },

    --- Pirma paslaptinga SMS (nežinomas numeris).
    introSms = 'Girdėjau, kad ieškai darbo. Atvažiuok vienas. Neklausinėk.',

    --- SMS su apytiksle vieta.
    locationSms = 'Sandy Shores, prie seno garažo. Ateik pėsčias. Būsiu ten.',

    --- Kontaktinis NPC (susitikimas).
    contactNpc = {
        model = 'a_m_m_hillbilly_01',
        coords = vector4(85.62, 2795.30, 58.34, 160.0),
        scenario = 'WORLD_HUMAN_SMOKING',
        label = 'Paslaptingas kontaktas',
        blip = { enabled = true, sprite = 480, color = 5, scale = 0.8, label = 'Nežinomas kontaktas' },
    },

    --- 1 užduotis: paimti uždarą siuntą.
    packagePickup = {
        coords = vector3(2543.15, 2607.24, 37.94),
        prop = 'prop_cs_package_01',
        radius = 60.0,        -- žemėlapyje rodoma zona (ne taškas)
        durationMs = 5000,
        label = 'Paimti siuntą',
    },

    --- 2 užduotis: pristatyti į dead drop.
    delivery = {
        coords = vector3(1391.02, 3605.44, 38.94),
        prop = 'prop_cs_package_01',
        radius = 55.0,
        durationMs = 5000,
        label = 'Palikti siuntą',
    },

    --- Galutinė SMS + atrakinimas.
    finalSms = 'Gerai padirbėta. Nuo šiol turi prieigą. Nusipirk sau įrenginį — žinai kur.',

    --- Blip'ų spalvos misijos etapams.
    routeBlip = { sprite = 480, color = 5, scale = 0.9 },
}

-- ═══════════════════════════════════════════════════════════════════
--  PASAULIO ŽALIAVŲ ŠALTINIAI (ne Dark Net)
-- ═══════════════════════════════════════════════════════════════════
Config.WorldSources = {
    --- Interaktyvaus rinkimo min. tarpas tarp gavimų GTA žaidimo minutėmis
    --- (NE realaus laiko cooldown). 0 = be limito.
    gatherGameMinuteGap = 180, -- ~3 GTA valandos

    --- Alkoholio fermentacijos ūkininkas — duoda alcohol_base.
    alcoholFarmer = {
        enabled = true,
        model = 'a_m_m_farmer_01',
        coords = vector4(2447.29, 4968.72, 46.79, 137.0),
        scenario = 'WORLD_HUMAN_STAND_MOBILE',
        label = 'Ūkininkas',
        item = 'alcohol_base',
        amountMin = 9,
        amountMax = 12,
        durationMs = 6000,
        actionLabel = 'Pasiimti fermentuotą misą',
        blip = { enabled = true, sprite = 93, color = 46, scale = 0.7, label = 'Fermentacijos ūkininkas' },
    },

    --- Vape „grey market" chemikas — duoda vape_liquid_base.
    vapeChemist = {
        enabled = true,
        model = 's_m_m_scientist_01',
        coords = vector4(-1090.36, -1682.20, 4.38, 213.0),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        label = 'Chemikas',
        item = 'vape_liquid_base',
        amountMin = 9,
        amountMax = 12,
        durationMs = 6000,
        actionLabel = 'Nusipirkti vape bazę',
        --- Papildomai nurašo šiek tiek nešvarių pinigų (juodoji rinka).
        costPerBatch = 150,
        blip = { enabled = true, sprite = 499, color = 26, scale = 0.7, label = 'Vape chemikas' },
    },

    --- Tablečių naktinis kontaktas — duoda pill_powder. Dirba tik naktį (GTA).
    pillsContact = {
        enabled = true,
        model = 's_m_y_dealer_01',
        coords = vector4(294.55, -1449.86, 29.92, 320.0),
        scenario = 'WORLD_HUMAN_DRUG_DEALER',
        label = 'Naktinis kontaktas',
        item = 'pill_powder',
        amountMin = 9,
        amountMax = 12,
        durationMs = 6000,
        costPerBatch = 200,
        nightOnly = true,      -- tik 20:00–08:00 GTA
        actionLabel = 'Nusipirkti miltelių',
        blip = { enabled = true, sprite = 51, color = 27, scale = 0.7, label = 'Naktinis kontaktas' },
    },
}

--- Aguonų laukas (heroino žaliava) — naudoja tą pačią harvest sistemą kaip grybai/koka.
Config.PoppyFields = {
    {
        id = 'grapeseed_poppy',
        center = vector3(2228.51, 4870.33, 40.92),
        radius = 40.0,
        spawnCount = 16,
        respawnSec = 110,
        item = 'poppy_flower',
        amountMin = 2,
        amountMax = 4,
        pickDurationMs = 5200,
        pickDistance = 2.4,
        pickLabel = 'Skinti aguonas',
        zoneRadius = 1.1,
        prop = 'prop_plant_01a',
        blip = {
            enabled = true,
            sprite = 496,
            color = 1,
            scale = 0.75,
            label = 'Aguonų laukas',
        },
    },
}
