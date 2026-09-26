--[[
    QBCore client adapter. The only client file allowed to touch QBCore.
    Open file: adapt these functions to support another framework.
]]

local QBCore = exports['qb-core']:GetCoreObject()

Bridge = Bridge or {}

---@param coords vector3
---@return integer vehicle handle or 0
function Bridge.GetClosestVehicle(coords)
    return QBCore.Functions.GetClosestVehicle(coords) or 0
end

---Framework notification (used when no dedicated notify resource is running).
---@param message string
---@param kind string
function Bridge.FrameworkNotify(message, kind)
    QBCore.Functions.Notify(message, kind)
end
