RegisterNetEvent('mrp_credits:client:balance', function(bal)
    --- Dashboard NUI lives in mrp_dashboard — forward there
    TriggerEvent('mrp_dashboard:client:setCredits', tonumber(bal) or 0)
end)
