local QBCore = exports['qb-core']:GetCoreObject()
local coordsHudEnabled = false
local slungProps = {}

local LongWeaponModels = {
    weapon_pistol = 'w_pi_pistol',
    weapon_pistol_mk2 = 'w_pi_pistolmk2',
    weapon_combatpistol = 'w_pi_combatpistol',
    weapon_appistol = 'w_pi_appistol',
    weapon_pistol50 = 'w_pi_pistol50',
    weapon_heavypistol = 'w_pi_heavypistol',
    weapon_snspistol = 'w_pi_sns_pistol',
    weapon_vintagepistol = 'w_pi_vintage_pistol',
    weapon_assaultrifle = 'w_ar_assaultrifle',
    weapon_assaultrifle_mk2 = 'w_ar_assaultrifle',
    weapon_carbinerifle = 'w_ar_carbinerifle',
    weapon_carbinerifle_mk2 = 'w_ar_carbinerifle',
    weapon_advancedrifle = 'w_ar_advancedrifle',
    weapon_specialcarbine = 'w_ar_specialcarbine',
    weapon_specialcarbine_mk2 = 'w_ar_specialcarbine',
    weapon_bullpuprifle = 'w_ar_bullpuprifle',
    weapon_bullpuprifle_mk2 = 'w_ar_bullpuprifle',
    weapon_compactrifle = 'w_ar_assaultrifle_smg',
    weapon_militaryrifle = 'w_ar_bullpuprifle',
    weapon_heavyrifle = 'w_ar_specialcarbine',
    weapon_mg = 'w_mg_mg',
    weapon_combatmg = 'w_mg_combatmg',
    weapon_combatmg_mk2 = 'w_mg_combatmg',
    weapon_gusenberg = 'w_sb_gusenberg',
    weapon_pumpshotgun = 'w_sg_pumpshotgun',
    weapon_pumpshotgun_mk2 = 'w_sg_pumpshotgun',
    weapon_sawnoffshotgun = 'w_sg_sawnoff',
    weapon_assaultshotgun = 'w_sg_assaultshotgun',
    weapon_bullpupshotgun = 'w_sg_bullpupshotgun',
    weapon_heavyshotgun = 'w_sg_heavyshotgun',
    weapon_combatshotgun = 'w_sg_pumpshotgun',
    weapon_sniperrifle = 'w_sr_sniperrifle',
    weapon_heavysniper = 'w_sr_heavysniper',
    weapon_heavysniper_mk2 = 'w_sr_heavysniper',
    weapon_marksmanrifle = 'w_sr_marksmanrifle',
    weapon_marksmanrifle_mk2 = 'w_sr_marksmanrifle',

    -- SMG (stambūs ne rankoj – rodomi tik be kuprinės, kaip karabinai)
    weapon_microsmg = 'w_sb_microsmg',
    weapon_smg = 'w_sb_smg',
    weapon_smg_mk2 = 'w_sb_smgmk2',
    weapon_assaultsmg = 'w_sb_assaultsmg',
    weapon_combatpdw = 'w_sb_pdw',
    weapon_machinepistol = 'w_sb_compactsmg',
    weapon_minismg = 'w_sb_minismg',
    weapon_raycarbine = 'w_ar_srifle',
    weapon_tecpistol = 'w_pi_pistolsmg_m31',
}

local function hasBackpackOnPed(ped)
    -- Component 5 is bags/parachutes for freemode peds.
    local drawable = GetPedDrawableVariation(ped, 5)
    return drawable and drawable > 0
end

local function clearSlungProps()
    for _, ent in pairs(slungProps) do
        if ent and DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
    slungProps = {}
end

local function attachWeaponModelToBack(slotIndex, modelName)
    local ped = PlayerPedId()
    local model = joaat(modelName)
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not HasModelLoaded(model) then return end
    local obj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    SetEntityCollision(obj, false, false)
    local bone = GetPedBoneIndex(ped, 24816)
    if slotIndex == 1 then
        AttachEntityToEntity(obj, ped, bone, -0.17, -0.15, 0.02, 0.0, 150.0, 0.0, true, true, false, true, 2, true)
    elseif slotIndex == 2 then
        AttachEntityToEntity(obj, ped, bone, 0.17, -0.15, 0.02, 0.0, 150.0, 0.0, true, true, false, true, 2, true)
    else
        local hipBone = GetPedBoneIndex(ped, 11816)
        AttachEntityToEntity(obj, ped, hipBone, 0.10, 0.02, 0.0, 75.0, 20.0, 170.0, true, true, false, true, 2, true)
    end
    slungProps[slotIndex] = obj
end

local function refreshSlungWeapons()
    clearSlungProps()
    local ped = PlayerPedId()
    -- Kuprinė „paslepia“ ilgus ginklus – jie lieka inventoriuje ir naudojami, tik nebededami ant nugaros.
    if hasBackpackOnPed(ped) then
        return
    end

    local pData = QBCore.Functions.GetPlayerData()
    local items = pData and pData.items or {}
    if not items then return end

    local currentWeaponHash = GetSelectedPedWeapon(ped)
    local currentWeaponData = QBCore.Shared.Weapons[currentWeaponHash]
    local equippedName = currentWeaponData and currentWeaponData.name or nil

    local carryModels = {}
    for _, item in pairs(items) do
        if item and item.type == 'weapon' and item.name ~= equippedName then
            local mdl = LongWeaponModels[item.name]
            if mdl then
                carryModels[#carryModels + 1] = mdl
            end
        end
        if #carryModels >= 3 then break end
    end

    for idx, mdl in ipairs(carryModels) do
        attachWeaponModelToBack(idx, mdl)
    end
end

CreateThread(function()
    Wait(1500)
    print("[fivempro_basics] Client script aktyvus.")
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            LocalPlayer.state:set('hasBackpack', hasBackpackOnPed(ped), true)
        end
        Wait(2000)
    end
end)

CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            refreshSlungWeapons()
            Wait(1200)
        else
            clearSlungProps()
            Wait(2000)
        end
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(1000)
    refreshSlungWeapons()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function()
    Wait(250)
    refreshSlungWeapons()
end)

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    clearSlungProps()
end)

-- Disable GTA default weapon wheel (TAB) so inventory/hotbar flow is consistent.
CreateThread(function()
    while true do
        DisableControlAction(0, 37, true) -- INPUT_SELECT_WEAPON (TAB)
        -- Pause/menu klavišai visose grupėse (kai kurie scriptai naudoja grupę 1/2).
        for cg = 0, 2 do
            EnableControlAction(cg, 199, true) -- P
            EnableControlAction(cg, 200, true) -- ESC
            EnableControlAction(cg, 202, true) -- FRONTEND_CANCEL (dalis UI)
        end
        Wait(0)
    end
end)

-- TAB shows qb-inventory hotbar (slots 1-5) while held.
CreateThread(function()
    local tabHotbarShown = false
    while true do
        if IsControlJustPressed(0, 37) then
            ExecuteCommand('hotbar')
            tabHotbarShown = true
        elseif tabHotbarShown and IsControlJustReleased(0, 37) then
            ExecuteCommand('hotbar')
            tabHotbarShown = false
        end
        Wait(0)
    end
end)

local function fivemproForceCloseAllUi()
    TriggerEvent('fivempro_dealership:client:forceCloseUi')
    TriggerEvent('fivempro_garages:client:forceCloseUi')
    TriggerEvent('fivempro_kma:client:forceCloseUi')
    TriggerEvent('fivempro_ltpd:client:forceCloseMdt')
    TriggerEvent('qb-menu:client:closeMenu')
    if GetResourceState('qb-menu') == 'started' then
        pcall(function()
            exports['qb-menu']:closeMenu()
        end)
    end
    TriggerEvent('qb-inventory:client:closeInv')
    pcall(function()
        if GetResourceState('ox_lib') == 'started' and exports.ox_lib and exports.ox_lib.hideContext then
            exports.ox_lib:hideContext()
        end
    end)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:DisableTarget(false)
    end
end

RegisterNetEvent('fivempro_basics:client:globalEscClose', fivemproForceCloseAllUi)

local blockedWeaponVehicles = {
    rhino = true,
    khanjali = true,
    insurgent = true,
    insurgent2 = true,
    insurgent3 = true,
    apc = true,
    scarab = true,
    scarab2 = true,
    scarab3 = true,
    halftrack = true,
    technical = true,
    technical2 = true,
    technical3 = true,
    nightshark = true,
    barrage = true,
    menacer = true,
    oppressor = true,
    oppressor2 = true,
    deluxo = true,
    ruiner2 = true,
    ruiner3 = true,
    lazer = true,
    hydra = true,
    savage = true,
    hunter = true,
    akula = true,
    valkyrie = true,
    valkyrie2 = true,
    annihilator = true,
    annihilator2 = true,
    strikeforce = true,
    rogue = true,
    molotok = true,
    pyro = true,
    starling = true,
    volatol = true,
    bombushka = true,
    nokota = true,
    buzzard = true,
    buzzard2 = true,
}

local function isVehicleWeaponBlocked(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local model = GetEntityModel(veh)
    local name = string.lower(GetDisplayNameFromVehicleModel(model) or '')
    if blockedWeaponVehicles[name] then
        return true
    end
    local class = GetVehicleClass(veh)
    if class == 19 then -- military
        return true
    end
    local patterns = { 'weapon', 'armed', 'turret', 'cannon', 'rocket', 'missile', 'gun' }
    for _, p in ipairs(patterns) do
        if name:find(p, 1, true) then
            return true
        end
    end
    return false
end

-- GTA `SetPlayerHealthRechargeMultiplier`: jei > 0, žaidėjas palaipsniui atsigauna (dažnai matoma kaip „gydymas“ po ~50 % HUD).
-- Anksčiau išjungdavom tik kai entity HP <= 50 % max — tada dar vis HP > 100 (pvz. 150 = 50 HUD) vis tiek leisdavo regen. Išjungiam visada (RP).
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
        end
        Wait(400)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh and veh ~= 0 then
                if isVehicleWeaponBlocked(veh) then
                    DisablePlayerFiring(PlayerId(), true)
                    DisableControlAction(0, 24, true)
                    DisableControlAction(0, 25, true)
                    DisableControlAction(0, 68, true)
                    DisableControlAction(0, 69, true)
                    DisableControlAction(0, 70, true)
                    DisableControlAction(0, 91, true)
                    DisableControlAction(0, 92, true)
                    DisableControlAction(0, 114, true)
                    DisableControlAction(0, 257, true)
                    DisableControlAction(0, 263, true)
                    DisableControlAction(0, 264, true)
                    DisableControlAction(0, 330, true)
                    DisableControlAction(0, 331, true)
                end
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

-- Nenaudojam globalių ESC/P keymappingų, nes jie gali konfliktuoti su native Pause/Map.
-- Uždarom UI tik per valdiklių aptikimą žemiau (kai NUI tikrai aktyvus).

-- Global fail-safe: ESC/P — valdikliai (kai pasiekiami) + atsarginis kelias.
CreateThread(function()
    while true do
        local pressed = false
        for cg = 0, 2 do
            if IsControlJustPressed(cg, 199) or IsDisabledControlJustPressed(cg, 199)
                or IsControlJustPressed(cg, 200) or IsDisabledControlJustPressed(cg, 200)
                or IsControlJustPressed(cg, 202) or IsDisabledControlJustPressed(cg, 202) then
                pressed = true
                break
            end
        end
        if pressed and type(IsNuiFocused) == 'function' and IsNuiFocused() then
            fivemproForceCloseAllUi()
        end
        Wait(0)
    end
end)

local function reviveLocalPlayer()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z + 0.5, heading, true, false)
    SetPlayerInvincible(PlayerId(), false)
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, 200)
    SetPedArmour(ped, 0)

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('Atsigavai (test revive).')
    EndTextCommandThefeedPostTicker(false, false)
    print('[fivempro_basics] Test revive ivykdytas.')
end

local function healLocalPlayer()
    local ped = PlayerPedId()
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
end

RegisterCommand('fprevive', function()
    reviveLocalPlayer()
end, false)

RegisterKeyMapping('fprevive', 'Fivempro test revive', 'keyboard', 'F6')

RegisterNetEvent('fivempro_basics:client:adminRevive', function()
    reviveLocalPlayer()
end)

RegisterNetEvent('fivempro_basics:client:adminHeal', function()
    healLocalPlayer()
end)

RegisterNetEvent('fivempro_basics:client:openRegister', function()
    if GetResourceState('fivempro_charcreator') ~= 'started' then
        QBCore.Functions.Notify('fivempro_charcreator nėra paleistas.', 'error')
        return
    end
    TriggerEvent('fivempro_charcreator:client:openWizard', true)
end)

RegisterNetEvent('fivempro_basics:client:toggleCoords', function()
    coordsHudEnabled = not coordsHudEnabled
    if coordsHudEnabled then
        QBCore.Functions.Notify('/coords ijungta', 'success')
    else
        QBCore.Functions.Notify('/coords isjungta', 'error')
    end
end)

CreateThread(function()
    while true do
        if coordsHudEnabled then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local text = ('COORDS  X: %.2f  Y: %.2f  Z: %.2f  H: %.2f'):format(coords.x, coords.y, coords.z, heading)

            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.38, 0.38)
            SetTextColour(255, 255, 255, 220)
            SetTextCentre(true)
            SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(text)
            EndTextCommandDisplayText(0.5, 0.02)

            Wait(0)
        else
            Wait(250)
        end
    end
end)

