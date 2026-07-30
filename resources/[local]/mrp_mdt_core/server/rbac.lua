--- RBAC: job + grade + onduty (+ optional mrp_bossmenu override for police legacy keys).

MdtRbac = MdtRbac or {}

local QBCore = exports['qb-core']:GetCoreObject()

local function isAdmin(src)
    for _, perm in ipairs(Config.AdminBypassPermissions or {}) do
        if QBCore.Functions.HasPermission(src, perm) then return true end
    end
    return false
end

local function resolveMinGrade(jobName, gradeLevel, rule)
    local need = tonumber(rule.minGrade) or 0
    local legacyKey = rule.legacyKey
    if legacyKey and jobName == 'police' and GetResourceState('mrp_bossmenu') == 'started' then
        local ok, override = pcall(function()
            return exports['mrp_bossmenu']:GetGradePermissionMin('police', gradeLevel, legacyKey)
        end)
        if ok and override ~= nil then
            need = tonumber(override) or need
        end
    end
    return need
end

local function jobNameMatchesRule(jobName, ruleJob)
    jobName = tostring(jobName or '')
    ruleJob = tostring(ruleJob or '')
    if jobName == ruleJob then return true end
    local shared = QBCore.Shared and QBCore.Shared.Jobs or {}
    local row = shared[jobName]
    if not row then return false end
    if ruleJob == 'mechanic' then return row.type == 'mechanic' end
    if ruleJob == 'ambulance' then return row.type == 'ems' end
    return false
end

local function ruleMatches(src, rule)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.job then return false end
    local job = Player.PlayerData.job
    if not jobNameMatchesRule(job.name, rule.job) then return false end
    if rule.requireDuty ~= false and job.onduty ~= true then return false end
    local grade = tonumber(job.grade and job.grade.level) or 0
    local need = resolveMinGrade(job.name, grade, rule)
    return grade >= need
end

--- @param source number
--- @param perm string  e.g. MDT_FINE
--- @return boolean
function MdtRbac.HasPermission(source, perm)
    source = tonumber(source)
    perm = tostring(perm or '')
    if not source or source < 1 or perm == '' then return false end
    if not MdtPermissions.IsKnown(perm) then return false end
    if isAdmin(source) then return true end

    local rules = Config.PermissionRules and Config.PermissionRules[perm]
    if type(rules) ~= 'table' or #rules == 0 then return false end

    for _, rule in ipairs(rules) do
        if ruleMatches(source, rule) then return true end
    end
    return false
end

--- @return boolean  true if allowed; otherwise notifies and returns false
function MdtRbac.Require(source, perm, notifyMsg)
    if MdtRbac.HasPermission(source, perm) then return true end
    if source and source > 0 then
        TriggerClientEvent('QBCore:Notify', source, notifyMsg or 'Nėra teisės atlikti šio veiksmo.', 'error')
    end
    return false
end

exports('HasPermission', function(source, perm)
    return MdtRbac.HasPermission(source, perm)
end)

exports('RequirePermission', function(source, perm, notifyMsg)
    return MdtRbac.Require(source, perm, notifyMsg)
end)
