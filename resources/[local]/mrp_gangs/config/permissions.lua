Config = Config or {}

Config.GangPermissionGroups = {
    gang = {
        'gang.view',
        'gang.edit',
        'gang.logs',
    },
    members = {
        'members.view',
        'members.invite',
        'members.kick',
        'members.set_role',
        'members.suspend',
    },
    roles = {
        'roles.view',
        'roles.manage',
    },
    missions = {
        'missions.view',
        'missions.start',
        'missions.cancel',
        'missions.manage_loot',
    },
    territories = {
        'territories.view',
        'territories.start_action',
        'territories.manage_bonus',
    },
    diplomacy = {
        'diplomacy.view',
        'diplomacy.propose',
        'diplomacy.accept',
        'diplomacy.break',
    },
    wars = {
        'wars.view',
        'wars.declare',
        'wars.manage_roster',
        'wars.manage_objective',
    },
    finance = {
        'finance.view',
        'finance.deposit',
        'finance.withdraw',
    },
}

Config.GangPermissionSet = {}
for _, permissions in pairs(Config.GangPermissionGroups) do
    for _, permission in ipairs(permissions) do
        Config.GangPermissionSet[permission] = true
    end
end

Config.DefaultGangRoles = {
    {
        key = 'boss',
        label = 'Bosas',
        priority = 100,
        isOwner = true,
        permissions = '*',
    },
    {
        key = 'underboss',
        label = 'Underboss',
        priority = 80,
        permissions = {
            'gang.view', 'gang.edit', 'gang.logs',
            'members.view', 'members.invite', 'members.kick', 'members.set_role', 'members.suspend',
            'roles.view', 'roles.manage',
            'missions.view', 'missions.start', 'missions.cancel', 'missions.manage_loot',
            'territories.view', 'territories.start_action',
            'diplomacy.view', 'diplomacy.propose', 'diplomacy.accept', 'diplomacy.break',
            'wars.view', 'wars.declare', 'wars.manage_roster', 'wars.manage_objective',
            'finance.view', 'finance.deposit', 'finance.withdraw',
        },
    },
    {
        key = 'lieutenant',
        label = 'Leitenantas',
        priority = 60,
        permissions = {
            'gang.view', 'gang.logs',
            'members.view', 'members.invite',
            'roles.view',
            'missions.view', 'missions.start', 'missions.cancel',
            'territories.view', 'territories.start_action',
            'diplomacy.view', 'diplomacy.propose',
            'wars.view', 'wars.manage_roster',
            'finance.view',
        },
    },
    {
        key = 'member',
        label = 'Narys',
        priority = 40,
        permissions = {
            'gang.view',
            'members.view',
            'missions.view', 'missions.start',
            'territories.view',
            'diplomacy.view',
            'wars.view',
        },
    },
    {
        key = 'prospect',
        label = 'Naujokas',
        priority = 20,
        permissions = {
            'gang.view',
            'members.view',
            'missions.view',
            'territories.view',
        },
    },
}

Config.GangResponsibilities = {
    recruiter = { label = 'Verbavimo vadovas', extraPermissions = { 'members.invite' } },
    diplomat = { label = 'Diplomatas', extraPermissions = { 'diplomacy.propose', 'diplomacy.accept' } },
    war_commander = { label = 'Karo vadas', extraPermissions = { 'wars.manage_roster', 'wars.manage_objective' } },
    quartermaster = { label = 'Sandėlio vadovas', extraPermissions = { 'missions.manage_loot' } },
    treasurer = { label = 'Iždininkas', extraPermissions = { 'finance.view', 'finance.deposit' } },
    turf_manager = { label = 'Teritorijų vadovas', extraPermissions = { 'territories.start_action' } },
}

Config.GangLimits = {
    maxMembers = 60,
    maxRoles = 12,
    inviteExpirySec = 300,
    memberNoteMax = 300,
}

--- Ar žaidėjai gali kurti gaują per tabletę (ne tik admin /gangcreatev2).
Config.AllowPlayerGangCreate = true

--- Kaina žaidėjui kuriant gaują per tabletę (nuima iš cash, jei neužtenka - iš banko).
--- Admin /gangcreatev2 komanda šio mokesčio nemoka.
Config.GangCreationCost = 50000
