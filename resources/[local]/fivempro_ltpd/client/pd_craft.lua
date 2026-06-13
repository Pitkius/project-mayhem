local QBCore = exports['qb-core']:GetCoreObject()

local crafting = false

local function cfg()
    return Config.PdWeaponCraft or {}
end

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function openCraftMenu(stationKey)
    if crafting then return end
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:getPdCraftMenu', function(data)
        if not data then
            return notify('Ginklų gamyba neprieinama.', 'error')
        end
        local matLabel = QBCore.Shared.Items[data.materialItem] and QBCore.Shared.Items[data.materialItem].label or 'žaliavų'
        local headerTxt = ('Lygis %d / %d'):format(data.craftLevel, data.maxLevel)
        if data.craftsNeeded and data.craftLevel < data.maxLevel then
            headerTxt = headerTxt .. (' · %d/%d iki kito lygio'):format(data.craftsAtLevel, data.craftsNeeded)
        end

        local menu = {
            { header = 'Policijos ginklų gamyba', txt = headerTxt, isMenuHeader = true },
        }

        local lastLv = 0
        for _, row in ipairs(data.recipes or {}) do
            if row.craftLevel ~= lastLv then
                lastLv = row.craftLevel
                menu[#menu + 1] = {
                    header = ('— %d lygis —'):format(row.craftLevel),
                    isMenuHeader = true,
                }
            end
            local txt = table.concat(row.materials, ' · ') .. (' · ~%ds'):format(row.timeSec)
            if row.locked then
                txt = txt .. ' · užrakinta'
            elseif not row.canCraft then
                txt = txt .. ' · trūksta ' .. matLabel
            end
            menu[#menu + 1] = {
                header = ('%s → %dx %s'):format(row.label, row.outputCount, row.outputLabel),
                txt = txt,
                disabled = row.locked or not row.canCraft,
                params = {
                    isAction = true,
                    event = function()
                        TriggerEvent('qb-menu:client:closeMenu')
                        TriggerEvent('fivempro_ltpd:client:runPdCraft', stationKey, row.id)
                    end,
                },
            }
        end

        menu[#menu + 1] = {
            header = 'Uždaryti',
            params = { isAction = true, event = function() TriggerEvent('qb-menu:client:closeMenu') end },
        }

        if GetResourceState('qb-menu') == 'started' then
            TriggerEvent('qb-menu:client:openMenu', menu, false, true)
        else
            notify('Reikia qb-menu.', 'error')
        end
    end, stationKey)
end

RegisterNetEvent('fivempro_ltpd:client:openPdWeaponCraft', function(data)
    local key = data and data.stationKey
    if not key then return end
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= (Config.JobName or 'police') or not P.job.onduty then
        return notify('Tik policijai tarnyboje.', 'error')
    end
    openCraftMenu(key)
end)

RegisterNetEvent('fivempro_ltpd:client:runPdCraft', function(stationKey, recipeId)
    if crafting then return end
    local recipe = (cfg().recipes or {})[tostring(recipeId or '')]
    if not recipe then return end
    crafting = true
    local duration = tonumber(recipe.timeMs) or 10000
    local label = ('Gaminama: %s'):format(recipe.label or recipeId)

    QBCore.Functions.Progressbar('ltpd_weapon_craft', label, duration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableCombat = true,
    }, {
        animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        anim = 'machinic_loop_mechandplayer',
        flags = 49,
    }, {}, {}, function()
        crafting = false
        TriggerServerEvent('fivempro_ltpd:server:pdWeaponCraft', stationKey, recipeId)
    end, function()
        crafting = false
        notify('Gamyba atšaukta.', 'error')
    end)
end)
