--- ARAS + bendras PD ginklų gamyba (NUI · lygiai + palaipsnis atrakimas)
--- MRPD craft: Z≈30.25 šalia inventoriaus. Sandy — be craft stočių.
Config.PdWeaponCraft = {
    --- Kiek sėkmingų craft'ų reikia dabartiniame lygyje, kad kiltum į kitą
    craftsPerLevel = { [1] = 8, [2] = 12 },
    maxLevel = 3,
    defaultLevel = 1,
    interactDistance = 3.0,

    levelLabels = {
        [1] = '1 lygis · Pistoletai / šarvai',
        [2] = '2 lygis · SMG / shotgun',
        [3] = '3 lygis · Stambūs ginklai',
    },

    stations = {
        --- MRPD — ARAS only (šalia PD craft / inventoriaus)
        {
            id = 'ls_aras_craft',
            stationId = 'ls_main',
            coords = vector3(458.2090, -977.9290, 30.2503),
            heading = 4.3676,
            label = 'ARAS ginklų gamykla',
            minGrade = 2,
            divisions = { 'aras' },
        },
        --- MRPD — bendras PD craft (visas police job, be ARAS apribojimo)
        {
            id = 'ls_pd_craft',
            stationId = 'ls_main',
            coords = vector3(462.4065, -978.1403, 30.2503),
            heading = 8.0996,
            label = 'PD ginklų gamykla',
            minGrade = 0,
        },
        --- Sandy — be ginklų craft (tik LS)
    },

    --- unlockOrder: kiek craft'ų reikia ŠIAME lygyje, kad receptas atrakintų (0 = iškart)
    --- Attachment itemai (qb-core) yra generic — tas pats item veikia keliems ginklams;
    --- receptai išdėstyti pagal ginklo lygį (pistoletai / SMG+shotgun / šautuvai).
    recipes = {
        --- ========== LYGIA 1 — pistoletai, ammo, armor, pistoletų priedai ==========
        pd_craft_combat_pistol = {
            label = 'Combat pistoletas',
            craftLevel = 1,
            unlockOrder = 0,
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
        pd_craft_pistol = {
            label = 'Standartinis pistoletas',
            craftLevel = 1,
            unlockOrder = 2,
            output = 'weapon_pistol',
            count = 1,
            timeMs = 24000,
            ingredients = {
                { item = 'gun_frame', count = 2 },
                { item = 'gun_barrel', count = 1 },
                { item = 'gun_spring', count = 3 },
                { item = 'gun_trigger', count = 1 },
                { item = 'weapon_parts', count = 2 },
                { item = 'metal_scrap', count = 3 },
            },
        },
        pd_craft_pistol_ammo = {
            label = 'Pistoletų kulkos (50 vnt.)',
            craftLevel = 1,
            unlockOrder = 0,
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
            unlockOrder = 1,
            output = 'armor_light',
            count = 1,
            timeMs = 18000,
            ingredients = {
                { item = 'metal_scrap', count = 7 },
                { item = 'plastic', count = 4 },
                { item = 'weapon_parts', count = 2 },
            },
        },
        pd_craft_armor_police = {
            label = 'Policijos taktinė liemenė',
            craftLevel = 1,
            unlockOrder = 4,
            output = 'armor_police',
            count = 1,
            timeMs = 24000,
            ingredients = {
                { item = 'metal_scrap', count = 10 },
                { item = 'plastic', count = 5 },
                { item = 'weapon_parts', count = 3 },
            },
        },
        pd_craft_pistol_flash = {
            label = 'Pistoletų žibintuvėlis',
            craftLevel = 1,
            unlockOrder = 3,
            output = 'flashlight_attachment',
            count = 1,
            timeMs = 12000,
            ingredients = {
                { item = 'weapon_parts', count = 2 },
                { item = 'electronickit', count = 2 },
                { item = 'metal_scrap', count = 2 },
            },
        },
        pd_craft_pistol_clip = {
            label = 'Pistoletų prailginta dėtuvė',
            craftLevel = 1,
            unlockOrder = 5,
            output = 'pistol_extendedclip',
            count = 1,
            timeMs = 14000,
            ingredients = {
                { item = 'metal_scrap', count = 4 },
                { item = 'weapon_parts', count = 2 },
                { item = 'gun_spring', count = 2 },
            },
        },
        pd_craft_pistol_supp = {
            label = 'Pistoletų slopintuvas',
            craftLevel = 1,
            unlockOrder = 6,
            output = 'suppressor_attachment',
            count = 1,
            timeMs = 16000,
            ingredients = {
                { item = 'gun_barrel', count = 2 },
                { item = 'metal_scrap', count = 5 },
                { item = 'weapon_parts', count = 2 },
            },
        },

        --- ========== LYGIA 2 — heavypistol, SMG, shotgun + SMG/shotgun priedai ==========
        pd_craft_heavypistol = {
            label = 'Sunkusis pistoletas',
            craftLevel = 2,
            unlockOrder = 0,
            output = 'weapon_heavypistol',
            count = 1,
            timeMs = 32000,
            ingredients = {
                { item = 'gun_frame', count = 2 },
                { item = 'gun_barrel', count = 2 },
                { item = 'gun_spring', count = 5 },
                { item = 'gun_trigger', count = 2 },
                { item = 'weapon_parts', count = 4 },
                { item = 'metal_scrap', count = 5 },
            },
        },
        pd_craft_smg_supp = {
            label = 'SMG / šratinio slopintuvas',
            craftLevel = 2,
            unlockOrder = 2,
            output = 'suppressor_attachment',
            count = 1,
            timeMs = 16000,
            ingredients = {
                { item = 'gun_barrel', count = 2 },
                { item = 'metal_scrap', count = 6 },
                { item = 'weapon_parts', count = 3 },
            },
        },
        pd_craft_smg_clip = {
            label = 'SMG prailginta dėtuvė',
            craftLevel = 2,
            unlockOrder = 3,
            output = 'smg_extendedclip',
            count = 1,
            timeMs = 15000,
            ingredients = {
                { item = 'metal_scrap', count = 5 },
                { item = 'weapon_parts', count = 3 },
                { item = 'gun_spring', count = 3 },
            },
        },
        pd_craft_smg = {
            label = 'SMG',
            craftLevel = 2,
            unlockOrder = 5,
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
        pd_craft_smg_ammo = {
            label = 'SMG kulkos (60 vnt.)',
            craftLevel = 2,
            unlockOrder = 5,
            output = 'smg_ammo',
            count = 60,
            timeMs = 12000,
            ingredients = {
                { item = 'metal_scrap', count = 8 },
                { item = 'weapon_parts', count = 3 },
                { item = 'plastic', count = 2 },
            },
        },
        pd_craft_assaultsmg = {
            label = 'Šturminis SMG',
            craftLevel = 2,
            unlockOrder = 7,
            output = 'weapon_assaultsmg',
            count = 1,
            timeMs = 46000,
            ingredients = {
                { item = 'gun_frame', count = 3 },
                { item = 'gun_barrel', count = 3 },
                { item = 'gun_spring', count = 7 },
                { item = 'gun_trigger', count = 3 },
                { item = 'weapon_parts', count = 5 },
                { item = 'metal_scrap', count = 8 },
            },
        },
        pd_craft_pumpshotgun = {
            label = 'Pompinis šratinis',
            craftLevel = 2,
            unlockOrder = 7,
            output = 'weapon_pumpshotgun',
            count = 1,
            timeMs = 44000,
            ingredients = {
                { item = 'gun_frame', count = 3 },
                { item = 'gun_barrel', count = 3 },
                { item = 'gun_spring', count = 5 },
                { item = 'gun_trigger', count = 2 },
                { item = 'weapon_parts', count = 5 },
                { item = 'metal_scrap', count = 8 },
            },
        },
        pd_craft_shotgun_ammo = {
            label = 'Šratinio kulkos (40 vnt.)',
            craftLevel = 2,
            unlockOrder = 7,
            output = 'shotgun_ammo',
            count = 40,
            timeMs = 12000,
            ingredients = {
                { item = 'metal_scrap', count = 9 },
                { item = 'weapon_parts', count = 3 },
                { item = 'plastic', count = 2 },
            },
        },
        pd_craft_smg_drum = {
            label = 'SMG būgninė dėtuvė',
            craftLevel = 2,
            unlockOrder = 8,
            output = 'smg_drum_attachment',
            count = 1,
            timeMs = 18000,
            ingredients = {
                { item = 'metal_scrap', count = 7 },
                { item = 'weapon_parts', count = 4 },
                { item = 'gun_spring', count = 4 },
                { item = 'plastic', count = 2 },
            },
        },
        pd_craft_smg_scope = {
            label = 'SMG taikiklis',
            craftLevel = 2,
            unlockOrder = 9,
            output = 'smallscope_attachment',
            count = 1,
            timeMs = 17000,
            ingredients = {
                { item = 'weapon_parts', count = 3 },
                { item = 'electronickit', count = 2 },
                { item = 'metal_scrap', count = 3 },
            },
        },

        --- ========== LYGIA 3 — automatiniai šautuvai + rifle priedai ==========
        pd_craft_carbine = {
            label = 'Karabinas',
            craftLevel = 3,
            unlockOrder = 0,
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
        pd_craft_rifle_ammo = {
            label = 'Karabino kulkos (90 vnt.)',
            craftLevel = 3,
            unlockOrder = 0,
            output = 'rifle_ammo',
            count = 90,
            timeMs = 13000,
            ingredients = {
                { item = 'metal_scrap', count = 10 },
                { item = 'weapon_parts', count = 4 },
                { item = 'plastic', count = 3 },
            },
        },
        pd_craft_rifle_scope = {
            label = 'Karabino taikiklis',
            craftLevel = 3,
            unlockOrder = 2,
            output = 'medscope_attachment',
            count = 1,
            timeMs = 19000,
            ingredients = {
                { item = 'weapon_parts', count = 5 },
                { item = 'electronickit', count = 3 },
                { item = 'metal_scrap', count = 4 },
            },
        },
        pd_craft_rifle_supp = {
            label = 'Karabino slopintuvas',
            craftLevel = 3,
            unlockOrder = 3,
            output = 'suppressor_attachment',
            count = 1,
            timeMs = 18000,
            ingredients = {
                { item = 'gun_barrel', count = 3 },
                { item = 'metal_scrap', count = 7 },
                { item = 'weapon_parts', count = 3 },
            },
        },
        pd_craft_rifle_clip = {
            label = 'Karabino prailginta dėtuvė',
            craftLevel = 3,
            unlockOrder = 4,
            output = 'rifle_extendedclip',
            count = 1,
            timeMs = 16000,
            ingredients = {
                { item = 'metal_scrap', count = 6 },
                { item = 'weapon_parts', count = 3 },
                { item = 'gun_spring', count = 3 },
            },
        },
        pd_craft_special_carbine = {
            label = 'Specialus karabinas',
            craftLevel = 3,
            unlockOrder = 5,
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
        pd_craft_rifle_grip = {
            label = 'Karabino rankena',
            craftLevel = 3,
            unlockOrder = 6,
            output = 'grip_attachment',
            count = 1,
            timeMs = 14000,
            ingredients = {
                { item = 'metal_scrap', count = 5 },
                { item = 'plastic', count = 4 },
                { item = 'weapon_parts', count = 2 },
            },
        },
        pd_craft_rifle_drum = {
            label = 'Karabino būgninė dėtuvė',
            craftLevel = 3,
            unlockOrder = 8,
            output = 'rifle_drum_attachment',
            count = 1,
            timeMs = 20000,
            ingredients = {
                { item = 'metal_scrap', count = 8 },
                { item = 'weapon_parts', count = 5 },
                { item = 'gun_spring', count = 5 },
                { item = 'plastic', count = 3 },
            },
        },
        pd_craft_heavyrifle = {
            label = 'Sunkusis šautuvas',
            craftLevel = 3,
            unlockOrder = 10,
            output = 'weapon_heavyrifle',
            count = 1,
            timeMs = 56000,
            ingredients = {
                { item = 'gun_frame', count = 4 },
                { item = 'gun_barrel', count = 4 },
                { item = 'gun_spring', count = 8 },
                { item = 'gun_trigger', count = 3 },
                { item = 'weapon_parts', count = 7 },
                { item = 'metal_scrap', count = 12 },
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
