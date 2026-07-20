--- Tikri GTA V / GTA Online minigame'ai (scaleform + sprites), ne custom NUI.

local active = false

local function loadScaleform(name)
    local sf = RequestScaleformMovie(name)
    local t = GetGameTimer() + 5000
    while not HasScaleformMovieLoaded(sf) and GetGameTimer() < t do
        Wait(0)
    end
    if not HasScaleformMovieLoaded(sf) then return nil end
    return sf
end

local function sfFloat(sf, method, value)
    BeginScaleformMovieMethod(sf, method)
    ScaleformMovieMethodAddParamFloat(value + 0.0)
    EndScaleformMovieMethod()
end

--- GTA Online Fleeca DRILLING scaleform (rodyklės: aukštyn/žemyn pozicija, kairėn/dešinėn greitis)
function RunNativeDrill(cb)
    if active then
        if cb then cb(false) end
        return false
    end
    active = true
    local result = false
    local sf = loadScaleform('DRILLING')
    if not sf then
        active = false
        if cb then cb(false) end
        return false
    end

    local speed, pos, temp, hole = 0.0, 0.0, 0.0, 0.1
    sfFloat(sf, 'SET_SPEED', 0.0)
    sfFloat(sf, 'SET_DRILL_POSITION', 0.0)
    sfFloat(sf, 'SET_TEMPERATURE', 0.0)
    sfFloat(sf, 'SET_HOLE_DEPTH', 0.0)

    local running = true
    while running do
        DrawScaleformMovieFullscreen(sf, 255, 255, 255, 255, 0)

        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 32, true)
        DisableControlAction(0, 33, true)
        DisableControlAction(0, 34, true)
        DisableControlAction(0, 35, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)

        local lastPos, lastSpeed, lastTemp = pos, speed, temp
        local dt = GetFrameTime()

        --- UP / DOWN — grąžto gylis
        if IsControlJustPressed(0, 172) then
            pos = math.min(1.0, pos + 0.01)
        elseif IsControlPressed(0, 172) then
            pos = math.min(1.0, pos + (0.1 * dt / (math.max(0.1, temp) * 10)))
        elseif IsControlJustPressed(0, 173) then
            pos = math.max(0.0, pos - 0.01)
        elseif IsControlPressed(0, 173) then
            pos = math.max(0.0, pos - (0.1 * dt))
        end

        --- LEFT / RIGHT — greitis
        if IsControlJustPressed(0, 175) then
            speed = math.min(1.0, speed + 0.05)
        elseif IsControlPressed(0, 175) then
            speed = math.min(1.0, speed + (0.5 * dt))
        elseif IsControlJustPressed(0, 174) then
            speed = math.max(0.0, speed - 0.05)
        elseif IsControlPressed(0, 174) then
            speed = math.max(0.0, speed - (0.5 * dt))
        end

        if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 177) then
            result = false
            running = false
            break
        end

        if pos > hole then
            if speed > 0.1 then
                temp = math.min(1.0, temp + (dt * speed))
                hole = pos
            else
                pos = hole
            end
        else
            temp = math.max(0.0, temp - dt)
        end

        if lastSpeed ~= speed then sfFloat(sf, 'SET_SPEED', speed) end
        if lastPos ~= pos then sfFloat(sf, 'SET_DRILL_POSITION', pos) end
        if lastTemp ~= temp then sfFloat(sf, 'SET_TEMPERATURE', temp) end
        sfFloat(sf, 'SET_HOLE_DEPTH', hole)

        if temp >= 1.0 then
            result = false
            running = false
        elseif pos >= 1.0 then
            result = true
            running = false
        end
        Wait(0)
    end

    SetScaleformMovieAsNoLongerNeeded(sf)
    active = false
    if cb then cb(result) end
    return result
end

--- GTA Data Crack (hackingNG sprites) — LMB fiksuoja žalią bloką eilėje
function RunNativeDatacrack(difficulty, cb)
    if active then
        if cb then cb(false) end
        return false
    end
    active = true
    difficulty = tonumber(difficulty) or 3.0
    if difficulty < 2.0 then difficulty = 2.0 end
    if difficulty > 5.0 then difficulty = 5.0 end
    local speedMul = difficulty * 10.0

    local pinY = {}
    local state = {} --- locked=1 idle, 0=active moving, done=val4 false means done in original
    for i = 1, 7 do
        pinY[i] = 0.4
        state[i] = {
            idle = true,
            speed = (0.02 + (i - 1) * 0.005) * 0.55,
            phase = 0.0,
            rising = true,
            done = false,
            active = false,
        }
    end
    state[1].idle = false
    state[1].active = true

    local current = 1
    local success = false
    local finished = false

    RequestStreamedTextureDict('hackingNG', false)
    local texT = GetGameTimer() + 5000
    while not HasStreamedTextureDictLoaded('hackingNG') and GetGameTimer() < texT do
        Wait(10)
    end

    local scaleform = RequestScaleformMovieInteractive('HACKING_PC')
    local sfT = GetGameTimer() + 5000
    while not HasScaleformMovieLoaded(scaleform) and GetGameTimer() < sfT do
        Wait(0)
    end
    if HasScaleformMovieLoaded(scaleform) then
        BeginScaleformMovieMethod(scaleform, 'SET_BACKGROUND')
        ScaleformMovieMethodAddParamInt(1)
        EndScaleformMovieMethod()
    end

    local function help(msg)
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandDisplayHelp(0, false, true, -1)
    end

    local function inGreen(i)
        return pinY[i] >= 0.51 and pinY[i] <= 0.62
    end

    local function ease(a, b, t)
        local n = (1.0 - math.cos(t * math.pi)) * 0.5
        return (a * (1.0 - n)) + (b * n)
    end

    while not finished do
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 257, true)
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 32, true)
        DisableControlAction(0, 33, true)
        DisableControlAction(0, 34, true)
        DisableControlAction(0, 35, true)

        help('LMB — fiksuoti  |  BACKSPACE — atšaukti')

        local dt = Timestep()
        for i = 1, 7 do
            local s = state[i]
            if s.active and not s.done then
                if s.rising then
                    s.phase = s.phase + (s.speed * dt * speedMul)
                    if s.phase >= 1.0 then s.phase = 1.0; s.rising = false end
                else
                    s.phase = s.phase - (s.speed * dt * speedMul)
                    if s.phase <= 0.0 then s.phase = 0.0; s.rising = true end
                end
                pinY[i] = ease(0.4, 0.744, s.phase)
            end
        end

        if HasScaleformMovieLoaded(scaleform) then
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
        end
        DrawSprite('hackingNG', 'DHMain', 0.50, 0.50, 0.731, 1.306, 0.0, 255, 255, 255, 255)

        local xs = { 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65 }
        for i = 1, 7 do
            local sprite = (state[i].active and not state[i].done) and 'DHCompHi' or 'DHComp'
            DrawSprite('hackingNG', sprite, xs[i], pinY[i], 0.4, 0.4, 0.0, 255, 255, 255, 255)
        end

        if IsControlJustReleased(2, 237) then
            if inGreen(current) then
                PlaySoundFrontend(-1, 'Pin_Good', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', true)
                state[current].done = true
                state[current].active = false
                pinY[current] = 0.572
                current = current + 1
                if current > 7 then
                    success = true
                    finished = true
                    PlaySoundFrontend(-1, 'HACKING_SUCCESS', '', true)
                    Wait(1000)
                else
                    state[current].active = true
                    state[current].idle = false
                end
            else
                PlaySoundFrontend(-1, 'Pin_Bad', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', true)
                if current > 1 then
                    state[current].active = false
                    current = current - 1
                    state[current].done = false
                    state[current].active = true
                end
            end
        elseif IsControlJustReleased(2, 202) or IsControlJustPressed(0, 200) then
            finished = true
            success = false
        end

        Wait(0)
    end

    if HasScaleformMovieLoaded(scaleform) then
        SetScaleformMovieAsNoLongerNeeded(scaleform)
    end
    SetStreamedTextureDictAsNoLongerNeeded('hackingNG')
    active = false
    if cb then cb(success) end
    return success
end

exports('RunNativeDrill', RunNativeDrill)
exports('RunNativeDatacrack', RunNativeDatacrack)
exports('IsNativeMinigameActive', function()
    return active
end)
