PhoneApps = PhoneApps or {}

--- App ids available per phone type. Same shell; filtered by type.
PhoneApps.ByType = {
    legal = {
        'calls', 'messages', 'contacts', 'settings',
        'camera', 'gallery', 'notes', 'appstore',
        'ads', 'insta', 'bank', 'weather', 'carplay', 'maps',
    },
    darknet = {
        'darknet_market', 'encrypted_messages', 'dead_drops', 'settings',
    },
}

PhoneApps.Meta = {
    calls = { label = 'Skambučiai', icon = 'calls' },
    messages = { label = 'Žinutės', icon = 'messages' },
    contacts = { label = 'Kontaktai', icon = 'contacts' },
    settings = { label = 'Nustatymai', icon = 'settings' },
    camera = { label = 'Kamera', icon = 'camera' },
    gallery = { label = 'Galerija', icon = 'gallery' },
    notes = { label = 'Užrašai', icon = 'notes' },
    appstore = { label = 'Programėlės', icon = 'appstore' },
    ads = { label = 'Skelbimai', icon = 'ads' },
    insta = { label = 'LifeGram', icon = 'insta' },
    bank = { label = 'BANKAS', icon = 'bank' },
    weather = { label = 'Orai', icon = 'weather' },
    carplay = { label = 'CarPlay', icon = 'carplay' },
    maps = { label = 'Žemėlapis', icon = 'maps' },
    darknet_market = { label = 'DarkNet Market', icon = 'darknet_market' },
    encrypted_messages = { label = 'Encrypted', icon = 'encrypted_messages' },
    dead_drops = { label = 'Dead Drops', icon = 'dead_drops' },
}

--- Defaults installed on first activation (legal only; darknet uses full ByType list).
PhoneApps.LegalDefaults = {
    calls = true, messages = true, contacts = true, settings = true,
    camera = true, gallery = true, notes = true, appstore = true,
    ads = true, bank = true,
}

function PhoneApps.ListForType(phoneType)
    phoneType = PhoneTypes and PhoneTypes.Normalize(phoneType) or 'legal'
    local ids = PhoneApps.ByType[phoneType] or PhoneApps.ByType.legal
    local out = {}
    for _, id in ipairs(ids) do
        local meta = PhoneApps.Meta[id] or { label = id, icon = id }
        out[#out + 1] = {
            id = id,
            label = meta.label,
            icon = meta.icon,
        }
    end
    return out
end

function PhoneApps.IsAllowed(phoneType, appId)
    phoneType = PhoneTypes and PhoneTypes.Normalize(phoneType) or 'legal'
    appId = tostring(appId or '')
    for _, id in ipairs(PhoneApps.ByType[phoneType] or {}) do
        if id == appId then return true end
    end
    return false
end
