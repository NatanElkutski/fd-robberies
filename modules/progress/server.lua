--[[
    Progress (server): XP, levels and the player's criminal profile (name + avatar).
]]

local config = require('config.server')

local MIN_NAME_LENGTH <const> = 3
local MAX_NAME_LENGTH <const> = 24
local AVATAR_COUNT <const> = 12
local DEFAULT_AVATAR <const> = 'face01'

FD.Progress = {}

---Loads (and creates on first use) a player's progress row.
---@param identifier string
---@return { xp: integer, completed: integer, criminal_name?: string, criminal_avatar: string, level: integer }
function FD.Progress.Get(identifier)
    local row = MySQL.single.await(
        'SELECT xp, completed, criminal_name, criminal_avatar FROM fd_robbery_progress WHERE citizenid = ?',
        { identifier }
    )

    if not row then
        MySQL.insert.await(
            'INSERT INTO fd_robbery_progress (citizenid, xp, completed, criminal_avatar) VALUES (?, 0, 0, ?)',
            { identifier, DEFAULT_AVATAR }
        )
        row = { xp = 0, completed = 0, criminal_name = nil, criminal_avatar = DEFAULT_AVATAR }
    end

    row.level = FD.Utils.levelFromXp(row.xp, config.xpPerLevel, config.maxLevel)
    row.criminal_avatar = row.criminal_avatar or DEFAULT_AVATAR
    return row
end

---@param identifier string
---@param xp integer
function FD.Progress.AddCompletion(identifier, xp)
    MySQL.update.await(
        'UPDATE fd_robbery_progress SET xp = xp + ?, completed = completed + 1 WHERE citizenid = ?',
        { xp, identifier }
    )
end

---Criminal name if set, otherwise character name, otherwise "ID <src>".
---@param src integer
---@return string
function FD.Progress.DisplayName(src)
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then
        return ('ID %s'):format(src)
    end

    local row = MySQL.single.await('SELECT criminal_name FROM fd_robbery_progress WHERE citizenid = ?', { identifier })
    if row?.criminal_name and row.criminal_name ~= '' then
        return row.criminal_name
    end

    return Bridge.GetCharacterName(src)
end

---@param avatar any
---@return string
local function sanitizeAvatar(avatar)
    avatar = tostring(avatar or DEFAULT_AVATAR)
    if not avatar:match('^face%d%d$') then
        return DEFAULT_AVATAR
    end

    local number = tonumber(avatar:match('%d+')) or 1
    if number < 1 or number > AVATAR_COUNT then
        return DEFAULT_AVATAR
    end

    return avatar
end

RegisterNetEvent(FD.Events.Server.SaveProfile, function(name, avatar)
    local src = source
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then
        return
    end

    name = FD.Utils.trim(tostring(name or ''):gsub('[<>\n\r]', '')):sub(1, MAX_NAME_LENGTH)
    if #name < MIN_NAME_LENGTH then
        return Bridge.Notify(src, locale('profile.name_too_short'), 'error')
    end

    MySQL.update.await(
        'UPDATE fd_robbery_progress SET criminal_name = ?, criminal_avatar = ? WHERE citizenid = ?',
        { name, sanitizeAvatar(avatar), identifier }
    )

    Bridge.Notify(src, locale('profile.saved'), 'success')
    TriggerClientEvent(FD.Events.Client.CrewRefresh, src)
end)
