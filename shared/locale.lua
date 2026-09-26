--[[
    Translations. Loads locales/en.json as the base, then the language set in
    config/shared.lua (`locale`, default 'he') on top of it. Deliberately independent of
    ox_lib's `ox:locale` convar / per-player setting, so the resource always shows the
    language the server owner configured.
]]

local sharedConfig = require('config.shared')

local language = sharedConfig.locale or 'he'
---@type table<string, string>
local dictionary = {}

---@param source table
---@param prefix? string
local function flatten(source, prefix)
    for key, value in pairs(source) do
        local fullKey = prefix and ('%s.%s'):format(prefix, key) or tostring(key)
        if type(value) == 'table' then
            flatten(value, fullKey)
        else
            dictionary[fullKey] = value
        end
    end
end

---@param lang string
local function load(lang)
    local raw = LoadResourceFile(FD.Resource, ('locales/%s.json'):format(lang))
    if not raw then
        print(('^3[%s] locales/%s.json not found^7'):format(FD.Resource, lang))
        return
    end
    flatten(json.decode(raw) or {})
end

load('en') -- base: a key missing from the selected language falls back to English
if language ~= 'en' then
    load(language)
end

---Translated text for `key`, formatted with the extra arguments (%s / %d). Returns the key if missing.
---@param key string
---@param ... string|number
---@return string
function locale(key, ...)
    local text = dictionary[key]
    if not text then
        return key
    end
    local first = ...
    if first == nil then
        return text
    end
    return text:format(...)
end

FD.Locale = {
    language = language,
}

---Whole flattened dictionary (sent to the NUI).
---@return table<string, string>
function FD.Locale.All()
    return dictionary
end
