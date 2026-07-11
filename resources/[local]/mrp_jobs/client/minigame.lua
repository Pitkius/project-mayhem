--[[
  mrp_jobs — minigame ADAPTERIS.
  Užduotys nurodo minigame per profilį (config/minigames.lua). Adapteris parenka
  tikrą realizaciją:
    - "fiziniai" tipai (sequence/hold/mash/drill) → mrp_hacking:RunPhysicalMinigame
    - kiti tipai → lengvas fallback (progress bar). Vėlesni etapai gali pridėti
      turtingesnius NUI minigame'us tiesiog papildydami šį adapterį.

  Naudojimas (blokuojantis):
    local ok, extra = Minigame.run(Config.GetMinigame('burger_grill'))
]]

Minigame = Minigame or {}

local PHYSICAL = {
    sequence = 'sequence',
    hold = 'hold',
    mash = 'mash',
    drill = 'drill',
}

-- Grąžina success(boolean), extra(table: { score, quality })
function Minigame.run(profile)
    profile = profile or {}
    local t = profile.type or 'timing'
    local attempts = math.max(1, tonumber(profile.attempts) or 1)

    -- 1) Fiziniai minigame'ai per mrp_hacking (jei įdiegtas).
    if PHYSICAL[t] and GetResourceState('mrp_hacking') == 'started' then
        for _ = 1, attempts do
            local ok = false
            local success = exports['mrp_hacking']:RunPhysicalMinigame(t, {
                label = profile.label or '',
                data = profile.data or {},
            })
            ok = success == true
            if ok then
                return true, { score = 1.0, quality = 'good' }
            end
        end
        return false, { score = 0.0, quality = 'poor' }
    end

    -- 2) Fallback — progress bar su galimybe atšaukti.
    -- (Placeholder: sėkmė = užbaigimas be atšaukimo. Turtingesni NUI minigame'ai
    --  bus pridėti vėlesniuose etapuose per šį patį adapterį.)
    local duration = tonumber(profile.duration) or (3000 + (tonumber(profile.difficulty) or 1) * 1000)
    -- Normalizuojam animaciją į QBCore Progressbar formatą (animDict/anim).
    local animOpt = {}
    if profile.anim then
        animOpt = {
            animDict = profile.anim.animDict or profile.anim.dict,
            anim = profile.anim.anim or profile.anim.clip,
            flags = profile.anim.flags or 49,
        }
    end
    local ok = JobProgress.run('mrp_jobs_mg', profile.label or 'Užduotis', duration, {
        canCancel = true,
        anim = animOpt,
    })
    if not ok then
        return false, { score = 0.0, quality = 'poor' }
    end
    -- Kokybė pagal sunkumą (kol nėra tikslaus skill įvertinimo) — vidutinė/gera.
    local score = 0.7
    return true, { score = score, quality = Utils.scoreToQuality(score) }
end
