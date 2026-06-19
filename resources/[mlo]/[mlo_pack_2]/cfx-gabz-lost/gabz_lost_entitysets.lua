--- Lost MC interjero užkrovimą valdo `fivempro_mapfix` (vengti dvigubo IPL / kolizijos konflikto).
--- Export paliktas suderinamumui.

exports('ReloadLostMc', function()
    if GetResourceState('fivempro_mapfix') == 'started' then
        pcall(function()
            exports['fivempro_mapfix']:ReloadLostMc()
        end)
    end
end)
