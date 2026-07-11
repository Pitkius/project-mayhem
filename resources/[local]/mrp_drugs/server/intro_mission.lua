--[[
  Server: civilio įvadinė Dark Net misija (vienkartinė).
  Būsenos valdomos per DrugPlayer (progression.lua). Visi žingsniai tikrinami serveryje.

    intro_state 1 → susitikti su kontaktu   (introMeetContact → 2)
    intro_state 2 → paimti siuntą           (introPickup     → 3)
    intro_state 3 → pristatyti siuntą        (introDeliver    → unlock + 4)
]]

local QBCore = exports['qb-core']:GetCoreObject()

local function nearCoords(src, coords, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local c = vector3(coords.x, coords.y, coords.z)
    return #(p - c) <= (maxDist or 3.0)
end

QBCore.Functions.CreateCallback('mrp_drugs:server:introMeetContact', function(src, cb)
    local intro = Config.IntroMission
    if not (intro and intro.enabled) then return cb({ ok = false }) end
    if DrugPlayer.getIntroState(src) ~= 1 then return cb({ ok = false, reason = 'Nėra ką aptarti.' }) end
    if not nearCoords(src, intro.contactNpc.coords, 3.0) then
        return cb({ ok = false, reason = 'Per toli.' })
    end
    DrugPlayer.setIntroState(src, 2)
    cb({ ok = true })
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:introPickup', function(src, cb)
    local intro = Config.IntroMission
    if not (intro and intro.enabled) then return cb({ ok = false }) end
    if DrugPlayer.getIntroState(src) ~= 2 then return cb({ ok = false, reason = 'Ne dabar.' }) end
    if not nearCoords(src, intro.packagePickup.coords, (intro.packagePickup.pickDistance or 2.5) + 1.0) then
        return cb({ ok = false, reason = 'Per toli nuo siuntos.' })
    end
    DrugPlayer.setIntroState(src, 3)
    cb({ ok = true })
end)

QBCore.Functions.CreateCallback('mrp_drugs:server:introDeliver', function(src, cb)
    local intro = Config.IntroMission
    if not (intro and intro.enabled) then return cb({ ok = false }) end
    if DrugPlayer.getIntroState(src) ~= 3 then return cb({ ok = false, reason = 'Ne dabar.' }) end
    if not nearCoords(src, intro.delivery.coords, (intro.delivery.pickDistance or 2.5) + 1.0) then
        return cb({ ok = false, reason = 'Per toli nuo pristatymo vietos.' })
    end
    DrugPlayer.unlockDarknet(src, true) -- nustato state 4, siunčia finalSms, sinchronizuoja
    cb({ ok = true })
end)
