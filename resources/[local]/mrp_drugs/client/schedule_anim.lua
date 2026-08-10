local activeProp = nil

local MODE_ANIMS = {
    trim = { dict = 'anim@amb@business@weed@weed_sorting_seated@', clip = 'sorter_right_sort_v3_weeddry01c', prop = 'prop_cs_scissors' },
    pack_bag = { dict = 'mp_common', clip = 'givetake1_a', prop = 'prop_meth_bag_01' },
    pack_brick = { dict = 'mp_common', clip = 'givetake1_a', prop = 'prop_meth_bag_01' },
    pack_bottle = { dict = 'amb@prop_human_parking_meter@female@idle_a', clip = 'idle_a_female', prop = 'prop_cs_script_bottle' },
    distill = { dict = 'amb@world_human_stand_fire@male@idle_a', clip = 'idle_a', prop = nil },
    cook = { dict = 'amb@world_human_stand_fire@male@idle_a', clip = 'idle_a', prop = nil },
    crystal = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', clip = 'coke_cut_v1_coccutter', prop = nil },
    meth_crystal = { dict = 'amb@prop_human_parking_meter@female@idle_a', clip = 'idle_a_female', prop = 'prop_cs_script_bottle' },
    press = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', clip = 'coke_cut_v1_coccutter', prop = nil },
    pills_press = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', clip = 'coke_cut_v1_coccutter', prop = nil },
    wash = { dict = 'amb@world_human_maid_clean@', clip = 'base', prop = 'prop_sponge_01' },
    mix = { dict = 'amb@world_human_bum_wash@male@high@base', clip = 'base', prop = nil },
    plant = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', prop = nil },
    weed_soil = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', prop = nil },
    weed_seed = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', prop = nil },
    weed_water = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', prop = 'prop_wateringcan' },
    weed_dry = { dict = 'anim@amb@business@weed@weed_sorting_seated@', clip = 'sorter_right_sort_v3_weeddry01c', prop = nil },
    weed_pack = { dict = 'mp_common', clip = 'givetake1_a', prop = 'prop_meth_bag_01' },
    weed_harvest = { dict = 'anim@amb@business@weed@weed_sorting_seated@', clip = 'sorter_right_sort_v3_weeddry01c', prop = 'prop_cs_scissors' },
    mushroom_harvest = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', prop = nil },
    coca_harvest = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', prop = nil },
    poppy_harvest = { dict = 'amb@world_human_gardener_plant@female@base', clip = 'base_female', prop = nil },
    thc_scrape = { dict = 'anim@amb@business@weed@weed_sorting_seated@', clip = 'sorter_right_sort_v3_weeddry01c', prop = 'prop_cs_scissors' },
    thc_cartridge = { dict = 'amb@prop_human_parking_meter@female@idle_a', clip = 'idle_a_female', prop = 'prop_cs_script_bottle' },
    moonshine_still = { dict = 'amb@world_human_stand_fire@male@idle_a', clip = 'idle_a', prop = nil },
    moonshine_jar = { dict = 'mp_common', clip = 'givetake1_a', prop = 'prop_cs_script_bottle' },
    vape_blend = { dict = 'amb@world_human_bum_wash@male@high@base', clip = 'base', prop = nil },
    vape_dropper = { dict = 'amb@prop_human_parking_meter@female@idle_a', clip = 'idle_a_female', prop = 'prop_cs_script_bottle' },
    heroin_cook = { dict = 'amb@world_human_stand_fire@male@idle_a', clip = 'idle_a', prop = 'prop_kitch_pot_fry' },
    heroin_fold = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', clip = 'coke_cut_v5_coccutter', prop = 'prop_paper_bag_small' },
    meth_crush_pack = { dict = 'melee@large_wpn@streamed_core', clip = 'ground_attack_on_spot', prop = 'prop_tool_hammer' },
    pills_blister = { dict = 'anim@amb@business@coc@coc_unpack_cut_left@', clip = 'coke_cut_v1_coccutter', prop = nil },
    mushroom_brush = { dict = 'amb@world_human_maid_clean@', clip = 'base', prop = 'prop_sponge_01' },
    mushroom_jar = { dict = 'mp_common', clip = 'givetake1_a', prop = 'prop_cs_script_bottle' },
    cocaine_wash = { dict = 'amb@world_human_bum_wash@male@high@base', clip = 'base', prop = nil },
    cocaine_brick = { dict = 'anim@amb@business@coc@coc_packing_hi@', clip = 'full_cycle_v1_pressoperator', prop = 'bkr_prop_coke_block_01a' },
    amp_stamp = { dict = 'mp_common', clip = 'givetake1_a', prop = 'prop_meth_bag_01' },
}

local function loadDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function clearScheduleProp()
    if activeProp and DoesEntityExist(activeProp) then
        DeleteEntity(activeProp)
    end
    activeProp = nil
end

function ScheduleAnimStart(mode)
    ScheduleAnimStop()
    local cfg = MODE_ANIMS[mode] or MODE_ANIMS.trim
    local ped = PlayerPedId()
    if cfg.dict and loadDict(cfg.dict) then
        TaskPlayAnim(ped, cfg.dict, cfg.clip, 4.0, -4.0, -1, 49, 0, false, false, false)
    end
    if cfg.prop then
        local hash = joaat(cfg.prop)
        RequestModel(hash)
        local timeout = GetGameTimer() + 3000
        while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(10) end
        if HasModelLoaded(hash) then
            local coords = GetEntityCoords(ped)
            activeProp = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
            AttachEntityToEntity(activeProp, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.02, -0.02, -90.0, 0.0, 0.0, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(hash)
        end
    end
end

function ScheduleAnimStop()
    clearScheduleProp()
    ClearPedSecondaryTask(PlayerPedId())
end
