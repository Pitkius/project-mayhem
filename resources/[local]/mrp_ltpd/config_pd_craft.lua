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
            coords = vector3(462.23, -981.12, 30.68),
            heading = 90.654,
            label = 'MRPD ginklų gamykla',
            minGrade = 0,
        },
        {
            id = 'sandy_craft',
            stationId = 'sandy',
            coords = vector3(1849.12, 3690.04, 34.27),
            heading = 210.0,
            label = 'Sandy PD ginklų gamykla',
            minGrade = 0,
        },
    },

    recipes = {
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
        pd_craft_combat_pistol = {
            label = 'Combat pistoletas',
            craftLevel = 1,
            output = 'weapon_combatpistol',
            count = 1,
            timeMs = 28000,
            ingredients = {
                { item = 'gun_frame', count = 2 },
                { item = 'gun_barrel', count = 2 },
                { item = 'gun_spring', count = 4 },
                { item = 'gun_trigger', count = 2 },
                { item = 'weapon_parts', count = 3 },
                { item = 'metal_scrap', count = 4 },
            },
        },
        pd_craft_stungun = {
            label = 'Tazeris',
            craftLevel = 1,
            output = 'weapon_stungun',
            count = 1,
            timeMs = 24000,
            ingredients = {
                { item = 'weapon_parts', count = 4 },
                { item = 'electronickit', count = 2 },
                { item = 'plastic', count = 3 },
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

        pd_craft_smg = {
            label = 'SMG',
            craftLevel = 2,
            output = 'weapon_smg',
            count = 1,
            timeMs = 40000,
            ingredients = {
                { item = 'gun_frame', count = 3 },
                { item = 'gun_barrel', count = 3 },
                { item = 'gun_spring', count = 6 },
                { item = 'gun_trigger', count = 3 },
                { item = 'weapon_parts', count = 4 },
                { item = 'metal_scrap', count = 6 },
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

        pd_craft_carbine = {
            label = 'Karabinas',
            craftLevel = 3,
            output = 'weapon_carbinerifle',
            count = 1,
            timeMs = 52000,
            ingredients = {
                { item = 'gun_frame', count = 3 },
                { item = 'gun_barrel', count = 3 },
                { item = 'gun_spring', count = 6 },
                { item = 'gun_trigger', count = 3 },
                { item = 'weapon_parts', count = 5 },
                { item = 'metal_scrap', count = 8 },
            },
        },
        pd_craft_special_carbine = {
            label = 'Special carbine',
            craftLevel = 3,
            output = 'weapon_specialcarbine',
            count = 1,
            timeMs = 54000,
            ingredients = {
                { item = 'gun_frame', count = 3 },
                { item = 'gun_barrel', count = 3 },
                { item = 'gun_spring', count = 8 },
                { item = 'gun_trigger', count = 3 },
                { item = 'weapon_parts', count = 6 },
                { item = 'metal_scrap', count = 10 },
            },
        },
        pd_craft_bullpup = {
            label = 'Bullpup rifle',
            craftLevel = 3,
            output = 'weapon_bullpuprifle',
            count = 1,
            timeMs = 54000,
            ingredients = {
                { item = 'gun_frame', count = 3 },
                { item = 'gun_barrel', count = 3 },
                { item = 'gun_spring', count = 8 },
                { item = 'gun_trigger', count = 3 },
                { item = 'weapon_parts', count = 6 },
                { item = 'metal_scrap', count = 10 },
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
