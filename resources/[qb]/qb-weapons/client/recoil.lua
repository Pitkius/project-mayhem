--- Sumažina žaidimo ginklo recoil drebulę; vertikalų kilimą valdo apačios CEventGunShot blokas + Config.RecoilMultiplier.
CreateThread(function()
    while true do
        local scale = Config.RecoilShakeAmplitude
        if scale == nil then
            Wait(500)
        else
            local ped = PlayerPedId()
            local _, weapon = GetCurrentPedWeapon(ped, true)
            if weapon ~= joaat('WEAPON_UNARMED') then
                pcall(function()
                    SetWeaponRecoilShakeAmplitude(weapon, scale)
                end)
                Wait(0)
            else
                Wait(200)
            end
        end
    end
end)

local recoils = {
    -- Handguns
    [`weapon_pistol`] = 0.3,
    [`weapon_pistol_mk2`] = 0.5,
    [`weapon_combatpistol`] = 0.2,
    [`weapon_appistol`] = 0.3,
    [`weapon_stungun`] = 0.1,
    [`weapon_pistol50`] = 0.6,
    [`weapon_snspistol`] = 0.2,
    [`weapon_heavypistol`] = 0.5,
    [`weapon_vintagepistol`] = 0.4,
    [`weapon_flaregun`] = 0.9,
    [`weapon_marksmanpistol`] = 0.9,
    [`weapon_revolver`] = 0.6,
    [`weapon_revolver_mk2`] = 0.6,
    [`weapon_doubleaction`] = 0.3,
    [`weapon_snspistol_mk2`] = 0.3,
    [`weapon_raypistol`] = 0.3,
    [`weapon_ceramicpistol`] = 0.3,
    [`weapon_navyrevolver`] = 0.3,
    [`weapon_gadgetpistol`] = 0.3,
    [`weapon_pistolxm3`] = 0.4,

    -- Submachine Guns
    [`weapon_microsmg`] = 0.5,
    [`weapon_smg`] = 0.4,
    [`weapon_smg_mk2`] = 0.1,
    [`weapon_assaultsmg`] = 0.1,
    [`weapon_combatpdw`] = 0.2,
    [`weapon_machinepistol`] = 0.3,
    [`weapon_minismg`] = 0.1,
    [`weapon_raycarbine`] = 0.3,
    [`weapon_tecpistol`] = 0.3,

    -- Shotguns
    [`weapon_pumpshotgun`] = 0.4,
    [`weapon_sawnoffshotgun`] = 0.7,
    [`weapon_assaultshotgun`] = 0.4,
    [`weapon_bullpupshotgun`] = 0.2,
    [`weapon_musket`] = 0.7,
    [`weapon_heavyshotgun`] = 0.2,
    [`weapon_dbshotgun`] = 0.7,
    [`weapon_autoshotgun`] = 0.2,
    [`weapon_pumpshotgun_mk2`] = 0.4,
    [`weapon_combatshotgun`] = 0.0,

    -- Assault Rifles
    [`weapon_assaultrifle`] = 0.5,
    [`weapon_assaultrifle_mk2`] = 0.2,
    [`weapon_carbinerifle`] = 0.3,
    [`weapon_carbinerifle_mk2`] = 0.1,
    [`weapon_advancedrifle`] = 0.1,
    [`weapon_specialcarbine`] = 0.2,
    [`weapon_bullpuprifle`] = 0.2,
    [`weapon_compactrifle`] = 0.3,
    [`weapon_specialcarbine_mk2`] = 0.2,
    [`weapon_bullpuprifle_mk2`] = 0.2,
    [`weapon_militaryrifle`] = 0.0,
    [`weapon_heavyrifle`] = 0.3,
    [`weapon_tacticalrifle`] = 0.2,

    -- Light Machine Guns
    [`weapon_mg`] = 0.1,
    [`weapon_combatmg`] = 0.1,
    [`weapon_gusenberg`] = 0.1,
    [`weapon_combatmg_mk2`] = 0.1,

    -- Sniper Rifles
    [`weapon_sniperrifle`] = 0.5,
    [`weapon_heavysniper`] = 0.7,
    [`weapon_marksmanrifle`] = 0.3,
    [`weapon_remotesniper`] = 1.2,
    [`weapon_heavysniper_mk2`] = 0.6,
    [`weapon_marksmanrifle_mk2`] = 0.3,
    [`weapon_precisionrifle`] = 0.3,

    -- Heavy Weapons
    [`weapon_rpg`] = 0.0,
    [`weapon_grenadelauncher`] = 1.0,
    [`weapon_grenadelauncher_smoke`] = 1.0,
    [`weapon_minigun`] = 0.1,
    [`weapon_firework`] = 0.3,
    [`weapon_railgun`] = 2.4,
    [`weapon_hominglauncher`] = 0.0,
    [`weapon_compactlauncher`] = 0.5,
    [`weapon_rayminigun`] = 0.3,
}

local lastRecoilAt = 0

local function applyVerticalRecoil(ped, weap)
    if not ped or ped == 0 then return end
    local base = recoils[weap]
    local mult = Config.RecoilMultiplier or 1.0
    local amount = base and base * mult or nil
    if not amount or amount <= 0.0 then return end

    local tv = 0.0
    if GetFollowPedCamViewMode() ~= 4 then
        repeat
            Wait(0)
            local p = GetGameplayCamRelativePitch()
            SetGameplayCamRelativePitch(p + 0.14, 0.24)
            tv += 0.14
        until tv >= amount
    else
        repeat
            Wait(0)
            local p = GetGameplayCamRelativePitch()
            SetGameplayCamRelativePitch(p + 0.75, 1.35)
            tv += 0.75
        until tv >= amount
    end
end

AddEventHandler('CEventGunShot', function(entities, eventEntity, args)
    local ped = PlayerPedId()
    if eventEntity ~= ped then return end
    if IsPedDoingDriveby(ped) then return end
    local _, weap = GetCurrentPedWeapon(ped, false)
    applyVerticalRecoil(ped, weap)
end)

-- Fallback, nes CEventGunShot kai kuriuose builduose suveikia ne kiekvienam šūviui.
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedShooting(ped) and not IsPedDoingDriveby(ped) then
            local now = GetGameTimer()
            if now - lastRecoilAt > 80 then
                local _, weap = GetCurrentPedWeapon(ped, false)
                applyVerticalRecoil(ped, weap)
                lastRecoilAt = now
            end
            Wait(0)
        else
            Wait(5)
        end
    end
end)
