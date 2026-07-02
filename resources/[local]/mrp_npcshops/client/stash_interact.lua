--- Sandėlių atidarymas – F2 (ne E / qb-target)
local DEFAULT_STASH_CONTROL = 289

local function stashOpenControl()
    return (Config and Config.StashOpenControl) or DEFAULT_STASH_CONTROL
end

local function stashOpenLabel()
    return (Config and Config.StashOpenKeyLabel) or 'F2'
end

local function enableStashOpenControl()
    EnableControlAction(0, stashOpenControl(), true)
end

local function isStashOpenPressed()
    local c = stashOpenControl()
    enableStashOpenControl()
    return IsControlJustPressed(0, c) or IsDisabledControlJustPressed(0, c)
end

local function stashInteractHint(label)
    return ('[%s] %s'):format(stashOpenLabel(), label or 'Sandėlis')
end

exports('StashOpenControl', stashOpenControl)
exports('StashOpenLabel', stashOpenLabel)
exports('StashInteractHint', stashInteractHint)
exports('IsStashOpenPressed', isStashOpenPressed)
exports('EnableStashOpenControl', enableStashOpenControl)
