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
        lines[#lines + 1] = ('%s %s — %s'):format(ok and 'OK' or 'NE', model, label)
    end
    notify(table.concat(lines, ' | '), 'primary')
    print('[mrp_buildcheck] ' .. table.concat(lines, '\n'))
end, false)

CreateThread(function()
    Wait(8000)
    local build = GetGameBuildNumber()
    if build < 3788 then
        notify(
            ('Tavo GTA build %s — nauji auto (Kortz) reikalauja 3788. Atnaujink GTA V per Rockstar Launcher.'):format(build),
            'error'
        )
    end
end)
