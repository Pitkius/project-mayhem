Config = {}

--- 1 EUR (Tebex package price) = 1 credit
Config.EurToCredits = 1

--- Official Tebex store (players buy here only)
Config.TebexStoreUrl = GetConvar('mrp_tebex_store', 'https://mayhem.tebex.io/')

--- Suggested packages for Tebex control panel (price EUR == credits)
Config.SuggestedPackages = {
    { name = '100 Kreditų', priceEur = 100, credits = 100 },
    { name = '500 Kreditų', priceEur = 500, credits = 500 },
    { name = '1000 Kreditų', priceEur = 1000, credits = 1000 },
    { name = '2500 Kreditų', priceEur = 2500, credits = 2500 },
    { name = '5000 Kreditų', priceEur = 5000, credits = 5000 },
}

--- Money account name in QBCore (must exist in QBConfig.Money.MoneyTypes)
Config.MoneyType = 'credits'

--- Discord webhook for purchase logs (optional, empty = off)
Config.DiscordWebhook = ''
