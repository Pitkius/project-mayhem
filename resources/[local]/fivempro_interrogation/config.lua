Config = {}

--- Žemėlapio blipai (policijos stotys + gaujų test parduotuvė)
Config.ShowBlips = true

--- LS oro uostas — ta pati testų eilė kaip fivempro_drugs
local DEV_CENTER = vector3(-886.92, -3208.01, 13.94)
local DEV_ROW_H = 239.51

local function devRow(offset)
    local h = math.rad(DEV_ROW_H)
    return vector3(
        DEV_CENTER.x + math.cos(h) * offset,
        DEV_CENTER.y + math.sin(h) * offset,
        DEV_CENTER.z
    )
end

local GANG_TEST_POS = devRow(-21.0)
local POLICE_DEV_POS = devRow(-24.5)

Config.ConsentTimeoutSec = 90
Config.MaxPressure = 100

Config.PoliceJob = 'police'
Config.PoliceMinGrade = 0

Config.CriminalRequiresGang = true

--- Test parduotuvė (išjunk production: EnableTestShop = false)
Config.EnableTestShop = true
Config.TestShop = {
    model = 'g_m_y_lost_02',
    coords = vector4(GANG_TEST_POS.x, GANG_TEST_POS.y, GANG_TEST_POS.z, DEV_ROW_H + 180.0),
    scenario = 'WORLD_HUMAN_SMOKING',
    interactDist = 2.8,
    label = 'Pirkti spaudimo įrangą',
    price = 250,
    payAccount = 'cash', -- cash | bank
    requireGang = false,
    blip = {
        enabled = true,
        coords = GANG_TEST_POS,
        sprite = 478,
        color = 27,
        scale = 0.85,
        label = 'Test: gaujų tardymas',
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
        id = 'ls_airport_interview',
        label = 'Test: policijos apklausa',
        devTest = true,
        center = POLICE_DEV_POS,
        radius = 10.0,
        suspectSeat = vector4(POLICE_DEV_POS.x + 1.0, POLICE_DEV_POS.y - 0.6, POLICE_DEV_POS.z - 1.0, 330.0),
        spotlight = {
            origin = vector3(POLICE_DEV_POS.x - 0.5, POLICE_DEV_POS.y + 0.8, POLICE_DEV_POS.z + 1.8),
            target = vector3(POLICE_DEV_POS.x + 1.0, POLICE_DEV_POS.y - 0.6, POLICE_DEV_POS.z + 0.3),
        },
        blip = {
            enabled = true,
            sprite = 60,
            color = 3,
            scale = 0.85,
            label = 'Test: policijos tardymas',
        },
    },
    {
        id = 'mrpd_interview_1',
        label = 'MRPD tardymo kambarys 1',
        center = vector3(486.1472, -987.6362, 26.2733),
        radius = 4.5,
        doorGroupId = 'ls_mrpd_interview_1',
        suspectSeat = vector4(486.1472, -987.6362, 25.2733, 185.6714),
        spotlight = {
            origin = vector3(486.1472, -986.15, 28.75),
            target = vector3(486.1472, -987.6362, 26.05),
        },
        blip = { enabled = false },
    },
    {
        id = 'mrpd_interview_2',
        label = 'MRPD tardymo kambarys 2',
        center = vector3(486.1502, -995.6803, 26.2733),
        radius = 4.5,
        doorGroupId = 'ls_mrpd_interview_2',
        suspectSeat = vector4(486.1502, -995.6803, 25.2733, 189.5927),
        spotlight = {
            origin = vector3(486.1502, -994.2, 28.75),
            target = vector3(486.1502, -995.6803, 26.05),
        },
        blip = { enabled = false },
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
