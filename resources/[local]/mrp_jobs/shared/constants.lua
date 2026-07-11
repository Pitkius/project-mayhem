--[[
  mrp_jobs — bendros konstantos (shared: serveris ir klientas)
  Naudojamos vietoj "magic string" reikšmių, kad visi moduliai kalbėtų viena kalba.
]]

Constants = Constants or {}

-- ── Aktyvaus darbo sesijos būsenos ────────────────────────────────
Constants.JobState = {
    NONE      = 'none',       -- neaktyvus
    SELECTING = 'selecting',  -- renkasi darbą / poziciją
    ACTIVE    = 'active',     -- vykdo užduotis
    DELIVERY  = 'delivery',   -- pristatymo faze (oil / vaisiai)
    COMPLETE  = 'complete',   -- pabaigtas, laukia atlygio / cooldown
}

-- ── Užduoties (task) būsenos ──────────────────────────────────────
Constants.TaskState = {
    PENDING = 'pending',
    ACTIVE  = 'active',
    DONE    = 'done',
    FAILED  = 'failed',
}

-- ── Minigame tipai (adapteris juos suriša su tikrais resursais) ───
Constants.Minigame = {
    TIMING       = 'timing',
    SKILLCHECK   = 'skillcheck',
    KEYSEQUENCE  = 'sequence',
    MEMORY       = 'memory',
    TEMPERATURE  = 'temperature',
    PRESSURE     = 'pressure',
    INGREDIENTS  = 'ingredient_order',
    PIPES        = 'pipe_connection',
    SORTING      = 'sorting',
    HOLD         = 'hold',
    MASH         = 'mash',
    DRILL        = 'drill',
}

-- ── Produkto kokybės pakopos (naudojama burgeriams / vaisiams) ────
Constants.Quality = {
    POOR    = 'poor',
    NORMAL  = 'normal',
    GOOD    = 'good',
    PERFECT = 'perfect',
}

-- Kokybės eiliškumas (score -> pakopa), naudojamas serverio pusėje.
Constants.QualityOrder = { 'poor', 'normal', 'good', 'perfect' }

-- ── Piniginės tipai ───────────────────────────────────────────────
Constants.Account = {
    CASH = 'cash',
    BANK = 'bank',
}

-- ── Log kategorijos (persistence / audit) ─────────────────────────
Constants.LogCat = {
    START   = 'start',
    STOP    = 'stop',
    REWARD  = 'reward',
    TASK    = 'task',
    ORDER   = 'order',
    DELIVERY= 'delivery',
}
