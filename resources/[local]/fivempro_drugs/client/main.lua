local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local currentStationId = nil
local testPed = 0
local supplyShopPed = 0
local supplyShopBlip = nil
local productBuyerPeds = {}
local productBuyerBlips = {}
local mapBlips = {}

local function nui(msg, data)
    SendNUIMessage({ action = msg, data = data or {} })
end

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    currentStationId = nil
    SetNuiFocus(false, false)
    nui('close')
end

local function openStationUi(stationId)
    QBCore.Functions.TriggerCallback('fivempro_drugs:server:getStationUi', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.reason) or 'Nepavyko atidaryti.', 'error')
        end
        currentStationId = stationId
        uiOpen = true
        SetNuiFocus(true, true)
        nui('open', res)
    end, stationId)
end

local PROGRESS_DISABLE = {
    disableMovement = true,
    disableCarMovement = true,
    disableCombat = true,
}

local function applyProgressDisables(disableControls)
    if type(disableControls) ~= 'table' then return end
    if disableControls.disableMovement then
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 36, true)
        DisableControlAction(0, 21, true)
    end
    if disableControls.disableCarMovement then
        DisableControlAction(0, 63, true)
        DisableControlAction(0, 64, true)
        DisableControlAction(0, 71, true)
        DisableControlAction(0, 72, true)
    end
    if disableControls.disableCombat then
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 47, true)
        DisableControlAction(0, 58, true)
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 143, true)
    end
end

local craftPropEntity = nil
local craftProgressToken = 0

local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function clearCraftProp()
    if craftPropEntity and DoesEntityExist(craftPropEntity) then
        DeleteEntity(craftPropEntity)
    end
    craftPropEntity = nil
end

local function attachCraftProp(propCfg)
    clearCraftProp()
    if not propCfg or not propCfg.model then return end
    local ped = PlayerPedId()
    local hash = joaat(propCfg.model)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(10)
    end
    if not HasModelLoaded(hash) then return end
    local coords = GetEntityCoords(ped)
    craftPropEntity = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    local bone = GetPedBoneIndex(ped, propCfg.bone or 28422)
    local pos = propCfg.pos or vector3(0.0, 0.0, 0.0)
    local rot = propCfg.rot or vector3(0.0, 0.0, 0.0)
    AttachEntityToEntity(craftPropEntity, ped, bone, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
end

local function stopCraftAnim()
    craftProgressToken = craftProgressToken + 1
    hideCraftProgress()
    clearCraftProp()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
end

local function hideCraftProgress()
    nui('craftProgressHide')
end

local function startCraftAnim(anim)
    if not anim or not anim.dict then return end
    if not loadAnimDict(anim.dict) then return end
    local ped = PlayerPedId()
    TaskPlayAnim(ped, anim.dict, anim.clip or 'base', 4.0, 4.0, -1, anim.flag or 49, 0, false, false, false)
end

local function runProgress(label, durationMs, onDone, anim, propCfg, meta)
    durationMs = tonumber(durationMs) or 5000
    label = label or 'Gaminama…'
    meta = meta or {}

    craftProgressToken = craftProgressToken + 1
    local token = craftProgressToken

    local phaseStart = GetGameTimer()
    local endAt = phaseStart + durationMs
    local totalMs = tonumber(meta.totalMs) or durationMs
    local elapsedBefore = tonumber(meta.elapsedMs) or 0
    local phaseIndex = tonumber(meta.phaseIndex) or 1
    local phaseCount = tonumber(meta.phaseCount) or 1

    if anim then
        if propCfg then attachCraftProp(propCfg) end
        startCraftAnim(anim)
    end

    nui('craftProgress', {
        label = label,
        phaseIndex = phaseIndex,
        phaseCount = phaseCount,
        durationMs = durationMs,
        totalMs = totalMs,
        elapsedMs = elapsedBefore,
    })

    CreateThread(function()
        local lastNuiUpdate = 0
        while GetGameTimer() < endAt do
            if token ~= craftProgressToken then return end

            applyProgressDisables(PROGRESS_DISABLE)

            if anim and anim.dict then
                local ped = PlayerPedId()
                local clip = anim.clip or 'base'
                if not IsEntityPlayingAnim(ped, anim.dict, clip, 3) then
                    TaskPlayAnim(ped, anim.dict, clip, 4.0, 4.0, -1, anim.flag or 49, 0, false, false, false)
                end
            end

            if IsControlJustReleased(0, 73) or IsControlJustReleased(0, 200) then
                hideCraftProgress()
                stopCraftAnim()
                if onDone then onDone(false) end
                return
            end

            local now = GetGameTimer()
            if now - lastNuiUpdate >= 100 then
                lastNuiUpdate = now
                local phaseElapsed = now - phaseStart
                local totalRemaining = math.max(0, totalMs - elapsedBefore - phaseElapsed)
                local overallPct = math.min(100, math.floor(((elapsedBefore + phaseElapsed) / totalMs) * 100))
                nui('craftProgressUpdate', {
                    totalRemainingMs = totalRemaining,
                    overallPct = overallPct,
                })
            end

            Wait(0)
        end

        if token ~= craftProgressToken then return end
        hideCraftProgress()
        clearCraftProp()
        local ped = PlayerPedId()
        ClearPedTasks(ped)
        if onDone then onDone(true) end
    end)
end

local pendingMinigame = nil

local function runSkillMinigame(onDone)
    pendingMinigame = onDone
    nui('minigameSkill', { durationMs = 4200 })
    SetNuiFocus(true, true)
end

local function runAdvancedMinigame(onDone)
    pendingMinigame = onDone
    nui('minigameAdvanced', { rounds = 3 })
    SetNuiFocus(true, true)
end

local function getAllStations()
    local list = {}
    for _, st in ipairs(Config.Stations or {}) do
        list[#list + 1] = st
    end
    local lab = Config.HeroinLab
    if lab and lab.stations then
        for _, st in ipairs(lab.stations) do
            list[#list + 1] = st
        end
    end
    local weedCayo = Config.WeedCayoLab
    if weedCayo and weedCayo.stations then
        for _, st in ipairs(weedCayo.stations) do
            list[#list + 1] = st
        end
    end
    local methLab = Config.MethLab
    if methLab and methLab.stations then
        for _, st in ipairs(methLab.stations) do
            list[#list + 1] = st
        end
    end
    local pillsLab = Config.PillsLab
    if pillsLab and pillsLab.stations then
        for _, st in ipairs(pillsLab.stations) do
            list[#list + 1] = st
        end
    end
    local ampLab = Config.AmpMobileLab
    if ampLab and ampLab.packStation then
        list[#list + 1] = ampLab.packStation
    end
    return list
end

local function getStationById(stationId)
    for _, st in ipairs(getAllStations()) do
        if st.id == stationId then return st end
    end
end

local function faceCraftStation(stationId)
    local st = getStationById(stationId)
    if not st or not st.coords then return end
    local c = st.coords
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, c.x, c.y, c.z, 900)
    Wait(700)
end

local function runWeaponCraftSequence(res, afterMinigame)
    closeUi()
    Wait(250)
    faceCraftStation(currentStationId)

    local wc = Config.WeaponCraft or {}
    local usesPrinter = res.usesPrinter == true
    local phases = usesPrinter and (wc.phases or {}) or (wc.benchPhases or wc.phases or {})
    if #phases == 0 then
        return runProgress(res.label, res.craftTimeMs or 60000, afterMinigame)
    end

    local level = tonumber(res.level) or 1
    local mult = (wc.timeMultiplier and wc.timeMultiplier[level]) or 1.0
    local baseMs = math.floor((res.craftTimeMs or 60000) * mult)
    local mg = res.minigame or 'progress'
    local minPhase = tonumber(wc.minPhaseMs) or 9000
    local phaseIndex = 1
    local phaseDurations = {}
    local totalMs = 0
    for _, phase in ipairs(phases) do
        local dur = math.max(minPhase, math.floor(baseMs * (phase.weight or 0.25)))
        phaseDurations[#phaseDurations + 1] = dur
        totalMs = totalMs + dur
    end

    local function runMinigameThen(nextFn)
        if mg == 'skill' then
            runSkillMinigame(function(success)
                if not success then return afterMinigame(false) end
                nextFn()
            end)
        elseif mg == 'advanced' then
            runAdvancedMinigame(function(success)
                if not success then return afterMinigame(false) end
                nextFn()
            end)
        else
            nextFn()
        end
    end

    local minigameAt = usesPrinter and 3 or math.max(1, #phases - 1)

    local function nextPhase()
        if phaseIndex > #phases then
            return afterMinigame(true)
        end
        local phase = phases[phaseIndex]
        local currentIdx = phaseIndex
        phaseIndex = phaseIndex + 1
        local dur = phaseDurations[currentIdx] or minPhase
        local elapsedBefore = 0
        for i = 1, currentIdx - 1 do
            elapsedBefore = elapsedBefore + (phaseDurations[i] or 0)
        end

        runProgress(phase.label or res.label, dur, function(ok)
            if not ok then return afterMinigame(false) end
            if currentIdx == minigameAt and (mg == 'skill' or mg == 'advanced') then
                return runMinigameThen(nextPhase)
            end
            nextPhase()
        end, phase.anim, phase.prop, {
            phaseIndex = currentIdx,
            phaseCount = #phases,
            totalMs = totalMs,
            elapsedMs = elapsedBefore,
        })
    end

    if usesPrinter then
        QBCore.Functions.Notify('3D spausdintuvas paleistas — neuždaryk proceso.', 'primary', 5000)
    else
        QBCore.Functions.Notify('Gamyba prasidėjo — neuždaryk proceso.', 'primary', 5000)
    end
    nextPhase()
end

local function startCraftFlow(productId)
    if not currentStationId then return end
    QBCore.Functions.TriggerCallback('fivempro_drugs:server:startCraft', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.reason) or 'Gamyba negalima.', 'error')
        end

        local function afterMinigame(success)
            stopCraftAnim()
            QBCore.Functions.TriggerCallback('fivempro_drugs:server:finishCraft', function(done)
                if not done or not done.ok then
                    QBCore.Functions.Notify((done and done.reason) or 'Gamyba nepavyko.', 'error')
                    if currentStationId then openStationUi(currentStationId) end
                    return
                end
                QBCore.Functions.Notify(('Pagaminta: %s x%d'):format(done.label or done.item, done.amount or 1), 'success')
                if currentStationId then openStationUi(currentStationId) end
            end, res.token, success)
        end

        if res.isWeapon then
            return runWeaponCraftSequence(res, afterMinigame)
        end

        local mg = res.minigame or 'progress'
        if mg == 'progress' then
            runProgress(res.label, res.craftTimeMs or 25000, afterMinigame)
        elseif mg == 'skill' then
            runProgress(res.label, math.floor((res.craftTimeMs or 30000) * 0.55), function(ok)
                if ok then runSkillMinigame(afterMinigame) else afterMinigame(false) end
            end)
        else
            runProgress(res.label, math.floor((res.craftTimeMs or 40000) * 0.45), function(ok)
                if ok then runAdvancedMinigame(afterMinigame) else afterMinigame(false) end
            end)
        end
    end, currentStationId, productId)
end

local function findSellTargetPed()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local handle, foundPed = FindFirstPed()
    local ok = true
    local target = 0
    repeat
        if foundPed and foundPed ~= ped and not IsPedAPlayer(foundPed) and not IsEntityDead(foundPed) then
            local tp = GetEntityCoords(foundPed)
            if #(p - tp) <= (Config.Sell and Config.Sell.maxDistanceToPed or 3.0) then
                target = foundPed
                break
            end
        end
        ok, foundPed = FindNextPed(handle)
    until not ok
    EndFindPed(handle)
    return target
end

local function trySellToNpc(itemName)
    local target = findSellTargetPed()
    if target == 0 then
        return QBCore.Functions.Notify('Netoliese nėra NPC.', 'error')
    end
    QBCore.Functions.TriggerCallback('fivempro_drugs:server:tryNpcSell', function(res)
        if not res or not res.ok then
            if res and res.panic then
                return QBCore.Functions.Notify(res.reason or 'NPC panikuoja!', 'error')
            end
            if res and res.refused then
                return QBCore.Functions.Notify('NPC atsisakė pirkti.', 'error')
            end
            return QBCore.Functions.Notify((res and res.reason) or 'Pardavimas nepavyko.', 'error')
        end
        QBCore.Functions.Notify(('Parduota už $%s'):format(res.price or 0), 'success')
        if res.alertPolice then
            QBCore.Functions.Notify('Kažkas gali būti iškvietęs policiją…', 'error', 5500)
        end
    end, itemName, NetworkGetNetworkIdFromEntity(target))
end

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb('ok')
end)

RegisterNUICallback('craft', function(data, cb)
    if data and data.productId then
        startCraftFlow(data.productId)
    end
    cb('ok')
end)

RegisterNUICallback('buyParts', function(_, cb)
    cb('ok')
    closeUi()
    CreateThread(function()
        Wait(300)
        openWeaponPartsMenu()
    end)
end)

RegisterNUICallback('refresh', function(_, cb)
    if currentStationId then openStationUi(currentStationId) end
    cb('ok')
end)

local function finishMinigame(success)
    SetNuiFocus(uiOpen, uiOpen)
    local cb = pendingMinigame
    pendingMinigame = nil
    if cb then cb(success == true) end
end

RegisterNUICallback('skillResult', function(data, cb)
    finishMinigame(data and data.success)
    cb('ok')
end)

RegisterNUICallback('advancedResult', function(data, cb)
    finishMinigame(data and data.success)
    cb('ok')
end)

RegisterCommand('drugsell', function()
    local sellables = {}
    for _, prod in pairs(Config.Products or {}) do
        if (prod.sellBase or 0) > 0 and prod.output then
            sellables[#sellables + 1] = prod.output
        end
    end
    for _, outItem in ipairs(sellables) do
        if QBCore.Functions.HasItem(outItem, 1) then
            return trySellToNpc(outItem)
        end
    end
    QBCore.Functions.Notify('Neturi parduodamų produktų.', 'error')
end, false)

local function setBlipLabel(blip, label)
    local text = tostring(label or 'Gamyba')
    if GetResourceState('fivempro_fonts') == 'started' then
        exports['fivempro_fonts']:SetBlipName(blip, text)
        return
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(text)
    EndTextCommandSetBlipName(blip)
end

local function resolveStationBlipCfg(st)
    if not st or st.blip == false then return nil end
    if not Config.ShowStationBlips and st.blip ~= true and type(st.blip) ~= 'table' then return nil end
    local def = Config.StationBlip or {}
    local custom = type(st.blip) == 'table' and st.blip or {}
    return {
        coords = custom.coords or st.coords,
        sprite = custom.sprite or def.sprite or 496,
        color = custom.color or def.color or 27,
        scale = custom.scale or def.scale or 0.72,
        shortRange = custom.shortRange ~= false and (def.shortRange ~= false),
        label = custom.label or st.label or def.label or 'Narkotikų gamyba',
    }
end

local function createMapBlip(cfg)
    if not cfg or not cfg.coords then return end
    local c = cfg.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, cfg.sprite or 496)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, cfg.scale or 0.72)
    SetBlipColour(blip, cfg.color or 27)
    SetBlipAsShortRange(blip, cfg.shortRange ~= false)
    setBlipLabel(blip, cfg.label)
    mapBlips[#mapBlips + 1] = blip
end

local function setupStationBlips()
    for _, bl in ipairs(mapBlips) do
        if bl and DoesBlipExist(bl) then RemoveBlip(bl) end
    end
    mapBlips = {}

    local function addCfgBlip(coords, blipCfg, fallbackLabel)
        if not coords or not blipCfg or blipCfg.enabled == false then return end
        createMapBlip({
            coords = coords,
            sprite = blipCfg.sprite,
            color = blipCfg.color,
            scale = blipCfg.scale,
            shortRange = blipCfg.shortRange ~= false,
            label = blipCfg.label or fallbackLabel,
        })
    end

    local function isCayoIslandLoaded()
        if GetResourceState('fivempro_cayoperico') ~= 'started' then return false end
        return exports['fivempro_cayoperico']:IsIslandLoaded()
    end

    local function addFieldBlip(field, fallbackLabel)
        if not field or not field.center then return end
        if field.requireIsland and not isCayoIslandLoaded() then return end
        addCfgBlip(field.center, field.blip, field.blip and field.blip.label or fallbackLabel)
    end

    -- Nelegalūs reikmenys (Grove)
    local supply = Config.SupplyShopNPC
    if supply and supply.enabled ~= false and supply.coords then
        addCfgBlip(
            (supply.blip and supply.blip.coords) or vector3(supply.coords.x, supply.coords.y, supply.coords.z),
            supply.blip or { enabled = true, label = supply.label },
            supply.label
        )
    end

    -- Žolės reikmenų NPC / laisvas auginimas išjungtas — žaliava tik iš nelegalių reikmenų parduotuvės

    -- Grybų rinkimas
    for _, field in ipairs(Config.MushroomFields or {}) do
        if field.center then
            addCfgBlip(field.center, field.blip, field.blip and field.blip.label or 'Grybų rinkimas')
        end
    end

    -- Kokos lapai (Cayo) — blipas tik priartėjus prie salos
    for _, field in ipairs(Config.CocaFields or {}) do
        addFieldBlip(field, 'Kokos lapai')
    end

    -- Heroino laboratorija
    local heroinLab = Config.HeroinLab
    if heroinLab and heroinLab.blip then
        addCfgBlip(heroinLab.blip.coords, heroinLab.blip, heroinLab.blip.label or 'Heroino laboratorija')
    end

    -- Žolės džiovinimas (hid_weed_lab)
    local weedCayo = Config.WeedCayoLab
    if weedCayo and weedCayo.blip and (not weedCayo.requireIsland or isCayoIslandLoaded()) then
        addCfgBlip(weedCayo.blip.coords, weedCayo.blip, weedCayo.blip.label or 'Žolės džiovinimas')
    end

    -- Metamfetamino supakavimas
    local methLab = Config.MethLab
    if methLab and methLab.blip then
        addCfgBlip(methLab.blip.coords, methLab.blip, methLab.blip.label or 'Metamfetamino laboratorija')
    end

    -- Tablečių gamyba
    local pillsLab = Config.PillsLab
    if pillsLab and pillsLab.blip then
        addCfgBlip(pillsLab.blip.coords, pillsLab.blip, pillsLab.blip.label or 'Tablečių gamyba')
    end

    -- Amfetamino laboratorija
    local ampLab = Config.AmpMobileLab
    if ampLab and ampLab.enabled ~= false and ampLab.blip then
        local bc = ampLab.blip.coords or (ampLab.lab and ampLab.lab.coords)
        addCfgBlip(bc, ampLab.blip, ampLab.blip.label or 'Amfetamino laboratorija')
    end

    -- Produktų supirkėjai
    for _, cfg in pairs(Config.ProductBuyerNPCs or {}) do
        if cfg and cfg.enabled ~= false and cfg.coords then
            addCfgBlip(
                vector3(cfg.coords.x, cfg.coords.y, cfg.coords.z),
                cfg.blip,
                cfg.label
            )
        end
    end

    -- Nelegalūs reikmenys (test) — tik kai įjungtas test NPC
    if Config.EnableDrugTestNPC then
        local testShop = Config.TestSupplyShopNPC
        if testShop and testShop.coords then
            addCfgBlip(
                vector3(testShop.coords.x, testShop.coords.y, testShop.coords.z),
                { enabled = true, sprite = 52, color = 27, scale = 0.75, label = testShop.label or 'Nelegalūs reikmenys (test)' },
                testShop.label
            )
        end
        local testNpc = Config.TestNPC
        if testNpc and testNpc.coords then
            addCfgBlip(
                vector3(testNpc.coords.x, testNpc.coords.y, testNpc.coords.z),
                { enabled = true, sprite = 496, color = 27, scale = 0.75, label = testNpc.label or 'Narkotikų gamyba (test)' },
                testNpc.label
            )
        end
    end

    if not Config.ShowStationBlips then return end
    local hub = Config.DevHub
    local def = Config.StationBlip or {}
    if hub and hub.blipCoords then
        createMapBlip({
            coords = hub.blipCoords,
            sprite = def.sprite,
            color = def.color,
            scale = def.scale,
            shortRange = def.shortRange,
            label = def.label or 'Test: narkotikai ir ginklai',
        })
    end
end

AddEventHandler('fivempro_cayoperico:client:islandState', function()
    setupStationBlips()
end)

local function setupStations()
    if GetResourceState('qb-target') ~= 'started' then return end
    for _, st in ipairs(getAllStations()) do
        local isWeapon = st.mode == 'weapon'
        local targetLabel = st.label
        if not targetLabel then
            targetLabel = isWeapon and ('Ginklų dirbtuvė: %s'):format(st.id) or ('Gamybos stotis: %s'):format(st.id)
        end
        local options = {
            {
                icon = isWeapon and 'fas fa-tools' or 'fas fa-flask',
                label = targetLabel,
                action = function()
                    openStationUi(st.id)
                end,
            },
        }
        if isWeapon then
            options[#options + 1] = {
                icon = 'fas fa-shopping-bag',
                label = 'Pirkti ginklų dalis',
                action = openWeaponPartsMenu,
            }
        end
        exports['qb-target']:AddCircleZone(('fivempro_drugs_%s'):format(st.id), st.coords, st.radius or 2.0, {
            name = ('fivempro_drugs_%s'):format(st.id),
            debugPoly = false,
            useZ = true,
        }, {
            options = options,
            distance = Config.InteractDistance or 2.0,
        })
    end
end

local WEAPON_PART_ITEMS = {
    'metal_scrap', 'gun_frame', 'gun_barrel', 'gun_spring', 'gun_trigger', 'weapon_parts', 'weapon_prototype', '3d_printer',
    'pistol_ammo', 'smg_ammo', 'rifle_ammo', 'shotgun_ammo',
}

local function resolveSharedItem(itemName)
    if not itemName then return nil end
    local key = tostring(itemName):lower()
    if QBCore.Shared.Items[key] then return QBCore.Shared.Items[key] end
    for _, info in pairs(QBCore.Shared.Items) do
        if type(info) == 'table' and info.name and string.lower(info.name) == key then
            return info
        end
    end
end

local function buyMaterialItem(itemName, amount)
    QBCore.Functions.TriggerCallback('fivempro_drugs:server:buyMaterial', function(res)
        if res and res.ok then
            QBCore.Functions.Notify(('Nupirkta: %s x%s'):format(res.label or itemName, res.amount or amount), 'success')
            return
        end
        QBCore.Functions.Notify((res and res.reason) or 'Pirkimas nepavyko.', 'error')
    end, itemName, amount)
end

local function openWeaponPartsMenu()
    local rows = {
        { header = 'Ginklų dalys ir reikmenys', isMenuHeader = true },
    }
    local shopItems = (Config.MaterialShop and Config.MaterialShop.items) or {}
    for _, itemName in ipairs(WEAPON_PART_ITEMS) do
        local row
        for _, shopRow in ipairs(shopItems) do
            if shopRow.name == itemName then
                row = shopRow
                break
            end
        end
        if row then
            local shared = resolveSharedItem(itemName)
            local label = shared and shared.label or itemName
            rows[#rows + 1] = {
                header = ('%s — $%s'):format(label, row.price),
                txt = 'Spustelėk — nusipirksi 1 vnt. tiesiai į inventorių',
                params = {
                    isAction = true,
                    event = function()
                        buyMaterialItem(itemName, 1)
                    end,
                },
            }
        end
    end
    rows[#rows + 1] = {
        header = 'Atidaryti pilną parduotuvę',
        txt = 'Visi ingredientai (inventoriaus langas)',
        params = { isAction = true, event = openMaterialShop },
    }
    rows[#rows + 1] = {
        header = 'Uždaryti',
        params = { isAction = true, event = function() TriggerEvent('qb-menu:client:closeMenu') end },
    }
    if GetResourceState('qb-menu') == 'started' then
        TriggerEvent('qb-menu:client:openMenu', rows, false, true)
    else
        openMaterialShop()
    end
end

local function openMaterialShop()
    QBCore.Functions.TriggerCallback('fivempro_drugs:server:openMaterialShop', function(res)
        if res and res.ok then
            QBCore.Functions.Notify('Pasirink prekes ir vilk į inventorių.', 'primary', 4500)
            return
        end
        QBCore.Functions.Notify((res and res.reason) or 'Parduotuvė neprieinama.', 'error')
    end)
end

local function openProductSellMenu(buyerId)
    buyerId = tostring(buyerId or '')
    local cfg = Config.ProductBuyerNPCs and Config.ProductBuyerNPCs[buyerId]
    if not cfg or cfg.enabled == false then return end
    local prices = cfg.prices or {}
    local rows = {
        { header = cfg.label or 'Supirkėjas', txt = 'Kainos už 1 vnt.', isMenuHeader = true },
    }
    local sorted = {}
    for itemName, price in pairs(prices) do
        sorted[#sorted + 1] = { item = itemName, price = tonumber(price) or 0 }
    end
    table.sort(sorted, function(a, b) return tostring(a.item) < tostring(b.item) end)
    for _, row in ipairs(sorted) do
        if row.price > 0 then
            local shared = QBCore.Shared.Items[row.item]
            local label = shared and shared.label or row.item
            rows[#rows + 1] = {
                header = ('%s — $%s / vnt.'):format(label, row.price),
                txt = row.item,
                isMenuHeader = true,
            }
        end
    end
    rows[#rows + 1] = {
        header = cfg.sellAllLabel or 'Parduoti viską',
        txt = 'Visi supirkėjo priimami produktai iš inventoriaus',
        params = {
            isAction = true,
            event = function()
                TriggerServerEvent('fivempro_drugs:server:sellProductAll', buyerId)
            end,
        },
    }
    rows[#rows + 1] = {
        header = 'Uždaryti',
        params = { isAction = true, event = function() TriggerEvent('qb-menu:client:closeMenu') end },
    }
    if GetResourceState('qb-menu') == 'started' then
        TriggerEvent('qb-menu:client:openMenu', rows, false, true)
    else
        TriggerServerEvent('fivempro_drugs:server:sellProductAll', buyerId)
    end
end

RegisterNetEvent('fivempro_drugs:client:openProductSellMenu', function(buyerId)
    openProductSellMenu(buyerId)
end)

local function openTestMenu()
    if not Config.EnableDrugTestNPC then return end
    local rows = {
        { header = 'Narkotikų gamyba', isMenuHeader = true },
        { header = 'Pirkti reikmenis (parduotuvė)', txt = 'Ingredientai ir ginklų dalys', params = { isAction = true, event = openMaterialShop } },
        { header = 'L1 sandėliukas', params = { isAction = true, event = function() openStationUi('stash_grove') end } },
        { header = 'L2 trap house', params = { isAction = true, event = function() openStationUi('trap_chamberlain') end } },
        { header = 'L3 kokaino lab.', params = { isAction = true, event = function() openStationUi('cartel_lab') end } },
        { header = 'Ginklų dirbtuvė L1', params = { isAction = true, event = function() openStationUi('weapon_bench_l1') end } },
        { header = 'Ginklų dirbtuvė L2', params = { isAction = true, event = function() openStationUi('weapon_bench_l2') end } },
        { header = 'Ginklų dirbtuvė L3', params = { isAction = true, event = function() openStationUi('weapon_bench_l3') end } },
        { header = 'Pardavimas (/drugsell)', txt = 'Stovėk prie NPC su produktu inventoriuje', isMenuHeader = true },
        { header = 'Uždaryti', params = { isAction = true, event = function() TriggerEvent('qb-menu:client:closeMenu') end } },
    }
    if GetResourceState('qb-menu') == 'started' then
        TriggerEvent('qb-menu:client:openMenu', rows, false, true)
    end
end

RegisterNetEvent('fivempro_drugs:client:testKit', function(data)
    TriggerServerEvent('fivempro_drugs:server:testGiveKit', data and data.kit or 'level1')
end)

local function spawnHubPed(cfg, onTarget)
    if not cfg then return 0 end
    local model = joaat(cfg.model or 's_m_y_dealer_01')
    RequestModel(model)
    local t = GetGameTimer() + 8000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(model) then return 0 end
    local c = cfg.coords
    local ped = CreatePed(0, model, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    if cfg.scenario then
        TaskStartScenarioInPlace(ped, cfg.scenario, 0, true)
    end
    if onTarget then onTarget(ped) end
    SetModelAsNoLongerNeeded(model)
    return ped
end

local function setNpcBlip(blip, label)
    local text = tostring(label or 'Nelegalūs reikmenys')
    if GetResourceState('fivempro_fonts') == 'started' then
        exports['fivempro_fonts']:SetBlipName(blip, text)
        return
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(text)
    EndTextCommandSetBlipName(blip)
end

local function createSupplyShopBlip()
    -- Blipai kuriami centralizuotai per setupStationBlips()
end

local function spawnSupplyShopNpc()
    local cfg = Config.SupplyShopNPC
    if not cfg or cfg.enabled == false or not cfg.coords then return end
    supplyShopPed = spawnHubPed(cfg, function(ped)
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = cfg.targetIcon or 'fas fa-store',
                    label = cfg.label or 'Nelegalūs reikmenys',
                    action = openMaterialShop,
                },
            },
            distance = (cfg.maxDistance or Config.InteractDistance or 2.5) + 1.0,
        })
    end)
    createSupplyShopBlip()
end

local function spawnTestSupplyShopNpc()
    if not Config.EnableDrugTestNPC or not Config.TestSupplyShopNPC then return end
    local cfg = Config.TestSupplyShopNPC
    spawnHubPed(cfg, function(ped)
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = 'fas fa-store',
                    label = cfg.label or 'Nelegalūs reikmenys (test)',
                    action = openMaterialShop,
                },
            },
            distance = (Config.InteractDistance or 2.5) + 1.0,
        })
    end)
end

local function createProductBuyerBlip(buyerId, cfg)
    -- Blipai kuriami centralizuotai per setupStationBlips()
end

local function spawnProductBuyerNpcs()
    for buyerId, cfg in pairs(Config.ProductBuyerNPCs or {}) do
        if cfg and cfg.enabled ~= false then
            local id = buyerId
            productBuyerPeds[id] = spawnHubPed(cfg, function(ped)
                exports['qb-target']:AddTargetEntity(ped, {
                    options = {
                        {
                            icon = cfg.targetIcon or 'fas fa-dollar-sign',
                            label = cfg.label or 'Supirkėjas',
                            action = function()
                                openProductSellMenu(id)
                            end,
                        },
                    },
                    distance = (cfg.maxDistance or Config.InteractDistance or 2.5) + 0.5,
                })
            end)
            createProductBuyerBlip(id, cfg)
        end
    end
end

local function spawnTestNpc()
    if not Config.EnableDrugTestNPC or not Config.TestNPC then return end
    testPed = spawnHubPed(Config.TestNPC, function(ped)
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = 'fas fa-vial',
                    label = Config.TestNPC.label or 'Narkotikų gamyba',
                    action = openTestMenu,
                },
                {
                    icon = 'fas fa-shopping-bag',
                    label = 'Pirkti reikmenis',
                    action = openMaterialShop,
                },
            },
            distance = (Config.InteractDistance or 2.5) + 1.0,
        })
    end)
end

--- Violetiniai žymekliai ant žemės — matosi eilė (tik test režime)
CreateThread(function()
    if not Config.EnableDrugTestNPC then return end
    while true do
        local sleep = 800
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local hub = Config.DevHub and (Config.DevHub.center or Config.DevHub.blipCoords)
        if hub and #(pos - hub) < 55.0 then
            sleep = 0
            for _, st in ipairs(Config.Stations or {}) do
                if st.coords then
                    DrawMarker(27, st.coords.x, st.coords.y, st.coords.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        1.15, 1.15, 0.25, 120, 80, 220, 140, false, false, 2, false, nil, nil, false)
                end
            end
            for _, key in ipairs({ 'TestNPC', 'TestSupplyShopNPC' }) do
                local npc = Config[key]
                if npc and npc.coords then
                    DrawMarker(2, npc.coords.x, npc.coords.y, npc.coords.z + 1.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.35, 0.35, 0.35, 251, 191, 36, 180, false, false, 2, false, nil, nil, false)
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(250)
    end
    Wait(500)
    setupStationBlips()
    setupStations()
    spawnTestNpc()
    spawnSupplyShopNpc()
    spawnTestSupplyShopNpc()
    spawnProductBuyerNpcs()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopCraftAnim()
    closeUi()
    for _, bl in ipairs(mapBlips) do
        if bl and DoesBlipExist(bl) then RemoveBlip(bl) end
    end
    mapBlips = {}
    if testPed ~= 0 and DoesEntityExist(testPed) then
        DeleteEntity(testPed)
    end
    if supplyShopPed ~= 0 and DoesEntityExist(supplyShopPed) then
        DeleteEntity(supplyShopPed)
    end
    if supplyShopBlip and DoesBlipExist(supplyShopBlip) then
        RemoveBlip(supplyShopBlip)
        supplyShopBlip = nil
    end
    for _, ped in pairs(productBuyerPeds) do
        if ped ~= 0 and DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    productBuyerPeds = {}
    productBuyerBlips = {}
end)
