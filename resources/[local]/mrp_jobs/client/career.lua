--[[
  mrp_jobs — Karjeros specialistas Laurynas.
  Bendras NPC, per kurį žaidėjas gali pradėti bet kurį legalų darbą.
]]

local CC = Config.Locations.career
local npcPed = nil

CreateThread(function()
    if CC.blip then
        local c = CC.npc.coords
        local b = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(b, CC.blip.sprite); SetBlipColour(b, CC.blip.color)
        SetBlipScale(b, CC.blip.scale); SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(CC.blip.name); EndTextCommandSetBlipName(b)
    end
end)

CreateThread(function()
    Wait(1200)
    if npcPed and DoesEntityExist(npcPed) then return end
    local m = LoadModel(CC.npc.model)
    if not m then return end
    local c = CC.npc.coords
    npcPed = CreatePed(0, m, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetEntityInvincible(npcPed, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)
    FreezeEntityPosition(npcPed, true)
    if CC.npc.scenario then TaskStartScenarioInPlace(npcPed, CC.npc.scenario, 0, true) end
    SetModelAsNoLongerNeeded(m)

    exports['qb-target']:AddTargetEntity(npcPed, {
        options = {
            { icon = 'fas fa-briefcase', label = CC.npc.label or 'Karjeros centras',
              canInteract = function() return not JobClient.isOnJob() end,
              action = function() JobClient.openMenu('career') end },
            { icon = 'fas fa-flag-checkered', label = 'Baigti dabartinį darbą',
              canInteract = function() return JobClient.isOnJob() end,
              action = function() TriggerServerEvent('mrp_jobs:server:stopJob') end },
        },
        distance = Config.Target.npcDistance or 2.5,
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if npcPed and DoesEntityExist(npcPed) then DeleteEntity(npcPed) end
end)
