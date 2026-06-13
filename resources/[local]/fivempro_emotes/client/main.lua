local QBCore = exports['qb-core']:GetCoreObject()

local menuOpen = false
local currentProp = 0
local catalogForNui = {}

local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function loadClipset(name)
    if not name or name == '' or name == 'reset' then return true end
    RequestAnimSet(name)
    local deadline = GetGameTimer() + 5000
    while not HasAnimSetLoaded(name) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimSetLoaded(name)
end

local function deleteProp()
    if currentProp ~= 0 and DoesEntityExist(currentProp) then
        DetachEntity(currentProp, true, true)
        DeleteEntity(currentProp)
    end
    currentProp = 0
end

local function canUseEmotes()
    local ped = PlayerPedId()
    if not ped or ped == 0 then return false end
    if IsEntityDead(ped) or IsPedRagdoll(ped) then return false end
    if Config.BlockInVehicle and IsPedInAnyVehicle(ped, false) then return false end
    return true
end

local function buildCatalog()
    catalogForNui = {}
    for i, entry in ipairs(EmoteCatalog or {}) do
        catalogForNui[#catalogForNui + 1] = {
            id = i,
            cat = entry.cat,
            label = entry.label,
            clipset = entry.clipset,
            dict = entry.dict,
            anim = entry.anim,
            scenario = entry.scenario,
            flags = entry.flags,
            prop = entry.prop,
        }
    end
end

local function cancelEmote(silent)
    deleteProp()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    ClearPedSecondaryTask(ped)
    if not silent then
        QBCore.Functions.Notify('Animacija atšaukta.', 'primary')
    end
end

local function attachProp(ped, entry)
    deleteProp()
    if not entry.prop then return end
    local model = type(entry.prop) == 'string' and joaat(entry.prop) or entry.prop
    RequestModel(model)
    local deadline = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do
        Wait(10)
    end
    if not HasModelLoaded(model) then return end

    local c = GetEntityCoords(ped)
    currentProp = CreateObject(model, c.x, c.y, c.z, true, true, false)
    SetEntityCollision(currentProp, false, false)
    local p = entry.placement or { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 }
    AttachEntityToEntity(
        currentProp,
        ped,
        GetPedBoneIndex(ped, entry.bone or 60309),
        p[1], p[2], p[3],
        p[4], p[5], p[6],
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(model)
end

local function playEmoteById(id)
    if not canUseEmotes() then
        return QBCore.Functions.Notify('Dabar negali naudoti animacijų.', 'error')
    end

    local entry = EmoteCatalog[tonumber(id)]
    if not entry then return end

    local ped = PlayerPedId()
    cancelEmote(true)

    if entry.clipset then
        if entry.clipset == 'reset' then
            ResetPedMovementClipset(ped, 0.25)
            ResetPedWeaponMovementClipset(ped)
            ResetPedStrafeClipset(ped)
            QBCore.Functions.Notify('Eismo stilius: normalus', 'success')
            return
        end
        if not loadClipset(entry.clipset) then
            return QBCore.Functions.Notify('Nepavyko užkrauti eismo stiliaus.', 'error')
        end
        SetPedMovementClipset(ped, entry.clipset, 0.25)
        QBCore.Functions.Notify(entry.label or 'Eismo stilius', 'success')
        return
    end

    if entry.scenario then
        TaskStartScenarioInPlace(ped, entry.scenario, 0, true)
        QBCore.Functions.Notify(entry.label or 'Scenarijus', 'success')
        return
    end

    if not entry.dict or not entry.anim then return end
    if not loadAnimDict(entry.dict) then
        return QBCore.Functions.Notify('Animacija nerasta.', 'error')
    end

    TaskPlayAnim(ped, entry.dict, entry.anim, 2.0, 2.0, -1, entry.flags or 49, 0.0, false, false, false)
    if entry.prop then
        attachProp(ped, entry)
    end
    QBCore.Functions.Notify(entry.label or 'Animacija', 'success')
end

local function openMenu()
    if menuOpen then return end
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        categories = Config.Categories,
        emotes = catalogForNui,
        total = #catalogForNui,
    })
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function toggleMenu()
    if menuOpen then
        closeMenu()
    else
        openMenu()
    end
end

RegisterNUICallback('emotes:close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('emotes:play', function(data, cb)
    if data and data.id then
        playEmoteById(data.id)
    end
    cb({ ok = true })
end)

RegisterNUICallback('emotes:cancel', function(_, cb)
    cancelEmote(false)
    cb({ ok = true })
end)

RegisterCommand('+fivempro_emotes_open', function()
    toggleMenu()
end, false)
RegisterCommand('-fivempro_emotes_open', function() end, false)
RegisterKeyMapping('+fivempro_emotes_open', 'Animacijų meniu (F3)', 'keyboard', Config.OpenKey or 'F3')

RegisterCommand('emotecancel', function()
    cancelEmote(false)
end, false)
RegisterKeyMapping('emotecancel', 'Atšaukti animaciją', 'keyboard', Config.CancelKey or 'X')

RegisterCommand(Config.OpenCommand or 'animacijos', function()
    toggleMenu()
end, false)

RegisterCommand('e', function(_, args)
    local query = table.concat(args or {}, ' '):lower()
    if query == '' or query == 'c' or query == 'cancel' then
        cancelEmote(false)
        return
    end
    for i, entry in ipairs(EmoteCatalog or {}) do
        if entry.label and entry.label:lower():find(query, 1, true) then
            playEmoteById(i)
            return
        end
    end
    QBCore.Functions.Notify('Animacija nerasta: ' .. query, 'error')
end, false)

CreateThread(function()
    buildCatalog()
end)

CreateThread(function()
    while true do
        if menuOpen and (IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322)) then
            closeMenu()
        end
        Wait(0)
    end
end)

exports('OpenEmoteMenu', openMenu)
exports('CancelEmote', cancelEmote)
exports('PlayEmote', playEmoteById)
