--[[
  mrp_jobs — fizinių objektų nešimo/krovimo pagalbininkas (klientas).
  Adaptuota iš mrp_gangs misijų šablono (AttachEntityToEntity + carry anim).
  Naudoja: naftos statinės (pakelti → nunešti → įkelti į transportą).
]]

Props = Props or {}

local CARRY_ANIM = { dict = 'anim@heists@box_carry@', clip = 'idle' }
local carried = nil     -- šiuo metu nešamas objektas (entity)

local function ensureCarryAnim()
    LoadAnimDict(CARRY_ANIM.dict)
end

-- Sukuria lokalų prop pasaulyje.
function Props.spawnWorld(model, coords, heading)
    local hash = LoadModel(model)
    if not hash then return nil end
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    if heading then SetEntityHeading(obj, heading) end
    SetModelAsNoLongerNeeded(hash)
    return obj
end

function Props.isCarrying()
    return carried ~= nil and DoesEntityExist(carried)
end

-- Pakelia objektą (arba sukuria naują) ir prikabina prie rankų su carry anim.
function Props.pickUp(model)
    if Props.isCarrying() then return false end
    local ped = PlayerPedId()
    local hash = LoadModel(model)
    if not hash then return false end
    local coords = GetEntityCoords(ped)
    local obj = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    ensureCarryAnim()
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, 57005),
        0.05, 0.10, -0.15, 5.0, 0.0, 0.0, true, true, false, true, 1, true)
    TaskPlayAnim(ped, CARRY_ANIM.dict, CARRY_ANIM.clip, 3.0, 3.0, -1, 49, 0, false, false, false)
    carried = obj
    return true
end

-- Nuima nešamą objektą (be įkėlimo — pvz. atsisakius).
function Props.removeCarried()
    local ped = PlayerPedId()
    if carried and DoesEntityExist(carried) then
        DetachEntity(carried, true, true)
        DeleteEntity(carried)
    end
    carried = nil
    StopAnimTask(ped, CARRY_ANIM.dict, CARRY_ANIM.clip, 3.0)
    ClearPedSecondaryTask(ped)
end

-- Įkelia nešamą objektą į transportą (prikabina prie offset'o), grąžina objektą.
function Props.loadIntoVehicle(veh, offset)
    if not Props.isCarrying() or not veh or veh == 0 then return nil end
    local ped = PlayerPedId()
    local obj = carried
    carried = nil
    DetachEntity(obj, true, true)
    AttachEntityToEntity(obj, veh, 0,
        offset.x, offset.y, offset.z, 0.0, 0.0, 0.0,
        false, false, false, false, 1, true)
    StopAnimTask(ped, CARRY_ANIM.dict, CARRY_ANIM.clip, 3.0)
    ClearPedSecondaryTask(ped)
    return obj
end

-- Anim palaikymas (kai nešama, kad neatsileistų).
CreateThread(function()
    while true do
        if Props.isCarrying() then
            local ped = PlayerPedId()
            if not IsEntityPlayingAnim(ped, CARRY_ANIM.dict, CARRY_ANIM.clip, 3) then
                ensureCarryAnim()
                TaskPlayAnim(ped, CARRY_ANIM.dict, CARRY_ANIM.clip, 3.0, 3.0, -1, 49, 0, false, false, false)
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Props.removeCarried()
end)
