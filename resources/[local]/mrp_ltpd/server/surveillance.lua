local QBCore = exports['qb-core']:GetCoreObject()

local CctvOffline = {} ---@type table<string, number> camId -> os.time() until
local BodycamBattery = {} ---@type table<number, number> source -> pct
local LastCctvTamperAt = 0

local function hasPerm(src, key)
    return exports['mrp_ltpd']:HasLtpdPermission(src, key)
end

local function isOnDuty(src)
    return exports['mrp_ltpd']:IsLtpdOnDuty(src)
end

local function isSurvMaintenance()
    return Config.Surveillance and Config.Surveillance.MaintenanceMode == true
end

local function survMaintenanceMessage()
    return (Config.Surveillance and Config.Surveillance.MaintenanceMessage)
        or 'Sistema laikinai neveikia. Dėl finansavimo skyrimo ir įrengimo kreipkitės į miesto merą.'
end

local function camById(camId)
    for _, c in ipairs(Config.Surveillance.CctvCameras or {}) do
        if c.id == camId then return c end
    end
    return nil
end

local function resolveCamCoords(cam)
    if not cam then return nil end
    if cam.coords then return cam.coords end
    if cam.propCoords then
        local c = cam.propCoords
        return vector3(c.x, c.y, c.z)
    end
    return nil
end

local function resolveCamLookAt(cam, coords)
    if cam.lookAt then return cam.lookAt end
    if cam.propCoords and coords then
        local c = cam.propCoords
        local h = math.rad(tonumber(c.w or c.heading) or 0.0)
        local dist = tonumber(cam.lookDistance) or 12.0
        return vector3(
            coords.x - math.sin(h) * dist,
            coords.y + math.cos(h) * dist,
            coords.z
        )
    end
    return coords
end

local function isCctvOnline(camId)
    local untilTs = CctvOffline[camId]
    if not untilTs then return true end
    if os.time() >= untilTs then
        CctvOffline[camId] = nil
        return true
    end
    return false
end

local function setBodycamState(src, active, extra)
    local ply = Player(src)
    if not ply or not ply.state then return end
    if not active then
        ply.state:set('ltpdBodycam', false, true)
        return
    end
    ply.state:set('ltpdBodycam', extra or true, true)
end

local function getOfficerLabel(Player)
    local char = Player.PlayerData.charinfo or {}
    local name = ((char.firstname or '') .. ' ' .. (char.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then name = 'Pareigūnas' end
    local callsign = Player.PlayerData.metadata and Player.PlayerData.metadata.callsign
    if type(callsign) ~= 'string' or callsign == '' then callsign = nil end
    return name, callsign
end

local function hasBodycamItem(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local item = Config.Surveillance.BodycamItem or 'police_bodycam'
    return Player.Functions.GetItemByName(item) ~= nil
end

local function stopBodycam(src, reason)
    BodycamBattery[src] = nil
    setBodycamState(src, false)
    TriggerClientEvent('mrp_ltpd:client:bodycamState', src, false, reason or 'off')
end

local function cctvSiteId(cam)
    if cam.siteId then return cam.siteId end
    if cam.bankId then return cam.bankId end
    local id = tostring(cam.id or '')
    local sites = Config.Surveillance.CctvSites or {}
    local bestId, bestLen = id, 0
    for siteId, _ in pairs(sites) do
        if id == siteId or id:sub(1, #siteId + 1) == siteId .. '_' then
            if #siteId > bestLen then
                bestId, bestLen = siteId, #siteId
            end
        end
    end
    return bestId
end

local function cctvSiteLabel(siteId, cameras)
    local cfg = Config.Surveillance.CctvSites and Config.Surveillance.CctvSites[siteId]
    if cfg and cfg.label then return cfg.label end
    if cameras and cameras[1] and cameras[1].label then return cameras[1].label end
    return siteId
end

local function cctvSiteZone(siteId, cameras)
    local cfg = Config.Surveillance.CctvSites and Config.Surveillance.CctvSites[siteId]
    if cfg and cfg.zone then return cfg.zone end
    if cameras and cameras[1] and cameras[1].zone then return cameras[1].zone end
    return 'other'
end

local function buildCctvCameraRow(c)
    local coords = resolveCamCoords(c)
    if not coords then return nil end
    local online = isCctvOnline(c.id)
    return {
        id = c.id,
        label = c.label,
        zone = c.zone,
        siteId = cctvSiteId(c),
        zoneLabel = (Config.Surveillance.CctvCategories or {})[c.zone] or c.zone,
        online = online,
        audio = c.audio == true,
        hasProp = c.propCoords ~= nil or c.propModel ~= nil,
        coords = { x = coords.x, y = coords.y, z = coords.z },
    }
end

local function buildCctvList()
    local rows = {}
    for _, c in ipairs(Config.Surveillance.CctvCameras or {}) do
        local row = buildCctvCameraRow(c)
        if row then rows[#rows + 1] = row end
    end
    return rows
end

local function buildCctvSites()
    local grouped = {} ---@type table<string, table[]>
    for _, c in ipairs(Config.Surveillance.CctvCameras or {}) do
        local row = buildCctvCameraRow(c)
        if row then
            local sid = row.siteId
            grouped[sid] = grouped[sid] or {}
            grouped[sid][#grouped[sid] + 1] = row
        end
    end

    local sites = {}
    for siteId, cameras in pairs(grouped) do
        table.sort(cameras, function(a, b) return (a.label or a.id) < (b.label or b.id) end)
        local zone = cctvSiteZone(siteId, cameras)
        local onlineCount = 0
        for i = 1, #cameras do
            if cameras[i].online then onlineCount = onlineCount + 1 end
        end
        local cx, cy, cz = 0.0, 0.0, 0.0
        for i = 1, #cameras do
            cx = cx + (cameras[i].coords.x or 0.0)
            cy = cy + (cameras[i].coords.y or 0.0)
            cz = cz + (cameras[i].coords.z or 0.0)
        end
        local n = math.max(1, #cameras)
        sites[#sites + 1] = {
            id = siteId,
            label = cctvSiteLabel(siteId, cameras),
            zone = zone,
            zoneLabel = (Config.Surveillance.CctvCategories or {})[zone] or zone,
            cameraCount = #cameras,
            onlineCount = onlineCount,
            allOnline = onlineCount == #cameras,
            coords = { x = cx / n, y = cy / n, z = cz / n },
            cameras = cameras,
        }
    end
    table.sort(sites, function(a, b) return (a.label or a.id) < (b.label or b.id) end)
    return sites
end

local function buildCctvSitesMaintenance()
    local counts = {}
    for _, c in ipairs(Config.Surveillance.CctvCameras or {}) do
        local sid = cctvSiteId(c)
        counts[sid] = (counts[sid] or 0) + 1
    end

    local sites = {}
    for siteId, cfg in pairs(Config.Surveillance.CctvSites or {}) do
        local zone = cfg.zone or 'other'
        local cameraCount = counts[siteId] or 0
        sites[#sites + 1] = {
            id = siteId,
            label = cfg.label or siteId,
            zone = zone,
            zoneLabel = (Config.Surveillance.CctvCategories or {})[zone] or zone,
            cameraCount = cameraCount,
            onlineCount = 0,
            allOnline = false,
            maintenance = true,
        }
    end
    table.sort(sites, function(a, b) return (a.label or a.id) < (b.label or b.id) end)
    return sites
end

local function stopAllBodycams(reason)
    for _, pid in ipairs(QBCore.Functions.GetPlayers()) do
        local src = tonumber(pid)
        if src and Player(src).state.ltpdBodycam then
            stopBodycam(src, reason or 'maintenance')
        end
    end
end

local function nearCctvStation(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    for _, st in ipairs(Config.Surveillance.CctvWatchStations or {}) do
        if #(p - st.coords) <= (st.radius or 40.0) then return true end
    end
    return false
end

local function buildBodycamList()
    local rows = {}
    for _, pid in ipairs(QBCore.Functions.GetPlayers()) do
        local src = tonumber(pid)
        local st = Player(src).state.ltpdBodycam
        if st and st ~= false and isOnDuty(src) and hasBodycamItem(src) then
            local Player = QBCore.Functions.GetPlayer(src)
            if Player then
                local meta = type(st) == 'table' and st or {}
                rows[#rows + 1] = {
                    serverId = src,
                    name = meta.name or 'Pareigūnas',
                    callsign = meta.callsign,
                    crew = meta.crew,
                    battery = meta.battery,
                    startedAt = meta.startedAt,
                    online = true,
                }
            end
        end
    end
    table.sort(rows, function(a, b) return (a.callsign or a.name) < (b.callsign or b.name) end)
    return rows
end

QBCore.Functions.CreateCallback('mrp_ltpd:server:cctvList', function(src, cb)
    if not hasPerm(src, 'mdt_cctv') then return cb({ ok = false }) end
    if isSurvMaintenance() then
        return cb({
            ok = true,
            maintenance = true,
            maintenanceMessage = survMaintenanceMessage(),
            sites = buildCctvSitesMaintenance(),
            cameras = {},
            categories = Config.Surveillance.CctvCategories or {},
        })
    end
    cb({
        ok = true,
        sites = buildCctvSites(),
        cameras = buildCctvList(),
        categories = Config.Surveillance.CctvCategories or {},
    })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:cctvWatch', function(src, cb, camId)
    if isSurvMaintenance() then
        return cb({ ok = false, msg = survMaintenanceMessage() })
    end
    if not hasPerm(src, 'mdt_cctv') then return cb({ ok = false, msg = 'Neturite teisės.' }) end
    if not nearCctvStation(src) then
        return cb({ ok = false, msg = 'CCTV per MDT – tik iš komisariato zonos.' })
    end
    camId = tostring(camId or '')
    local cam = camById(camId)
    if not cam then return cb({ ok = false, msg = 'Kamera nerasta.' }) end
    if not isCctvOnline(camId) then return cb({ ok = false, msg = 'Kamera neprieinama (sugadinta).' }) end
    local coords = resolveCamCoords(cam)
    if not coords then return cb({ ok = false, msg = 'Kamera neteisingai sukonfigūruota.' }) end
    local lookAt = resolveCamLookAt(cam, coords)
    cb({
        ok = true,
        camId = cam.id,
        cam = {
            id = cam.id,
            label = cam.label,
            coords = { x = coords.x, y = coords.y, z = coords.z },
            lookAt = { x = lookAt.x, y = lookAt.y, z = lookAt.z },
            fov = cam.fov or 55.0,
            audio = cam.audio == true,
        },
    })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:bodycamList', function(src, cb)
    if not hasPerm(src, 'mdt_bodycam') then return cb({ ok = false }) end
    if isSurvMaintenance() then
        return cb({
            ok = true,
            maintenance = true,
            maintenanceMessage = survMaintenanceMessage(),
            feeds = {},
        })
    end
    cb({ ok = true, feeds = buildBodycamList() })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:bodycamWatch', function(src, cb, targetId)
    if isSurvMaintenance() then
        return cb({ ok = false, msg = survMaintenanceMessage() })
    end
    if not hasPerm(src, 'mdt_bodycam') then return cb({ ok = false }) end
    targetId = tonumber(targetId)
    if not targetId or targetId < 1 then return cb({ ok = false, msg = 'Neteisingas ID.' }) end
    local tPed = GetPlayerPed(targetId)
    if not tPed or tPed == 0 then return cb({ ok = false, msg = 'Pareigūnas neprisijungęs.' }) end
    if not isOnDuty(targetId) then return cb({ ok = false, msg = 'Pareigūnas ne tarnyboje.' }) end
    if not hasBodycamItem(targetId) then return cb({ ok = false, msg = 'Pareigūnas neturi bodycam.' }) end
    local st = Player(targetId).state.ltpdBodycam
    if not st or st == false then return cb({ ok = false, msg = 'Kūno kamera neprieinama.' }) end
    cb({ ok = true, targetId = targetId })
end)

RegisterNetEvent('mrp_ltpd:server:bodycamToggle', function()
    local src = source
    if isSurvMaintenance() then
        return TriggerClientEvent('QBCore:Notify', src, survMaintenanceMessage(), 'error')
    end
    if not hasPerm(src, 'bodycam_wear') or not isOnDuty(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Kūno kamera – tik policijai tarnyboje.', 'error')
    end
    if not hasBodycamItem(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturite bodycam įrenginio.', 'error')
    end

    local cur = Player(src).state.ltpdBodycam
    if cur and cur ~= false then
        stopBodycam(src, 'toggle')
        TriggerClientEvent('QBCore:Notify', src, 'Kūno kamera išjungta.', 'primary')
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    local name, callsign = getOfficerLabel(Player)
    local battCfg = Config.Surveillance.Bodycam or {}
    local battery = battCfg.batteryMax or 100
    if battCfg.batteryEnabled then
        BodycamBattery[src] = battery
    end

    local crewId = nil
    if Player.PlayerData.metadata and Player.PlayerData.metadata.dispatchCrew then
        crewId = Player.PlayerData.metadata.dispatchCrew
    end

    local payload = {
        active = true,
        name = name,
        callsign = callsign,
        crew = crewId,
        battery = battery,
        startedAt = os.time(),
    }
    setBodycamState(src, true, payload)
    TriggerClientEvent('mrp_ltpd:client:bodycamState', src, true, 'on')
    TriggerClientEvent('QBCore:Notify', src, 'Kūno kamera įjungta.', 'success')
end)

RegisterNetEvent('mrp_ltpd:server:bodycamForceOff', function(reason)
    local src = source
    stopBodycam(src, reason or 'off')
end)

RegisterNetEvent('mrp_ltpd:server:bodycamPanicAutoOn', function()
    local src = source
    if isSurvMaintenance() then return end
    local cfg = Config.Surveillance.Bodycam or {}
    if not cfg.autoOnPanic or not hasPerm(src, 'bodycam_wear') or not isOnDuty(src) then return end
    if not hasBodycamItem(src) then return end
    if Player(src).state.ltpdBodycam then return end

    local Player = QBCore.Functions.GetPlayer(src)
    local name, callsign = getOfficerLabel(Player)
    local battCfg = Config.Surveillance.Bodycam or {}
    local battery = battCfg.batteryMax or 100
    if battCfg.batteryEnabled then BodycamBattery[src] = battery end
    setBodycamState(src, true, {
        active = true,
        name = name,
        callsign = callsign,
        crew = Player.PlayerData.metadata and Player.PlayerData.metadata.dispatchCrew,
        battery = battery,
        startedAt = os.time(),
        panic = true,
    })
    TriggerClientEvent('mrp_ltpd:client:bodycamState', src, true, 'panic')
end)

QBCore.Functions.CreateUseableItem(Config.Surveillance.BodycamItem or 'police_bodycam', function(source)
    TriggerClientEvent('mrp_ltpd:client:bodycamUseItem', source)
end)

AddEventHandler('playerDropped', function()
    local src = source
    stopBodycam(src, 'disconnect')
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    stopBodycam(src, 'unload')
end)

CreateThread(function()
    local cfg = Config.Surveillance.Bodycam or {}
    if not cfg.batteryEnabled then return end
    local drain = tonumber(cfg.drainPerMinute) or 2.5
    local tickMs = 60000
    while true do
        if isSurvMaintenance() then
            Wait(300000)
        else
            Wait(tickMs)
            for _, pid in ipairs(QBCore.Functions.GetPlayers()) do
                local src = tonumber(pid)
                local st = Player(src).state.ltpdBodycam
                if st and type(st) == 'table' and st.active then
                    local cur = BodycamBattery[src] or st.battery or 100
                    cur = cur - drain
                    if cur <= 0 then
                        stopBodycam(src, 'battery')
                        TriggerClientEvent('QBCore:Notify', src, 'Kūno kameros baterija išsekusi.', 'error')
                    else
                        BodycamBattery[src] = cur
                        st.battery = math.floor(cur + 0.5)
                        setBodycamState(src, true, st)
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        if isSurvMaintenance() then
            Wait(120000)
        else
            Wait(15000)
        end
        local now = os.time()
        for id, untilTs in pairs(CctvOffline) do
            if now >= untilTs then CctvOffline[id] = nil end
        end
        if not isSurvMaintenance() then
            for _, pid in ipairs(QBCore.Functions.GetPlayers()) do
                local src = tonumber(pid)
                if Player(src).state.ltpdBodycam and not hasBodycamItem(src) then
                    stopBodycam(src, 'no_item')
                    TriggerClientEvent('QBCore:Notify', src, 'Kūno kamera išjungta – įrenginys ne inventoriuje.', 'error')
                end
            end
        end
    end
end)

CreateThread(function()
    Wait(1500)
    if isSurvMaintenance() then
        stopAllBodycams('maintenance')
    end
end)

--- Apiplėšimai / hack
local function tamperCam(camId, seconds, reason)
    seconds = math.max(5, math.min(tonumber(seconds) or 120, 3600))
    CctvOffline[camId] = os.time() + seconds
    return true
end

RegisterNetEvent('mrp_ltpd:server:cctvTamper', function(camId, seconds)
    local src = source
  --- Tik ne-pd (nusikaltėliai) – serveris gali tikrinti job jei reikia; dabar leidžiame bet kam su event (naudok export iš robbery)
    camId = tostring(camId or '')
    if camById(camId) then tamperCam(camId, seconds, 'tamper') end
end)

exports('TamperCctv', function(camId, seconds)
    return tamperCam(tostring(camId), seconds)
end)

exports('TamperCctvRadius', function(coords, radius, seconds)
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return 0 end
    local now = os.time()
    local cd = tonumber(Config.Surveillance.CctvTamperCooldownSec) or 45
    if (now - LastCctvTamperAt) < cd then return 0 end
    LastCctvTamperAt = now
    local cx, cy, cz = coords.x, coords.y, coords.z
    radius = tonumber(radius) or 25.0
    seconds = tonumber(seconds) or 180
    local n = 0
    for _, c in ipairs(Config.Surveillance.CctvCameras or {}) do
        local cc = resolveCamCoords(c)
        if not cc then goto continue end
        local dist = #(vector3(cx, cy, cz) - cc)
        if dist <= radius then
            tamperCam(c.id, seconds)
            n = n + 1
        end
        ::continue::
    end
    return n
end)

exports('GetCctvList', function()
    return buildCctvList()
end)

exports('IsBodycamActive', function(src)
    local st = Player(src).state.ltpdBodycam
    return st and st ~= false
end)
