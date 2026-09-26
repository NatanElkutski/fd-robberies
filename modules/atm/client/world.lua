--[[
    ATM breach (client) — hides one specific map ATM while its networked replacement exists.

    Only the exact map object is hidden (visibility + collision), matched by model and position
    with a tight radius, so neighbouring ATMs and the replacement prop are never affected.
    Map objects are recreated when they stream back in, so hidden ones are re-applied while
    the player is nearby. Late joiners fetch the current list; everything is restored when the
    contract ends or the resource stops.
]]

local MATCH_RADIUS <const> = 0.35
local REAPPLY_RANGE <const> = 200.0
local REAPPLY_MS <const> = 1000

---@type table<string, { coords: vector3, model: integer }>
local hidden = {}

---@param coords vector3
---@param model integer
---@return string
local function keyOf(coords, model)
    return ('%.2f:%.2f:%.2f:%d'):format(coords.x, coords.y, coords.z, model)
end

---The map (non-networked) ATM at exactly these coordinates, if streamed in. Scans the object
---pool because the networked replacement sits at the very same spot with the same model.
---@param coords vector3
---@param model integer
---@return integer|nil
local function mapAtmAt(coords, model)
    for _, entity in ipairs(GetGamePool('CObject')) do
        if
            GetEntityModel(entity) == model
            and not NetworkGetEntityIsNetworked(entity)
            and #(GetEntityCoords(entity) - coords) <= MATCH_RADIUS
        then
            return entity
        end
    end
end

---@param entry { coords: vector3, model: integer }
---@param visible boolean
local function apply(entry, visible)
    local entity = mapAtmAt(entry.coords, entry.model)
    if entity then
        SetEntityVisible(entity, visible, false)
        SetEntityCollision(entity, visible, visible)
    end
end

FD.Atm.World = {}

---@param coords vector3
---@param model integer
function FD.Atm.World.Hide(coords, model)
    local entry = { coords = vec3(coords.x, coords.y, coords.z), model = model }
    hidden[keyOf(entry.coords, model)] = entry
    apply(entry, false)
end

---@param coords vector3
---@param model integer
function FD.Atm.World.Restore(coords, model)
    local key = keyOf(vec3(coords.x, coords.y, coords.z), model)
    local entry = hidden[key]
    if entry then
        hidden[key] = nil
        apply(entry, true)
    end
end

---True for a map ATM that is currently hidden (it must not offer breach options).
---@param entity integer
---@return boolean
function FD.Atm.World.IsHidden(entity)
    if NetworkGetEntityIsNetworked(entity) then
        return false
    end
    local coords, model = GetEntityCoords(entity), GetEntityModel(entity)
    for _, entry in pairs(hidden) do
        if entry.model == model and #(entry.coords - coords) <= MATCH_RADIUS then
            return true
        end
    end
    return false
end

RegisterNetEvent(FD.Events.Client.HideAtm, function(coords, model)
    FD.Atm.World.Hide(coords, model)
end)

RegisterNetEvent(FD.Events.Client.RestoreAtm, function(coords, model)
    FD.Atm.World.Restore(coords, model)
end)

CreateThread(function()
    local list = lib.callback.await(FD.Events.Callback.GetHiddenAtms, false) or {}
    for _, entry in pairs(list) do
        FD.Atm.World.Hide(entry.coords, entry.model)
    end
end)

-- map objects are recreated when streamed back in: keep nearby hidden ATMs hidden
CreateThread(function()
    while true do
        Wait(REAPPLY_MS)
        if next(hidden) then
            local origin = GetEntityCoords(cache.ped)
            for _, entry in pairs(hidden) do
                if #(origin - entry.coords) <= REAPPLY_RANGE then
                    apply(entry, false)
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= FD.Resource then
        return
    end
    for _, entry in pairs(hidden) do
        apply(entry, true)
    end
end)
