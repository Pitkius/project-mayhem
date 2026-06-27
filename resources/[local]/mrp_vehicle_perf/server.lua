exports('CalculateVehiclePrice', function(model, category)
    local price, profile = VehiclePricing.CalculatePrice(model, category)
    return price, profile
end)

exports('GetVehiclePerfProfile', function(model, category)
    return VehiclePricing.ResolveProfile(model, category)
end)

exports('GetVehicleTierLabel', function(tier)
    return VehiclePricing.GetTierLabel(tier)
end)
