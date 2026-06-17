WeaponDamage = WeaponDamage or {}

local AMMO_DEFAULT_DAMAGE = {
    AMMO_PISTOL = 27.0,
    AMMO_SMG = 22.0,
    AMMO_RIFLE = 32.0,
    AMMO_SHOTGUN = 29.0,
    AMMO_MG = 30.0,
    AMMO_SNIPER = 101.0,
    AMMO_MUSKET = 165.0,
}

function WeaponDamage.resolveModifier(entry)
    if type(entry) == 'number' then
        return entry
    end
    if type(entry) ~= 'table' then
        return nil
    end
    if entry.modifier then
        return entry.modifier + 0.0
    end
    local shots = tonumber(entry.targetBodyShotsFullArmor) or 0
    local hp = tonumber(entry.playerHealthPool) or 200
    local armor = tonumber(entry.playerArmorPool) or 100
    local base = tonumber(entry.assumedBaseDamage) or 0
    if shots <= 0 or base <= 0 then
        return nil
    end
    local targetPerShot = (hp + armor) / shots
    return targetPerShot / base
end

function WeaponDamage.resolveFlatBulletDamage(weaponName, weaponData)
    if not weaponName then return nil end

    local flat = Config.FlatBulletDamage
    if type(flat) == 'table' and flat[weaponName] then
        return flat[weaponName] + 0.0
    end

    local balance = Config.WeaponDamageBalance
    if type(balance) == 'table' and balance[weaponName] then
        local entry = balance[weaponName]
        local mult = WeaponDamage.resolveModifier(entry)
        local base = type(entry) == 'table' and tonumber(entry.assumedBaseDamage) or nil
        if mult and base and base > 0 then
            return mult * base
        end
    end

    local defaults = Config.DefaultBulletDamage
    if type(defaults) == 'table' and defaults[weaponName] then
        return defaults[weaponName] + 0.0
    end

    local ammoType = weaponData and weaponData.ammotype
    if ammoType and AMMO_DEFAULT_DAMAGE[ammoType] then
        return AMMO_DEFAULT_DAMAGE[ammoType]
    end

    return tonumber(Config.FlatBulletDamageDefault) or 27.0
end
