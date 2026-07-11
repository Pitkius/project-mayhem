--[[
  mrp_jobs — atlygio išmokėjimas (serveris, autoritetingas).
  Klientas NIEKADA nenurodo sumos. Sumą apskaičiuoja darbo modulis serveryje
  ir perduoda čia. Ši funkcija tik saugiai išmoka ir loguoja.
]]

local QBCore = exports['qb-core']:GetCoreObject()

Rewards = Rewards or {}

-- Saugus atlygio išmokėjimas.
-- src: žaidėjo šaltinis; amount: sveika suma; account: 'cash'|'bank'; reason: log eilutė.
-- Grąžina true jei išmokėta.
function Rewards.pay(src, amount, account, reason, meta)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    account = account == Constants.Account.CASH and 'cash' or 'bank'

    Player.Functions.AddMoney(account, amount, reason or 'mrp_jobs')

    local session = JobManager.getBySource(src)
    if session then
        session.paidTotal = (session.paidTotal or 0) + amount
    end
    if Persistence then
        Persistence.log(Player.PlayerData.citizenid,
            session and session.jobType or (meta and meta.jobType),
            session and session.role or (meta and meta.role),
            Constants.LogCat.REWARD, amount, meta)
    end
    return true
end

-- Bendra formulė-pagalbininkė: suapvalina ir pritaiko kokybės koeficientą.
-- base: bazinė suma; qualityMult: lentelė { poor=0.9, normal=1.0, good=1.1, perfect=1.25 }
function Rewards.applyQuality(base, quality, qualityMult)
    qualityMult = qualityMult or {}
    local m = qualityMult[quality] or 1.0
    return math.floor((tonumber(base) or 0) * m)
end
