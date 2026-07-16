--- Vertikalus recoil (kameros kilimas) + bloom išjungimas.
--- Kulka skrenda ten, kur taikiklis šūvio momentu; po šūvio kamera kyla.

local function applyNoBloom(weapon)
    if Config.ZeroWeaponBloom == false then return end
    if not weapon or weapon == 0 or weapon == `WEAPON_UNARMED` then return end
    pcall(function()
        if SetWeaponAccuracySpread then
            SetWeaponAccuracySpread(weapon, 0.0)
        end
    end)
    pcall(function()
        SetWeaponRecoilShakeAmplitude(weapon, Config.RecoilShakeAmplitude or 0.0)
    end)
end

CreateThread(function()
    local lastWeapon = 0
    while true do
        local ped = PlayerPedId()
        local _, weapon = GetCurrentPedWeapon(ped, true)
        if WeaponHash and WeaponHash.recoilLookupHash then
            weapon = WeaponHash.recoilLookupHash(weapon)
        end
        if weapon ~= `WEAPON_UNARMED` then
            if weapon ~= lastWeapon then
                applyNoBloom(weapon)
                lastWeapon = weapon
            elseif IsPedShooting(ped) then
                --- GTA kartais atstato bloom per burst — priverstinai 0.
                applyNoBloom(weapon)
            end
            Wait(IsPedShooting(ped) and 0 or 250)
        else
            lastWeapon = 0
            Wait(400)
        end
    end
end)

local recoils = {
    -- Handguns
    [`weapon_pistol`] = 0.38,
    [`weapon_pistol_mk2`] = 0.58,
    [`weapon_combatpistol`] = 0.28,
    [`weapon_appistol`] = 0.36,
    [`weapon_stungun`] = 0.12,
    [`weapon_pistol50`] = 0.72,
    [`weapon_snspistol`] = 0.26,
    [`weapon_heavypistol`] = 0.58,
    [`weapon_vintagepistol`] = 0.48,
    [`weapon_flaregun`] = 0.95,
    [`weapon_marksmanpistol`] = 0.95,
    [`weapon_revolver`] = 0.72,
    [`weapon_revolver_mk2`] = 0.72,
    [`weapon_doubleaction`] = 0.38,
    [`weapon_snspistol_mk2`] = 0.36,
    [`weapon_raypistol`] = 0.36,
    [`weapon_ceramicpistol`] = 0.36,
    [`weapon_navyrevolver`] = 0.38,
    [`weapon_gadgetpistol`] = 0.36,
    [`weapon_pistolxm3`] = 0.48,

    -- Submachine Guns
    [`weapon_microsmg`] = 0.58,
    [`weapon_smg`] = 0.48,
    [`weapon_smg_mk2`] = 0.22,
    [`weapon_assaultsmg`] = 0.22,
    [`weapon_combatpdw`] = 0.28,
    [`weapon_machinepistol`] = 0.36,
    [`weapon_minismg`] = 0.22,
    [`weapon_raycarbine`] = 0.36,
    [`weapon_tecpistol`] = 0.36,
    [`weapon_fgc9`] = 0.48,
    [`weapon_tacticalsmg`] = 0.36,

    -- Shotguns
    [`weapon_pumpshotgun`] = 0.52,
    [`weapon_sawnoffshotgun`] = 0.82,
    [`weapon_assaultshotgun`] = 0.48,
    [`weapon_bullpupshotgun`] = 0.28,
    [`weapon_musket`] = 0.82,
    [`weapon_heavyshotgun`] = 0.28,
    [`weapon_dbshotgun`] = 0.82,
    [`weapon_autoshotgun`] = 0.28,
    [`weapon_pumpshotgun_mk2`] = 0.52,
    [`weapon_combatshotgun`] = 0.22,

    -- Assault Rifles
    [`weapon_assaultrifle`] = 0.58,
    [`weapon_assaultrifle_mk2`] = 0.28,
    [`weapon_carbinerifle`] = 0.38,
    [`weapon_carbinerifle_mk2`] = 0.22,
    [`weapon_advancedrifle`] = 0.22,
    [`weapon_specialcarbine`] = 0.28,
    [`weapon_bullpuprifle`] = 0.28,
    [`weapon_compactrifle`] = 0.38,
    [`weapon_specialcarbine_mk2`] = 0.28,
    [`weapon_bullpuprifle_mk2`] = 0.28,
    [`weapon_militaryrifle`] = 0.22,
    [`weapon_heavyrifle`] = 0.38,
    [`weapon_tacticalrifle`] = 0.28,
    [`weapon_servicecarbine`] = 0.30,

    -- Light Machine Guns
    [`weapon_mg`] = 0.22,
    [`weapon_combatmg`] = 0.22,
    [`weapon_gusenberg`] = 0.22,
    [`weapon_combatmg_mk2`] = 0.22,

    -- Sniper Rifles
    [`weapon_sniperrifle`] = 0.62,
    [`weapon_heavysniper`] = 0.82,
    [`weapon_marksmanrifle`] = 0.38,
    [`weapon_remotesniper`] = 1.2,
    [`weapon_heavysniper_mk2`] = 0.72,
    [`weapon_marksmanrifle_mk2`] = 0.38,
    [`weapon_precisionrifle`] = 0.38,

    -- Heavy Weapons
    [`weapon_rpg`] = 0.0,
    [`weapon_grenadelauncher`] = 1.0,
    [`weapon_grenadelauncher_smoke`] = 1.0,
    [`weapon_minigun`] = 0.18,
    [`weapon_firework`] = 0.36,
    [`weapon_railgun`] = 2.4,
    [`weapon_hominglauncher`] = 0.0,
    [`weapon_compactlauncher`] = 0.55,
    [`weapon_rayminigun`] = 0.36,
}

local lastRecoilAt = 0

--- Tik vertikalus kilimas — be šoninio kick ir be jitter (bloom).
local function applyVerticalRecoil(ped, weap)
    if not ped or ped == 0 then return end
    local base = recoils[weap]
    if base == nil then
        base = Config.RecoilMinimumBase or 0.22
    elseif base <= 0.0 then
        base = Config.RecoilMinimumBase or 0.22
    end
    local mult = Config.RecoilMultiplier or 1.0
    local scale = Config.RecoilBaseScale or 1.0
    local amount = base * mult * scale
    if amount <= 0.0 then return end

    applyNoBloom(weap)

    local tv = 0.0
    if GetFollowPedCamViewMode() ~= 4 then
        repeat
            Wait(0)
            local p = GetGameplayCamRelativePitch()
            SetGameplayCamRelativePitch(p + 0.16, 0.28)
            tv = tv + 0.16
        until tv >= amount
    else
        repeat
            Wait(0)
            local p = GetGameplayCamRelativePitch()
            SetGameplayCamRelativePitch(p + 0.85, 1.45)
            tv = tv + 0.85
        until tv >= amount
    end

    --- Šoninis / jitter — tik jei config > 0 (numatytai išjungta).
    local hAmp = Config.RecoilHorizontalSpread or 0.0
    if hAmp > 0.0 then
        local hKick = (math.random() * 2.0 - 1.0) * amount * hAmp
        SetGameplayCamRelativeHeading(GetGameplayCamRelativeHeading() + hKick)
    end
    local vJit = Config.RecoilPitchVariance or 0.0
    if vJit > 0.0 then
        local pj = (math.random() * 2.0 - 1.0) * amount * vJit
        SetGameplayCamRelativePitch(GetGameplayCamRelativePitch() + pj, 0.18)
    end
end

AddEventHandler('CEventGunShot', function(entities, eventEntity, args)
    local ped = PlayerPedId()
    if eventEntity ~= ped then return end
    if IsPedDoingDriveby(ped) then return end
    local _, weap = GetCurrentPedWeapon(ped, false)
    if WeaponHash and WeaponHash.recoilLookupHash then
        weap = WeaponHash.recoilLookupHash(weap)
    end
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
                if WeaponHash and WeaponHash.recoilLookupHash then
                    weap = WeaponHash.recoilLookupHash(weap)
                end
                applyVerticalRecoil(ped, weap)
                lastRecoilAt = now
            end
            Wait(16)
        else
            Wait(50)
        end
    end
end)
