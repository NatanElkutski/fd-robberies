--[[
    QBCore server adapter. The only server file allowed to touch QBCore.
    Open file: adapt these functions to support another framework.
]]

local QBCore = exports['qb-core']:GetCoreObject()

Bridge = Bridge or {}

---@param src integer
---@return table|nil
function Bridge.GetPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

---@param src integer
---@return string|nil
function Bridge.GetIdentifier(src)
    local player = QBCore.Functions.GetPlayer(src)
    return player and player.PlayerData.citizenid
end

---Character "firstname lastname" (trimmed), or '' when unavailable.
---@param src integer
---@return string
function Bridge.GetCharacterName(src)
    local player = QBCore.Functions.GetPlayer(src)
    local charinfo = player and player.PlayerData.charinfo or {}
    return FD.Utils.trim(('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''))
end

---@return integer[]
function Bridge.GetPlayers()
    local sources = {}
    for src in pairs(QBCore.Functions.GetQBPlayers()) do
        sources[#sources + 1] = src
    end
    return sources
end

---@param jobName string
---@return integer
function Bridge.CountOnDuty(jobName)
    local count = 0
    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        local job = player.PlayerData.job
        if job?.onduty and job.name == jobName then
            count += 1
        end
    end
    return count
end

---Exact item name exists in the shared item list.
---@param name string
---@return boolean
function Bridge.ItemExists(name)
    return QBCore.Shared.Items[name] ~= nil
end

---Returns the defined item name matching `name` exactly or in lower case.
---@param name string
---@return string|nil
function Bridge.ResolveItemName(name)
    if QBCore.Shared.Items[name] then
        return name
    end
    local lower = string.lower(name)
    if QBCore.Shared.Items[lower] then
        return lower
    end
end

---@param src integer
---@param name string
---@return integer
function Bridge.GetItemCount(src, name)
    local player = QBCore.Functions.GetPlayer(src)
    local item = player and player.Functions.GetItemByName(name)
    return item and item.amount or 0
end

---@return boolean
function Bridge.AddItem(src, name, amount)
    local player = QBCore.Functions.GetPlayer(src)
    return player ~= nil and player.Functions.AddItem(name, amount) == true
end

---@return boolean
function Bridge.RemoveItem(src, name, amount)
    local player = QBCore.Functions.GetPlayer(src)
    return player ~= nil and player.Functions.RemoveItem(name, amount) == true
end

---@param account 'cash'|'bank'|string
---@return number
function Bridge.GetMoney(src, account)
    local player = QBCore.Functions.GetPlayer(src)
    local money = player and player.PlayerData.money
    return money and money[account] or 0
end

---@return boolean
function Bridge.AddMoney(src, account, amount, reason)
    local player = QBCore.Functions.GetPlayer(src)
    return player ~= nil and player.Functions.AddMoney(account, amount, reason) ~= false
end

---@return boolean
function Bridge.RemoveMoney(src, account, amount, reason)
    local player = QBCore.Functions.GetPlayer(src)
    return player ~= nil and player.Functions.RemoveMoney(account, amount, reason) and true or false
end
