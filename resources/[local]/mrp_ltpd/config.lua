Config = {}

--[[
  ═══════════════════════════════════════════════════════════════════
  mrp_ltpd — pagrindinė policijos sistemos konfigūracija
  ═══════════════════════════════════════════════════════════════════

  Susiję resursai:
    · mrp_garages      — pdGarageId → Config.Garages (asmeninis PD transportas)
    · mrp_dealership   — policijos salonas (per garage marker meniu)
    · mrp_duty_locker  — uniformos (lockers / locker2)
    · mrp_bossmenu     — vadovybės meniu (boss laptop, jei įjungta)
    · mrp_npcshops     — supply (darbo reikmenys) + PD maistas
    · qb-inventory     — armory + stashes (stashId unikalus DB)
    · mrp_siren_controller — F6 sirenos (Config.FleetVehicles)

  Žemėlapio taškai (client/pd_markers.lua):
    · duty      — [E] pradėti / baigti pamainą
    · garage    — [E] garažas + transporto pirkimas
    · locker    — [E] tarnybinė apranga (mrp_duty_locker)
    · armory    — [E] ARAS / ginklinė (divisions + minGrade)
    · stash     — [F2] sandėlis (mėlynas trikampis)
    · supply    — [E] inventorius (žalias trikampis)
    · food      — [E] maisto pirkimas (žalias trikampis)
    · armory    — [E] ARAS ginklų pirkimas (žalias trikampis)
    · craft     — ginklų gamyba (oranžinis trikampis)

  Koordinates: /coords arba txAdmin — atnaujink čia, tada restart mrp_ltpd.
]]

--- Darbo pavadinimas turi sutapti su `qb-core/shared/jobs.lua` įrašu `police`.
Config.JobName = 'police'

--[[
  Padaliniai – saugoma DB `ltpd_profiles.division` (tik police job).
  Rangai 0–3: automatiškai LPM. Nuo 4 rango – žaidėjas renkasi padalinį (/pddept arba rūbinėje).
]]
Config.DivisionRules = {
    lpmMaxGrade = 3,      -- įskaitant 3 – vis dar LPM
    chooseMinGrade = 4,   -- nuo šio rango galima keisti padalinį
}

Config.Divisions = {
    lpm = { label = 'LPM (mokymo padalinys)', abbr = 'LPM', minGrade = 0, choosable = false, autoOnly = true },
    mp = { label = 'Miesto patrulių divizija', abbr = 'MP', minGrade = 4, choosable = true },
    kpd = { label = 'Kelių policijos divizija', abbr = 'KPD', minGrade = 4, choosable = true },
    ktd = { label = 'Kriminalinių tyrimų divizija', abbr = 'KTD', minGrade = 4, choosable = true },
    aras = { label = 'Antiteroristinių operacijų rinktinė', abbr = 'ARAS', minGrade = 4, choosable = true },
    opd = { label = 'Oro paramos divizija', abbr = 'OPD', minGrade = 4, choosable = true },
    kd = { label = 'Kinologų divizija', abbr = 'KD', minGrade = 4, choosable = true },
    vtd = { label = 'Vidaus tyrimų divizija', abbr = 'VTD', minGrade = 4, choosable = true },
    admin = { label = 'Administracija', abbr = 'ADM', minGrade = 7, choosable = false },
}

--- Kol nėra atskirų ARAS aprangų įrašų su `divisions = {'aras'}`, ARAS rūbinė rodo tas pačias uniformas
Config.AroLockerShowsAllUniforms = true

--- Minimalus grade (0 = Kursantas) veiksmui
--- F7 – surinktų pirštų atspaudų žurnalas (tarnybos metu)
Config.FingerprintJournalKey = 'F7'

Config.Permissions = {
    mdt_open = 0,
    mdt_search_basic = 0,
    mdt_search_full = 3, -- pinigai, transportas, išsamiau
    mdt_fine = 1,
    mdt_wanted = 2,
    mdt_fingerprint = 1,
    mdt_arrest_record = 2,
    mdt_interrogation = 2,
    cuff = 1,
    search_inventory = 1,
    traffic_radar = 1, -- rezervas / ateities integracija
    division_admin = 8,
    armory = 0, -- bendra policijos ginklinė (stash)
    garage = 0, -- PD tarnybinio transporto išėmimas
    boss_menu = 7, -- Įdarb./atleisti/rangas (isboss arba ≥ šis grade – qb-core rangų sutapimas)
    --- PD sirenos / laikina įranga ant civilinės mašinos
    pd_siren_controller = 0,
    pd_emergency_kit = 0,
    --- PD išorinių / vidinių durų ir vartų užraktas (E) – tik tarnyboje
    pd_doors = 0,
    pd_craft = 0,
    mdt_cctv = 0,
    mdt_bodycam = 0,
    mdt_weapon_license = 3,
    bodycam_wear = 0,
}

--- Šviesų ir sirenos valdymas (masinoje): režimas per entity statebag (sinchr. visiems žaidėjams)
--- Fleet / MRPD: tik native SetVehicleSiren (kaip GTA police) — jokių custom DrawLight.
--- Prop lightbar + script flash → tik civilinė TP su pd_emergency_kit, arba emergencyLights='script'.
Config.EmergencyVehicle = {
    --- qb-menu komandos (tik adminams – žaidėjai naudoja itemą)
    sirenMenuCommand = 'pdsirenai',
    kitMenuCommand = 'pdiranga',
    commandsAdminOnly = true,
    kitItem = 'pd_emergency_kit',
    returnKitItemOnRemove = true,
    --- kai išlipi iš vairuotojo vietos – išjungti sirenos režimą ir garsą
    resetModeWhenLeaveDriverSeat = true,
    --- nuo transporto centro atstumas (m), kuriuo serveris priima veiksmus
    validateDistance = 28.0,
    --- Laikina švyturėlių juosta civilinei TP (prop ant stogo)
    lightbarModel = 'prop_lightbar_01',
    lightbarYOffset = -0.10,
    lightbarZOffset = 0.06,
    --- Mažos matomos lempos ant švyturėlio (šviesa papildomai piešiama scriptu)
    lensModel = 'prop_warninglight_01',
    lensHideProp = false,
    lensLeftOffset = { x = -0.26, y = 0.0, z = 0.08 },
    lensRightOffset = { x = 0.26, y = 0.0, z = 0.08 },
    --- Vizualas: standard | enhanced (dvigubas halo + bar pulse)
    flashVisualPreset = 'enhanced',
    flashColors = {
        red = { r = 255, g = 48, b = 52 },
        blue = { r = 58, g = 128, b = 255 },
        white = { r = 248, g = 252, b = 255 },
    },
    --- Mirksėjimo intervalas (ms)
    flashIntervalMs = 420,
    flashTickMs = 65,
    --- Šviesos prie lempų – ryškesnės, panašiau į tikrą policijos signalą
    flashLightRange = 13.5,
    flashLightIntensity = 5.2,
    flashUseLensGlow = true,
    flashUseBarGlow = true,
    flashMarkerScale = 0.058,
    flashMarkerGlowScale = 0.145,
    --- Kryptiniai spinduliai (matomi ir toliau)
    flashUseSpotBeams = true,
    flashUseNearSpotBeams = true,
    flashNearSpotDistance = 48.0,
    flashSpotRange = 24.0,
    flashSpotIntensity = 9.5,
    flashUseAmbientGlow = true,
    flashDrawDistance = 80.0,
    --- Tik Config.FleetVehicles + native emergency — ne visi GetVehicleClass 18 (addon klaidos)
    trustVehicleClassEmergency = false,
    --- Originalūs packai (dabar spawn mrpd*) naudoja kūrėjo native carcols.
    --- Jokių scriptinių stogo ar bone šviesų ant jų nepiešiame.
    nativeFlashAssist = false,
    fleetRoofFlashAssist = false,
    fleetRoofFlashY = -0.15,
    fleetRoofFlashZ = 0.92,
    fleetRoofFlashXSpread = 0.42,
    fleetRoofFlashIntervalMs = 90,
    fleetRoofFlashRange = 4.5,
    fleetRoofFlashIntensity = 2.8,
    fleetSirenBoneLights = false,
    fleetSirenBoneLightsWithNative = false,
    fleetSirenBoneIntervalMs = 90,
    fleetSirenBoneRange = 2.6,
    fleetSirenBoneIntensity = 1.5,
    fleetSirenBoneMaxPoints = 8,
    --- Script flash (prop + DrawLight) TIK civilinei TP su pd_emergency_kit
    --- Lengvas „tuning“ civilinei TP su įranga (sirenos + švyturėliai)
    allowPassengerControl = true,
    performanceTune = {
        enabled = true,
        acceleration = 1.045,
        topSpeed = 1.028,
        extraMaxKmh = 6,
        braking = 1.06,
        steering = 1.025,
        traction = 1.03,
        driveInertia = 0.97,
    },
}

--- Baudų šablonai (kodas rodomas MDT)
Config.FinePresets = {
    { code = 'SPEED', label = 'Greičio viršijimas', defaultAmount = 150 },
    { code = 'RED', label = 'Raudono šviesoforo pažeidimas', defaultAmount = 200 },
    { code = 'PARK', label = 'Netinkamas parkavimas', defaultAmount = 80 },
    { code = 'DOC', label = 'Dokumentų neturėjimas', defaultAmount = 120 },
    { code = 'NOISE', label = 'Triukšmo pažeidimas', defaultAmount = 100 },
}

--- MDT žemėlapis — Leaflet CRS.Simple + satelitinį PNG.
--- projection = homography: projekcinė transformacija (stabiliausia su 20+ taškų).
--- coordSpace = pixel: žymekliai tiesiai ant PNG pikselių (ne per ištemptą game bbox).
--- Paleisti: node tools/mdt_map_fit.mjs
Config.MdtMap = {
    projection = 'homography',
    coordSpace = 'pixel',
    gameMin = { x = -4000.0, y = -4000.0 },
    gameMax = { x = 4500.0, y = 6625.0 },
    coordMin = { x = -4000.0, y = -4000.0 },
    coordMax = { x = 4500.0, y = 6625.0 },
    viewMin = { x = -4000.0, y = -4000.0 },
    viewMax = { x = 4500.0, y = 6625.0 },
    offsetX = 0.0,
    offsetY = 0.0,
    scaleX = 1.0,
    scaleY = 1.0,
    flipY = false,
    imageFile = 'mdt/asset/gtav_satellite_2048.png',
    imageWidth = 2048,
    imageHeight = 2048,
    calibration = {
        { gx = -448.15,  gy = 6012.0,   u = 0.4585, v = 0.1099 },
        { gx = 450.77,   gy = 5566.86,  u = 0.5352, v = 0.1426 },
        { gx = 1853.2,   gy = 3686.5,   u = 0.6460, v = 0.2881 },
        { gx = 1695.0,   gy = 4785.0,   u = 0.6616, v = 0.1904 },
        { gx = 611.0,    gy = 2745.0,   u = 0.5156, v = 0.3901 },
        { gx = -2360.0,  gy = 3249.0,   u = 0.2261, v = 0.3896 },
        { gx = -3192.0,  gy = 1100.0,   u = 0.1025, v = 0.5894 },
        { gx = -1520.0,  gy = -440.0,   u = 0.2593, v = 0.6978 },
        { gx = -1098.0,  gy = -808.0,   u = 0.3022, v = 0.7280 },
        { gx = 441.84,   gy = -982.05,  u = 0.4487, v = 0.7383 },
        { gx = 195.0,    gy = -933.0,   u = 0.4092, v = 0.7446 },
        { gx = 311.0,    gy = -590.0,   u = 0.4136, v = 0.6953 },
        { gx = 379.39,   gy = -1591.37, u = 0.4390, v = 0.8008 },
        { gx = 85.0,     gy = -1958.0,  u = 0.3989, v = 0.8276 },
        { gx = -1037.0,  gy = -2737.0,  u = 0.2827, v = 0.9175 },
        { gx = 1206.24,  gy = -3157.06, u = 0.4688, v = 0.9116 },
        { gx = 293.0,    gy = 180.0,    u = 0.4395, v = 0.6274 },
        { gx = -800.0,   gy = 180.0,    u = 0.3472, v = 0.6489 },
        { gx = 981.69,   gy = -102.8,   u = 0.5078, v = 0.6528 },
        { gx = 2452.28,  gy = 4969.7,   u = 0.7065, v = 0.1758 },
        { gx = 826.0,    gy = -1290.0,  u = 0.4727, v = 0.7417 },
        { gx = -75.0,    gy = -818.0,   u = 0.4009, v = 0.7231 },
    },
}

--- MDT GPS žemėlapis — laikinas išjungimas (skirta nuo CCTV/bodycam).
--- Neįtakoja: PANIC mygtuko, dispatch blipų įprastame žemėlapyje, iškvietimų sąrašo.
Config.MdtMapMaintenance = {
    enabled = true,
    message = 'GPS žemėlapio sistema laikinai neveikia. Dėl finansavimo skyrimo ir įrengimo kreipkitės į miesto merą.',
}

--- Maks. atstumas iki ginklinės / sandėlių / PD garažo (patikra serveryje)
Config.ArmoryGarageDistance = 38.0
--- (Rezervas) vadovybės veiksmų atstumo patikra serveryje
Config.ManagementRadius = 18.0

--- Blipai žemėlapyje (komisariatai) — naudoja Config.Stations[].blipCoords arba coords
Config.ShowStationBlips = true
Config.BlipSprite = 60
Config.BlipColour = 38
Config.BlipScale = 0.85
--- Stogo helipado blipas (PD sraigtasparnis)
Config.ShowHelipadBlip = false
Config.HelipadBlipSprite = 43
Config.HelipadBlipScale = 0.9

--- 3D markeriai ant žemės (MRPD / Sandy) — trikampiai inventory taškams
Config.ShowPd3DMarkers = true
Config.PdMarkerDrawDistance = 14.0
--- Kai markeris matomas, bet ne interact: ~20 FPS (mažina CPU vs Wait(0))
Config.PdMarkerNearTickMs = 50
--- Max DrawMarker per kadrą (arti lieka interact; tolimesni praleidžiami)
Config.PdMarkerMaxDraw = 4
Config.PdMarkerZOffset = 0.02
--- Trikampis (DrawMarker tipas 2): žalia=parduotuvė, mėlyna=sandėlis, oranžinė=craft
Config.PdTriangleMarkerType = 2
Config.PdTriangleMarkerScale = { x = 0.38, y = 0.38, z = 0.38 }
Config.PdStashMarkerType = 2
Config.PdStashMarkerScale = { x = 0.38, y = 0.38, z = 0.38 }
Config.PdStashMarkerDrawDistance = 12.0
Config.PdInventoryMarkerDrawDistance = 12.0
Config.PdMarkerTextDistance = 2.2

--- Tarnybinis transportas (perkurta iš Animuotu + undercover + MPRPD RAR)
--- emergencyLights:
---   'native' / 'hybrid' = SetVehicleSiren + mašinos lightbar (carcols)
---   'script' = prop lightbar (tik modeliams be savų lempų)
Config.FleetVehicles = {
  -- ŽYMĖTOS Non-ELS
  { model = 'mrpd1', label = 'MRPD 1 (žymėta)', emergencyLights = 'native' },
  { model = 'mrpd2', label = 'MRPD 2 (žymėta)', emergencyLights = 'native' },
  { model = 'mrpd3', label = 'MRPD 3 (žymėta)', emergencyLights = 'native' },
  { model = 'mrpd4', label = 'MRPD 4 (žymėta)', emergencyLights = 'native' },
  { model = 'mrpd5', label = 'MRPD 5 (žymėta)', emergencyLights = 'native' },
  { model = 'mrpd6', label = 'MRPD 6 (žymėta)', emergencyLights = 'native' },
  { model = 'mrpd7', label = 'MRPD 7 (žymėta)', emergencyLights = 'native' },
  { model = 'mrpd8', label = 'MRPD 8 (žymėta)', emergencyLights = 'native' },
  { model = 'mrpd9', label = 'MRPD 9 — Audi RS6 Avant', emergencyLights = 'native' },
  { model = 'mrpd10', label = 'MRPD 10 — Kia Stinger', emergencyLights = 'native' },
  { model = 'mrpd11', label = 'MRPD 11 — Hyundai', emergencyLights = 'native' },
  { model = 'mrpd12', label = 'MRPD 12 — Alfa Romeo', emergencyLights = 'native' },
  -- ŽYMĖTOS LT ELS
  { model = 'mrpd13', label = 'MRPD 13 — Audi S3 (LT ELS)', emergencyLights = 'els' },
  { model = 'mrpd14', label = 'MRPD 14 — BMW 540i (LT ELS)', emergencyLights = 'els' },
  { model = 'mrpd15', label = 'MRPD 15 — BMW X5 (LT ELS)', emergencyLights = 'els' },
  { model = 'mrpd16', label = 'MRPD 16 — Skoda Hatch (LT ELS)', emergencyLights = 'els' },
  { model = 'mrpd23', label = 'MRPD 23 — Skoda Estate (LT ELS)', emergencyLights = 'els' },
  -- NEŽYMĖTOS Non-ELS
  { model = 'mrpd17', label = 'MRPD 17 (nežymėta)', emergencyLights = 'native' },
  { model = 'mrpd18', label = 'MRPD 18 (nežymėta)', emergencyLights = 'native' },
  { model = 'mrpd19', label = 'MRPD 19 (nežymėta)', emergencyLights = 'native' },
  { model = 'mrpd20', label = 'MRPD 20 (nežymėta)', emergencyLights = 'native' },
  -- NEŽYMĖTOS LT ELS
  { model = 'mrpd21', label = 'MRPD 21 — BMW 540i VAD (LT ELS)', emergencyLights = 'els' },
  { model = 'mrpd22', label = 'MRPD 22 — Audi S3 nežymėta (ELS)', emergencyLights = 'els' },
}

--- Built-in fleet: tik Non-ELS carcols šviesos per SetVehicleSiren (ELS čia NEįtraukti).
Config.BuiltInFleetModels = {
    'mrpd1', 'mrpd2', 'mrpd3', 'mrpd4', 'mrpd5', 'mrpd6', 'mrpd7', 'mrpd8',
    'mrpd9', 'mrpd10', 'mrpd11', 'mrpd12',
    'mrpd17', 'mrpd18', 'mrpd19', 'mrpd20',
    'polmav', 'buzzard2',
}

--- Sena dokumentacija — nebenaudojama (extras valdomi tik jei egzistuoja ant modelio).
Config.FleetExclusiveExtras = {}
Config.FleetLightbarExtraDefault = nil
Config.FleetLightbarExtra = {}

--- Sraigtasparniai (stogas / helipadas) – spawn ant `heliGarage.spawn`
Config.FleetHelicopters = {
    { model = 'polmav', label = 'Policijos Maverick' },
    { model = 'buzzard2', label = 'Buzzard (tarnybinis)' },
}

--- PD registratūra (civiliai) ir priėmimo anketos
Config.Reception = {
    statementMinLen = 15,
    applicationMinMotivation = 20,
    applicationCooldownHours = 48,
    statementCooldownMinutes = 10,
}

--[[
  ═══════════════════════════════════════════════════════════════════
  PD STOČIOS (Config.Stations)
  ═══════════════════════════════════════════════════════════════════

  Kiekvienos stoties laukai:
    id            — unikalus ID (server eventai, pdGarageId nuoroda)
    coords        — stoties centras (duty = true naudoja čia pamainai)
    blipCoords    — policijos blipas žemėlapyje (ShowStationBlips)
    duty          — { coords } arba true (= coords)
    reception     — civiliai; atskiras blip (client/reception.lua)
    supply        — darbo reikmenys (mrp_npcshops job supply)
    armory        — ARAS / ginklinė; divisions + minGrade; [E]
    pdGarageId    — mrp_garages Config.Garages.id (pvz. pd_ls_main)
    garage        — 3D markeris: garažas + salonas; spawn = fleet spawn
    boss          — laptop qb-target; vadovybė (≥ Config.Permissions.boss_menu)
    bossAro       — papildomas ARAS aukšto vadovybės laptopas (tas pats meniu)
    lockers[]     — kelios standartinės rūbinės (uniformos)
    locker2       — ARAS rūbinė (lockerMode = 'aro', divisions = aras)
    stashes[]     — sandėliai; [F2]; minGrade didėja; stashId → qb-inventory
    heliGarage    — sraigtasparniai (Config.FleetHelicopters)

  ls_main — NTeam MRPD (cfx-nteam-mrpd)
  sandy   — Sandy Shores PD MLO
]]
Config.Stations = {
    --- ─── Los Santos · Mission Row (MRPD) ───────────────────────────
    {
        id = 'ls_main',
        label = 'Los Santos – pagrindinė komisariatas',
        coords = vector3(441.84, -982.05, 30.69),
        blipCoords = vector3(427.120, -979.559, 30.716),
        heading = 90.0,
        --- Pamaina — violetinis markeris
        duty = {
            coords = vector3(440.085, -974.924, 30.689),
        },
        --- Civiliai — atskiras registratūros blipas
        reception = {
            coords = vector3(431.06, -988.37, 31.39),
            heading = 180.0,
            length = 1.65,
            width = 1.45,
            label = 'PD registratūra',
            blip = { sprite = 280, color = 3, scale = 0.72, label = 'PD registratūra' },
        },
        --- Darbo reikmenys (taisyklės, radijas ir t. t.)
        supply = {
            coords = vector3(462.23, -981.12, 30.68),
            label = 'PD ginklinė / inventorius',
        },
        --- Maisto pirkimas (pigiau nei 24/7) — stogas Z≈42
        foodSupply = {
            coords = vector3(459.1157, -980.6447, 42.2494),
            heading = 84.6649,
            label = 'PD maisto parduotuvė',
        },
        --- ARAS ginklų pirkimas (ARAS padalinys + vadas/pavaduotojas)
        armory = {
            coords = vector3(472.5475, -947.7100, 38.2497),
            heading = 272.8297,
            label = 'ARAS ginklų pirkimas',
            minGrade = 2,
            divisions = { 'aras' },
        },
        --- Nuoroda į mrp_garages — asmeninis PD transporto garažas DB
        pdGarageId = 'pd_ls_main',
        --- Peržiūros taškas (salonas atidaromas per garage marker meniu)
        policeDealership = {
            coords = vector3(447.9836, -967.4344, 22.8469),
            heading = 84.1690,
        },
        --- 3D markeris [E]: garažas + „Transporto pirkimas“ → mrp_dealership
        garage = {
            coords = vector3(447.9836, -967.4344, 22.8469),
            spawn = vector4(447.9836, -967.4344, 22.8469, 84.1690),
        },
        --- qb-target ant laptopo — įdarb./atleisti/rangas (client/boss.lua)
        boss = {
            coords = vector4(454.8502, -931.5825, 34.2503, 350.3920),
            label = 'LTPD vadovybė',
            prop = 'prop_laptop_01a',
            spawnProp = true,
        },
        --- ARAS aukštas — atskiras vadovybės laptopas
        bossAro = {
            coords = vector4(466.7161, -928.0859, 38.2496, 188.3563),
            label = 'ARAS vadovybė',
            prop = 'prop_laptop_01a',
            spawnProp = true,
        },
        --- Standartinės rūbinės — mrp_duty_locker, lockerMode = standard
        lockers = {
            { coords = vector3(449.5441, -979.1705, 30.2503), heading = 269.1113, label = 'PD rūbinė 1' },
            { coords = vector3(448.1797, -976.9896, 30.2503), heading = 93.1164, label = 'PD rūbinė 2' },
            { coords = vector3(444.9413, -979.2111, 30.2503), heading = 87.7559, label = 'PD rūbinė 3' },
            { coords = vector3(446.3055, -976.9395, 30.2503), heading = 273.1330, label = 'PD rūbinė 4' },
        },
        --- ARAS specialioji rūbinė (atskirai nuo lockers[])
        locker2 = {
            coords = vector3(455.65, -997.62, 30.6896),
            heading = 90.0,
            label = 'ARAS rūbinė',
            lockerMode = 'aro',
            divisions = { 'aras' },
        },
        --- Sandėliai — [F2] prie markerio; stashId unikalus visam serveriui
        stashes = {
            {
                coords = vector3(453.075, -980.124, 30.889),
                stashId = 'ltpd_stash_public_ls',
                label = 'PD sandėlis (bendras)',
                minGrade = 0,
                divisions = { 'lpm', 'mp', 'kpd', 'ktd', 'aras', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 2000000,
                slots = 60,
            },
            {
                coords = vector3(451.7031, -973.232, 30.689),
                stashId = 'ltpd_stash_grade3_ls',
                label = 'PD sandėlis (≥3 rango)',
                minGrade = 3,
                divisions = { 'lpm', 'mp', 'kpd', 'ktd', 'aras', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 2500000,
                slots = 70,
            },
            {
                coords = vector3(455.1456, -985.462, 30.689),
                stashId = 'ltpd_stash_grade8_ls',
                label = 'PD sandėlis (vadovų)',
                minGrade = 8,
                divisions = { 'mp', 'kpd', 'ktd', 'aras', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 3000000,
                slots = 80,
            },
            {
                coords = vector3(472.5426, -933.1423, 34.2504),
                stashId = 'ltpd_stash_boss_ls',
                label = 'PD sandėlis (bosas / pavaduotojas)',
                minGrade = 7,
                divisions = { 'mp', 'kpd', 'ktd', 'aras', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 3500000,
                slots = 90,
            },
            --- ARAS daiktų dėžė — ginklai / daiktai (tik ARAS; vadas/pavaduotojas apeina padalinį)
            {
                coords = vector3(472.5499, -945.3289, 38.2497),
                stashId = 'ltpd_stash_aro_ls',
                label = 'ARAS daiktų sandėlis',
                minGrade = 2,
                divisions = { 'aras' },
                maxweight = 4000000,
                slots = 100,
            },
            --- Konfiskuoti daiktai (MRPD rūsys z≈22.85) — [F2]
            {
                coords = vector3(455.0941, -1004.6840, 22.8469),
                heading = 273.5348,
                stashId = 'ltpd_stash_confisc_pd_ls',
                label = 'Konfiskuotų policijos daiktų sandėlis',
                minGrade = 0,
                divisions = { 'lpm', 'mp', 'kpd', 'ktd', 'aras', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 5000000,
                slots = 120,
            },
            {
                coords = vector3(455.1414, -1001.9164, 22.8469),
                heading = 263.0187,
                stashId = 'ltpd_stash_confisc_aro_ls',
                label = 'Konfiskuotų ARAS daiktų sandėlis',
                minGrade = 0,
                divisions = { 'aras' },
                maxweight = 5000000,
                slots = 120,
            },
            {
                coords = vector3(457.9408, -1002.8630, 22.8469),
                heading = 272.9747,
                stashId = 'ltpd_stash_confisc_weapons_ls',
                label = 'Konfiskuotų ginklų sandėlis',
                minGrade = 0,
                divisions = { 'lpm', 'mp', 'kpd', 'ktd', 'aras', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 5000000,
                slots = 120,
            },
            --- Maisto sandėlis (stogas Z≈42)
            {
                coords = vector3(462.9796, -975.2534, 42.2494),
                heading = 272.3348,
                stashId = 'ltpd_stash_food_ls',
                label = 'PD maisto sandėlis',
                minGrade = 0,
                divisions = { 'lpm', 'mp', 'kpd', 'ktd', 'aras', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 1500000,
                slots = 50,
            },
        },
        --- Stogo helipadas — Config.FleetHelicopters spawn
        heliGarage = {
            coords = vector3(449.168, -981.325, 43.691),
            spawn = vector4(449.168, -981.325, 43.691, 87.234),
        },
    },
    --- ─── Sandy Shores PD (antra stotis / blip kopija) ───────────────
    {
        id = 'sandy',
        label = 'Sandy Shores PD',
        coords = vector3(1853.7436, 3688.6435, 29.8185),
        blipCoords = vector3(1853.7436, 3688.6435, 29.8185),
        heading = 206.0,
        duty = true, --- pamaina ties coords
        reception = {
            coords = vector3(1859.75, 3689.12, 33.99),
            heading = 210.0,
            length = 1.65,
            width = 1.45,
            label = 'PD registratūra',
            blip = { sprite = 280, color = 3, scale = 0.72, label = 'PD registratūra (Sandy)' },
        },
        supply = {
            coords = vector3(1849.12, 3690.04, 34.27),
            label = 'PD inventorius',
        },
        armory = {
            coords = vector3(1847.0, 3691.5, 34.27),
            label = 'ARAS ginklinė (Sandy)',
            minGrade = 2,
            divisions = { 'aras' },
        },
        pdGarageId = 'pd_sandy',
        policeDealership = {
            coords = vector3(1869.5, 3695.2, 33.53),
            heading = 210.0,
        },
        garage = {
            coords = vector3(1869.5, 3695.2, 33.53),
            spawn = vector4(1869.5, 3695.2, 33.53, 210.0),
        },
        boss = {
            coords = vector4(1852.0, 3688.5, 34.27, 210.0),
            label = 'LTPD vadovybė',
            prop = 'prop_laptop_01a',
            spawnProp = true,
        },
        --- Sandy rūbinės (2 vnt.) — tas pats mrp_duty_locker flow kaip MRPD
        lockers = {
            { coords = vector3(1854.1200, 3687.8689, 29.8185), heading = 206.7797, label = 'PD rūbinė 1' },
            { coords = vector3(1853.3671, 3689.4180, 29.8185), heading = 41.1066, label = 'PD rūbinė 2' },
        },
        --- Sandy sandėliai — [F2]; sandėlis 3 koord. tikslinti jei reikia
        stashes = {
            {
                coords = vector3(1861.8282, 3688.3879, 34.2194),
                stashId = 'ltpd_stash_public_sandy',
                label = 'PD sandėlis 1',
                minGrade = 0,
                divisions = { 'lpm', 'mp', 'kpd', 'ktd', 'aras', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 2000000,
                slots = 60,
            },
            {
                coords = vector3(1859.6638, 3688.9521, 34.2194),
                stashId = 'ltpd_stash_grade3_sandy',
                label = 'PD sandėlis 2',
                minGrade = 3,
                divisions = { 'lpm', 'mp', 'kpd', 'ktd', 'aras', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 2500000,
                slots = 70,
            },
            {
                coords = vector3(1860.7460, 3688.6700, 34.2194),
                stashId = 'ltpd_stash_grade8_sandy',
                label = 'PD sandėlis 3',
                minGrade = 8,
                divisions = { 'mp', 'kpd', 'ktd', 'aras', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 3000000,
                slots = 80,
            },
            {
                coords = vector3(1849.2041, 3695.5696, 38.2205),
                stashId = 'ltpd_stash_boss_sandy',
                label = 'PD boso sandėlis',
                minGrade = 7,
                divisions = { 'mp', 'kpd', 'ktd', 'aras', 'opd', 'kd', 'vtd', 'admin' },
                maxweight = 3500000,
                slots = 90,
            },
        },
    },
}

--- Tarnybinė PD apranga – žr. config_duty_outfits.lua (addon kolekcijos mrp_pd_uniforms)

Config.TargetDistance = 2.5
Config.MaxFineAmount = 50000

--- PD durys / vartai — client/pd_doors.lua; [E] arba qb-target (PdDoorUseQbTarget)
--- NTeam MRPD (LS) + Sandy Shores MLO — entityScan randa prop modelius zonoje
Config.PdDoorToggleReach = 6.0
--- Spynos ikonos Z poslinkis nuo durų slab koord. (standartinės durys)
Config.PdDoorLockIconZOffset = 0.38
--- Spynos ikona rodoma tik arti durų; arti piešiama kiekvieną kadrą, kad nemirgėtų.
Config.PdDoorLockIconDrawDistance = 5.5
--- false = tik E mygtukas; true = papildomai qb-target (numatyta: tik E)
Config.PdDoorUseQbTarget = false
Config.PdDoorGroups = {
    {
        id = 'ls_mrpd_garage_roll',
        label = 'Garažo vartai (MRPD)',
        doorType = 'garage_roll',
        interact = vector3(447.9836, -967.4344, 22.8469),
        interactDist = 5.0,
        defaultLocked = true,
        doors = {},
        entityScan = {
            center = vector3(447.5, -967.0, 23.5),
            radius = 18.0,
            models = { 'nteam_mrpd_garagedoors', 'nteam_mrpd_shut' },
        },
    },
    {
        id = 'ls_mrpd_front_entry',
        label = 'Priekinis kiemas (vartai)',
        doorType = 'barrier',
        interact = vector3(410.223, -1021.4033, 29.2392),
        interactDist = 5.5,
        defaultLocked = true,
        doors = {
            { model = 'prop_facgate_07b', coords = vector3(411.0243, -1025.059, 28.335), heading = 270.0 },
        },
        entityScan = {
            center = vector3(411.0243, -1025.059, 28.335),
            radius = 12.0,
            models = { 'prop_facgate_07b' },
        },
    },
    {
        id = 'ls_mrpd_back_gate',
        label = 'Kiemo vartai',
        doorType = 'barrier',
        interact = vector3(488.8, -1020.2, 29.0),
        interactDist = 12.0,
        defaultLocked = true,
        doors = {
            { model = 'hei_prop_station_gate', coords = vector3(488.8, -1017.2, 27.1) },
        },
        entityScan = {
            center = vector3(488.8, -1017.2, 27.1),
            radius = 14.0,
            models = { 'hei_prop_station_gate' },
        },
    },
    {
        id = 'ss_pd_front_manual',
        label = 'Sandy PD main doors',
        interact = vector3(1859.75, 3689.12, 33.99),
        interactDist = 2.9,
        defaultLocked = true,
        doors = {
            { model = 'hedwig_sheriff_door01', coords = vector3(1860.32, 3689.71, 33.986) },
            { model = 'hedwig_sheriff_door01', coords = vector3(1859.18, 3688.52, 33.986) },
        },
    },
    {
        id = 'ss_pd_garage_manual',
        label = 'Sandy PD garage door',
        doorType = 'garage_roll',
        interact = vector3(1854.92, 3701.15, 33.73),
        interactDist = 3.8,
        defaultLocked = true,
        doors = {
            { model = 'hedwig_sheriff_garage_gardoor', coords = vector3(1854.92, 3701.15, 33.73), heading = 0.0 },
        },
        entityScan = {
            center = vector3(1854.92, 3701.15, 33.73),
            radius = 12.0,
            models = { 'hedwig_sheriff_garage_gardoor', 'hedwig_sheriff_garage_door' },
        },
    },
}

Config.PdDoorInteractExtras = {
    { groupId = 'ls_mrpd_garage_roll', interact = vector3(447.9836, -967.4344, 22.8469), interactDist = 5.0 },
    { groupId = 'ls_mrpd_front_entry', interact = vector3(410.1, -1024.3, 29.75), interactDist = 5.0 },
    { groupId = 'ls_mrpd_back_gate', interact = vector3(488.8, -1017.2, 27.1), interactDist = 6.0 },
}

--- Automatinis durų radimas (objektai žemėlapyje pagal modelį ir dėžę)
Config.PdDoorDynamics = {
    {
        stationId = 'ls_main',
        label = 'PD durys (NTeam MRPD – auto)',
        bounds = {
            min = vector3(400.0, -1060.0, 18.0),
            max = vector3(505.0, -910.0, 58.0),
        },
        models = {
            'nteam_mrpd_metaldoor',
            'nteam_mrpd_garagedoors',
            'nteam_mrpd_bathroomdoor',
            'nteam_mrpd_tamdoor',
            'nteam_mrpd_shut',
            'xm3_prop_xm3_glass_door_02a',
            'v_ilev_ph_gendoor',
            'v_ilev_fib_doore_l',
            'v_ilev_fib_doore_r',
        },
        pairDist = 4.35,
        interactDist = 2.85,
    },
    {
        stationId = 'sandy',
        label = 'PD durys (Sandy)',
        bounds = { min = vector3(1775.0, 3585.0, 18.0), max = vector3(1935.0, 3785.0, 75.0) },
        models = {
            'hedwig_sheriff_door01',
            'hedwig_sheriff_door02',
            'hedwig_sheriff_door03',
            'hedwig_sheriff_door04',
            'hedwig_sheriff_door05',
            'hedwig_sheriff_door06',
            'hedwig_sheriff_garage_gardoor',
            'hedwig_sheriff_garage_door',
        },
        pairDist = 4.35,
        interactDist = 2.85,
    },
}

--- MDT asmens paieška — licencijų rodymas (sutampa su mrp_licenses / drivingschool)
Config.MdtLicenses = {
    DrivingCategories = {
        { key = 'driver_a', letter = 'A', label = 'Motociklai' },
        { key = 'driver_b', letter = 'B', label = 'Lengvieji automobiliai', altKeys = { 'driver' } },
        { key = 'driver_c', letter = 'C', label = 'Sunkvežimiai' },
    },
    DrivingItems = { 'driving_license', 'driver_license' },
    IdItem = 'id_card',
    FishingItem = 'fishing_license',
    HuntingItem = 'hunting_license',
    WeaponItem = 'weaponlicense',
}
