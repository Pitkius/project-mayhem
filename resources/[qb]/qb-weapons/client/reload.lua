--- Native GTA reload sesija.
--- Šis modulis nekuria animacijų ir garsų: visa prezentacija valdoma GTA natives.
WeaponReload = WeaponReload or {}

local activeSession = nil

local function selectedWeaponIs(ped, weaponHash)
    return ped and ped ~= 0
        and DoesEntityExist(ped)
        and GetSelectedPedWeapon(ped) == weaponHash
end

local function finishSession(session, reason)
    if not session or session.finished then return end
    session.finished = true
    if activeSession == session then
        activeSession = nil
    end

    local ped = session.ped
    local loaded = 0
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        loaded = WeaponAmmo.finishNativeReload(
            ped,
            session.weaponHash,
            session.clipBefore,
            session.maxClip,
            session.staged,
            session.weaponData
        )
    end

    if session.onFinished then
        session.onFinished(loaded, reason or 'finished')
    end
end

function WeaponReload.isActive()
    return activeSession ~= nil and activeSession.finished ~= true
end

function WeaponReload.start(ped, weaponHash, bullets, weaponData, onFinished, maxClipOverride)
    if WeaponReload.isActive() then return false, 'reload_busy' end
    if not selectedWeaponIs(ped, weaponHash) then return false, 'weapon_changed' end

    WeaponAmmo.ensureClipComponents(ped, weaponHash, weaponData)
    local clipBefore, maxClip, missing = WeaponAmmo.getClipAmmoState(ped, weaponHash, weaponData)
    maxClipOverride = math.floor(tonumber(maxClipOverride) or 0)
    if maxClipOverride > 0 then
        maxClip = math.max(maxClip, maxClipOverride)
        missing = math.max(0, maxClip - clipBefore)
    end
    local staged = math.min(
        math.max(0, math.floor(tonumber(bullets) or 0)),
        math.max(0, missing)
    )
    if staged <= 0 then return false, 'nothing_to_reload' end

    staged = WeaponAmmo.stageNativeReserve(ped, weaponHash, weaponData, staged)
    if staged <= 0 then return false, 'stage_failed' end

    local session = {
        ped = ped,
        weaponHash = weaponHash,
        weaponData = weaponData,
        clipBefore = clipBefore,
        maxClip = maxClip,
        staged = staged,
        onFinished = onFinished,
        finished = false,
        cancelled = false,
    }
    activeSession = session

    -- MakePedReload / TaskReloadWeapon naudoja pačios GTA animaciją ir garsą.
    MakePedReload(ped)

    CreateThread(function()
        local startDeadline = GetGameTimer() + (tonumber(Config.NativeReloadStartTimeout) or 900)
        local finishDeadline = GetGameTimer() + (tonumber(Config.NativeReloadTimeout) or 6500)
        local started = false
        local fallbackIssued = false

        while activeSession == session and not session.finished do
            local now = GetGameTimer()
            if session.cancelled then
                return finishSession(session, 'cancelled')
            end
            if not DoesEntityExist(ped) or IsEntityDead(ped) then
                return finishSession(session, 'ped_unavailable')
            end
            if not selectedWeaponIs(ped, weaponHash) then
                return finishSession(session, 'weapon_changed')
            end

            if IsPedReloading(ped) then
                started = true
            elseif started then
                return finishSession(session, 'finished')
            elseif now >= startDeadline then
                if not fallbackIssued then
                    fallbackIssued = true
                    startDeadline = now + 500
                    TaskReloadWeapon(ped, true)
                else
                    return finishSession(session, 'not_started')
                end
            end

            if now >= finishDeadline then
                return finishSession(session, 'timeout')
            end
            Wait(0)
        end
    end)

    return true
end

function WeaponReload.cancel()
    local session = activeSession
    if not session or session.finished then return false end
    session.cancelled = true
    return true
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local session = activeSession
    if session and not session.finished then
        WeaponAmmo.finishNativeReload(
            session.ped,
            session.weaponHash,
            session.clipBefore,
            session.maxClip,
            session.staged,
            session.weaponData
        )
        activeSession = nil
    end
end)
