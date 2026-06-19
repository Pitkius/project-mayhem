local QBCore = exports['qb-core']:GetCoreObject()

local function isPlayerVictim(hitGlobalId)
    if not hitGlobalId or hitGlobalId == 0 then return false end
    local victim = NetworkGetEntityFromNetworkId(hitGlobalId)
    if not victim or victim == 0 then return false end
    return IsPedAPlayer(victim)
end

AddEventHandler('weaponDamageEvent', function(sender, data)
    if not Config.FlatHitboxDamage or type(data) ~= 'table' then return end

    local damageType = tonumber(data.damageType) or 0
    if damageType ~= 3 then return end

    if not isPlayerVictim(data.hitGlobalId) then return end

    local weaponHash = tonumber(data.weaponType) or 0
    if weaponHash == 0 then return end

    local weaponData = QBCore.Shared.Weapons[weaponHash]
    local weaponName = weaponData and weaponData.name
    if WeaponHash and WeaponHash.inventoryNameFromNative then
        local invName = WeaponHash.inventoryNameFromNative(weaponHash)
        if invName then
            weaponName = invName
            weaponData = QBCore.Shared.Weapons[joaat(invName)] or weaponData
        end
    end
    if weaponData and weaponData.ammotype == 'AMMO_SHOTGUN' then return end

    local flatDamage = WeaponDamage.resolveFlatBulletDamage(weaponName, weaponData)
    if not flatDamage or flatDamage <= 0 then return end

    data.overrideDefaultDamage = true
    data.weaponDamage = math.floor(flatDamage + 0.5)
end)
