--- PD padaliniai – bendra prieigos logika (client + server)
PdDivisions = PdDivisions or {}

local ALIASES = {
    sor = 'aras',
    ARAS = 'aras',
    aro = 'aras',
    patrol = 'mp',
    traffic = 'kpd',
    criminal = 'ktd',
}

local function rules()
    return Config.DivisionRules or {}
end

function PdDivisions.normalize(divisionId)
    local d = tostring(divisionId or 'mp'):lower()
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

--- Vadas (isboss) / pavaduotojas (≥ boss_menu) — apeina padalinio filtrą (pvz. ARAS taškai)
function PdDivisions.isBossOrDeputy(grade, isBoss)
    if isBoss == true then return true end
    grade = tonumber(grade) or 0
    return grade >= (tonumber(Config.Permissions and Config.Permissions.boss_menu) or 7)
end

function PdDivisions.canAccessPoint(grade, storedDivision, entry, isBoss)
    if not entry then return false end
    grade = tonumber(grade) or 0
    local div = PdDivisions.effectiveDivision(grade, storedDivision)
    local minG = tonumber(entry.minGrade) or 0
    if grade < minG then
        return false
    end
    local bossBypass = entry.allowBossBypass == true and PdDivisions.isBossOrDeputy(grade, isBoss)
    if entry.divisions and type(entry.divisions) == 'table' and #entry.divisions > 0 then
        local ok = bossBypass
        if not ok then
            for _, d in ipairs(entry.divisions) do
                if PdDivisions.normalize(d) == div then
                    ok = true
                    break
                end
            end
        end
        if not ok then
            return false
        end
    end
    if not bossBypass and entry.excludeDivisions and type(entry.excludeDivisions) == 'table' then
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

function PdDivisions.outfitAllowed(outfit, lockerMode, grade, storedDivision, isBoss)
    if not outfit then return false end
    grade = tonumber(grade) or 0
    if grade < (tonumber(outfit.minGrade) or 0) then
        return false
    end
    local mode = tostring(lockerMode or 'standard'):lower()
    local divs = outfit.divisions
    if mode == 'aro' or mode == 'aras' or mode == 'sor' then
        if Config.AroLockerShowsAllUniforms then
            local eff = PdDivisions.effectiveDivision(grade, storedDivision)
            if eff == 'aras' then return true end
            --- Vadas/pavaduotojas gali matyti ARAS rūbinę (tie patys drabužiai)
            return PdDivisions.isBossOrDeputy(grade, isBoss)
        end
        if not divs or #divs == 0 then
            return false
        end
        for _, d in ipairs(divs) do
            if PdDivisions.normalize(d) == 'aras' then
                return true
            end
        end
        return false
    end
    -- Standartinė rūbinė – nerodyti tik ARAS skirtų
    if divs and #divs > 0 then
        local onlyAras = true
        for _, d in ipairs(divs) do
            if PdDivisions.normalize(d) ~= 'aras' then
                onlyAras = false
                break
            end
        end
        if onlyAras then
            return false
        end
    end
    return true
end
