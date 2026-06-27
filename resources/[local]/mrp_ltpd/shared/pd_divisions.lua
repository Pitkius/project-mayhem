--- PD padaliniai – bendra prieigos logika (client + server)
PdDivisions = PdDivisions or {}

local ALIASES = {
    aras = 'aro',
    ARAS = 'aro',
}

local function rules()
    return Config.DivisionRules or {}
end

function PdDivisions.normalize(divisionId)
    local d = tostring(divisionId or 'patrol'):lower()
    return ALIASES[d] or d
end

--- Efektyvus padalinys pagal rangą (0–3 visada LPM)
function PdDivisions.effectiveDivision(grade, storedDivision)
    grade = tonumber(grade) or 0
    local stored = PdDivisions.normalize(storedDivision)
    local lpmMax = tonumber(rules().lpmMaxGrade) or 3
    if grade <= lpmMax then
        return 'lpm'
    end
    if stored == 'lpm' then
        return 'patrol'
    end
    if Config.Divisions and Config.Divisions[stored] then
        return stored
    end
    return 'patrol'
end

function PdDivisions.isChoosable(divisionId)
    divisionId = PdDivisions.normalize(divisionId)
    local cfg = Config.Divisions and Config.Divisions[divisionId]
    return cfg and cfg.choosable == true
end

function PdDivisions.canAccessPoint(grade, storedDivision, entry)
    if not entry then return false end
    grade = tonumber(grade) or 0
    local div = PdDivisions.effectiveDivision(grade, storedDivision)
    local minG = tonumber(entry.minGrade) or 0
    if grade < minG then
        return false
    end
    if entry.divisions and type(entry.divisions) == 'table' and #entry.divisions > 0 then
        local ok = false
        for _, d in ipairs(entry.divisions) do
            if PdDivisions.normalize(d) == div then
                ok = true
                break
            end
        end
        if not ok then
            return false
        end
    end
    if entry.excludeDivisions and type(entry.excludeDivisions) == 'table' then
        for _, d in ipairs(entry.excludeDivisions) do
            if PdDivisions.normalize(d) == div then
                return false
            end
        end
    end
    return true
end

function PdDivisions.listChoosable(grade)
    grade = tonumber(grade) or 0
    local chooseMin = tonumber(rules().chooseMinGrade) or 4
    if grade < chooseMin then
        return {}
    end
    local out = {}
    for id, cfg in pairs(Config.Divisions or {}) do
        if cfg.choosable and grade >= (tonumber(cfg.minGrade) or chooseMin) then
            out[#out + 1] = { id = id, label = cfg.label or id }
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

function PdDivisions.outfitAllowed(outfit, lockerMode, grade, storedDivision)
    if not outfit then return false end
    grade = tonumber(grade) or 0
    if grade < (tonumber(outfit.minGrade) or 0) then
        return false
    end
    local mode = tostring(lockerMode or 'standard'):lower()
    local divs = outfit.divisions
    if mode == 'aro' then
        if Config.AroLockerShowsAllUniforms then
            return PdDivisions.effectiveDivision(grade, storedDivision) == 'aro'
        end
        if not divs or #divs == 0 then
            return false
        end
        for _, d in ipairs(divs) do
            if PdDivisions.normalize(d) == 'aro' then
                return true
            end
        end
        return false
    end
    -- Standartinė rūbinė – nerodyti tik ARO skirtų
    if divs and #divs > 0 then
        local onlyAro = true
        for _, d in ipairs(divs) do
            if PdDivisions.normalize(d) ~= 'aro' then
                onlyAro = false
                break
            end
        end
        if onlyAro then
            return false
        end
    end
    return true
end
