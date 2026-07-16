--- Policijos ginklų gamyba (NUI · gang-style receptai)
Config.PdWeaponCraft = {
    craftsPerLevel = { [1] = 6, [2] = 10 },
    maxLevel = 3,
    defaultLevel = 1,
    interactDistance = 3.0,

    levelLabels = {
        [1] = '1 lygis · Bazinis',
        [2] = '2 lygis · Patyręs',
        [3] = '3 lygis · Elitas',
    },

    stations = {
        {
            id = 'ls_main_craft',
            stationId = 'ls_main',
            coords = vector3(464.35, -981.12, 30.68),
            heading = 90.654,
            label = 'MRPD ginklų gamykla',
            minGrade = 0,
        },
        {
            id = 'sandy_craft',
            stationId = 'sandy',
            coords = vector3(1851.20, 3690.04, 34.27),
            heading = 210.0,
            label = 'Sandy PD ginklų gamykla',
            minGrade = 0,
        },
    },

    recipes = {
        --- Bazinė PD ginkluotė (visi policininkai)
        pd_craft_pistol = {
            label = 'Tarnybinis pistoletas',
            craftLevel = 1,
            output = 'weapon_pistol',
            count = 1,
            timeMs = 26000,
            ingredients = {
                { item = 'gun_frame', count = 2 },
                { item = 'gun_barrel', count = 2 },
                { item = 'gun_spring', count = 3 },
                { item = 'gun_trigger', count = 2 },
                { item = 'weapon_parts', count = 2 },
                { item = 'metal_scrap', count = 5 },
            },
        },
        pd_craft_stungun = {
            label = 'Elektros šokas (Tazeris)',
            craftLevel = 1,
            output = 'weapon_stungun',
            count = 1,
            timeMs = 22000,
            ingredients = {
                { item = 'weapon_parts', count = 3 },
                { item = 'electronickit', count = 2 },
                { item = 'plastic', count = 4 },
                { item = 'metal_scrap', count = 3 },
            },
        },
        pd_craft_nightstick = {
            label = 'Policininko lazda',
            craftLevel = 1,
            output = 'weapon_nightstick',
            count = 1,
            timeMs = 12000,
            ingredients = {
                { item = 'metal_scrap', count = 6 },
                { item = 'plastic', count = 4 },
                { item = 'weapon_parts', count = 2 },
            },
        },
        pd_craft_cuffs = {
            label = 'Antrankiai',
            craftLevel = 1,
            output = 'handcuffs',
            count = 1,
            timeMs = 8000,
            ingredients = {
                { item = 'metal_scrap', count = 4 },
                { item = 'weapon_parts', count = 2 },
            },
        },
        pd_craft_pistol_flash = {
            label = 'Pistoletų žibintuvėlis',
            craftLevel = 1,
            output = 'flashlight_attachment',
            count = 1,
            timeMs = 12000,
            ingredients = {
                { item = 'weapon_parts', count = 2 },
                { item = 'electronickit', count = 2 },
                { item = 'metal_scrap', count = 2 },
            },
        },
        pd_craft_pistol_supp = {
            label = 'Pistoletų slopintuvas',
            craftLevel = 1,
            output = 'suppressor_attachment',
            count = 1,
            timeMs = 16000,
            ingredients = {
                { item = 'gun_barrel', count = 2 },
                { item = 'metal_scrap', count = 5 },
                { item = 'weapon_parts', count = 2 },
            },
        },
        pd_craft_pistol_clip = {
            label = 'Papildomas pistoletų apkaba',
            craftLevel = 1,
            output = 'clip_attachment',
            count = 1,
            timeMs = 14000,
            ingredients = {
                { item = 'metal_scrap', count = 4 },
                { item = 'weapon_parts', count = 2 },
                { item = 'gun_spring', count = 2 },
            },
        },
        pd_craft_pistol_ammo = {
            label = 'Pistoletų kulkos (50 vnt.)',
            craftLevel = 1,
            output = 'pistol_ammo',
            count = 50,
            timeMs = 10000,
            ingredients = {
                { item = 'metal_scrap', count = 7 },
                { item = 'weapon_parts', count = 2 },
                { item = 'plastic', count = 2 },
            },
        },
        pd_craft_armor_light = {
            label = 'Pusiniai šarvai',
            craftLevel = 1,
            output = 'armor_light',
            count = 1,
            timeMs = 18000,
            ingredients = {
                { item = 'metal_scrap', count = 7 },
                { item = 'plastic', count = 4 },
                { item = 'weapon_parts', count = 2 },
            },
        },

        pd_craft_assault_smg = {
            label = 'Šturminis SMG',
            craftLevel = 2,
            output = 'weapon_assaultsmg',
            count = 1,
            timeMs = 38000,
            ingredients = {
                { item = 'gun_frame', count = 3 },
                { item = 'gun_barrel', count = 3 },
                { item = 'gun_spring', count = 5 },
                { item = 'gun_trigger', count = 2 },
                { item = 'weapon_parts', count = 4 },
                { item = 'metal_scrap', count = 7 },
            },
        },
        pd_craft_smg_scope = {
            label = 'SMG taikiklis',
            craftLevel = 2,
            output = 'smallscope_attachment',
            count = 1,
            timeMs = 17000,
            ingredients = {
                { item = 'weapon_parts', count = 3 },
                { item = 'electronickit', count = 2 },
                { item = 'metal_scrap', count = 3 },
            },
        },
        pd_craft_smg_ammo = {
            label = 'SMG kulkos (60 vnt.)',
            craftLevel = 2,
            output = 'smg_ammo',
            count = 60,
            timeMs = 12000,
            ingredients = {
                { item = 'metal_scrap', count = 8 },
                { item = 'weapon_parts', count = 3 },
                { item = 'plastic', count = 2 },
            },
        },
        pd_craft_armor_police = {
            label = 'Pilni šarvai (policijos liemenė)',
            craftLevel = 2,
            output = 'armor_police',
            count = 1,
            timeMs = 24000,
            ingredients = {
                { item = 'metal_scrap', count = 10 },
                { item = 'plastic', count = 5 },
                { item = 'weapon_parts', count = 3 },
            },
        },

        pd_craft_rifle_scope = {
            label = 'Karabino taikiklis',
            craftLevel = 3,
            output = 'medscope_attachment',
            count = 1,
            timeMs = 19000,
            ingredients = {
                { item = 'weapon_parts', count = 5 },
                { item = 'electronickit', count = 3 },
                { item = 'metal_scrap', count = 4 },
            },
        },
        pd_craft_rifle_grip = {
            label = 'Karabino rankena',
            craftLevel = 3,
            output = 'grip_attachment',
            count = 1,
            timeMs = 14000,
            ingredients = {
                { item = 'metal_scrap', count = 5 },
                { item = 'plastic', count = 4 },
                { item = 'weapon_parts', count = 2 },
            },
        },
        pd_craft_rifle_ammo = {
            label = 'Karabino kulkos (90 vnt.)',
            craftLevel = 3,
            output = 'rifle_ammo',
            count = 90,
            timeMs = 13000,
            ingredients = {
                { item = 'metal_scrap', count = 10 },
                { item = 'weapon_parts', count = 4 },
                { item = 'plastic', count = 3 },
            },
        },

        --- ARAS padalinys (tik division = aras)
        pd_craft_heavy_pistol = {
            label = 'Sunkusis pistoletas (ARAS)',
            craftLevel = 1,
            output = 'weapon_heavypistol',
            count = 1,
            timeMs = 28000,
            divisions = { 'aras' },
            ingredients = {
                { item = 'gun_frame', count = 2 },
                { item = 'gun_barrel', count = 2 },
                { item = 'gun_spring', count = 4 },
                { item = 'gun_trigger', count = 2 },
                { item = 'weapon_parts', count = 3 },
                { item = 'metal_scrap', count = 8 },
            },
        },
        pd_craft_tactical_smg = {
            label = 'Taktinis SMG (ARAS)',
            craftLevel = 2,
            output = 'weapon_tacticalsmg',
            count = 1,
            timeMs = 40000,
            divisions = { 'aras' },
            ingredients = {
                { item = 'gun_frame', count = 3 },
                { item = 'gun_barrel', count = 3 },
                { item = 'gun_spring', count = 5 },
                { item = 'gun_trigger', count = 2 },
                { item = 'weapon_parts', count = 4 },
                { item = 'electronickit', count = 1 },
                { item = 'metal_scrap', count = 8 },
            },
        },
        pd_craft_aro_shotgun = {
            label = 'Pompinis šratinis (ARAS)',
            craftLevel = 2,
            output = 'weapon_pumpshotgun',
            count = 1,
            timeMs = 42000,
            divisions = { 'aras' },
            ingredients = {
                { item = 'gun_frame', count = 3 },
                { item = 'gun_barrel', count = 3 },
                { item = 'gun_spring', count = 3 },
                { item = 'gun_trigger', count = 2 },
                { item = 'weapon_parts', count = 4 },
                { item = 'metal_scrap', count = 10 },
            },
        },
        pd_craft_special_carbine = {
            label = 'Specialus karabinas (ARAS)',
            craftLevel = 3,
            output = 'weapon_specialcarbine',
            count = 1,
            timeMs = 52000,
            divisions = { 'aras' },
            ingredients = {
                { item = 'gun_frame', count = 3 },
                { item = 'gun_barrel', count = 3 },
                { item = 'gun_spring', count = 6 },
                { item = 'gun_trigger', count = 3 },
                { item = 'weapon_parts', count = 5 },
                { item = 'metal_scrap', count = 10 },
            },
        },
        pd_craft_heavy_rifle = {
            label = 'Sunkusis šautuvas (ARAS)',
            craftLevel = 3,
            output = 'weapon_heavyrifle',
            count = 1,
            timeMs = 54000,
            divisions = { 'aras' },
            ingredients = {
                { item = 'gun_frame', count = 3 },
                { item = 'gun_barrel', count = 3 },
                { item = 'gun_spring', count = 7 },
                { item = 'gun_trigger', count = 3 },
                { item = 'weapon_parts', count = 6 },
                { item = 'metal_scrap', count = 12 },
            },
        },
        pd_craft_sniper_rifle = {
            label = 'Snaiperio šautuvas (ARAS)',
            craftLevel = 3,
            output = 'weapon_sniperrifle',
            count = 1,
            timeMs = 58000,
            divisions = { 'aras' },
            ingredients = {
                { item = 'gun_frame', count = 3 },
                { item = 'gun_barrel', count = 4 },
                { item = 'gun_spring', count = 4 },
                { item = 'gun_trigger', count = 2 },
                { item = 'weapon_parts', count = 6 },
                { item = 'electronickit', count = 2 },
                { item = 'metal_scrap', count = 14 },
            },
        },
        pd_craft_snp_ammo = {
            label = 'Snaiperio kulkos (20 vnt.)',
            craftLevel = 3,
            output = 'snp_ammo',
            count = 20,
            timeMs = 14000,
            divisions = { 'aras' },
            ingredients = {
                { item = 'metal_scrap', count = 12 },
                { item = 'weapon_parts', count = 4 },
                { item = 'plastic', count = 2 },
            },
        },
    },
}

function Config.PdRecipeIngredients(recipe)
    if not recipe then return {} end
    if recipe.ingredients then return recipe.ingredients end
    local out = {}
    for item, cnt in pairs(recipe.materials or {}) do
        out[#out + 1] = { item = item, count = cnt }
    end
    return out
end
