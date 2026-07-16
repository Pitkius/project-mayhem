--- PD padaliniai – bendra prieigos logika (client + server)
PdDivisions = PdDivisions or {}

local ALIASES = {
    sor = 'aras',
    SOR = 'aras',
    aro = 'aras',
    ARO = 'aras',
    ARAS = 'aras',
    patrol = 'mp',
    traffic = 'kpd',
    criminal = 'ktd',
}

local function rules()
    return Config.DivisionRules or {}
end

function PdDivisions.normalize(divisionId)
    local d = tostring(divisionId or 'mp'):lower()
    return ALIASES[d] or ALIASES[divisionId] or d
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
        return 'mp'
    end
    if Config.Divisions and Config.Divisions[stored] then
        return stored
    end
    return 'mp'
end

function PdDivisions.isChoosable(divisionId)
    divisionId = PdDivisions.normalize(divisionId)
    local cfg = Config.Divisions and Config.Divisions[divisionId]
    return cfg and cfg.choosable == true
end

function PdDivisions.isAras(divisionId)
    return PdDivisions.normalize(divisionId) == 'aras'
end

--- Policijos vadas (`isboss`) arba pavaduotojas (`isdeputy`).
--- Priima job lentelę arba boolean (jau apskaičiuota vėliava).
function PdDivisions.isLeadership(jobOrFlag)
    if type(jobOrFlag) == 'boolean' then
        return jobOrFlag
    end
    if type(jobOrFlag) ~= 'table' then
        return false
    end
    if jobOrFlag.isboss == true or jobOrFlag.isdeputy == true then
        return true
    end
    local grade = jobOrFlag.grade
    if type(grade) == 'table' and (grade.isboss == true or grade.isdeputy == true) then
        return true
    end
    return false
end

--- Taškas ribojamas tik ARAS padaliniui (ginklinė, ARAS rūbinė).
function PdDivisions.entryIsSorRestricted(entry)
    if not entry or type(entry.divisions) ~= 'table' or #entry.divisions == 0 then
        return false
    end
    for _, d in ipairs(entry.divisions) do
        if not PdDivisions.isAras(d) then
            return false
        end
    end
    return true
end

--- @param leadershipOrJob boolean|table|nil  vadas/pavaduotojas – ARAS taškuose apeina padalinį (rangas lieka)
function PdDivisions.canAccessPoint(grade, storedDivision, entry, leadershipOrJob)
    if not entry then return false end
    grade = tonumber(grade) or 0
    local leadership = PdDivisions.isLeadership(leadershipOrJob)
    --- Tik vadas / pavaduotojas
    if entry.leadershipOnly then
        return leadership
    end
    local div = PdDivisions.effectiveDivision(grade, storedDivision)
    local minG = tonumber(entry.minGrade) or 0
    if grade < minG then
        return false
    end
    if leadership and PdDivisions.entryIsSorRestricted(entry) then
        return true
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
            local label = cfg.label or id
            if cfg.abbr then label = ('[%s] %s'):format(cfg.abbr, label) end
            out[#out + 1] = { id = id, label = label }
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

local function isArasLockerMode(lockerMode)
    local mode = tostring(lockerMode or 'standard'):lower()
    return mode == 'aro' or mode == 'sor' or mode == 'aras'
end

function PdDivisions.outfitAllowed(outfit, lockerMode, grade, storedDivision, leadershipOrJob)
    if not outfit then return false end
    grade = tonumber(grade) or 0
    if grade < (tonumber(outfit.minGrade) or 0) then
        return false
    end
    local divs = outfit.divisions
    if isArasLockerMode(lockerMode) then
        if PdDivisions.isLeadership(leadershipOrJob) then
            return true
        end
        if Config.AroLockerShowsAllUniforms then
            return PdDivisions.isAras(PdDivisions.effectiveDivision(grade, storedDivision))
        end
        if not divs or #divs == 0 then
            return false
        end
        for _, d in ipairs(divs) do
            if PdDivisions.isAras(d) then
                return true
            end
        end
        return false
    end
    -- Standartinė rūbinė – nerodyti tik ARAS skirtų
    if divs and #divs > 0 then
        local onlyTactical = true
        for _, d in ipairs(divs) do
            if not PdDivisions.isAras(d) then
                onlyTactical = false
                break
            end
        end
        if onlyTactical then
            return false
        end
    end
    return true
end
