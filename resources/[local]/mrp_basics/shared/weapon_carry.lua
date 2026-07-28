--- Ginklų nešiojimo vizualė: kas ant nugaros (prop), kas per GTA native holsterį (diržas).
WeaponCarry = WeaponCarry or {}

--- Custom / addon ginklai, kurių hash grupė nepadeda (pvz. FGC-9 → combat pistol hash).
WeaponCarry.ForceBack = {
    weapon_fgc9 = true,
}

--- Inventoriaus pavadinimas → GTA native (addon ginklams).
WeaponCarry.NativeHashName = {
    weapon_fgc9 = 'weapon_combatpistol',
}

function WeaponCarry.resolveHash(name)
    name = WeaponCarry.normalizeName(name)
    local native = WeaponCarry.NativeHashName[name]
    if native then return joaat(native) end
    return joaat(name)
end

--- Visada native holsteris (ne ant nugaros prop).
WeaponCarry.ForceHolsterOnly = {
    weapon_stungun = true,
    weapon_flaregun = true,
    weapon_petrolcan = true,
    weapon_fireextinguisher = true,
    weapon_machinepistol = true,
    weapon_tecpistol = true,
}

--- Fallback prop modeliai, jei CreateWeaponObject nepavyksta.
WeaponCarry.FallbackModels = {
    weapon_assaultrifle = 'w_ar_assaultrifle',
    weapon_assaultrifle_mk2 = 'w_ar_assaultrifle',
    weapon_carbinerifle = 'w_ar_carbinerifle',
    weapon_carbinerifle_mk2 = 'w_ar_carbinerifle',
    weapon_advancedrifle = 'w_ar_advancedrifle',
    weapon_specialcarbine = 'w_ar_specialcarbine',
    weapon_specialcarbine_mk2 = 'w_ar_specialcarbine',
    weapon_bullpuprifle = 'w_ar_bullpuprifle',
    weapon_bullpuprifle_mk2 = 'w_ar_bullpuprifle',
    weapon_compactrifle = 'w_ar_assaultrifle_smg',
    weapon_militaryrifle = 'w_ar_bullpuprifle',
    weapon_heavyrifle = 'w_ar_specialcarbine',
    weapon_tacticalrifle = 'w_ar_carbinerifle',
    weapon_mg = 'w_mg_mg',
    weapon_combatmg = 'w_mg_combatmg',
    weapon_combatmg_mk2 = 'w_mg_combatmg',
    weapon_gusenberg = 'w_sb_gusenberg',
    weapon_pumpshotgun = 'w_sg_pumpshotgun',
    weapon_pumpshotgun_mk2 = 'w_sg_pumpshotgun',
    weapon_sawnoffshotgun = 'w_sg_sawnoff',
    weapon_assaultshotgun = 'w_sg_assaultshotgun',
    weapon_bullpupshotgun = 'w_sg_bullpupshotgun',
    weapon_heavyshotgun = 'w_sg_heavyshotgun',
    weapon_combatshotgun = 'w_sg_pumpshotgun',
    weapon_dbshotgun = 'w_sg_sawnoff',
    weapon_autoshotgun = 'w_sg_assaultshotgun',
    weapon_sweepershotgun = 'w_sg_pumpshotgun',
    weapon_musket = 'w_sr_sniperrifle',
    weapon_sniperrifle = 'w_sr_sniperrifle',
    weapon_heavysniper = 'w_sr_heavysniper',
    weapon_heavysniper_mk2 = 'w_sr_heavysniper',
    weapon_marksmanrifle = 'w_sr_marksmanrifle',
    weapon_marksmanrifle_mk2 = 'w_sr_marksmanrifle',
    weapon_precisionrifle = 'w_sr_marksmanrifle',
    weapon_microsmg = 'w_sb_microsmg',
    weapon_smg = 'w_sb_smg',
    weapon_smg_mk2 = 'w_sb_smgmk2',
    weapon_assaultsmg = 'w_sb_assaultsmg',
    weapon_combatpdw = 'w_sb_pdw',
    weapon_minismg = 'w_sb_minismg',
    weapon_fgc9 = 'w_pi_combatpistol',
    weapon_raycarbine = 'w_ar_srifle',
    weapon_tecpistol = 'w_pi_pistolsmg_m31',
}

local backGroups = {
    [`GROUP_RIFLE`] = true,
    [`GROUP_SMG`] = true,
    [`GROUP_SHOTGUN`] = true,
    [`GROUP_SNIPER`] = true,
    [`GROUP_MG`] = true,
}

function WeaponCarry.normalizeName(name)
    return tostring(name or ''):lower()
end

function WeaponCarry.isHolsterOnly(name)
    name = WeaponCarry.normalizeName(name)
    if name == '' or name == 'weapon_unarmed' then return true end
    return WeaponCarry.ForceHolsterOnly[name] == true
end

function WeaponCarry.isBackCarried(name)
    name = WeaponCarry.normalizeName(name)
    if name == '' or name == 'weapon_unarmed' then return false end
    if WeaponCarry.isHolsterOnly(name) then return false end
    if WeaponCarry.ForceBack[name] then return true end

    local hash = joaat(name)
    if hash == 0 then return false end

    local grp = GetWeapontypeGroup(hash)
    if backGroups[grp] then return true end

    return WeaponCarry.FallbackModels[name] ~= nil and grp ~= `GROUP_PISTOL`
end

function WeaponCarry.fallbackModel(name)
    return WeaponCarry.FallbackModels[WeaponCarry.normalizeName(name)]
end

function WeaponCarry.maxBackSlots()
    return 2
end

--- Rūšiavimas: ilgesni / sunkesni ginklai pirmiau ant nugaros.
local carryPriority = {
    weapon_heavysniper = 100,
    weapon_heavysniper_mk2 = 100,
    weapon_sniperrifle = 95,
    weapon_marksmanrifle = 90,
    weapon_marksmanrifle_mk2 = 90,
    weapon_precisionrifle = 90,
    weapon_musket = 85,
    weapon_combatmg = 80,
    weapon_combatmg_mk2 = 80,
    weapon_mg = 78,
    weapon_assaultshotgun = 75,
    weapon_pumpshotgun = 70,
    weapon_pumpshotgun_mk2 = 70,
    weapon_assaultrifle = 65,
    weapon_carbinerifle = 65,
    weapon_specialcarbine = 65,
    weapon_fgc9 = 60,
}

function WeaponCarry.carryPriority(name)
    name = WeaponCarry.normalizeName(name)
    return carryPriority[name] or 50
end

function WeaponCarry.isBulkyItem(name)
    name = WeaponCarry.normalizeName(name)
    if WeaponCarry.ForceHolsterOnly[name] then return false end
    if WeaponCarry.ForceBack[name] then return true end
    return WeaponCarry.FallbackModels[name] ~= nil
end
