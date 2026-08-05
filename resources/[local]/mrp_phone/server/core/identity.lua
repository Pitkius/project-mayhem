PhoneIdentity = PhoneIdentity or {}

local function randomDigits(len)
    local s = ''
    for _ = 1, len do
        s = s .. tostring(math.random(0, 9))
    end
    return s
end

local function uniqueInColumn(column, generator, attempts)
    attempts = attempts or 40
    for _ = 1, attempts do
        local value = generator()
        local exists = MySQL.scalar.await(
            ('SELECT phone_id FROM mrp_phones WHERE `%s` = ? LIMIT 1'):format(column),
            { value }
        )
        if not exists then return value end
    end
    return generator()
end

function PhoneIdentity.NewNumber()
    local minN = (Config.Phone and Config.Phone.numberMin) or 100000
    local maxN = (Config.Phone and Config.Phone.numberMax) or 999999
    return uniqueInColumn('phone_number', function()
        return tostring(math.random(minN, maxN))
    end)
end

function PhoneIdentity.NewImei()
    return uniqueInColumn('imei', function()
        return '35' .. randomDigits(13)
    end)
end

function PhoneIdentity.NewSimId()
    return uniqueInColumn('sim_id', function()
        return 'SIM' .. randomDigits(12)
    end)
end

function PhoneIdentity.NewPhoneId()
    -- UUID-ish without requiring external lib
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return (template:gsub('[xy]', function(c)
        local v = (c == 'x') and math.random(0, 15) or math.random(8, 11)
        return string.format('%x', v)
    end))
end
