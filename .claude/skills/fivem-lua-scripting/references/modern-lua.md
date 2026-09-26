# Modern FiveM Lua (CfxLua 5.4) — what "modern" means and what it doesn't

Lua has **no arrow functions or lambdas**: `function(args) ... end` is the only function syntax in every Lua version, including CfxLua. Writing `function()` is not old-fashioned. What *is* old-fashioned in FiveM code is the list below.

## Contents
1. Language features to use
2. Deprecated / legacy APIs → modern replacements
3. Structure and readability
4. Before/after examples from this repo

## 1. Language features to use

Standard Lua 5.4 (all artifacts):
```lua
local MAX_CREW <const> = 4                 -- compile-time constant; reassigning is a compile error
local q = 7 // 2                           -- integer division (3)
local ok = math.type(x) == 'integer'
for i = #list, 1, -1 do ... end
goto continue ... ::continue::              -- `continue` substitute inside loops
```

CfxLua extensions (FiveM only — cheap, readable, use them):
```lua
local model = `prop_atm_01`                -- compile-time joaat hash; replaces GetHashKey('prop_atm_01')
count += 1; total -= price; mult *= 2      -- compound operators: += -= *= /= <<= >>= &= |= ^=
local grade = Player?.PlayerData?.job?.grade?.level   -- safe navigation: nil instead of an error
local a <close> = ...                       -- to-be-closed variables (auto cleanup)
```
Available but use sparingly (unfamiliar to most FiveM devs and tooling):
`local x, y, z in coords` (in-unpacking), `{ .police, .sheriff }` (set constructor = `{police=true, sheriff=true}`), `defer ... end`, `/* C comments */`.

Editor support: CfxLua syntax confuses stock Lua language servers. Recommend the **CfxLua / FiveM Lua** VS Code extension (sumneko with the cfxlua addon) so `+=`, `?.` and backticks don't show as errors.

Vectors are first-class: `vec3(x, y, z)` (alias of `vector3`), `#(a - b)` distance, `v.xy`, `v * 2.0`, `vector4.xyz`. Pass vectors directly instead of `x, y, z` triplets where the API accepts them.

## 2. Legacy APIs → modern replacements

| Legacy | Modern | Why |
|---|---|---|
| `GetHashKey('model')` in code paths | `` `model` `` literal | computed at compile time, zero runtime cost |
| `Citizen.CreateThread`, `Citizen.Wait`, `Citizen.SetTimeout` | `CreateThread`, `Wait`, `SetTimeout` | same functions, shorter aliases |
| `GetDistanceBetweenCoords(...)` | `#(a - b)` | native call vs pure vector math |
| `SetTextEntry` / `AddTextComponentString` / `DrawText` | `BeginTextCommandDisplayText` / `AddTextComponentSubstringPlayerName` / `EndTextCommandDisplayText` | old names are deprecated aliases |
| `SetTextEntry_2` / `DrawSubtitleTimed` | `BeginTextCommandPrint` / `EndTextCommandPrint` | same |
| `QBCore.Functions.GetPlayers()` + `GetPlayer` loop | `QBCore.Functions.GetQBPlayers()` or `GetPlayersOnDuty(job)` | `GetPlayers` is deprecated |
| `QBCore.Functions.CreateCallback` / `TriggerCallback` (when ox_lib is loaded) | `lib.callback.register` / `lib.callback.await` | synchronous-style code, no nested callbacks |
| `QBCore.Functions.Progressbar(... 11 positional args ...)` (when ox_lib is loaded) | `if lib.progressBar({...}) then` | named options, returns bool, no callback pyramid |
| `while not HasModelLoaded(m) do Wait(0) end` | `lib.requestModel(m, 5000)` | built-in timeout |
| `IsControlJustPressed` polling in a Wait(0) loop for a hotkey | `RegisterKeyMapping` / `lib.addKeybind` | rebindable, zero idle cost |
| Distance-check `while true` loops for areas | `lib.points` / `lib.zones` / target zones | event-driven |
| `PlayerPedId()` called repeatedly | `cache.ped` (ox_lib) or one local per tick | fewer native calls |
| `pcall(ALTER TABLE ADD COLUMN)` every start | check `information_schema` / `ADD COLUMN IF NOT EXISTS` (MariaDB) | no error spam, intent is clear |
| `TriggerEvent('chat:addMessage')` for feedback | server notify/bridge | consistent UX |
| `RegisterServerEvent` / `RegisterNetEvent(name)` + separate `AddEventHandler(name, fn)` | `RegisterNetEvent(name, function(...) end)` | one call; `RegisterServerEvent` is a legacy alias |
| `json.decode(LoadResourceFile(...))` for static data every call | load once at start and cache | IO per call |
| `math.randomseed(os.time())` | nothing — Lua 5.4 seeds randomly at start | reseeding with low-entropy time is worse |
| `table.getn(t)` / `unpack` | `#t` / `table.unpack` | removed in 5.2+ |

When ox_lib is already a dependency (as in fd-robberies — it's in `shared_scripts` but barely used), prefer its modules over the framework's older helpers for new code; don't mix two styles inside one function.

## 3. Structure and readability

- **One statement per line, 4-space indent, blank lines between functions.** Dense `a;b;c` one-liners (as in the current `server.lua`/`client.lua`) are an old "minify by hand" habit; they hide bugs, make diffs unreadable and don't run faster. Escrow already protects the source — obfuscation-by-formatting adds nothing.
- `local` for everything; module-level state in a few named tables (`local State = { active = {}, cooldowns = {} }`), not dozens of top-level locals (Lua has a 200-locals limit per function/chunk).
- Early returns (guard clauses) instead of deep nesting.
- Split big files by domain once they grow: `server/main.lua`, `server/crew.lua`, `server/atm.lua`, `client/atm.lua`, `client/store.lua`, `shared/utils.lua`, `bridge/*.lua`. Use fxmanifest globs.
- Named functions for handlers you reference more than once; LuaLS annotations (`---@param src number`) for public helpers.
- Constants UPPER_SNAKE with `<const>`; event names in one table so client and server don't drift:
  ```lua
  -- shared/events.lua
  Events = { Start = 'fd-robberies:server:start', Ended = 'fd-robberies:client:ended' }
  ```

## 4. Before / after (from this repo)

```lua
-- before (server.lua)
local function police() local n=0; for _,id in pairs(QBCore.Functions.GetPlayers()) do local p=QBCore.Functions.GetPlayer(id); if p and p.PlayerData.job and p.PlayerData.job.name==Config.RequiredJob and p.PlayerData.job.onduty then n=n+1 end end; return n end

-- after
local function countOnDutyPolice()
    local count = 0
    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        local job = player.PlayerData.job
        if job?.onduty and job.name == Config.RequiredJob then
            count += 1
        end
    end
    return count
end
```

```lua
-- before (client.lua)
QBCore.Functions.TriggerCallback('fd-robberies:server:checkMethod', function(ok, msg)
    if not ok then return notify(msg, 'error') end
    QBCore.Functions.Progressbar('robbery_action', label, time, false, true, {...}, {...}, {}, {}, function() ... end, function() ... end)
end, method)

-- after (ox_lib is already loaded)
local ok, msg = lib.callback.await('fd-robberies:server:checkMethod', false, method)
if not ok then return notify(msg, 'error') end
if not lib.progressBar({ duration = time, label = label, canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 } }) then
    return TriggerServerEvent('fd-robberies:server:releaseATMMethod')
end
```

```lua
-- before
local model=GetHashKey(Config.HubNPC.model); RequestModel(model); while not HasModelLoaded(model) do Wait(50) end
-- after
local model = lib.requestModel(Config.HubNPC.model, 10000)
```

```lua
-- before
SetTextEntry('STRING'); AddTextComponentString(text); DrawText(x, y)
-- after
BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(text); EndTextCommandDisplayText(x, y)
```
