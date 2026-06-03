Config = {}

Config.ConsentTimeoutSec = 90
Config.MaxPressure = 100

Config.PoliceJob = 'police'
Config.PoliceMinGrade = 0

Config.CriminalRequiresGang = true

--- Test parduotuvė (išjunk production: EnableTestShop = false)
Config.EnableTestShop = true
Config.TestShop = {
    model = 'g_m_y_lost_02',
    coords = vector4(128.0, -1928.0, 21.38, 180.0),
    scenario = 'WORLD_HUMAN_SMOKING',
    interactDist = 2.8,
    label = 'Pirkti spaudimo įrangą',
    price = 250,
    payAccount = 'cash', -- cash | bank
    requireGang = false,
    blip = {
        enabled = true,
        coords = vector3(128.0, -1928.0, 21.38),
        sprite = 478,
        color = 27,
        scale = 0.75,
        label = 'Test: gaujų įranga',
    },
}

--- Gaujų įranga (itemas → dedama ant žemės, išlieka po restart)
Config.GangKit = {
    item = 'gang_interrog_kit',
    propModel = 'prop_tool_box_05',
    chairModel = 'prop_chair_08',
    placeMaxDist = 4.0,
    pickupDist = 2.8,
    sessionRadius = 7.0,
    --- Kėdė / įtariamasis relative to kit (heading)
    suspectSeatOffset = vector4(0.0, -0.9, -0.45, 0.0),
    spotlightOffset = { origin = vector3(0.0, 0.6, 1.4), target = vector3(0.0, -0.9, 0.2) },
}

--- Policija: tik fiksuotos stotys, tik pareigūnai tarnyboje
Config.PoliceStations = {
    {
        id = 'mrpd_interview',
        label = 'MRPD apklausos kambarys',
        center = vector3(475.35, -1003.15, 26.27),
        radius = 14.0,
        doorGroupId = 'ls_mrpd_interview',
        suspectSeat = vector4(476.75, -1004.35, 25.27, 270.0),
        spotlight = {
            origin = vector3(474.5, -1003.2, 28.8),
            target = vector3(476.75, -1004.35, 26.0),
        },
    },
}

--- Animacijos (GTA misijos) – be žalos / damage
Config.Anims = {
    --- Policija: ramus sėdėjimas prie stalo
    suspectSitCalm = { dict = 'anim@amb@business@bgen@bgen_no_work@', name = 'sit_phone_phoneputdown_idle_nowork', flag = 1 },
    --- Policija: intensyvi apklausa (FBI kėdė)
    suspectInterrogate = { dict = 'missfbi1leadinout', name = 'fbi_intro_loop_chair', flag = 1 },
    officerSlapDesk = { dict = 'missheist_jewel', name = 'smash_case', flag = 48 },
    officerThreat = { dict = 'anim@gangops@facility@servers@', name = 'hotwire', flag = 48 },

    --- Gauja: aukos (misija Trevor / FBI torture RP)
    gangVictimChair = { dict = 'missfbi1leadinout', name = 'fbi_intro_loop_chair', flag = 1 },
    gangVictimTooth = { dict = 'missfbi1', name = 'idle_c', flag = 1 },
    gangVictimGas = { dict = 'missfbi1leadinout', name = 'fbi_outro_loop_chair', flag = 1 },
    gangVictimElectric = { dict = 'random@burial', name = 'b_burial', flag = 1 },

    gangLeadTooth = { dict = 'missfbi1', name = 'idle_b', flag = 48 },
    gangLeadGas = { dict = 'weapon@w_sp_jerrycan', name = 'fire', flag = 48 },
    gangLeadElectric = { dict = 'anim@gangops@facility@servers@', name = 'hotwire', flag = 48 },
}

Config.GangTortureActions = {
    { id = 'tooth', label = 'Dantų traukimas', victim = 'gangVictimTooth', lead = 'gangLeadTooth', pressure = 18 },
    { id = 'gas', label = 'Benzinas (RP)', victim = 'gangVictimGas', lead = 'gangLeadGas', pressure = 22 },
    { id = 'electric', label = 'Elektra (RP)', victim = 'gangVictimElectric', lead = 'gangLeadElectric', pressure = 25 },
}

Config.Results = {
    police = {
        { id = 'cooperative', label = 'Bendradarbiavo' },
        { id = 'partial', label = 'Dalinė informacija' },
        { id = 'silent', label = 'Tyli / atsisakė' },
        { id = 'denied', label = 'Neigia kaltę' },
    },
    criminal = {
        { id = 'complied', label = 'Pateikė informaciją' },
        { id = 'partial', label = 'Dalinė informacija' },
        { id = 'refused', label = 'Atsisakė' },
    },
}
