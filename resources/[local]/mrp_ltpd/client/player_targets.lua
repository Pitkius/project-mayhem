local QBCore = exports['qb-core']:GetCoreObject()

local function isPoliceOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == 'police' and P.job.onduty
end

local function hasPermGrade(permKey)
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job then return false end
    local need = (Config.Permissions and Config.Permissions[permKey]) or 0
    return (tonumber(P.job.grade.level) or 0) >= need
end

local function targetRestrained(ped)
    local idx = NetworkGetPlayerIndexFromPed(ped)
    if idx == -1 then return false end
    return Player(idx).state.ltpdCuffed == true
end

local function targetHandsUp(ped)
    if not ped or ped == 0 then return false end
    if IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3) then return true end
    local idx = NetworkGetPlayerIndexFromPed(ped)
    if idx == -1 then return false end
    return Player(idx).state.handsUp == true
end

local function isEntityDown(ped)
    if not ped or ped == 0 then return false end
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return true end
    local idx = NetworkGetPlayerIndexFromPed(ped)
    if idx == -1 then return false end
    local st = Player(idx).state
    return st and (st.isDead == true or st.dead == true)
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end
    --- Papildomi PD labeliai (mrp_restraints jau duoda bendrus antrankius / apieškojimą)
    exports['qb-target']:AddGlobalPlayer({
        options = {
            {
                icon = 'fas fa-handcuffs',
                label = 'Antrankiai (PD)',
                canInteract = function(entity)
                    if not isPoliceOnDuty() or not hasPermGrade('cuff') then return false end
                    if targetRestrained(entity) then return true end
                    return targetHandsUp(entity) or isEntityDown(entity)
                end,
                action = function(entity)
                    local idx = NetworkGetPlayerIndexFromPed(entity)
                    if idx == -1 then return end
                    TriggerServerEvent('mrp_ltpd:server:cuffPlayer', GetPlayerServerId(idx))
                end,
            },
            {
                icon = 'fas fa-search',
                label = 'Apieškoti (PD)',
                canInteract = function(entity)
                    if not isPoliceOnDuty() or not hasPermGrade('search_inventory') then return false end
                    return targetRestrained(entity) or targetHandsUp(entity) or isEntityDown(entity)
                end,
                action = function(entity)
                    local idx = NetworkGetPlayerIndexFromPed(entity)
                    if idx == -1 then return end
                    TriggerServerEvent('mrp_ltpd:server:trySearchInventory', GetPlayerServerId(idx))
                end,
            },
        },
        distance = 2.5,
    })
end)
