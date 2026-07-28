local cooldownUntil = 0

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function isPoliceOnDuty()
    local pd = QBCore.Functions.GetPlayerData()
    local job = pd and pd.job
    return job and job.name == 'police' and job.onduty == true
end

--- Officer charge / takedown (pervertimas)
local function tackleAnim()
    local ped = PlayerPedId()
    local dict = 'melee@unarmed@streamed_variations'
    local anim = 'plyr_takedown_front_slap'
    if not loadAnimDict(dict) then return end
    ClearPedTasksImmediately(ped)
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, 900, 0, 0.0, false, false, false)
    Wait(700)
    if not IsPedRagdoll(ped) then
        ClearPedSecondaryTask(ped)
    end
end

--- Victim: knock-down reaction, then ragdoll
local function getTackledAnim()
    local ped = PlayerPedId()
    local dict = 'melee@unarmed@streamed_variations'
    local anim = 'victim_takedown_front_slap'
    if loadAnimDict(dict) then
        ClearPedTasksImmediately(ped)
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, 1200, 0, 0.0, false, false, false)
        Wait(450)
    end
    SetPedToRagdoll(ped, math.random(2500, 4500), math.random(2500, 4500), 0, false, false, false)
end

---@param requireShift boolean keybind path must hold sprint/Shift
local function tryTackle(requireShift)
    if GetGameTimer() < cooldownUntil then return end
    if not isPoliceOnDuty() then return end

    -- Shift+G: G is keymapped; sprint/Shift (control 21) must be held
    if requireShift and not IsControlPressed(0, 21) and not IsDisabledControlPressed(0, 21) then
        return
    end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsPedRagdoll(ped) then return end

    local pd = QBCore.Functions.GetPlayerData()
    if pd.metadata and pd.metadata.ishandcuffed then return end

    if GetEntitySpeed(ped) < 2.0 then return end

    local closestPlayer, distance = QBCore.Functions.GetClosestPlayer()
    if distance == -1 or distance >= 2.0 then return end

    cooldownUntil = GetGameTimer() + 4000
    TriggerServerEvent('tackle:server:TacklePlayer', GetPlayerServerId(closestPlayer))
    tackleAnim()
end

RegisterCommand('+pdTackle', function()
    tryTackle(true)
end, false)

RegisterCommand('-pdTackle', function() end, false)

-- Default G; hold Shift (sprint) — shown in keybind description
RegisterKeyMapping('+pdTackle', 'Policijos pervertimas (laikyk Shift)', 'keyboard', 'G')

-- Typed /tackle — police only, no Shift required
RegisterCommand('tackle', function()
    tryTackle(false)
end, false)

RegisterNetEvent('tackle:client:GetTackled', function()
    getTackledAnim()
end)
