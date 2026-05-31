local QBCore = exports['qb-core']:GetCoreObject()

local theorySessions = {}
local pendingPractical = {}

local function shuffle(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    for i = #out, 2, -1 do
        local j = math.random(i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

local function shuffleQuestion(q)
    local answers = {}
    local correctText = q.answers[q.correct]
    for _, a in ipairs(q.answers) do
        answers[#answers + 1] = a
    end
    answers = shuffle(answers)
    local newCorrect = 1
    for i, a in ipairs(answers) do
        if a == correctText then
            newCorrect = i
            break
        end
    end
    return { q = q.q, answers = answers, correct = newCorrect }
end

local function hasLicence(Player, key)
    if not Player then return false end
    local licences = Player.PlayerData.metadata and Player.PlayerData.metadata.licences or {}
    return licences[key] == true
end

local function setLicence(Player, key, value)
    local licences = Player.PlayerData.metadata.licences or {}
    licences[key] = value == true
    Player.Functions.SetMetaData('licences', licences)
end

local function issueDriverItem(src, Player, cat)
    if cat.licenceKey ~= 'driver' then return end
    local items = Player.Functions.GetItemsByName('driver_license')
    for _, it in pairs(items or {}) do
        local info = it.info or {}
        if info.citizenid == Player.PlayerData.citizenid then return end
    end
    local charinfo = Player.PlayerData.charinfo or {}
    local info = {
        citizenid = Player.PlayerData.citizenid,
        firstname = charinfo.firstname or '',
        lastname = charinfo.lastname or '',
        birthdate = charinfo.birthdate or '',
        type = cat.licenceLabel,
    }
    if Player.Functions.AddItem('driver_license', 1, false, info) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items['driver_license'], 'add')
    end
end

QBCore.Functions.CreateCallback('fivempro_drivingschool:server:getLicenceStatus', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    local licences = Player.PlayerData.metadata.licences or {}
    cb(licences)
end)

QBCore.Functions.CreateCallback('fivempro_drivingschool:server:startTheory', function(source, cb, category)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false, nil, 'Klaida.') return end

    local cat = Config.Categories[category]
    if not cat then cb(false, nil, 'Nežinoma kategorija.') return end

    if hasLicence(Player, cat.licenceKey) then
        cb(false, nil, 'Jau turite šią licenciją.')
        return
    end

    if theorySessions[src] then
        cb(false, nil, 'Jau vyksta teorijos egzaminas.')
        return
    end

    local price = tonumber(cat.examPrice) or 0
    if price > 0 and Player.PlayerData.money.cash < price then
        cb(false, nil, ('Reikia $%s egzaminui.'):format(price))
        return
    end

    local pool = Config.Questions[category]
    if not pool or #pool < Config.TheoryQuestionCount then
        cb(false, nil, 'Klausimų bankas neparuoštas.')
        return
    end

    if price > 0 and not Player.Functions.RemoveMoney('cash', price, 'driving-school-exam') then
        cb(false, nil, 'Nepavyko apmokėti.')
        return
    end

    local picked = shuffle(pool)
    local questions = {}
    for i = 1, Config.TheoryQuestionCount do
        questions[i] = shuffleQuestion(picked[i])
    end

    local sessionId = ('%s_%s_%s'):format(src, category, os.time())
    theorySessions[src] = {
        sessionId = sessionId,
        category = category,
        questions = questions,
        index = 1,
        score = 0,
        total = Config.TheoryQuestionCount,
    }

    local clientQuestions = {}
    for _, q in ipairs(questions) do
        clientQuestions[#clientQuestions + 1] = { q = q.q, answers = q.answers }
    end

    cb(true, {
        sessionId = sessionId,
        questions = clientQuestions,
        total = Config.TheoryQuestionCount,
    }, nil)
end)

QBCore.Functions.CreateCallback('fivempro_drivingschool:server:submitTheoryAnswer', function(source, cb, sessionId, chosen)
    local src = source
    local session = theorySessions[src]
    if not session or session.sessionId ~= sessionId then
        cb({ done = true, passed = false, score = 0, total = Config.TheoryQuestionCount })
        return
    end

    local q = session.questions[session.index]
    if not q then
        theorySessions[src] = nil
        cb({ done = true, passed = false, score = session.score, total = session.total })
        return
    end

    if tonumber(chosen) == q.correct then
        session.score = session.score + 1
    end

    session.index = session.index + 1
    if session.index > session.total then
        local needed = math.ceil(session.total * (Config.TheoryPassPercent / 100))
        local passed = session.score >= needed
        if passed then
            pendingPractical[src] = session.category
        end
        theorySessions[src] = nil
        cb({
            done = true,
            passed = passed,
            score = session.score,
            total = session.total,
        })
        return
    end

    cb({ done = false, index = session.index })
end)

RegisterNetEvent('fivempro_drivingschool:server:practicalResult', function(category, passed)
    local src = source
    if pendingPractical[src] ~= category then return end
    pendingPractical[src] = nil

    if not passed then return end

    local Player = QBCore.Functions.GetPlayer(src)
    local cat = Config.Categories[category]
    if not Player or not cat then return end

    if hasLicence(Player, cat.licenceKey) then
        TriggerClientEvent('QBCore:Notify', src, 'Jau turite licenciją.', 'error')
        return
    end

    setLicence(Player, cat.licenceKey, true)
    issueDriverItem(src, Player, cat)
    TriggerClientEvent('QBCore:Notify', src, cat.licenceLabel .. ' suteikta!', 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    theorySessions[src] = nil
    pendingPractical[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    theorySessions = {}
    pendingPractical = {}
end)
