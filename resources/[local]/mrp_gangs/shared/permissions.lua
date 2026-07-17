--[[
  ═══════════════════════════════════════════════════════════════════
  mrp_gangs — Organizacijos teisių (permissions) ir atsakomybių katalogas
  ═══════════════════════════════════════════════════════════════════
  Bendras failas (shared) — naudoja ir serveris (autoritetinga logika),
  ir klientas/NUI (tik atvaizdavimui). Visa TIKRA teisių patikra vyksta
  serverio pusėje (server_org.lua). UI paslėpimas nėra apsauga.

  Teisių raktas = 'kategorija.veiksmas'. Owner rangas turi '*' (visos teisės).
]]

Config = Config or {}

-- ── Teisių kategorijos ir raktai (UI grupavimui) ───────────────────
Config.GangPermissionGroups = {
    {
        id = 'gang',
        label = 'Gaujos valdymas',
        perms = {
            { key = 'gang.open_menu',      label = 'Atidaryti gaujos meniu' },
            { key = 'gang.view_structure', label = 'Matyti organizacijos struktūrą' },
            { key = 'gang.edit_info',      label = 'Keisti gaujos informaciją' },
            { key = 'gang.edit_emblem',    label = 'Keisti emblemą' },
            { key = 'gang.edit_color',     label = 'Keisti spalvą' },
            { key = 'gang.edit_name',      label = 'Keisti pavadinimą' },
            { key = 'gang.manage_affiliates', label = 'Valdyti neoficialias / oficialias afiliacijas' },
            { key = 'gang.view_logs',      label = 'Matyti veiklos žurnalą' },
        },
    },
    {
        id = 'members',
        label = 'Narių valdymas',
        perms = {
            { key = 'members.invite',        label = 'Pakviesti narį' },
            { key = 'members.approve',       label = 'Patvirtinti prašymą' },
            { key = 'members.kick',          label = 'Išmesti narį' },
            { key = 'members.promote',       label = 'Paaukštinti' },
            { key = 'members.demote',        label = 'Pažeminti' },
            { key = 'members.move_rank',     label = 'Perkelti į kitą rangą' },
            { key = 'members.edit_notes',    label = 'Redaguoti pastabas' },
            { key = 'members.suspend',       label = 'Suspenduoti narį' },
            { key = 'members.assign_resp',   label = 'Priskirti atsakomybes' },
            { key = 'members.view_lastseen', label = 'Matyti paskutinį prisijungimą' },
        },
    },
    {
        id = 'ranks',
        label = 'Rangų valdymas',
        perms = {
            { key = 'ranks.create',           label = 'Kurti rangus' },
            { key = 'ranks.edit',             label = 'Redaguoti rangus' },
            { key = 'ranks.delete',           label = 'Naikinti rangus' },
            { key = 'ranks.reorder',          label = 'Keisti hierarchiją' },
            { key = 'ranks.edit_permissions', label = 'Keisti rangų teises' },
            { key = 'ranks.assign_leaders',   label = 'Priskirti rangų vadovus' },
        },
    },
    {
        id = 'associates',
        label = 'Asocijuotų civilių valdymas',
        perms = {
            { key = 'associates.add',         label = 'Pridėti asocijuotą civilį' },
            { key = 'associates.remove',      label = 'Pašalinti asocijuotą' },
            { key = 'associates.edit_status', label = 'Keisti statusą' },
            { key = 'associates.assign_tasks',label = 'Skirti užduotis' },
            { key = 'associates.view_info',   label = 'Matyti veiklos informaciją' },
            { key = 'associates.promote',     label = 'Paaukštinti į pilną narį' },
        },
    },
    {
        id = 'diplomacy',
        label = 'Diplomatija',
        perms = {
            { key = 'diplomacy.send_offer',   label = 'Siųsti pasiūlymą' },
            { key = 'diplomacy.accept_offer', label = 'Priimti pasiūlymą' },
            { key = 'diplomacy.break',        label = 'Nutraukti santykį' },
            { key = 'diplomacy.set_neutral',  label = 'Pažymėti neutralia' },
            { key = 'diplomacy.set_hostile',  label = 'Pažymėti priešiška' },
            { key = 'diplomacy.view',         label = 'Matyti santykius' },
        },
    },
    {
        id = 'finance',
        label = 'Finansai (ateities integracija)',
        perms = {
            { key = 'finance.view',       label = 'Matyti balansą' },
            { key = 'finance.deposit',    label = 'Įnešti pinigus' },
            { key = 'finance.withdraw',   label = 'Išimti pinigus' },
            { key = 'finance.history',    label = 'Matyti istoriją' },
            { key = 'finance.set_limits', label = 'Nustatyti limitus' },
        },
    },
    {
        id = 'turf',
        label = 'Teritorijos (ateities integracija)',
        perms = {
            { key = 'turf.view',            label = 'Matyti teritorijas' },
            { key = 'turf.manage_members',  label = 'Valdyti teritorijos narius' },
            { key = 'turf.start_action',    label = 'Pradėti teritorijos veiksmą' },
            { key = 'turf.manage_vendors',  label = 'Valdyti pardavėjus' },
        },
    },
}

-- Greitas visų galiojančių teisių rinkinys (validacijai serveryje).
Config.GangPermissionSet = {}
Config.GangPermissionList = {}
for _, group in ipairs(Config.GangPermissionGroups) do
    for _, p in ipairs(group.perms) do
        Config.GangPermissionSet[p.key] = true
        Config.GangPermissionList[#Config.GangPermissionList + 1] = p.key
    end
end

function Config.IsValidGangPermission(key)
    return key ~= nil and Config.GangPermissionSet[tostring(key)] == true
end

-- ── Atsakomybės (žymos) — atskiros nuo rango ───────────────────────
-- Gali turėti papildomų teisių (extraPerms), kurios pridedamos prie rango teisių.
Config.GangResponsibilities = {
    { id = 'finance_manager',   label = 'Finansų vadovas',                 extraPerms = { 'finance.view', 'finance.history' } },
    { id = 'armory_keeper',     label = 'Ginklų sandėlio prižiūrėtojas',   extraPerms = {} },
    { id = 'recruiter',         label = 'Naujokų prižiūrėtojas',           extraPerms = { 'members.invite' } },
    { id = 'diplomat',          label = 'Diplomatas',                      extraPerms = { 'diplomacy.view', 'diplomacy.send_offer' } },
    { id = 'turf_manager',      label = 'Teritorijų vadovas',              extraPerms = { 'turf.view' } },
    { id = 'transport_manager', label = 'Transporto vadovas',              extraPerms = {} },
    { id = 'drug_manager',      label = 'Narkotikų gamybos vadovas',       extraPerms = {} },
    { id = 'security_manager',  label = 'Saugumo vadovas',                 extraPerms = {} },
    { id = 'intel_manager',     label = 'Žvalgybos vadovas',               extraPerms = {} },
    { id = 'associate_handler', label = 'Asocijuotų civilių prižiūrėtojas',extraPerms = { 'associates.view_info', 'associates.assign_tasks' } },
}

Config.GangResponsibilitySet = {}
for _, r in ipairs(Config.GangResponsibilities) do
    Config.GangResponsibilitySet[r.id] = r
end

function Config.IsValidResponsibility(id)
    return id ~= nil and Config.GangResponsibilitySet[tostring(id)] ~= nil
end

-- ── Nario / asocijuoto statusai ────────────────────────────────────
Config.GangMemberStatuses = { 'active', 'suspended', 'inactive' }
Config.GangAssociateStatuses = { 'active', 'probation', 'trusted', 'suspended', 'inactive', 'blacklisted' }

Config.GangAssociateTypes = {
    { id = 'driver',       label = 'Vairuotojas' },
    { id = 'mechanic',     label = 'Mechanikas' },
    { id = 'courier',      label = 'Kurjeris' },
    { id = 'informant',    label = 'Informatorius' },
    { id = 'distributor',  label = 'Narkotikų platintojas' },
    { id = 'launderer',    label = 'Pinigų plovėjas' },
    { id = 'business',     label = 'Verslo savininkas' },
    { id = 'arms_dealer',  label = 'Ginklų tiekėjas' },
    { id = 'scout',        label = 'Žvalgas' },
    { id = 'hired',        label = 'Samdomas civilis' },
}

-- Ribotos teisės, kurias galima suteikti asocijuotam civiliui (NE gaujos permissions).
Config.GangAssociateAccessKeys = {
    { key = 'assoc.receive_tasks', label = 'Gauti gaujos užduotis' },
    { key = 'assoc.see_handler',   label = 'Matyti atsakingą kontaktą' },
    { key = 'assoc.use_workspot',  label = 'Naudoti darbo vietą' },
    { key = 'assoc.use_vehicle',   label = 'Naudoti transportą' },
    { key = 'assoc.sell_products', label = 'Parduoti produktus gaujos vardu' },
    { key = 'assoc.app',           label = 'Naudoti asocijuotų programėlę' },
}
Config.GangAssociateAccessSet = {}
for _, a in ipairs(Config.GangAssociateAccessKeys) do
    Config.GangAssociateAccessSet[a.key] = true
end

-- ── Diplomatijos santykių tipai ────────────────────────────────────
-- mutual = ar santykiui reikia abiejų gaujų sutikimo (pasiūlymas → priėmimas).
Config.GangRelationTypes = {
    { id = 'friendly',  label = 'Draugiška',        mutual = true },
    { id = 'allied',    label = 'Sąjungininkė',     mutual = true },
    { id = 'neutral',   label = 'Neutrali',         mutual = false },
    { id = 'tense',     label = 'Įtempti santykiai',mutual = false },
    { id = 'hostile',   label = 'Priešiška',        mutual = false },
    { id = 'war',       label = 'Karas',            mutual = false, restricted = true },
    { id = 'blocked',   label = 'Blokuota',         mutual = false },
}
Config.GangRelationSet = {}
for _, r in ipairs(Config.GangRelationTypes) do
    Config.GangRelationSet[r.id] = r
end

function Config.IsValidRelationType(id)
    return id ~= nil and Config.GangRelationSet[tostring(id)] ~= nil
end

-- ── Limitai ────────────────────────────────────────────────────────
Config.GangMaxRanks = 15          -- maks. rangų vienai gaujai
Config.GangMaxMembers = 60        -- maks. narių (0 = be limito)
Config.GangRankNameMax = 32
Config.GangNoteMax = 300
Config.GangInviteExpirySec = 60   -- pakvietimo galiojimas

-- ── Numatytoji rangų hierarchija naujai gaujai ─────────────────────
-- priority: didesnis = aukštesnis. isOwner: apsaugotas viršutinis rangas.
Config.GangDefaultRanks = {
    { name = 'boss',      label = 'Bosas',      priority = 100, color = '#EF4444', icon = 'crown',      isOwner = true,  canHaveChildren = true,  permissions = '*' },
    { name = 'underboss', label = 'Underboss',  priority = 80,  color = '#F59E0B', icon = 'star',       isOwner = false, canHaveChildren = true,  permissions = {
        'gang.open_menu','gang.view_structure','gang.edit_info','gang.manage_affiliates','gang.view_logs',
        'members.invite','members.approve','members.kick','members.promote','members.demote','members.move_rank','members.edit_notes','members.suspend','members.assign_resp','members.view_lastseen',
        'ranks.create','ranks.edit','ranks.reorder','ranks.edit_permissions','ranks.assign_leaders',
        'associates.add','associates.remove','associates.edit_status','associates.assign_tasks','associates.view_info','associates.promote',
        'diplomacy.send_offer','diplomacy.accept_offer','diplomacy.break','diplomacy.set_neutral','diplomacy.set_hostile','diplomacy.view',
    } },
    { name = 'capo',      label = 'Capo',       priority = 60,  color = '#3B82F6', icon = 'shield',     isOwner = false, canHaveChildren = true,  permissions = {
        'gang.open_menu','gang.view_structure','gang.view_logs',
        'members.invite','members.promote','members.demote','members.edit_notes','members.view_lastseen',
        'associates.add','associates.edit_status','associates.assign_tasks','associates.view_info',
        'diplomacy.view',
    } },
    { name = 'soldier',   label = 'Soldier',    priority = 40,  color = '#22C55E', icon = 'user',       isOwner = false, canHaveChildren = false, permissions = {
        'gang.open_menu','gang.view_structure',
        'associates.view_info',
    } },
    { name = 'prospect',  label = 'Prospect',   priority = 20,  color = '#64748B', icon = 'user-clock', isOwner = false, canHaveChildren = false, permissions = {
        'gang.open_menu','gang.view_structure',
    } },
}
