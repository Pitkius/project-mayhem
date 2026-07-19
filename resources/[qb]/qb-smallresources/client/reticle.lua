--- GTA taikinukas visada baltas — nerodo raudonos/pilkos, kai taikaisi į pedą / žaidėją.
--- Native reticle slepiamas, piešiamas baltas + (sniperio scope neliečiamas).

local GROUP_SNIPER = joaat('GROUP_SNIPER')

local function applyEnemyHudWhite()
    --- HUD_COLOUR_ENEMY / FRIENDLY — GTA jomis tintina taikinuką ant taikinio
    ReplaceHudColourWithRgba(119, 255, 255, 255, 255)
    ReplaceHudColourWithRgba(118, 255, 255, 255, 255)
end

local function drawWhiteReticle()
    local cx, cy = 0.5, 0.5
    local gap = 0.00115
    local arm = 0.0036
    local t = 0.0010
    local r, g, b, a = 255, 255, 255, 235
    DrawRect(cx, cy - gap - arm * 0.5, t, arm, r, g, b, a)
    DrawRect(cx, cy + gap + arm * 0.5, t, arm, r, g, b, a)
    DrawRect(cx - gap - arm * 0.5, cy, arm, t, r, g, b, a)
    DrawRect(cx + gap + arm * 0.5, cy, arm, t, r, g, b, a)
end

local function isSniperScopeActive()
    if not IsFirstPersonAimCamActive() then return false end
    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    return GetWeapontypeGroup(weapon) == GROUP_SNIPER
end

local function shouldForceWhiteReticle()
    local ped = PlayerPedId()
    if IsPauseMenuActive() then return false end
    if IsPedDeadOrDying(ped, true) then return false end
    if not IsPedArmed(ped, 4) and not IsPedArmed(ped, 2) then return false end
    if isSniperScopeActive() then return false end

    local pid = PlayerId()
    if IsPlayerFreeAiming(pid) then return true end
    if IsAimCamActive() then return true end
    --- RMB aim (control 25)
    if IsControlPressed(0, 25) or IsDisabledControlPressed(0, 25) then return true end
    return false
end

CreateThread(function()
    if Config.AlwaysWhiteReticle == false then return end
    applyEnemyHudWhite()
    while true do
        if shouldForceWhiteReticle() then
            HideHudComponentThisFrame(14)
            drawWhiteReticle()
            Wait(0)
        else
            Wait(80)
        end
    end
end)

CreateThread(function()
    if Config.AlwaysWhiteReticle == false then return end
    while true do
        applyEnemyHudWhite()
        Wait(5000)
    end
end)
