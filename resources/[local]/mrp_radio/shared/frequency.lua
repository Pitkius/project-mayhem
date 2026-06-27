RadioFreq = RadioFreq or {}

function RadioFreq.parse(raw)
    if raw == nil then return nil end
    local s = tostring(raw):gsub(',', '.')
    return tonumber(s)
end

function RadioFreq.normalize(raw)
    local f = RadioFreq.parse(raw)
    if not f then return nil end
    f = math.floor(f * 100 + 0.5) / 100
    local minF = Config.MinFrequency or 1.0
    local maxF = Config.MaxFrequency or 999.99
    if f < minF or f > maxF then return nil end
    return f
end

function RadioFreq.toKey(freq)
    freq = RadioFreq.normalize(freq)
    if not freq then return nil end
    return math.floor(freq * 100 + 0.5)
end

function RadioFreq.fromKey(key)
    key = tonumber(key)
    if not key then return nil end
    return key / 100.0
end

function RadioFreq.toVoiceChannel(freq)
    return RadioFreq.toKey(freq)
end

function RadioFreq.format(freq)
    freq = RadioFreq.normalize(freq)
    if not freq then return '--.--' end
    local whole = math.floor(freq + 1e-6)
    local frac = math.floor((freq - whole) * 100 + 0.5)
    if frac >= 100 then
        whole = whole + 1
        frac = 0
    end
    if whole >= 100 then
        return ('%d.%02d'):format(whole, frac)
    end
    return ('%02d.%02d'):format(whole, frac)
end
