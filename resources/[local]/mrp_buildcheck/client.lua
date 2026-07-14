local QBCore = exports['qb-core']:GetCoreObject()

local TEST_MODELS = {
    { 'adder', 'Vanilla (adder)' },
    { 'suzume', 'Money Fronts (3570)' },
    { 'astrale', 'Safehouse (3751)' },
    { 'merula', 'Kortz Center (3788)' },
    { 'laufer', 'Kortz Center (3788)' },
}

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary', 8000)
end

RegisterCommand('checkbuild', function()
    local build = GetGameBuildNumber()
    local enforced = GetConvar('sv_enforceGameBuild', '?')
    notify(('Tavo GTA build: %s | Serveris reikalauja: %s'):format(build, enforced), build >= 3788 and 'success' or 'error')
end, false)

RegisterCommand('checkmodels', function()
    local build = GetGameBuildNumber()
    local lines = { ('Build: %s'):format(build) }
    for _, entry in ipairs(TEST_MODELS) do
        local model, label = entry[1], entry[2]
        local hash = joaat(model)
        local ok = IsModelInCdimage(hash) and IsModelAVehicle(hash)
        lines[#lines + 1] = ('%s %s — %s'):format(ok and '✓' or '✗', model, label)
    end
    notify(table.concat(lines, '\n'), 'primary')
    print('[mrp_buildcheck]\n' .. table.concat(lines, '\n'))
end, false)
