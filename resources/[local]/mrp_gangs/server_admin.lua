local QBCore = exports['qb-core']:GetCoreObject()

--- QBCore HasPermission (qbcore.admin) + txAdmin / server.cfg group.admin (command ACE).
function HasGangAdminPermission(src)
    if type(src) ~= 'number' or src < 1 then return false end

    for _, perm in ipairs(Config.AdminPermissions or {}) do
        if QBCore.Functions.HasPermission(src, perm) then return true end
        if IsPlayerAceAllowed(src, 'qbcore.' .. perm) then return true end
    end

    for _, ace in ipairs(Config.AdminAceFallbacks or {}) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end

    return false
end
