-- Variables

local alcoholCount = 0
local healing, parachuteEquipped = false, false
local currVest, currVestTexture = nil, nil
local currVestComponent = 9
local lastEquippedVestItem = nil
local consumableProgressToken = 0

local CONSUMABLE_DISABLE = {
    disableMovement = false,
    disableCarMovement = false,
    disableMouse = false,
    disableCombat = true,
}

local function applyConsumableDisables(disableControls)
    disableControls = disableControls or CONSUMABLE_DISABLE
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

local function loadAnimDict(dict)
    if not dict or dict == '' or HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function attachConsumableProp(prop)
    if not prop or not prop.model then return nil end
    local ped = PlayerPedId()
    local model = type(prop.model) == 'number' and prop.model or joaat(prop.model)
    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do
        Wait(10)
    end
    if not HasModelLoaded(model) then return nil end
    local coords = GetEntityCoords(ped)
    local obj = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    local bone = prop.bone or 60309
    local offset = prop.coords or vec3(0.0, 0.0, 0.0)
    local rotation = prop.rotation or vec3(0.0, 0.0, 0.0)
    AttachEntityToEntity(
        obj, ped, GetPedBoneIndex(ped, bone),
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(model)
    return obj
end

local function clearConsumableProp(propObj)
    if propObj and DoesEntityExist(propObj) then
        DeleteEntity(propObj)
    end
end

local function runConsumableProgress(opts)
    opts = opts or {}
    consumableProgressToken = consumableProgressToken + 1
    local token = consumableProgressToken
    local duration = tonumber(opts.duration) or 5000
    local label = opts.label or 'Vykdoma…'
    local animation = opts.animation or {}
    local prop = opts.prop
    local disableControls = opts.disableControls or CONSUMABLE_DISABLE
    local canCancel = opts.canCancel ~= false
    local animDict = animation.animDict or animation.dict
    local animClip = animation.anim or animation.clip
    local animFlags = animation.flags or 49

    CreateThread(function()
        Wait(350)
        if token ~= consumableProgressToken then return end

        local ped = PlayerPedId()
        if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
            if opts.onCancel then opts.onCancel() end
            return
        end

        if animDict then loadAnimDict(animDict) end
        local propObj = attachConsumableProp(prop)
        if animDict and animClip and HasAnimDictLoaded(animDict) then
            TaskPlayAnim(ped, animDict, animClip, 4.0, 4.0, -1, animFlags, 0.0, false, false, false)
        end

        QBCore.Functions.Notify(label, 'primary', duration)

        local endAt = GetGameTimer() + duration
        local cancelAfter = GetGameTimer() + 800

        while GetGameTimer() < endAt do
            if token ~= consumableProgressToken then
                clearConsumableProp(propObj)
                ClearPedTasks(ped)
                return
            end

            ped = PlayerPedId()
            applyConsumableDisables(disableControls)

            if animDict and animClip and HasAnimDictLoaded(animDict) and not IsEntityPlayingAnim(ped, animDict, animClip, 3) then
                TaskPlayAnim(ped, animDict, animClip, 4.0, 4.0, -1, animFlags, 0.0, false, false, false)
            end

            if canCancel and GetGameTimer() > cancelAfter then
                if IsControlJustReleased(0, 73) or IsControlJustReleased(0, 200) or IsControlJustReleased(0, 322) then
                    clearConsumableProp(propObj)
                    ClearPedTasks(ped)
                    if opts.onCancel then opts.onCancel() end
                    return
                end
            end

            Wait(0)
        end

        if token ~= consumableProgressToken then
            clearConsumableProp(propObj)
            ClearPedTasks(ped)
            return
        end

        clearConsumableProp(propObj)
        ClearPedTasks(ped)
        if opts.onFinish then opts.onFinish() end
    end)
end

local function equipParachuteAnim()
    loadAnimDict('clothingshirt')
    TaskPlayAnim(PlayerPedId(), 'clothingshirt', 'try_shirt_positive_d', 8.0, 1.0, -1, 49, 0, false, false, false)
end

local function healOxy()
    if healing then return end

    healing = true

    local count = 9
    while count > 0 do
        Wait(1000)
        count -= 1
        SetEntityHealth(PlayerPedId(), GetEntityHealth(PlayerPedId()) + 6)
    end
    healing = false
end

local function trevorEffect()
    StartScreenEffect('DrugsTrevorClownsFightIn', 3.0, 0)
    Wait(3000)
    StartScreenEffect('DrugsTrevorClownsFight', 3.0, 0)
    Wait(3000)
    StartScreenEffect('DrugsTrevorClownsFightOut', 3.0, 0)
    StopScreenEffect('DrugsTrevorClownsFight')
    StopScreenEffect('DrugsTrevorClownsFightIn')
    StopScreenEffect('DrugsTrevorClownsFightOut')
end

local function methBagEffect()
    local startStamina = 8
    trevorEffect()
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.49)
    while startStamina > 0 do
        Wait(1000)
        if math.random(5, 100) < 10 then
            RestorePlayerStamina(PlayerId(), 1.0)
        end
        startStamina = startStamina - 1
        if math.random(5, 100) < 51 then
            trevorEffect()
        end
    end
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
end

local function ecstasyEffect()
    local startStamina = 30
    SetFlash(0, 0, 500, 7000, 500)
    while startStamina > 0 do
        Wait(1000)
        startStamina -= 1
        RestorePlayerStamina(PlayerId(), 1.0)
        if math.random(1, 100) < 51 then
            SetFlash(0, 0, 500, 7000, 500)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.08)
        end
    end
    if IsPedRunning(PlayerPedId()) then
        SetPedToRagdoll(PlayerPedId(), math.random(1000, 3000), math.random(1000, 3000), 3, false, false, false)
    end
end

local function alienEffect()
    StartScreenEffect('DrugsMichaelAliensFightIn', 3.0, 0)
    Wait(math.random(5000, 8000))
    StartScreenEffect('DrugsMichaelAliensFight', 3.0, 0)
    Wait(math.random(5000, 8000))
    StartScreenEffect('DrugsMichaelAliensFightOut', 3.0, 0)
    StopScreenEffect('DrugsMichaelAliensFightIn')
    StopScreenEffect('DrugsMichaelAliensFight')
    StopScreenEffect('DrugsMichaelAliensFightOut')
end

local function crackBaggyEffect()
    local startStamina = 8
    local ped = PlayerPedId()
    alienEffect()
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.3)
    while startStamina > 0 do
        Wait(1000)
        if math.random(1, 100) < 10 then
            RestorePlayerStamina(PlayerId(), 1.0)
        end
        startStamina -= 1
        if math.random(1, 100) < 60 and IsPedRunning(ped) then
            SetPedToRagdoll(ped, math.random(1000, 2000), math.random(1000, 2000), 3, false, false, false)
        end
        if math.random(1, 100) < 51 then
            alienEffect()
        end
    end
    if IsPedRunning(ped) then
        SetPedToRagdoll(ped, math.random(1000, 3000), math.random(1000, 3000), 3, false, false, false)
    end
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
end

local function cokeBaggyEffect()
    local startStamina = 20
    local ped = PlayerPedId()
    alienEffect()
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.1)
    while startStamina > 0 do
        Wait(1000)
        if math.random(1, 100) < 20 then
            RestorePlayerStamina(PlayerId(), 1.0)
        end
        startStamina -= 1
        if math.random(1, 100) < 10 and IsPedRunning(ped) then
            SetPedToRagdoll(ped, math.random(1000, 3000), math.random(1000, 3000), 3, false, false, false)
        end
        if math.random(1, 300) < 10 then
            alienEffect()
            Wait(math.random(3000, 6000))
        end
    end
    if IsPedRunning(ped) then
        SetPedToRagdoll(ped, math.random(1000, 3000), math.random(1000, 3000), 3, false, false, false)
    end
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
end

-- Events

RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

RegisterNetEvent('consumables:client:Eat', function(itemName, slot)
    runConsumableProgress({
        label = Lang:t('consumables.eat_progress'),
        duration = 5000,
        animation = {
            animDict = 'mp_player_inteat@burger',
            anim = 'mp_player_int_eat_burger',
            flags = 49,
        },
        prop = {
            model = 'prop_cs_burger_01',
            bone = 60309,
            coords = vec3(0.0, 0.0, -0.02),
            rotation = vec3(30.0, 0.0, 0.0),
        },
        onFinish = function()
            TriggerServerEvent('consumables:server:finishEat', itemName, slot)
            TriggerServerEvent('hud:server:RelieveStress', math.random(2, 4))
        end,
        onCancel = function()
            QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
        end,
    })
end)

RegisterNetEvent('consumables:client:Drink', function(itemName, slot)
    runConsumableProgress({
        label = Lang:t('consumables.drink_progress'),
        duration = 5000,
        animation = {
            animDict = 'mp_player_intdrink',
            anim = 'loop_bottle',
            flags = 49,
        },
        prop = {
            model = 'vw_prop_casino_water_bottle_01a',
            bone = 60309,
            coords = vec3(0.0, 0.0, -0.05),
            rotation = vec3(0.0, 0.0, -40.0),
        },
        onFinish = function()
            TriggerServerEvent('consumables:server:finishDrink', itemName, slot)
        end,
        onCancel = function()
            QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
        end,
    })
end)

RegisterNetEvent('consumables:client:DrinkAlcohol', function(itemName, slot)
    runConsumableProgress({
        label = Lang:t('consumables.liqour_progress'),
        duration = math.random(3000, 6000),
        animation = {
            animDict = 'mp_player_intdrink',
            anim = 'loop_bottle',
            flags = 49,
        },
        prop = {
            model = 'prop_cs_beer_bot_40oz',
            bone = 60309,
            coords = vec3(0.0, 0.0, -0.05),
            rotation = vec3(0.0, 0.0, -40.0),
        },
        onFinish = function()
            TriggerServerEvent('consumables:server:finishDrinkAlcohol', itemName, slot)
            TriggerServerEvent('hud:server:RelieveStress', math.random(2, 4))
            alcoholCount += 1
            AlcoholLoop()
            if alcoholCount > 1 and alcoholCount < 4 then
                TriggerEvent('evidence:client:SetStatus', 'alcohol', 200)
            elseif alcoholCount >= 4 then
                TriggerEvent('evidence:client:SetStatus', 'heavyalcohol', 200)
            end
        end,
        onCancel = function()
            QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
        end,
    })
end)

RegisterNetEvent('consumables:client:Custom', function(itemName)
    QBCore.Functions.TriggerCallback('consumables:itemdata', function(data)
        QBCore.Functions.Progressbar('custom_consumable', data.progress.label, data.progress.time, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true
        }, {
            animDict = data.animation.animDict,
            anim = data.animation.anim,
            flags = data.animation.flags
        }, {
            model = data.prop.model,
            bone = data.prop.bone,
            coords = data.prop.coords,
            rotation = data.prop.rotation
        }, {}, function() -- Done
            ClearPedTasks(PlayerPedId())
            TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items[itemName], 'remove')
            if data.replenish.type then
                TriggerServerEvent('consumables:server:add' .. data.replenish.type, QBCore.Functions.GetPlayerData().metadata[string.lower(data.replenish.type)] + data.replenish.replenish)
            end
            if data.replenish.isAlcohol then
                alcoholCount += 1
                AlcoholLoop()
                if alcoholCount > 1 and alcoholCount < 4 then
                    TriggerEvent('evidence:client:SetStatus', 'alcohol', 200)
                elseif alcoholCount >= 4 then
                    TriggerEvent('evidence:client:SetStatus', 'heavyalcohol', 200)
                end
            end
            if data.replenish.event then
                TriggerEvent(data.replenish.event)
            end
        end)
    end, itemName)
end)

RegisterNetEvent('consumables:client:Cokebaggy', function()
    local ped = PlayerPedId()
    QBCore.Functions.Progressbar('snort_coke', Lang:t('consumables.coke_progress'), math.random(5000, 8000), false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'switch@trevor@trev_smoking_meth',
        anim = 'trev_smoking_meth_loop',
        flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(ped, 'switch@trevor@trev_smoking_meth', 'trev_smoking_meth_loop', 1.0)
        TriggerServerEvent('consumables:server:useCokeBaggy')
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['cokebaggy'], 'remove')
        TriggerEvent('evidence:client:SetStatus', 'widepupils', 200)
        cokeBaggyEffect()
    end, function() -- Cancel
        StopAnimTask(ped, 'switch@trevor@trev_smoking_meth', 'trev_smoking_meth_loop', 1.0)
        QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
    end)
end)

RegisterNetEvent('consumables:client:Crackbaggy', function()
    local ped = PlayerPedId()
    QBCore.Functions.Progressbar('snort_coke', Lang:t('consumables.crack_progress'), math.random(7000, 10000), false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'switch@trevor@trev_smoking_meth',
        anim = 'trev_smoking_meth_loop',
        flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(ped, 'switch@trevor@trev_smoking_meth', 'trev_smoking_meth_loop', 1.0)
        TriggerServerEvent('consumables:server:useCrackBaggy')
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['crack_baggy'], 'remove')
        TriggerEvent('evidence:client:SetStatus', 'widepupils', 300)
        crackBaggyEffect()
    end, function() -- Cancel
        StopAnimTask(ped, 'switch@trevor@trev_smoking_meth', 'trev_smoking_meth_loop', 1.0)
        QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
    end)
end)

RegisterNetEvent('consumables:client:EcstasyBaggy', function()
    QBCore.Functions.Progressbar('use_ecstasy', Lang:t('consumables.ecstasy_progress'), 3000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'mp_suicide',
        anim = 'pill',
        flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(PlayerPedId(), 'mp_suicide', 'pill', 1.0)
        TriggerServerEvent('consumables:server:useXTCBaggy')
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['xtcbaggy'], 'remove')
        ecstasyEffect()
    end, function() -- Cancel
        StopAnimTask(PlayerPedId(), 'mp_suicide', 'pill', 1.0)
        QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
    end)
end)

RegisterNetEvent('consumables:client:oxy', function()
    QBCore.Functions.Progressbar('use_oxy', Lang:t('consumables.healing_progress'), 2000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'mp_suicide',
        anim = 'pill',
        flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(PlayerPedId(), 'mp_suicide', 'pill', 1.0)
        TriggerServerEvent('consumables:server:useOxy')
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['oxy'], 'remove')
        ClearPedBloodDamage(PlayerPedId())
        healOxy()
    end, function() -- Cancel
        StopAnimTask(PlayerPedId(), 'mp_suicide', 'pill', 1.0)
        QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
    end)
end)

RegisterNetEvent('consumables:client:meth', function()
    QBCore.Functions.Progressbar('snort_meth', Lang:t('consumables.meth_progress'), 1500, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'switch@trevor@trev_smoking_meth',
        anim = 'trev_smoking_meth_loop',
        flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(PlayerPedId(), 'switch@trevor@trev_smoking_meth', 'trev_smoking_meth_loop', 1.0)
        TriggerServerEvent('consumables:server:useMeth')
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['meth'], 'remove')
        TriggerEvent('evidence:client:SetStatus', 'widepupils', 300)
        TriggerEvent('evidence:client:SetStatus', 'agitated', 300)
        methBagEffect()
    end, function() -- Cancel
        StopAnimTask(PlayerPedId(), 'switch@trevor@trev_smoking_meth', 'trev_smoking_meth_loop', 1.0)
        QBCore.Functions.Notify(Lang:t('consumables.canceled'), 'error')
    end)
end)

RegisterNetEvent('consumables:client:UseJoint', function()
    QBCore.Functions.Progressbar('smoke_joint', Lang:t('consumables.joint_progress'), 1500, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['joint'], 'remove')
        if IsPedInAnyVehicle(PlayerPedId(), false) then
            QBCore.Functions.PlayAnim('timetable@gardener@smoking_joint', 'smoke_idle', false)
        else
            QBCore.Functions.PlayAnim('timetable@gardener@smoking_joint', 'smoke_idle', false)
        end
        TriggerEvent('evidence:client:SetStatus', 'weedsmell', 300)
        TriggerServerEvent('hud:server:RelieveStress', Config.RelieveWeedStress)
    end)
end)

RegisterNetEvent('consumables:client:UseParachute', function()
    equipParachuteAnim()
    QBCore.Functions.Progressbar('use_parachute', Lang:t('consumables.use_parachute_progress'), 5000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        local ped = PlayerPedId()
        TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['parachute'], 'remove')
        GiveWeaponToPed(ped, `GADGET_PARACHUTE`, 1, false, false)
        local parachuteData = {
            outfitData = { ['bag'] = { item = 7, texture = 0 } } -- Adding Parachute Clothing
        }
        TriggerEvent('qb-clothing:client:loadOutfit', parachuteData)
        parachuteEquipped = true
        TaskPlayAnim(ped, 'clothingshirt', 'exit', 8.0, 1.0, -1, 49, 0, false, false, false)
    end)
end)

RegisterNetEvent('consumables:client:ResetParachute', function()
    if parachuteEquipped then
        equipParachuteAnim()
        QBCore.Functions.Progressbar('reset_parachute', Lang:t('consumables.pack_parachute_progress'), 40000, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function() -- Done
            local ped = PlayerPedId()
            TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items['parachute'], 'add')
            local parachuteResetData = {
                outfitData = { ['bag'] = { item = 0, texture = 0 } } -- Removing Parachute Clothing
            }
            TriggerEvent('qb-clothing:client:loadOutfit', parachuteResetData)
            TaskPlayAnim(ped, 'clothingshirt', 'exit', 8.0, 1.0, -1, 49, 0, false, false, false)
            TriggerServerEvent('consumables:server:AddParachute')
            parachuteEquipped = false
        end)
    else
        QBCore.Functions.Notify(Lang:t('consumables.no_parachute'), 'error')
    end
end)

local function applyVestDrawable(ped, PlayerData, vestCfg)
    if not vestCfg or not vestCfg.vest or Config.Disable.vestDrawable then return end
    local gender = PlayerData.charinfo and PlayerData.charinfo.gender or 0
    local v = (gender == 0 and vestCfg.vest.male) or vestCfg.vest.female
    if not v then return end
    currVestComponent = v.component or 9
    currVest = GetPedDrawableVariation(ped, currVestComponent)
    currVestTexture = GetPedTextureVariation(ped, currVestComponent)
    SetPedComponentVariation(ped, currVestComponent, v.drawable, v.texture, v.palette or 2)
end

RegisterNetEvent('consumables:client:UseArmorVest', function(itemName)
    local vestCfg = Config.ArmorVests and Config.ArmorVests[itemName]
    if not vestCfg then return end

    local ped = PlayerPedId()
    local currentArmor = GetPedArmour(ped)
    if currentArmor >= vestCfg.armor then
        QBCore.Functions.Notify(('Jau turi %s ar aukštesnę apsaugą.'):format(vestCfg.armor), 'error')
        return
    end

    local PlayerData = QBCore.Functions.GetPlayerData()
    if vestCfg.job and (not PlayerData.job or PlayerData.job.name ~= vestCfg.job) then
        QBCore.Functions.Notify('Ši liemenė skirta tik tarnautojams.', 'error')
        return
    end

    QBCore.Functions.Progressbar(('use_armor_%s'):format(itemName), vestCfg.progress or 'Užsidedama liemenė...', vestCfg.duration or 5000, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        applyVestDrawable(ped, PlayerData, vestCfg)
        lastEquippedVestItem = itemName
        TriggerServerEvent('consumables:server:useArmorVest', itemName)
    end)
end)

RegisterNetEvent('consumables:client:UseArmor', function()
    TriggerEvent('consumables:client:UseArmorVest', 'armor')
end)

RegisterNetEvent('consumables:client:UseHeavyArmor', function()
    TriggerEvent('consumables:client:UseArmorVest', 'heavyarmor')
end)

RegisterNetEvent('consumables:client:ResetArmor', function()
    local ped = PlayerPedId()
    if currVest ~= nil and currVestTexture ~= nil then
        QBCore.Functions.Progressbar('remove_armor', Lang:t('consumables.remove_armor_progress'), 2500, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function() -- Done
            SetPedComponentVariation(ped, currVestComponent or 9, currVest, currVestTexture, 2)
            SetPedArmour(ped, 0)
            local returnItem = lastEquippedVestItem or 'heavyarmor'
            if QBCore.Shared.Items[returnItem] then
                TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items[returnItem], 'add')
            end
            TriggerServerEvent('consumables:server:resetArmor', returnItem)
            lastEquippedVestItem = nil
            currVest, currVestTexture = nil, nil
        end)
    else
        QBCore.Functions.Notify(Lang:t('consumables.armor_empty'), 'error')
    end
end)

-- RegisterNetEvent('consumables:client:UseRedSmoke', function()
--     if parachuteEquipped then
--         local ped = PlayerPedId()
--         SetPlayerParachuteSmokeTrailColor(ped, 255, 0, 0)
--         SetPlayerCanLeaveParachuteSmokeTrail(ped, true)
--         TriggerEvent("qb-inventory:client:ItemBox", QBCore.Shared.Items["smoketrailred"], "remove")
--     else
--         QBCore.Functions.Notify("You need to have a paracute to activate smoke!", "error")
--     end
-- end)

--Threads
local looped = false
function AlcoholLoop()
    if not looped then
        looped = true
        CreateThread(function()
            while true do
                Wait(10)
                if alcoholCount > 0 then
                    Wait(1000 * 60 * 15)
                    alcoholCount -= 1
                else
                    looped = false
                    break
                end
            end
        end)
    end
end
