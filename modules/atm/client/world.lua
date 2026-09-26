--[[
    ATM breach (client) — map ATM visibility. While a ripped ATM prop exists, the original map
    ATM is hidden for every player (it would otherwise stay on the wall). Late joiners fetch the
    current list; everything is restored when the contract ends or the resource stops.
]]

local HIDE_RADIUS <const> = 1.5

---@type table<string, { coords: vector3, model: integer }>
local hidden = {}

---@param coords vector3
---@param model integer
---@return string
local function keyOf(coords, model)
    return ('%.1f:%.1f:%.1f:%d'):format(coords.x, coords.y, coords.z, model)
end

FD.Atm.World = {}

---@param coords vector3
---@param model integer
function FD.Atm.World.Hide(coords, model)
    local key = keyOf(coords, model)
    if hidden[key] then
        return
    end
    hidden[key] = { coords = coords, model = model }
    CreateModelHide(coords.x, coords.y, coords.z, HIDE_RADIUS, model, true)
end

---@param coords vector3
---@param model integer
function FD.Atm.World.Restore(coords, model)
    local key = keyOf(coords, model)
    if not hidden[key] then
        return
    end
    hidden[key] = nil
    RemoveModelHide(coords.x, coords.y, coords.z, HIDE_RADIUS, model, false)
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

AddEventHandler('onResourceStop', function(resource)
    if resource ~= FD.Resource then
        return
    end
    for _, entry in pairs(hidden) do
        RemoveModelHide(entry.coords.x, entry.coords.y, entry.coords.z, HIDE_RADIUS, entry.model, false)
    end
end)
