-- Peradresuoja qb-log į server_logs (kai qb-smallresources webhookai tušti)
local QB_LOG_MAP = {
    death = 'death',
    report = 'reports',
    bans = 'admin',
    anticheat = 'security',
    palert = 'admin',
    ['911'] = 'admin',
    ['112'] = 'admin',
    ooc = 'chat',
    me = 'chat',
    robbing = 'security',
    cuffing = 'police',
    house = 'warehouse',
    banking = 'bank',
    trunk = 'vehicle',
    glovebox = 'vehicle',
    stash = 'warehouse',
    playerinventory = 'inventory',
}

local function parsePlayerId(message)
    if type(message) ~= 'string' then return nil end
    local id = message:match('| id:%s*(%d+)')
        or message:match('%[(%d+)%]')
        or message:match('%((%d+)%)')
    return id and tonumber(id) or nil
end

AddEventHandler('qb-log:server:CreateLog', function(name, title, _color, message, tagEveryone)
    local logType = QB_LOG_MAP[name]
    if not logType then return end

    local webhook = Config.Webhooks and Config.Webhooks[logType]
    if not webhook or webhook == '' then return end

    local eventSource = tonumber(source)
    local src = (eventSource and eventSource > 0) and eventSource or parsePlayerId(message)
    local fields = nil
    if tagEveryone then
        fields = { { name = 'Tag', value = '@everyone', inline = true } }
    end

    SendLog(logType, title or name, message or '', fields, src)
end)
