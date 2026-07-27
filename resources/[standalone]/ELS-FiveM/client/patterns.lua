els_patterns = {}

--- Guard: pattern runners crash if pattern id is missing or elsVehs[k] is cleared mid-flash.
local function resolvePatternId(pattern)
    local id = tonumber(pattern) or 1
    if id < 1 then id = 1 end
    return id
end

local function elsState(k)
    return elsVehs and elsVehs[k] or nil
end

function getNumberOfPrimaryPatterns(veh)
    local info = getVehicleVCFInfo(veh)
    if not info or info == false then return 0 end
    local count = 0
    if info.priml and info.priml.type == "leds" then
        for _, v in pairs(led_PrimaryPatterns) do
            if v ~= nil then count = count + 1 end
        end
    elseif info.priml and info.priml.type == "chp" then
        count = 3
    end
    return count
end

function getNumberOfSecondaryPatterns(veh)
    local info = getVehicleVCFInfo(veh)
    if not info or info == false then return 0 end
    local count = 0
    if info.secl and info.secl.type == "leds" then
        for _, v in pairs(led_SecondaryPatterns) do
            if v ~= nil then count = count + 1 end
        end
    end
    if info.secl and info.secl.type == "traf" then
        for _, v in pairs(traf_Patterns) do
            if v ~= nil then count = count + 1 end
        end
    end
    if info.secl and info.secl.type == "chp" then
        count = 3
    end
    return count
end

function getNumberOfAdvisorPatterns(veh)
    local info = getVehicleVCFInfo(veh)
    if not info or info == false then return 0 end
    local count = 0
    if info.wrnl and info.wrnl.type == "leds" then
        for _, v in pairs(leds_WarningPatterns) do
            if v ~= nil then count = count + 1 end
        end
    end
    if info.secl and info.secl.type == "chp" then
        count = 1
    end
    return count
end

function runEnvironmentLight(k, extra)
    Citizen.CreateThread(function()
        if not k or IsEntityDead(k) then return end
        local vehN = checkCarHash(k)
        local vehCfg = els_Vehicles and els_Vehicles[vehN]
        local extraCfg = vehCfg and vehCfg.extras and vehCfg.extras[extra]
        if not extraCfg or not extraCfg.env_light then return end

        local boneIndex = GetEntityBoneIndexByName(k, "extra_" .. extra)
        if not boneIndex or boneIndex == -1 then return end
        local coords = GetWorldPositionOfEntityBone(k, boneIndex)
        local pos = extraCfg.env_pos
        local color = extraCfg.env_color
        if not pos or not color then return end

        for _ = 1, 6 do
            if IsVehicleExtraTurnedOn(k, extra) == false then break end
            DrawLightWithRangeAndShadow(
                coords.x + pos.x, coords.y + pos.y, coords.z + pos.z,
                color.r, color.g, color.b,
                50.0, environmentLightBrightness, 5.0
            )
            Wait(2)
        end
    end)
end

local chpPatternReady = {}
function runCHPPattern(k, pattern, stage)
    Citizen.CreateThread(function()
        if (not IsEntityDead(k) and DoesEntityExist(k) and (chpPatternReady[k] or chpPatternReady[k] == nil)) then

                chpPatternReady[k] = false

                local done = {}
                for i=1, 10 do
                    done[i] = false
                end

                if stage == 1 then
                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageOne[pattern][1]) do
                            local c = tonumber(string.sub(chp_StageOne[pattern][1], spot, spot) )
                            setExtraState(k, 1, c)
                            if c == 0 then
                                runEnvironmentLight(k, 1)
                            end

                            if not elsState(k) or elsState(k).advisorPattern ~= pattern then
                                done[1] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageOne[pattern][1]) then
                                done[1] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageOne[pattern][2]) do
                            local c = tonumber(string.sub(chp_StageOne[pattern][2], spot, spot) )
                            setExtraState(k, 2, c)
                            if c == 0 then
                                runEnvironmentLight(k, 2)
                            end

                            if not elsState(k) or elsState(k).advisorPattern ~= pattern then
                                done[2] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageOne[pattern][2]) then
                                done[2] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageOne[pattern][3]) do
                            local c = tonumber(string.sub(chp_StageOne[pattern][3], spot, spot) )
                            setExtraState(k, 3, c)
                            if c == 0 then
                                runEnvironmentLight(k, 3)
                            end

                            if not elsState(k) or elsState(k).advisorPattern ~= pattern then
                                done[3] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageOne[pattern][3]) then
                                done[3] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageOne[pattern][4]) do
                            local c = tonumber(string.sub(chp_StageOne[pattern][4], spot, spot) )
                            setExtraState(k, 4, c)
                            if c == 0 then
                                runEnvironmentLight(k, 4)
                            end

                            if not elsState(k) or elsState(k).advisorPattern ~= pattern then
                                done[4] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageOne[pattern][4]) then
                                done[4] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageOne[pattern][5]) do
                            local c = tonumber(string.sub(chp_StageOne[pattern][5], spot, spot) )
                            setExtraState(k, 5, c)
                            if c == 0 then
                                runEnvironmentLight(k, 5)
                            end

                            if not elsState(k) or elsState(k).advisorPattern ~= pattern then
                                done[5] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageOne[pattern][5]) then
                                done[5] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageOne[pattern][6]) do
                            local c = tonumber(string.sub(chp_StageOne[pattern][6], spot, spot) )
                            setExtraState(k, 6, c)
                            if c == 0 then
                                runEnvironmentLight(k, 6)
                            end

                            if not elsState(k) or elsState(k).advisorPattern ~= pattern then
                                done[6] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageOne[pattern][6]) then
                                done[6] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageOne[pattern][7]) do
                            local c = tonumber(string.sub(chp_StageOne[pattern][7], spot, spot) )
                            setExtraState(k, 7, c)
                            if c == 0 then
                                runEnvironmentLight(k, 7)
                            end

                            if not elsState(k) or elsState(k).advisorPattern ~= pattern then
                                done[7] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageOne[pattern][7]) then
                                done[7] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageOne[pattern][8]) do
                            local c = tonumber(string.sub(chp_StageOne[pattern][8], spot, spot) )
                            setExtraState(k, 8, c)
                            if c == 0 then
                                runEnvironmentLight(k, 8)
                            end

                            if not elsState(k) or elsState(k).advisorPattern ~= pattern then
                                done[8] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageOne[pattern][8]) then
                                done[8] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageOne[pattern][9]) do
                            local c = tonumber(string.sub(chp_StageOne[pattern][9], spot, spot) )
                            setExtraState(k, 9, c)
                            if c == 0 then
                                runEnvironmentLight(k, 9)
                            end

                            if not elsState(k) or elsState(k).advisorPattern ~= pattern then
                                done[9] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageOne[pattern][9]) then
                                done[9] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageOne[pattern][10]) do
                            local c = tonumber(string.sub(chp_StageOne[pattern][10], spot, spot) )
                            setExtraState(k, 10, c)
                            if c == 0 then
                                runEnvironmentLight(k, 10)
                            end

                            if not elsState(k) or elsState(k).advisorPattern ~= pattern then
                                done[10] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageOne[pattern][10]) then
                                done[10] = true
                                break
                            end
                        end

                        return
                    end)
                elseif stage == 2 then
                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageTwo[pattern][1]) do
                            local c = tonumber(string.sub(chp_StageTwo[pattern][1], spot, spot) )
                            setExtraState(k, 1, c)
                            if c == 0 then
                                runEnvironmentLight(k, 1)
                            end

                            if not elsState(k) or elsState(k).secPattern ~= pattern then
                                done[1] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageTwo[pattern][1]) then
                                done[1] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageTwo[pattern][2]) do
                            local c = tonumber(string.sub(chp_StageTwo[pattern][2], spot, spot) )
                            setExtraState(k, 2, c)
                            if c == 0 then
                                runEnvironmentLight(k, 2)
                            end

                            if not elsState(k) or elsState(k).secPattern ~= pattern then
                                done[2] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageTwo[pattern][2]) then
                                done[2] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageTwo[pattern][3]) do
                            local c = tonumber(string.sub(chp_StageTwo[pattern][3], spot, spot) )
                            setExtraState(k, 3, c)
                            if c == 0 then
                                runEnvironmentLight(k, 3)
                            end

                            if not elsState(k) or elsState(k).secPattern ~= pattern then
                                done[3] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageTwo[pattern][3]) then
                                done[3] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageTwo[pattern][4]) do
                            local c = tonumber(string.sub(chp_StageTwo[pattern][4], spot, spot) )
                            setExtraState(k, 4, c)
                            if c == 0 then
                                runEnvironmentLight(k, 4)
                            end

                            if not elsState(k) or elsState(k).secPattern ~= pattern then
                                done[4] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageTwo[pattern][4]) then
                                done[4] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageTwo[pattern][5]) do
                            local c = tonumber(string.sub(chp_StageTwo[pattern][5], spot, spot) )
                            setExtraState(k, 5, c)
                            if c == 0 then
                                runEnvironmentLight(k, 5)
                            end

                            if not elsState(k) or elsState(k).secPattern ~= pattern then
                                done[5] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageTwo[pattern][5]) then
                                done[5] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageTwo[pattern][6]) do
                            local c = tonumber(string.sub(chp_StageTwo[pattern][6], spot, spot) )
                            setExtraState(k, 6, c)
                            if c == 0 then
                                runEnvironmentLight(k, 6)
                            end

                            if not elsState(k) or elsState(k).secPattern ~= pattern then
                                done[6] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageTwo[pattern][6]) then
                                done[6] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageTwo[pattern][7]) do
                            local c = tonumber(string.sub(chp_StageTwo[pattern][7], spot, spot) )
                            setExtraState(k, 7, c)
                            if c == 0 then
                                runEnvironmentLight(k, 7)
                            end

                            if not elsState(k) or elsState(k).secPattern ~= pattern then
                                done[7] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageTwo[pattern][7]) then
                                done[7] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageTwo[pattern][8]) do
                            local c = tonumber(string.sub(chp_StageTwo[pattern][8], spot, spot) )
                            setExtraState(k, 8, c)
                            if c == 0 then
                                runEnvironmentLight(k, 8)
                            end

                            if not elsState(k) or elsState(k).secPattern ~= pattern then
                                done[8] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageTwo[pattern][8]) then
                                done[8] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageTwo[pattern][9]) do
                        local c = tonumber(string.sub(chp_StageTwo[pattern][9], spot, spot) )
                            setExtraState(k, 9, c)
                            if c == 0 then
                                runEnvironmentLight(k, 9)
                            end

                            if not elsState(k) or elsState(k).secPattern ~= pattern then
                                done[9] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageTwo[pattern][9]) then
                                done[9] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageTwo[pattern][10]) do
                            local c = tonumber(string.sub(chp_StageTwo[pattern][10], spot, spot) )
                            setExtraState(k, 10, c)
                            if c == 0 then
                                runEnvironmentLight(k, 10)
                            end

                            if not elsState(k) or elsState(k).secPattern ~= pattern then
                                done[10] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageTwo[pattern][10]) then
                                done[10] = true
                                break
                            end
                        end

                        return
                    end)
                elseif stage == 3 then
                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageThree[pattern][1]) do
                            local c = tonumber(string.sub(chp_StageThree[pattern][1], spot, spot) )
                            setExtraState(k, 1, c)
                            if c == 0 then
                                runEnvironmentLight(k, 1)
                            end

                            if not elsState(k) or elsState(k).primPattern ~= pattern then
                                done[1] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageThree[pattern][1]) then
                                done[1] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageThree[pattern][2]) do
                            local c = tonumber(string.sub(chp_StageThree[pattern][2], spot, spot) )
                            setExtraState(k, 2, c)
                            if c == 0 then
                                runEnvironmentLight(k, 2)
                            end

                            if not elsState(k) or elsState(k).primPattern ~= pattern then
                                done[2] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageThree[pattern][2]) then
                                done[2] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageThree[pattern][3]) do
                            local c = tonumber(string.sub(chp_StageThree[pattern][3], spot, spot) )
                            setExtraState(k, 3, c)
                            if c == 0 then
                                runEnvironmentLight(k, 3)
                            end

                            if not elsState(k) or elsState(k).primPattern ~= pattern then
                                done[3] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageThree[pattern][3]) then
                                done[3] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageThree[pattern][4]) do
                            local c = tonumber(string.sub(chp_StageThree[pattern][4], spot, spot) )
                            setExtraState(k, 4, c)
                            if c == 0 then
                                runEnvironmentLight(k, 4)
                            end

                            if not elsState(k) or elsState(k).primPattern ~= pattern then
                                done[4] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageThree[pattern][4]) then
                                done[4] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageThree[pattern][5]) do
                            local c = tonumber(string.sub(chp_StageThree[pattern][5], spot, spot) )
                            setExtraState(k, 5, c)
                            if c == 0 then
                                runEnvironmentLight(k, 5)
                            end

                            if not elsState(k) or elsState(k).primPattern ~= pattern then
                                done[5] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageThree[pattern][5]) then
                                done[5] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageThree[pattern][6]) do
                            local c = tonumber(string.sub(chp_StageThree[pattern][6], spot, spot) )
                            setExtraState(k, 6, c)
                            if c == 0 then
                                runEnvironmentLight(k, 6)
                            end

                            if not elsState(k) or elsState(k).primPattern ~= pattern then
                                done[6] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageThree[pattern][6]) then
                                done[6] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageThree[pattern][7]) do
                            local c = tonumber(string.sub(chp_StageThree[pattern][7], spot, spot) )
                            setExtraState(k, 7, c)
                            if c == 0 then
                                runEnvironmentLight(k, 7)
                            end

                            if not elsState(k) or elsState(k).primPattern ~= pattern then
                                done[7] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageThree[pattern][7]) then
                                done[7] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageThree[pattern][8]) do
                            local c = tonumber(string.sub(chp_StageThree[pattern][8], spot, spot) )
                            setExtraState(k, 8, c)
                            if c == 0 then
                                runEnvironmentLight(k, 8)
                            end

                            if not elsState(k) or elsState(k).primPattern ~= pattern then
                                done[8] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageThree[pattern][8]) then
                                done[8] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageThree[pattern][9]) do
                            local c = tonumber(string.sub(chp_StageThree[pattern][9], spot, spot) )
                            setExtraState(k, 9, c)
                            if c == 0 then
                                runEnvironmentLight(k, 9)
                            end

                            if not elsState(k) or elsState(k).primPattern ~= pattern then
                                done[9] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageThree[pattern][9]) then
                                done[9] = true
                                break
                            end
                        end

                        return
                    end)

                    Citizen.CreateThread(function()
                        for spot = 1, string.len(chp_StageThree[pattern][10]) do
                            local c = tonumber(string.sub(chp_StageThree[pattern][10], spot, spot) )
                            setExtraState(k, 10, c)
                            if c == 0 then
                                runEnvironmentLight(k, 10)
                            end

                            if not elsState(k) or elsState(k).primPattern ~= pattern then
                                done[10] = true
                                break
                            end

                            Wait(GetConvarInt("els_lightDelay", 10))

                            if spot == string.len(chp_StageThree[pattern][10]) then
                                done[10] = true
                                break
                            end
                        end

                        return
                    end)
                end

                while (not done[1] or not done[2] or not done[3] or not done[4] or not done[5] or not done[6] or not done[7] or not done[8] or not done[9] or not done[10]) do Wait(0) end
                if done[1] and done[2] and done[3] and done[4] and done[5] and done[6] and done[7] and done[8] and done[9] and done[10] then
                    chpPatternReady[k] = true
                end
        end
    end)
end


trafFR = 0
local trafPatternReady = {}
function runTrafPattern(k, pattern) 
    Citizen.CreateThread(function()
        if (not IsEntityDead(k) and DoesEntityExist(k) and (trafPatternReady[k] or trafPatternReady[k] == nil)) then
            if (GetGameTimer() - trafFR >= GetConvarInt("els_lightDelay", 10)) then

                trafPatternReady[k] = false

                local done = {}
                for i=1, 3 do
                    done[i] = false
                end

                Citizen.CreateThread(function()
                    for spot = 1, string.len(traf_Patterns[pattern][7]) do
                        local c = tonumber(string.sub(traf_Patterns[pattern][7], spot, spot) )
                        setExtraState(k, 7, c)
                        if c == 0 then
                            runEnvironmentLight(k, 7)
                        end

                        if not elsState(k) or elsState(k).secPattern ~= pattern then
                            done[1] = true
                            break
                        end

                        if not elsState(k) or not elsState(k).secondary then
                            done[1] = true
                            break
                        end

                        Wait(GetConvarInt("els_flashDelay", 15))

                        if spot == string.len(traf_Patterns[pattern][7]) then
                            done[1] = true
                            break
                        end
                    end

                    return
                end)

                Citizen.CreateThread(function()
                    for spot = 1, string.len(traf_Patterns[pattern][8]) do
                        local c = tonumber(string.sub(traf_Patterns[pattern][8], spot, spot) )
                        setExtraState(k, 8, c)
                        if c == 0 then
                            runEnvironmentLight(k, 8)
                        end

                        if not elsState(k) or elsState(k).secPattern ~= pattern then
                            done[2] = true
                            break
                        end

                        if not elsState(k) or not elsState(k).secondary then
                            done[2] = true
                            break
                        end

                        Wait(GetConvarInt("els_flashDelay", 15))

                        if spot == string.len(traf_Patterns[pattern][8]) then
                            done[2] = true
                            break
                        end
                    end

                    return
                end)

                Citizen.CreateThread(function()
                    for spot = 1, string.len(traf_Patterns[pattern][9]) do
                        local c = tonumber(string.sub(traf_Patterns[pattern][9], spot, spot) )
                        setExtraState(k, 9, c)
                        if c == 0 then
                            runEnvironmentLight(k, 9)
                        end

                        if not elsState(k) or elsState(k).secPattern ~= pattern then
                            done[3] = true
                            break
                        end

                        if not elsState(k) or not elsState(k).secondary then
                            done[3] = true
                            break
                        end

                        Wait(GetConvarInt("els_flashDelay", 15))

                        if spot == string.len(traf_Patterns[pattern][9]) then
                            done[3] = true
                            break
                        end
                    end

                    return
                end)

                while (not done[1] or not done[2] or not done[3]) do Wait(0) end
                if done[1] and done[2] and done[3] then
                    trafPatternReady[k] = true
                end

                trafFR = GetGameTimer()
            end
        end
    end)
end

secdFR = 0
local ledSecondaryReady = {}
function runLedPatternSecondary(k, pattern)
    Citizen.CreateThread(function()
        pattern = resolvePatternId(pattern)
        if not led_SecondaryPatterns[pattern] or not led_SecondaryPatterns[pattern][7] or not led_SecondaryPatterns[pattern][8] or not led_SecondaryPatterns[pattern][9] then
            ledSecondaryReady[k] = true
            return
        end
        if (not IsEntityDead(k) and DoesEntityExist(k) and (ledSecondaryReady[k] or ledSecondaryReady[k] == nil)) then
            if (GetGameTimer() - trafFR >= GetConvarInt("els_lightDelay", 10)) then

                ledSecondaryReady[k] = false

                local done = {}
                for i=1, 3 do
                    done[i] = false
                end

                Citizen.CreateThread(function()
                    for spot = 1, string.len(led_SecondaryPatterns[pattern][7]) do
                        local c = tonumber(string.sub(led_SecondaryPatterns[pattern][7], spot, spot) )

                        setExtraState(k, 7, c)
                        if c == 0 then
                            runEnvironmentLight(k, 7)
                        end

                        if elsState(k) ~= nil then
                            if elsState(k).secPattern ~= pattern then
                                done[1] = true
                                ledSecondary = 1
                                break
                            end
                        end

                        if not elsState(k) or not elsState(k).secondary then
                            done[1] = true
                            break
                        end


                        Wait(GetConvarInt("els_flashDelay", 15))

                        if spot == string.len(led_SecondaryPatterns[pattern][7]) then
                            done[1] = true
                            break
                        end
                    end

                    return
                end)

                Citizen.CreateThread(function()
                    for spot = 1, string.len(led_SecondaryPatterns[pattern][8]) do
                        local c = tonumber(string.sub(led_SecondaryPatterns[pattern][8], spot, spot) )

                        setExtraState(k, 8, c)
                        if c == 0 then
                            runEnvironmentLight(k, 8)
                        end

                        if elsState(k) ~= nil then
                            if elsState(k).secPattern ~= pattern then
                                done[2] = true
                                ledSecondary = 1
                                break
                            end
                        end

                        if not elsState(k) or not elsState(k).secondary then
                            done[2] = true
                            break
                        end


                        Wait(GetConvarInt("els_flashDelay", 15))

                        if spot == string.len(led_SecondaryPatterns[pattern][8]) then
                            done[2] = true
                            break
                        end
                    end

                    return
                end)

                Citizen.CreateThread(function()
                    for spot = 1, string.len(led_SecondaryPatterns[pattern][9]) do
                        local c = tonumber(string.sub(led_SecondaryPatterns[pattern][9], spot, spot) )
                        setExtraState(k, 9, c)
                        if c == 0 then
                            runEnvironmentLight(k, 9)
                        end

                        if elsState(k) ~= nil then
                            if elsState(k).secPattern ~= pattern then
                                done[3] = true
                                ledSecondary = 1
                                break
                            end
                        end

                        if not elsState(k) or not elsState(k).secondary then
                            done[3] = true
                            break
                        end


                        Wait(GetConvarInt("els_flashDelay", 15))

                        if spot == string.len(led_SecondaryPatterns[pattern][9]) then
                            done[3] = true
                            break
                        end
                    end

                    return
                end)

                while (not done[1] or not done[2] or not done[3]) do Wait(0) end
                if done[1] and done[2] and done[3] then
                    ledSecondaryReady[k] = true
                end
                secdFR = GetGameTimer()
            end
        end
    end)
end

warnFR = 0
local ledWarningReady = {}
function runLedPatternWarning(k, pattern) 
    Citizen.CreateThread(function()
        pattern = resolvePatternId(pattern)
        if not leds_WarningPatterns[pattern] or not leds_WarningPatterns[pattern][5] or not leds_WarningPatterns[pattern][6] then
            ledWarningReady[k] = true
            return
        end
        if (not IsEntityDead(k) and DoesEntityExist(k) and (ledWarningReady[k] or ledWarningReady[k] == nil)) then
            if (GetGameTimer() - warnFR >= GetConvarInt("els_lightDelay", 10)) then

                ledWarningReady[k] = false

                local done = {}
                for i=1, 3 do
                    done[i] = false
                end

                Citizen.CreateThread(function()
                    for spot = 1, string.len(leds_WarningPatterns[pattern][5]) do
                        local c = tonumber(string.sub(leds_WarningPatterns[pattern][5], spot, spot) )
                        setExtraState(k, 5, c)
                        if c == 0 then
                            runEnvironmentLight(k, 5)
                        end

                        if not elsState(k) or elsState(k).advisorPattern ~= pattern then
                            done[1] = true
                            break
                        end

                        if not elsState(k) or not elsState(k).warning then
                            done[1] = true
                            break
                        end


                        Wait(GetConvarInt("els_flashDelay", 15))

                        if spot == string.len(leds_WarningPatterns[pattern][5]) then
                            done[1] = true
                            break
                        end
                    end

                    return
                end)

                Citizen.CreateThread(function()
                    for spot = 1, string.len(leds_WarningPatterns[pattern][6]) do
                        local c = tonumber(string.sub(leds_WarningPatterns[pattern][6], spot, spot) )
                        setExtraState(k, 6, c)
                        if c == 0 then
                            runEnvironmentLight(k, 6)
                        end

                        if not elsState(k) or elsState(k).advisorPattern ~= pattern then
                            done[2] = true
                            break
                        end

                        if not elsState(k) or not elsState(k).warning then
                            done[2] = true
                            break
                        end


                        Wait(GetConvarInt("els_flashDelay", 15))

                        if spot == string.len(leds_WarningPatterns[pattern][6]) then
                            done[2] = true
                            break
                        end
                    end

                    return
                end)

                while (not done[1] or not done[2]) do Wait(0) end
                if done[1] and done[2] then
                    ledWarningReady[k] = true
                end
                warnFR = GetGameTimer()
            end
        end
    end)
end

primFR = 0
local ledPrimaryReady = {}
function runLedPatternPrimary(k, pattern) 
    Citizen.CreateThread(function()
        pattern = resolvePatternId(pattern)
        if not led_PrimaryPatterns[pattern] or not led_PrimaryPatterns[pattern][1] or not led_PrimaryPatterns[pattern][2] or not led_PrimaryPatterns[pattern][3] or not led_PrimaryPatterns[pattern][4] then
            ledPrimaryReady[k] = true
            return
        end
        if (not IsEntityDead(k) and DoesEntityExist(k) and (ledPrimaryReady[k] or ledPrimaryReady[k] == nil)) then
            if (GetGameTimer() - primFR >= GetConvarInt("els_lightDelay", 10)) then
                ledPrimaryReady[k] = false

                local done = {}
                for i=1, 4 do
                    done[i] = false
                end

                Citizen.CreateThread(function()
                    for spot = 1, string.len(led_PrimaryPatterns[pattern][1]) do
                        local c = tonumber(string.sub(led_PrimaryPatterns[pattern][1], spot, spot) )
                        setExtraState(k, 1, c)
                        if c == 0 then
                            runEnvironmentLight(k, 1)
                        end

                        if not elsState(k) or elsState(k).primPattern ~= pattern then
                            done[1] = true
                            break
                        end

                        if not elsState(k) or not elsState(k).primary then
                            done[1] = true
                            break
                        end


                        Wait(GetConvarInt("els_flashDelay", 15))

                        if spot == string.len(led_PrimaryPatterns[pattern][1]) then
                            done[1] = true
                            break
                        end
                    end

                    return
                end)

                Citizen.CreateThread(function()
                    for spot = 1, string.len(led_PrimaryPatterns[pattern][2]) do
                        local c = tonumber(string.sub(led_PrimaryPatterns[pattern][2], spot, spot) )
                        setExtraState(k, 2, c)
                        if c == 0 then
                            runEnvironmentLight(k, 2)
                        end

                        if not elsState(k) or elsState(k).primPattern ~= pattern then
                            done[2] = true
                            break
                        end

                        if not elsState(k) or not elsState(k).primary then
                            done[2] = true
                            break
                        end

                        Wait(GetConvarInt("els_flashDelay", 15))

                        if spot == string.len(led_PrimaryPatterns[pattern][2]) then
                            done[2] = true
                            break
                        end
                    end

                    return
                end)

                Citizen.CreateThread(function()
                    for spot = 1, string.len(led_PrimaryPatterns[pattern][3]) do
                        local c = tonumber(string.sub(led_PrimaryPatterns[pattern][3], spot, spot) )
                        setExtraState(k, 3, c)
                        if c == 0 then
                            runEnvironmentLight(k, 3)
                        end

                        if not elsState(k) or elsState(k).primPattern ~= pattern then
                            done[3] = true
                            break
                        end
                        
                        if not elsState(k) or not elsState(k).primary then
                            done[3] = true
                            break
                        end

                        Wait(GetConvarInt("els_flashDelay", 15))

                        if spot == string.len(led_PrimaryPatterns[pattern][3]) then
                            done[3] = true
                            break
                        end
                    end

                    return
                end)

                Citizen.CreateThread(function()
                    for spot = 1, string.len(led_PrimaryPatterns[pattern][4]) do
                        local c = tonumber(string.sub(led_PrimaryPatterns[pattern][4], spot, spot) )
                        setExtraState(k, 4, c)
                        if c == 0 then
                            runEnvironmentLight(k, 4)
                        end

                        if not elsState(k) or elsState(k).primPattern ~= pattern then
                            done[4] = true
                            break
                        end

                        if not elsState(k) or not elsState(k).primary then
                            done[4] = true
                            break
                        end

                        Wait(GetConvarInt("els_flashDelay", 15))

                        if spot == string.len(led_PrimaryPatterns[pattern][4]) then
                            done[4] = true
                            break
                        end
                    end

                    return
                end)
                
                while (not done[1] or not done[2] or not done[3] or not done[4]) do Wait(0) end
                if done[1] and done[2] and done[3] and done[4] then
                    ledPrimaryReady[k] = true
                end
                primFR = GetGameTimer()
            end
        end
    end)
end