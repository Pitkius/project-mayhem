--[[
  DarkNet market bridge — session gate + market payload from mrp_drugs.
  Place/cancel/collect remain mrp_drugs callbacks (client forwards after session check).
]]

local QBCore = exports['qb-core']:GetCoreObject()

local function requireDarknetSession(src)
    local s = PhoneSession.Require(src)
    if not s then return nil, 'Sesija neaktyvi.' end
    if s.phoneType ~= PhoneTypes.DARKNET then
        return nil, 'Tik DarkNet telefonas.'
    end
    return s
end

QBCore.Functions.CreateCallback('mrp_phone:server:darknetMarketState', function(src, cb)
    local s, err = requireDarknetSession(src)
    if not s then return cb({ ok = false, message = err }) end
    if GetResourceState('mrp_drugs') ~= 'started' then
        return cb({ ok = false, message = 'DarkNet ekonomika nepasiekiama.' })
    end
    local ok, payload = pcall(function()
        return exports['mrp_drugs']:DarkNetBuildMarketPayload(src)
    end)
    if not ok or not payload then
        return cb({ ok = false, message = 'Nepavyko gauti katalogo.' })
    end
    cb({
        ok = true,
        products = payload.products or {},
        order = payload.order,
        isNight = payload.isNight,
        levelUnlocked = payload.levelUnlocked,
        phoneId = s.phoneId,
    })
end)

QBCore.Functions.CreateCallback('mrp_phone:server:darknetDropState', function(src, cb)
    local s, err = requireDarknetSession(src)
    if not s then return cb({ ok = false, message = err }) end
    if GetResourceState('mrp_drugs') ~= 'started' then
        return cb({ ok = false, message = 'offline' })
    end
    local ok, payload = pcall(function()
        return exports['mrp_drugs']:DarkNetBuildMarketPayload(src)
    end)
    if not ok or not payload then
        return cb({ ok = false, message = 'Nėra duomenų.' })
    end
    cb({ ok = true, order = payload.order })
end)

print('[mrp_phone] DarkNet bridge loaded.')
