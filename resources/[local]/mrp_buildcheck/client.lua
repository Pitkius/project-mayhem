local QBCore = exports['qb-core']:GetCoreObject()

local REQUIRED_BUILD = 3788

--- Kortz Center (build 3788 / Patch 2026-1) — spawn vardai patvirtinti GTA Wiki.
local KORTZ_MODELS = {
    { 'merula', 'Albany Merula' },
    { 'laufer', 'Benefactor Läufer' },
    { 'lrcgt', 'Benefactor LRC GT' },
    { 'cartucciagt', 'Grotti Cartuccia GT' },
    { 'estride', 'Ocelot E-Stride' },
    { 'velenogt', 'Grotti Veleno GT' },
}

local TEST_MODELS = {
    { 'adder', 'Vanilla (adder)' },
    { 'suzume', 'Money Fronts (3570)' },
    { 'astrale', 'Safehouse (3751)' },
    KORTZ_MODELS[1],
    KORTZ_MODELS[3],
}

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary', 10000)
end

local function modelAvailable(spawnName)
    local hash = joaat(spawnName)
    return IsModelInCdimage(hash) and IsModelAVehicle(hash)
end

local function countKortzAvailable()
    local ok, total = 0, #KORTZ_MODELS
    for _, entry in ipairs(KORTZ_MODELS) do
        if modelAvailable(entry[1]) then ok = ok + 1 end
    end
    return ok, total
end

local function kortzMissingHint()
    return table.concat({
        'Kortz Center auto (3788) neįkelti tavo GTA V failuose.',
        '1) Rockstar Launcher → GTA V → Patikrinti failus / Verify integrity',
        '2) Atnaujink FiveM klientą (Settings → Update channel → Latest/Canary)',
        '3) Perkrauk PC ir bandyk /checkmodels',
    }, ' ')
end

RegisterCommand('checkbuild', function()
    QBCore.Functions.TriggerCallback('mrp_buildcheck:server:getEnforcedBuild', function(enforced)
        local build = GetGameBuildNumber()
        local kortzOk, kortzTotal = countKortzAvailable()
        local msg = ('Tavo build: %s | Serveris: %s | Kortz auto: %d/%d'):format(
            build, enforced or '?', kortzOk, kortzTotal
        )
        local ntype = 'primary'
        if kortzOk < kortzTotal then
            ntype = 'error'
            msg = msg .. ' — trūksta Title Update 1.73 (Patch 2026-1) failų.'
        elseif build >= REQUIRED_BUILD and tonumber(enforced) == REQUIRED_BUILD then
            ntype = 'success'
        end
        notify(msg, ntype)
        if kortzOk < kortzTotal then
            notify(kortzMissingHint(), 'error')
        end
    end)
end, false)

RegisterCommand('checkmodels', function()
    local build = GetGameBuildNumber()
    local lines = { ('Build: %s'):format(build) }
    for _, entry in ipairs(TEST_MODELS) do
        local model, label = entry[1], entry[2]
        local ok = modelAvailable(model)
        lines[#lines + 1] = ('%s %s — %s'):format(ok and 'OK' or 'NE', model, label)
    end
    local kortzOk, kortzTotal = countKortzAvailable()
    lines[#lines + 1] = ('Kortz iš viso: %d/%d'):format(kortzOk, kortzTotal)
    notify(table.concat(lines, ' | '), kortzOk >= kortzTotal and 'success' or 'error')
    print('[mrp_buildcheck] ' .. table.concat(lines, '\n'))
    if kortzOk < kortzTotal then
        notify(kortzMissingHint(), 'error')
    end
end, false)

CreateThread(function()
    Wait(12000)
    local kortzOk, kortzTotal = countKortzAvailable()
    if kortzOk >= kortzTotal then return end
    notify(
        ('Kortz Center auto neprieinami (%d/%d). %s'):format(kortzOk, kortzTotal, kortzMissingHint()),
        'error'
    )
end)
