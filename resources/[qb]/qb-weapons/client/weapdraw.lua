local QBCore = exports['qb-core']:GetCoreObject()

local function isReloadBusy()
    local ok, busy = pcall(function()
        return exports['qb-weapons']:IsReloadBusy()
    end)
    return ok and busy == true
end

local function clearPedTasksSafe(ped)
    if isReloadBusy() then return end
    ClearPedTasks(ped)
end

local weapons = {
    'WEAPON_KNIFE',
    'WEAPON_NIGHTSTICK',
    'WEAPON_BREAD',
    'WEAPON_FLASHLIGHT',
    'WEAPON_HAMMER',
    'WEAPON_BAT',
    'WEAPON_GOLFCLUB',
    'WEAPON_CROWBAR',
    'WEAPON_BOTTLE',
    'WEAPON_DAGGER',
    'WEAPON_HATCHET',
    'WEAPON_MACHETE',
    'WEAPON_SWITCHBLADE',
    'WEAPON_BATTLEAXE',
    'WEAPON_POOLCUE',
    'WEAPON_WRENCH',
    'WEAPON_PISTOL',
    'WEAPON_PISTOL_MK2',
    'WEAPON_COMBATPISTOL',
    'WEAPON_APPISTOL',
    'WEAPON_PISTOL50',
    'WEAPON_REVOLVER',
    'WEAPON_SNSPISTOL',
    'WEAPON_HEAVYPISTOL',
    'WEAPON_VINTAGEPISTOL',
    'WEAPON_MICROSMG',
    'WEAPON_SMG',
    'WEAPON_ASSAULTSMG',
    'WEAPON_MINISMG',
    'WEAPON_MACHINEPISTOL',
    'WEAPON_COMBATPDW',
    'WEAPON_PUMPSHOTGUN',
    'WEAPON_SAWNOFFSHOTGUN',
    'WEAPON_ASSAULTSHOTGUN',
    'WEAPON_BULLPUPSHOTGUN',
    'WEAPON_HEAVYSHOTGUN',
    'WEAPON_ASSAULTRIFLE',
    'WEAPON_CARBINERIFLE',
    'WEAPON_ADVANCEDRIFLE',
    'WEAPON_SPECIALCARBINE',
    'WEAPON_BULLPUPRIFLE',
    'WEAPON_COMPACTRIFLE',
    'WEAPON_MG',
    'WEAPON_COMBATMG',
    'WEAPON_GUSENBERG',
    'WEAPON_SNIPERRIFLE',
    'WEAPON_HEAVYSNIPER',
    'WEAPON_MARKSMANRIFLE',
    'WEAPON_GRENADELAUNCHER',
    'WEAPON_RPG',
    'WEAPON_STINGER',
    'WEAPON_MINIGUN',
    'WEAPON_GRENADE',
    'WEAPON_STICKYBOMB',
    'WEAPON_SMOKEGRENADE',
    'WEAPON_BZGAS',
    'WEAPON_MOLOTOV',
    'WEAPON_DIGISCANNER',
    'WEAPON_FIREWORK',
    'WEAPON_MUSKET',
    'WEAPON_STUNGUN',
    'WEAPON_HOMINGLAUNCHER',
    'WEAPON_PROXMINE',
    'WEAPON_FLAREGUN',
    'WEAPON_MARKSMANPISTOL',
    'WEAPON_RAILGUN',
    'WEAPON_DBSHOTGUN',
    'WEAPON_AUTOSHOTGUN',
    'WEAPON_COMPACTLAUNCHER',
    'WEAPON_PIPEBOMB',
    'WEAPON_DOUBLEACTION',
    'WEAPON_SNOWBALL',
    'WEAPON_PISTOLXM3',
    'WEAPON_CANDYCANE',
    'WEAPON_CERAMICPISTOL',
    'WEAPON_NAVYREVOLVER',
    'WEAPON_GADGETPISTOL',
    'WEAPON_PISTOLXM3',
    'WEAPON_TECPISTOL',
    'WEAPON_HEAVYRIFLE',
    'WEAPON_MILITARYRIFLE',
    'WEAPON_TACTICALRIFLE',
    'WEAPON_SWEEPERSHOTGUN',
    'WEAPON_ASSAULTRIFLE_MK2',
    'WEAPON_BULLPUPRIFLE_MK2',
    'WEAPON_CARBINERIFLE_MK2',
    'WEAPON_COMBATMG_MK2',
    'WEAPON_HEAVYSNIPER_MK2',
    'WEAPON_KNUCKLE',
    'WEAPON_MARKSMANRIFLE_MK2',
    'WEAPON_PRECISIONRIFLE',
    'WEAPON_PETROLCAN',
    'WEAPON_PUMPSHOTGUN_MK2',
    'WEAPON_RAYCARBINE',
    'WEAPON_RAYMINIGUN',
    'WEAPON_RAYPISTOL',
    'WEAPON_REVOLVER_MK2',
    'WEAPON_SMG_MK2',
    'WEAPON_SNSPISTOL_MK2',
    'WEAPON_SPECIALCARBINE_MK2',
    'WEAPON_STONE_HATCHET'
}

local holstered = true
local canFire = true
local drawSession = 0
local currWeap = `WEAPON_UNARMED`
local pendingEquipHash = nil
local currHolster = nil
local currHolsterTexture = nil
local wearingHolster = nil

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

--- QB inventoriuje dažnai `weapon_smg`; animacijų sąraše – `WEAPON_SMG`.
local function joaatQbWeaponFromUpper(upper)
    if type(upper) ~= 'string' then return nil end
    local rest = upper:match('^WEAPON_(.+)$')
    if rest then return joaat(('weapon_' .. rest):lower()) end
    return nil
end

local function hashesMatchListedWeapon(candidateHash, listEntry)
    if not candidateHash or candidateHash == 0 then return false end
    local a = joaat(listEntry)
    if candidateHash == a then return true end
    local b = joaatQbWeaponFromUpper(listEntry)
    if b and candidateHash == b then return true end
    return false
end

local function checkWeapon(newWeap)
    if not newWeap or newWeap == 0 or newWeap == `WEAPON_UNARMED` then return false end
    for i = 1, #weapons do
        if hashesMatchListedWeapon(newWeap, weapons[i]) then
            return true
        end
    end
    if QBCore.Shared.Weapons and QBCore.Shared.Weapons[newWeap] then
        return true
    end
    local grp = GetWeapontypeGroup(newWeap)
    if grp and grp ~= `GROUP_UNARMED` and grp ~= `GROUP_THROWN` and grp ~= `GROUP_PETROLCAN` then
        return true
    end
    return false
end

local function isLongWeapon(weap)
    if not weap or weap == 0 then return false end
    local grp = GetWeapontypeGroup(weap)
    return grp == `GROUP_RIFLE`
        or grp == `GROUP_SMG`
        or grp == `GROUP_SHOTGUN`
        or grp == `GROUP_SNIPER`
        or grp == `GROUP_MG`
        or grp == `GROUP_HEAVY`
end

local function playDrawIntro(ped, pos, rot, wearingHolster, weap)
    if wearingHolster and not isLongWeapon(weap) then
        TaskPlayAnimAdvanced(ped, 'rcmjosh4', 'josh_leadout_cop2', pos.x, pos.y, pos.z, 0, 0, rot, 3.0, 3.0, -1, 50, 0, 0, 0)
        return 300
    end
    TaskPlayAnimAdvanced(ped, 'reaction@intimidation@1h', 'intro', pos.x, pos.y, pos.z, 0, 0, rot, 8.0, 3.0, -1, 50, 0, 0, 0)
    return isLongWeapon(weap) and 1200 or 1000
end

local function playDrawOutro(ped, pos, rot, wearingHolster, weap)
    if wearingHolster and not isLongWeapon(weap) then
        TaskPlayAnimAdvanced(ped, 'reaction@intimidation@cop@unarmed', 'intro', pos.x, pos.y, pos.z, 0, 0, rot, 3.0, 3.0, -1, 50, 0, 0, 0)
        return 500
    end
    TaskPlayAnimAdvanced(ped, 'reaction@intimidation@1h', 'outro', pos.x, pos.y, pos.z, 0, 0, rot, 8.0, 3.0, -1, 50, 0, 0, 0)
    return isLongWeapon(weap) and 1600 or 1400
end

local function pedWearingHolster(ped)
    local holsterVariant = GetPedDrawableVariation(ped, 8)
    for i = 1, #Config.WeapDraw.variants, 1 do
        if holsterVariant == Config.WeapDraw.variants[i] then
            return true
        end
    end
    return false
end

local function isWeaponHolsterable(weap)
    for i = 1, #Config.WeapDraw.weapons do
        if hashesMatchListedWeapon(weap, Config.WeapDraw.weapons[i]) then
            return true
        end
    end
    return false
end

RegisterNetEvent('qb-weapons:ResetHolster', function()
    holstered = true
    canFire = true
    currWeap = `WEAPON_UNARMED`
    pendingEquipHash = nil
    currHolster = nil
    currHolsterTexture = nil
    wearingHolster = nil
end)

--- Atšaukia veikiančią draw/holster giją prieš inventoriaus perkrovimą (be holster outro race).
RegisterNetEvent('qb-weapons:client:InvalidateDraw', function()
    drawSession = drawSession + 1
    pendingEquipHash = nil
    canFire = true
    _G.QBWeaponDrawBusy = false
end)

local function sessionAlive(mySession)
    return mySession == drawSession
end

local function waitInSession(mySession, ms)
    local deadline = GetGameTimer() + math.max(0, math.floor(tonumber(ms) or 0))
    while sessionAlive(mySession) and GetGameTimer() < deadline do
        Wait(0)
    end
    return sessionAlive(mySession)
end

RegisterNetEvent('qb-weapons:client:DrawWeapon', function(targetWeaponName)
    if GetResourceState('qb-inventory') == 'missing' then return end

    local holsterMode = targetWeaponName == '__holster__'
    local targetHash = nil
    if holsterMode then
        targetWeaponName = nil
    elseif targetWeaponName and targetWeaponName ~= '' then
        if WeaponHash and WeaponHash.resolve then
            targetHash = WeaponHash.resolve(targetWeaponName)
        else
            targetHash = joaat(tostring(targetWeaponName))
        end
    end

    drawSession = drawSession + 1
    local mySession = drawSession
    _G.QBWeaponDrawBusy = true

    local ped = PlayerPedId()
    if holsterMode and ped and ped ~= 0 then
        local held = GetSelectedPedWeapon(ped)
        if held and held ~= 0 and held ~= `WEAPON_UNARMED` and checkWeapon(held) then
            currWeap = held
            holstered = false
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        end
        pendingEquipHash = nil
    elseif targetHash and targetHash ~= 0 and targetHash ~= `WEAPON_UNARMED` and ped and ped ~= 0 then
        if not HasPedGotWeapon(ped, targetHash, false) then
            GiveWeaponToPed(ped, targetHash, 0, true, false)
        end
        pendingEquipHash = targetHash

        local held = GetSelectedPedWeapon(ped)
        -- Weapon→weapon: pirma holster dabartinį, tik tada draw naują (nepradėti draw iš karto).
        if held and held ~= 0 and held ~= `WEAPON_UNARMED` and held ~= targetHash and checkWeapon(held) then
            currWeap = held
            holstered = false
            SetPedCurrentWeaponVisible(ped, true, false, false, false)
            SetCurrentPedWeapon(ped, held, true)
        else
            currWeap = `WEAPON_UNARMED`
            holstered = true
            SetPedCurrentWeaponVisible(ped, false, false, false, false)
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        end
    end

    local sleep
    local weaponCheck = 0
    while sessionAlive(mySession) do
        local ped = PlayerPedId()
        sleep = 250
        if DoesEntityExist(ped) and not IsEntityDead(ped) and not IsPedInParachuteFreeFall(ped) and not IsPedFalling(ped) and (GetPedParachuteState(ped) == -1 or GetPedParachuteState(ped) == 0) then
            sleep = 0
            local selectedWeap = GetSelectedPedWeapon(ped)
            local newWeap = selectedWeap
            if pendingEquipHash then
                if not holstered and checkWeapon(currWeap) and currWeap ~= pendingEquipHash then
                    -- Swap: holster currWeap, then draw pending.
                    newWeap = pendingEquipHash
                    pendingEquipHash = nil
                elseif holstered and (selectedWeap == `WEAPON_UNARMED` or selectedWeap == pendingEquipHash) then
                    newWeap = pendingEquipHash
                    pendingEquipHash = nil
                end
            end
            if isReloadBusy() then
                sleep = 50
            elseif currWeap ~= newWeap then
                local pos = GetEntityCoords(ped, true)
                local rot = GetEntityHeading(ped)

                SetCurrentPedWeapon(ped, currWeap, true)
                loadAnimDict('reaction@intimidation@1h')
                loadAnimDict('reaction@intimidation@cop@unarmed')
                loadAnimDict('rcmjosh4')
                loadAnimDict('weapons@pistol@')

                local wearingHolster = pedWearingHolster(ped)
                if checkWeapon(newWeap) then
                    if holstered then
                        if wearingHolster and not isLongWeapon(newWeap) then
                            canFire = false
                            CeaseFire()
                            currHolster = GetPedDrawableVariation(ped, 7)
                            currHolsterTexture = GetPedTextureVariation(ped, 7)
                            TaskPlayAnimAdvanced(ped, 'rcmjosh4', 'josh_leadout_cop2', pos.x, pos.y, pos.z, 0, 0, rot, 3.0, 3.0, -1, 50, 0, 0, 0)
                            if not waitInSession(mySession, 300) then break end
                            SetCurrentPedWeapon(ped, newWeap, true)
                            SetPedCurrentWeaponVisible(ped, true, false, false, false)

                            if isWeaponHolsterable(newWeap) then
                                SetPedComponentVariation(ped, 7, currHolster == 8 and 2 or currHolster == 1 and 3 or currHolster == 6 and 5, currHolsterTexture, 2)
                            end
                            currWeap = newWeap
                            if not waitInSession(mySession, 300) then break end
                            clearPedTasksSafe(ped)
                            holstered = false
                            canFire = true
                        else
                            canFire = false
                            CeaseFire()
                            local waitMs = playDrawIntro(ped, pos, rot, wearingHolster, newWeap)
                            if not waitInSession(mySession, waitMs) then break end
                            SetCurrentPedWeapon(ped, newWeap, true)
                            SetPedCurrentWeaponVisible(ped, true, false, false, false)
                            currWeap = newWeap
                            if not waitInSession(mySession, wearingHolster and not isLongWeapon(newWeap) and 300 or (isLongWeapon(newWeap) and 400 or 1400)) then break end
                            clearPedTasksSafe(ped)
                            holstered = false
                            canFire = true
                        end
                    elseif newWeap ~= currWeap and checkWeapon(currWeap) then
                        if wearingHolster then
                            canFire = false
                            CeaseFire()

                            TaskPlayAnimAdvanced(ped, 'reaction@intimidation@cop@unarmed', 'intro', pos.x, pos.y, pos.z, 0, 0, rot, 3.0, 3.0, -1, 50, 0, 0, 0)
                            if not waitInSession(mySession, 500) then break end

                            if isWeaponHolsterable(currWeap) then
                                SetPedComponentVariation(ped, 7, currHolster, currHolsterTexture, 2)
                            end

                            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                            currHolster = GetPedDrawableVariation(ped, 7)
                            currHolsterTexture = GetPedTextureVariation(ped, 7)
                            holstered = true

                            -- Holster baigtas — dabar draw naują ginklą.
                            TaskPlayAnimAdvanced(ped, 'rcmjosh4', 'josh_leadout_cop2', pos.x, pos.y, pos.z, 0, 0, rot, 3.0, 3.0, -1, 50, 0, 0, 0)
                            if not waitInSession(mySession, 300) then break end
                            SetCurrentPedWeapon(ped, newWeap, true)
                            SetPedCurrentWeaponVisible(ped, true, false, false, false)

                            if isWeaponHolsterable(newWeap) then
                                SetPedComponentVariation(ped, 7, currHolster == 8 and 2 or currHolster == 1 and 3 or currHolster == 6 and 5, currHolsterTexture, 2)
                            end

                            if not waitInSession(mySession, 500) then break end
                            currWeap = newWeap
                            clearPedTasksSafe(ped)
                            holstered = false
                            canFire = true
                        else
                            canFire = false
                            CeaseFire()
                            local outroMs = playDrawOutro(ped, pos, rot, wearingHolster, currWeap)
                            if not waitInSession(mySession, outroMs) then break end
                            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                            holstered = true
                            local introMs = playDrawIntro(ped, pos, rot, wearingHolster, newWeap)
                            if not waitInSession(mySession, introMs) then break end
                            SetCurrentPedWeapon(ped, newWeap, true)
                            SetPedCurrentWeaponVisible(ped, true, false, false, false)
                            currWeap = newWeap
                            if not waitInSession(mySession, isLongWeapon(newWeap) and 400 or 1400) then break end
                            clearPedTasksSafe(ped)
                            holstered = false
                            canFire = true
                        end
                    else
                        if wearingHolster then
                            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                            currHolster = GetPedDrawableVariation(ped, 7)
                            currHolsterTexture = GetPedTextureVariation(ped, 7)
                            TaskPlayAnimAdvanced(ped, 'rcmjosh4', 'josh_leadout_cop2', pos.x, pos.y, pos.z, 0, 0, rot, 3.0, 3.0, -1, 50, 0, 0, 0)
                            if not waitInSession(mySession, 300) then break end
                            SetCurrentPedWeapon(ped, newWeap, true)

                            if isWeaponHolsterable(newWeap) then
                                SetPedComponentVariation(ped, 7, currHolster == 8 and 2 or currHolster == 1 and 3 or currHolster == 6 and 5, currHolsterTexture, 2)
                            end

                            currWeap = newWeap
                            if not waitInSession(mySession, 300) then break end
                            clearPedTasksSafe(ped)
                            holstered = false
                            canFire = true
                        else
                            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                            local waitMs = playDrawIntro(ped, pos, rot, wearingHolster, newWeap)
                            if not waitInSession(mySession, waitMs) then break end
                            SetCurrentPedWeapon(ped, newWeap, true)
                            SetPedCurrentWeaponVisible(ped, true, false, false, false)
                            currWeap = newWeap
                            if not waitInSession(mySession, wearingHolster and not isLongWeapon(newWeap) and 300 or (isLongWeapon(newWeap) and 400 or 1400)) then break end
                            clearPedTasksSafe(ped)
                            holstered = false
                            canFire = true
                        end
                    end
                else
                    if not holstered and checkWeapon(currWeap) then
                        if wearingHolster and not isLongWeapon(currWeap) then
                            canFire = false
                            CeaseFire()
                            TaskPlayAnimAdvanced(ped, 'reaction@intimidation@cop@unarmed', 'intro', pos.x, pos.y, pos.z, 0, 0, rot, 3.0, 3.0, -1, 50, 0, 0, 0)
                            if not waitInSession(mySession, 500) then break end

                            if isWeaponHolsterable(currWeap) then
                                SetPedComponentVariation(ped, 7, currHolster, currHolsterTexture, 2)
                            end

                            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                            clearPedTasksSafe(ped)
                            SetCurrentPedWeapon(ped, newWeap, true)
                            holstered = true
                            canFire = true
                            currWeap = newWeap
                        else
                            canFire = false
                            CeaseFire()
                            local outroMs = playDrawOutro(ped, pos, rot, wearingHolster, currWeap)
                            if not waitInSession(mySession, outroMs) then break end
                            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                            clearPedTasksSafe(ped)
                            SetCurrentPedWeapon(ped, newWeap, true)
                            holstered = true
                            canFire = true
                            currWeap = newWeap
                        end
                    else
                        SetCurrentPedWeapon(ped, newWeap, true)
                        holstered = false
                        canFire = true
                        currWeap = newWeap
                    end
                end
            end
        end
        Wait(sleep)
        if not sessionAlive(mySession) then break end
        if pendingEquipHash then
            weaponCheck = 0
        elseif currWeap == nil or currWeap == `WEAPON_UNARMED` then
            weaponCheck += 1
            if weaponCheck == 2 then
                break
            end
        else
            weaponCheck = 0
        end
    end
    canFire = true

    if not sessionAlive(mySession) then
        return
    end

  --- Animacija kartais palieka UNARMED — grąžinam tikslų ginklą jei jis vis dar pasirinktas inventoriuje.
    if targetHash and targetHash ~= 0 and targetHash ~= `WEAPON_UNARMED` then
        local ped = PlayerPedId()
        if ped and ped ~= 0 and HasPedGotWeapon(ped, targetHash, false) then
            SetPedCurrentWeaponVisible(ped, true, false, false, false)
            SetCurrentPedWeapon(ped, targetHash, true)
            currWeap = targetHash
            holstered = false
        end
    end
    _G.QBWeaponDrawBusy = false
    if holsterMode then
        TriggerEvent('qb-weapons:client:HolsterComplete')
        return
    end
    TriggerEvent('qb-weapons:client:HolsterVisualsAfterDraw')
end)

function CeaseFire()
    CreateThread(function()
        if GetResourceState('qb-inventory') == 'missing' then return end
        while not canFire do
            DisableControlAction(0, 25, true)
            DisablePlayerFiring(PlayerId(), true)
            Wait(0)
        end
    end)
end
