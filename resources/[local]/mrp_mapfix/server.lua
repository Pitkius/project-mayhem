--- druglabs may run: O'Neil (brown_amfsted*) is archived out of stream.
--- Client mapfix still strips any leftover O'Neil druglab IPLs if they appear.

CreateThread(function()
    Wait(2000)
    if GetResourceState('druglabs') == 'started' then
        print('[mrp_mapfix] druglabs started — O\'Neil shells archived; La Mesa/Port labs active')
    end
end)
