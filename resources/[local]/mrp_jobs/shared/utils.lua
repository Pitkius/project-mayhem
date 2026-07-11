--[[
  mrp_jobs — bendri pagalbiniai (shared).
  Tik grynos funkcijos, be šalutinių efektų, kad būtų saugu naudoti abiejose pusėse.
]]

Utils = Utils or {}

function Utils.round(n, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor((tonumber(n) or 0) * mult + 0.5) / mult
end

function Utils.clamp(n, lo, hi)
    n = tonumber(n) or 0
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function Utils.tableCount(t)
    if type(t) ~= 'table' then return 0 end
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

function Utils.deepcopy(orig)
    if type(orig) ~= 'table' then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = Utils.deepcopy(v)
    end
    return copy
end

-- Ar reikšmė yra masyve.
function Utils.contains(arr, value)
    if type(arr) ~= 'table' then return false end
    for _, v in ipairs(arr) do
        if v == value then return true end
    end
    return false
end

-- Saugus procentinis paskirstymas (grąžina sveikus skaičius, likutį prideda pirmam).
-- shares: masyvas dalių { 0.35, 0.65 }; total: bendra suma.
function Utils.splitAmount(total, shares)
    total = math.floor(tonumber(total) or 0)
    local out, acc = {}, 0
    for i = 1, #shares do
        out[i] = math.floor(total * (shares[i] or 0))
        acc = acc + out[i]
    end
    if out[1] then out[1] = out[1] + (total - acc) end
    return out
end

-- Atsitiktinis sveikas [min, max]
function Utils.randInt(min, max)
    min, max = math.floor(min or 0), math.floor(max or 0)
    if max < min then min, max = max, min end
    return math.random(min, max)
end

-- Konvertuoja score (0..1) į kokybės pakopą pagal ribas.
-- thresholds: { poor=0.0, normal=0.4, good=0.7, perfect=0.9 }
function Utils.scoreToQuality(score, thresholds)
    score = Utils.clamp(score or 0, 0, 1)
    thresholds = thresholds or { normal = 0.35, good = 0.65, perfect = 0.9 }
    if score >= (thresholds.perfect or 0.9) then return Constants.Quality.PERFECT end
    if score >= (thresholds.good or 0.65) then return Constants.Quality.GOOD end
    if score >= (thresholds.normal or 0.35) then return Constants.Quality.NORMAL end
    return Constants.Quality.POOR
end
