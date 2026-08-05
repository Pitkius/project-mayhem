PhonePolice = PhonePolice or {}

local QBCore = exports['qb-core']:GetCoreObject()

local function isPoliceOnDuty(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    local job = P.PlayerData.job
    if not job or job.name ~= 'police' then return false end
    return job.onduty == true
end

local ALLOWED = {
    [PhoneStates.FROZEN] = true,
    [PhoneStates.EVIDENCE] = true,
    [PhoneStates.ACTIVE] = true,
}

function PhonePolice.SetStatus(src, phoneId, newStatus, reason)
    if not isPoliceOnDuty(src) then
        return false, 'Reikia būti tarnyboje (police).'
    end
    newStatus = PhoneStates.Normalize(newStatus)
    if not ALLOWED[newStatus] then
        return false, 'Negalima nustatyti šios būsenos.'
    end
    local row = PhoneCore.GetById(phoneId)
    if not row then return false, 'Telefonas nerastas.' end
    if PhoneStates.Normalize(row.status) == PhoneStates.DESTROYED then
        return false, 'Telefonas sunaikintas.'
    end

    local P = QBCore.Functions.GetPlayer(src)
    local cid = P and P.PlayerData.citizenid or nil
    MySQL.update.await('UPDATE mrp_phones SET status = ? WHERE phone_id = ?', { newStatus, phoneId })
    PhoneDB.Audit(phoneId, cid, 'police_status', ('%s:%s'):format(newStatus, tostring(reason or ''):sub(1, 180)))

    if PhoneStates.BlocksUse(newStatus) then
        for _, playerId in ipairs(GetPlayers()) do
            local psrc = tonumber(playerId)
            local s = PhoneSession.Get(psrc)
            if s and s.phoneId == phoneId then
                PhoneSession.Clear(psrc)
                TriggerClientEvent('mrp_phone:client:forceClose', psrc, { reason = newStatus })
            end
        end
    end

    return true, PhoneCore.Public(PhoneCore.GetById(phoneId))
end

exports('SetPhoneStatus', function(phoneId, newStatus, actorSrc, reason)
    if actorSrc then
        return PhonePolice.SetStatus(actorSrc, phoneId, newStatus, reason)
    end
    newStatus = PhoneStates.Normalize(newStatus)
    if not ALLOWED[newStatus] and newStatus ~= PhoneStates.LOCKED then
        return false, 'Invalid status'
    end
    MySQL.update.await('UPDATE mrp_phones SET status = ? WHERE phone_id = ?', { newStatus, phoneId })
    PhoneDB.Audit(phoneId, nil, 'status_force', newStatus)
    return true
end)
