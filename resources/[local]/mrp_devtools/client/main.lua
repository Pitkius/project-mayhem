local QBCore = nil
pcall(function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

local resmonVisible = false

local function notify(msg, ntype)
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(msg, ntype or 'primary', 9000)
    end
    print(('[^5mrp_devtools^7] %s'):format(msg))
end

local function isStaff()
    return IsAceAllowed('command.resmon')
        or IsAceAllowed('command.profiler')
        or IsAceAllowed('group.admin')
end

local function isDevMode()
    return GetConvarInt('moo', 0) == 31337
end

local function tryEnableDevMode()
    if isDevMode() then return true end
    ExecuteCommand('set moo 31337')
    Wait(50)
    return isDevMode()
end

local function printHelp()
    print([[
^5════════ mrp_devtools ════════^7
^3Resmon (resursų apkrova)^7
  ^2F10^7 — įjungti / išjungti resmon
  F8: resmon true  |  resmon false

^3NUI (HTML/CSS/JS)^7
  /devtools  arba F8: nui_devTools
  Naršyklė: ^2http://localhost:13172/^7

^3Serverio profilis (txAdmin)^7
  profiler record 300
  profiler view

^3Jei F10 neveikia^7
  Paleisk FiveM per ^2tools\Start-FiveM-Dev.bat^7
  arba shortcut su: +set moo 31337
^5══════════════════════════════════^7]])
end

local function toggleResmon()
    if not isStaff() then
        notify('Resmon tik adminams.', 'error')
        return
    end

    if not tryEnableDevMode() then
        notify('Dev režimas išjungtas. Paleisk FiveM per tools\\Start-FiveM-Dev.bat (+set moo 31337)', 'error')
        return
    end

    resmonVisible = not resmonVisible
    ExecuteCommand(resmonVisible and 'resmon true' or 'resmon false')
    notify(resmonVisible and 'Resmon įjungtas (F10 — uždaryti)' or 'Resmon išjungtas', resmonVisible and 'success' or 'primary')
end

RegisterCommand('devresmon_toggle', toggleResmon, false)
RegisterKeyMapping('devresmon_toggle', 'Resmon — resursų monitorius (admin)', 'keyboard', 'F10')

RegisterCommand('devhelp', function()
    printHelp()
    notify('Instrukcijos — F8 konsolėje (/devhelp)', 'primary')
end, false)

RegisterCommand('devtools', function()
    if not isStaff() then
        notify('Tik adminams.', 'error')
        return
    end
    if not tryEnableDevMode() then
        notify('Paleisk FiveM per tools\\Start-FiveM-Dev.bat', 'error')
        return
    end
    ExecuteCommand('nui_devTools')
    notify('NUI DevTools — naršyklėje: http://localhost:13172/', 'primary')
end, false)

RegisterCommand('devresmon', function(_, args)
    if not isStaff() then
        notify('Tik adminams.', 'error')
        return
    end
    if not tryEnableDevMode() then
        notify('Paleisk FiveM per tools\\Start-FiveM-Dev.bat', 'error')
        return
    end
    local arg = args[1]
    local on = not (arg == '0' or arg == 'false' or arg == 'off')
    resmonVisible = on
    ExecuteCommand(on and 'resmon true' or 'resmon false')
    notify(on and 'Resmon įjungtas' or 'Resmon išjungtas', on and 'success' or 'primary')
end, false)

RegisterCommand('devnui', function()
    if not isStaff() then return end
    notify('Atidaryk: http://localhost:13172/', 'primary')
end, false)

RegisterNetEvent('mrp_devtools:client:enableDev', function()
    tryEnableDevMode()
end)

CreateThread(function()
    Wait(5000)
    if not isStaff() then return end
    if isDevMode() then
        printHelp()
        notify('Dev ON | F10 = resmon | /devtools = NUI inspector', 'success')
        return
    end
    print('[^3mrp_devtools^7] Dev OFF — F10/resmon reikia +set moo 31337. Paleisk tools\\Start-FiveM-Dev.bat')
end)
