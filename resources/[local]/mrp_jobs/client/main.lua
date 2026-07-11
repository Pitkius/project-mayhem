--[[
  mrp_jobs — kliento bootstrap: notify + progress wrapper.
  Progress naudoja QBCore.Functions.Progressbar (kuris pats turi fallback,
  jei 'progressbar' resursas neįdiegtas).
]]

QBCore = exports['qb-core']:GetCoreObject()
RegisterNetEvent('QBCore:Client:UpdateObject', function() QBCore = exports['qb-core']:GetCoreObject() end)

JobProgress = JobProgress or {}

local DEFAULT_DISABLE = {
    disableMovement = true,
    disableCarMovement = true,
    disableCombat = true,
}

-- Notify wrapper.
function Notify(msg, typ, dur)
    QBCore.Functions.Notify(msg, typ or 'primary', dur or (Config.Notify and Config.Notify.duration) or 5000)
end

-- Blokuojantis progress bar. Grąžina true (baigta) / false (atšaukta).
-- opts: { canCancel, useWhileDead, disable, anim, prop, propTwo }
function JobProgress.run(name, label, duration, opts)
    opts = opts or {}
    local p = promise.new()
    local settled = false
    local function done(v) if not settled then settled = true; p:resolve(v) end end

    QBCore.Functions.Progressbar(
        name or 'mrp_jobs',
        label or 'Vykdoma…',
        tonumber(duration) or 4000,
        opts.useWhileDead == true,
        opts.canCancel ~= false,
        opts.disable or DEFAULT_DISABLE,
        opts.anim or {},
        opts.prop or {},
        opts.propTwo or {},
        function() done(true) end,
        function() done(false) end
    )
    return Citizen.Await(p)
end

-- Animacijos pakrovimas (naudinga darbų moduliams).
function LoadAnimDict(dict)
    if not dict or dict == '' then return false end
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(10) end
    return HasAnimDictLoaded(dict)
end

-- Modelio pakrovimas (props / peds / vehicles).
function LoadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end
