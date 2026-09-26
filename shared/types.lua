--[[
    LuaLS type annotations for state shared between modules. No runtime code.
]]

---@class CrewState
---@field leader integer
---@field members table<integer, true>

---@class ActiveContract
---@field owner integer                 leader source that started it
---@field members table<integer, true>
---@field started integer               os.time()
---@field expires integer               os.time()
---@field actions table<string, true>   one-time loot flags
---@field objectiveDone boolean
---@field safeCodes table<integer, integer>
---@field atmCompleted boolean
---@field atmInProgress? integer        source currently breaching an ATM
---@field atmMethod? string
---@field explosiveReady boolean
---@field ropeATM? integer              network id of the ripped (spawned) ATM prop
---@field ropeOwner? integer            source that ripped it (physics owner, marks it lootable)
---@field atmBody? integer              network id of the steel body attached behind a thin ATM panel
---@field hiddenAtm? { coords: vector3, model: integer } map ATM hidden while the prop exists
---@field ropeLootable? boolean
---@field ropeLooted table<integer, true>
---@field ropeDetached? boolean

---@class RunningMission
---@field id string
---@field ends integer                  GetGameTimer() deadline

---@class TargetOption
---@field icon string
---@field label string
---@field canInteract? fun(entity: integer, distance: number): boolean
---@field onSelect fun(entity: integer)
