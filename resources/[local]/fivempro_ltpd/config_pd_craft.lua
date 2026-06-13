--- Policijos ginklų gamyba (lygių sistema · MRPD)
Config.PdWeaponCraft = {
    --- Kiek pagamintų daiktų reikia kitam lygiui
    craftsPerLevel = { [1] = 6, [2] = 10 },
    maxLevel = 3,
    defaultLevel = 1,
    interactDistance = 2.2,

    stations = {
        {
            id = 'ls_main_craft',
            stationId = 'ls_main',
            coords = vector3(487.2437, -997.1946, 30.6896),
            heading = 268.2779,
            label = 'Policijos ginklų gamyba',
            minGrade = 0,
        },
    },

    --- Žaliava (PD inventorius / sandėlis)
    materialItem = 'pd_armory_materials',

    recipes = {
        --- 1 lygis — antrankiai, combat pistol, tazeris, pistoletų priedai, kulkos, pusiniai šarvai
        pd_craft_cuffs = {
            label = 'Antrankiai',
            craftLevel = 1,
            output = 'handcuffs',
            count = 1,
            materials = { pd_armory_materials = 2 },
            timeMs = 6500,
        },
        pd_craft_combat_pistol = {
            label = 'Combat pistoletas',
            craftLevel = 1,
            output = 'weapon_combatpistol',
            count = 1,
            materials = { pd_armory_materials = 10 },
            timeMs = 22000,
        },
        pd_craft_stungun = {
            label = 'Tazeris',
            craftLevel = 1,
            output = 'weapon_stungun',
            count = 1,
            materials = { pd_armory_materials = 8 },
            timeMs = 18000,
        },
        pd_craft_pistol_flash = {
            label = 'Pistoletų žibintuvėlis',
            craftLevel = 1,
            output = 'flashlight_attachment',
            count = 1,
            materials = { pd_armory_materials = 3 },
            timeMs = 9000,
        },
        pd_craft_pistol_supp = {
            label = 'Pistoletų slopintuvas',
            craftLevel = 1,
            output = 'suppressor_attachment',
            count = 1,
            materials = { pd_armory_materials = 5 },
            timeMs = 12000,
        },
        pd_craft_pistol_clip = {
            label = 'Papildomas pistoletų apkaba',
            craftLevel = 1,
            output = 'clip_attachment',
            count = 1,
            materials = { pd_armory_materials = 4 },
            timeMs = 10000,
        },
        pd_craft_pistol_ammo = {
            label = 'Pistoletų kulkos (50 vnt.)',
            craftLevel = 1,
            output = 'pistol_ammo',
            count = 50,
            materials = { pd_armory_materials = 3 },
            timeMs = 7000,
        },
        pd_craft_armor_light = {
            label = 'Pusiniai šarvai (lengva liemenė)',
            craftLevel = 1,
            output = 'armor_light',
            count = 1,
            materials = { pd_armory_materials = 6 },
            timeMs = 14000,
        },

        --- 2 lygis — SMG, priedai, kulkos, pilni šarvai
        pd_craft_smg = {
            label = 'SMG',
            craftLevel = 2,
            output = 'weapon_smg',
            count = 1,
            materials = { pd_armory_materials = 18 },
            timeMs = 32000,
        },
        pd_craft_smg_scope = {
            label = 'SMG taikiklis',
            craftLevel = 2,
            output = 'smallscope_attachment',
            count = 1,
            materials = { pd_armory_materials = 6 },
            timeMs = 13000,
        },
        pd_craft_smg_ammo = {
            label = 'SMG kulkos (60 vnt.)',
            craftLevel = 2,
            output = 'smg_ammo',
            count = 60,
            materials = { pd_armory_materials = 5 },
            timeMs = 9000,
        },
        pd_craft_armor_police = {
            label = 'Pilni šarvai (policijos liemenė)',
            craftLevel = 2,
            output = 'armor_police',
            count = 1,
            materials = { pd_armory_materials = 12 },
            timeMs = 18000,
        },

        --- 3 lygis — karabinai ir rifle priedai
        pd_craft_carbine = {
            label = 'Karabinas',
            craftLevel = 3,
            output = 'weapon_carbinerifle',
            count = 1,
            materials = { pd_armory_materials = 28 },
            timeMs = 42000,
        },
        pd_craft_special_carbine = {
            label = 'Special carbine',
            craftLevel = 3,
            output = 'weapon_specialcarbine',
            count = 1,
            materials = { pd_armory_materials = 30 },
            timeMs = 44000,
        },
        pd_craft_bullpup = {
            label = 'Bullpup rifle',
            craftLevel = 3,
            output = 'weapon_bullpuprifle',
            count = 1,
            materials = { pd_armory_materials = 30 },
            timeMs = 44000,
        },
        pd_craft_rifle_scope = {
            label = 'Karabino taikiklis',
            craftLevel = 3,
            output = 'medscope_attachment',
            count = 1,
            materials = { pd_armory_materials = 8 },
            timeMs = 15000,
        },
        pd_craft_rifle_grip = {
            label = 'Karabino rankena',
            craftLevel = 3,
            output = 'grip_attachment',
            count = 1,
            materials = { pd_armory_materials = 5 },
            timeMs = 11000,
        },
        pd_craft_rifle_ammo = {
            label = 'Karabino kulkos (90 vnt.)',
            craftLevel = 3,
            output = 'rifle_ammo',
            count = 90,
            materials = { pd_armory_materials = 7 },
            timeMs = 10000,
        },
    },
}
