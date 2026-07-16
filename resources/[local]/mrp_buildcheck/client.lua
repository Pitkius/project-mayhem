local QBCore = exports['qb-core']:GetCoreObject()

--- A Safehouse in the Hills (mansion DLC) — be Kortz Center (3788).
local REQUIRED_BUILD = 3717

local TEST_MODELS = {
    { 'adder', 'Vanilla (adder)' },
    { 'suzume', 'Money Fronts (3570)' },
    { 'astrale', 'Safehouse (3717+)' },
}

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary', 8000)
end

local function modelAvailable(spawnName)
    local hash = joaat(spawnName)
    return IsModelInCdimage(hash) and IsModelAVehicle(hash)
end

RegisterCommand('checkbuild', function()
    QBCore.Functions.TriggerCallback('mrp_buildcheck:server:getEnforcedBuild', function(enforced)
        local build = GetGameBuildNumber()
        local msg = ('Tavo build: %s | Serveris: %s (reikia %s — Safehouse mansion)'):format(
            build, enforced or '?', REQUIRED_BUILD
        )
        local ntype = 'primary'
        if tonumber(build) and tonumber(build) >= REQUIRED_BUILD and tonumber(enforced) == REQUIRED_BUILD then
            ntype = 'success'
        elseif tonumber(enforced) and tonumber(enforced) ~= REQUIRED_BUILD then
            ntype = 'error'
        end
        notify(msg, ntype)
    end)
end, false)

RegisterCommand('checkmodels', function()
    local build = GetGameBuildNumber()
    local lines = { ('Build: %s'):format(build) }
    local allOk = true
    for _, entry in ipairs(TEST_MODELS) do
        local model, label = entry[1], entry[2]
        local ok = modelAvailable(model)
        if not ok then allOk = false end
        lines[#lines + 1] = ('%s %s — %s'):format(ok and 'OK' or 'NE', model, label)
    end
    notify(table.concat(lines, ' | '), allOk and 'success' or 'error')
    print('[mrp_buildcheck] ' .. table.concat(lines, '\n'))
end, false)
