local QBCore = nil
pcall(function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

local function isDevMode()
    return GetConvarInt('moo', 0) == 31337
end

local function notify(msg, ntype)
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(msg, ntype or 'primary', 10000)
    end
    print(('[^5fivempro_devtools^7] %s'):format(msg))
end

local function devGuard()
    if isDevMode() then return true end
    notify('Dev režimas išjungtas. Paleisk FiveM per tools/Start-FiveM-Dev.bat (+set moo 31337)', 'error')
    return false
end

local function printHelp()
    print([[
^5════════ fivempro_devtools ════════^7
^3NUI (HTML/CSS/JS)^7
  F8: nui_devTools
  Naršyklė: ^2http://localhost:13172/^7  ← pasirink resursą (pvz. fivempro_charcreator), NE pilkas „Main cfx.re“
  Žaidime: /devtools  arba ^2F10^7

^3Resursų apkrova (klientas)^7
  F8: resmon true   |   resmon false
  Žaidime: /devresmon 1  |  /devresmon 0

^3Serverio profilis (txAdmin Live Console)^7
  profiler record 300
  profiler view

^3Greita diagnostika^7
  /devhelp — šis sąrašas
^5══════════════════════════════════^7]])
end

RegisterCommand('devhelp', function()
    printHelp()
    if devGuard() then
        notify('Instrukcijos — F8 konsolėje (devhelp)', 'success')
    end
end, false)

RegisterCommand('devtools', function()
    if not devGuard() then return end
    ExecuteCommand('nui_devTools')
    notify('NUI DevTools: naršyklėje atidaryk http://localhost:13172/ ir pasirink UI resursą', 'primary')
end, false)

RegisterCommand('devresmon', function(_, args)
    if not devGuard() then return end
    local arg = args[1]
    local on = not (arg == '0' or arg == 'false' or arg == 'off')
    ExecuteCommand(on and 'resmon true' or 'resmon false')
    notify(on and 'resmon įjungtas (F8 overlay)' or 'resmon išjungtas', on and 'success' or 'error')
end, false)

RegisterCommand('devnui', function()
    if not devGuard() then return end
    notify('Atidaryk Chrome/Edge: http://localhost:13172/', 'primary')
    print('^2[fivempro_devtools]^7 NUI sąrašas: http://localhost:13172/')
end, false)

RegisterKeyMapping('devtools', 'NUI DevTools (reikia dev režimo)', 'keyboard', 'F10')

CreateThread(function()
    Wait(4000)
    if not isDevMode() then
        print('[^3fivempro_devtools^7] Dev OFF — naudok tools/Start-FiveM-Dev.bat. Komandos: /devhelp')
        return
    end
    printHelp()
    notify('Dev ON | NUI: F10 arba http://localhost:13172/ | resmon: /devresmon 1', 'success')
end)
