PhoneTypes = PhoneTypes or {}

PhoneTypes.LEGAL = 'legal'
PhoneTypes.DARKNET = 'darknet'

PhoneTypes.ItemByType = {
    legal = 'phone',
    darknet = 'darknet_phone',
}

PhoneTypes.TypeByItem = {
    phone = 'legal',
    darknet_phone = 'darknet',
}

function PhoneTypes.Normalize(t)
    t = tostring(t or ''):lower()
    if t == PhoneTypes.DARKNET then return PhoneTypes.DARKNET end
    return PhoneTypes.LEGAL
end

function PhoneTypes.FromItem(itemName)
    return PhoneTypes.TypeByItem[tostring(itemName or '')] or PhoneTypes.LEGAL
end

function PhoneTypes.ItemFor(phoneType)
    phoneType = PhoneTypes.Normalize(phoneType)
    return PhoneTypes.ItemByType[phoneType] or 'phone'
end
