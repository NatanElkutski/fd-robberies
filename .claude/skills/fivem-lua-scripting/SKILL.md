---
name: fivem-lua-scripting
description: Core standards for writing FiveM (GTA V / Cfx.re) resource code in Lua — fxmanifest, client/server/shared split, net events, callbacks, threads and tick performance, natives, entities, models, blips, keybinds and cleanup. Use this whenever writing, editing, reviewing or debugging any client.lua / server.lua / shared / fxmanifest.lua in a FiveM resource, adding a feature to a GTA RP script (robbery, job, heist, shop, mission, NPC, target zone, progress bar), or when the user mentions FiveM, Cfx, CitizenFX, GTA V server, RP server, natives, resmon or "script for my server" — even if they don't say "FiveM" explicitly.
---

# FiveM Lua scripting

FiveM resources run in two separate Lua runtimes — each player's game client and the server — that only talk through events. Most bugs and exploits in RP scripts come from forgetting that split, so keep it in mind for every line you write.

Related skills: security rules live in `fivem-server-security` (read it before writing any server event that touches money, items, XP or world state); framework APIs in `fivem-framework-apis`; UI in `fivem-nui`; packaging in `fivem-escrow-release`.

## 1. Detect the stack before writing code

Open `fxmanifest.lua` and the top of `client.lua` / `server.lua` first. Use what the resource already depends on — never introduce a new framework, target, inventory or notify system without asking, because the customer's server has to install it.

| Look for | Means |
|---|---|
| `exports['qb-core']:GetCoreObject()` | QBCore |
| `exports.qbx_core` / `qbx_core` dependency | Qbox (ox_inventory, ox_lib first-class) |
| `exports['es_extended']:getSharedObject()` | ESX |
| `@ox_lib/init.lua` in shared_scripts | `lib.*` and `cache.*` available |
| `@oxmysql/lib/MySQL.lua` | `MySQL.*` available (server only) |
| `qb-target` / `ox_target` exports | interaction system |
| `Config.*Resource` values | integration is configurable — go through the config, don't hardcode |

In this repo (fd-robberies): QBCore + ox_lib + oxmysql + qb-target (via `Config.TargetResource`), QBCore callbacks, notify through `cm-notification` with QBCore fallback, dispatch via `Config.DispatchResource`. Hebrew user-facing strings.

## 2. fxmanifest.lua

```lua
fx_version 'cerulean'          -- the only current recommended value (adamant/bodacious are older)
game 'gta5'
lua54 'yes'                    -- now a no-op (5.4 is default) but harmless; keep for older artifacts
author 'FIVE DEV'
version '1.0.0'                -- keep in sync with README/changelog

shared_scripts { '@ox_lib/init.lua', 'config.lua', 'locales/*.lua' }
client_scripts { 'client/*.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/*.lua' }

ui_page 'html/index.html'
files { 'html/**' }            -- every file NUI loads must be listed; globs: * (one level), ** (recursive)

dependencies { 'qb-core', 'oxmysql', 'ox_lib' }
```

- `fx_version` accepts only named versions (`cerulean`, `bodacious`, `adamant`). A value like `'3.6.0'` is not a valid fx_version — flag it if you see one.
- Load order inside a list is the order written; shared scripts load before client/server ones on each side.
- `@resource/file.lua` imports another resource's file into this runtime.
- Anything the client needs (NUI files, images, `stream/` assets, data files) must be in `files` or `data_file`; the server never sends unlisted files.

## 3. The client/server split

- **server** — authority over money, items, XP, cooldowns, crews, mission state, DB. Has limited natives: entity natives work under OneSync (`GetEntityCoords(GetPlayerPed(src))`, `NetworkGetEntityFromNetworkId`, `CreateObjectNoOffset`, `DeleteEntity`), but no drawing, input, camera, UI or local-ped natives.
- **client** — presentation and input: drawing, targets, animations, progress bars, props, peds, NUI, reading controls. Everything here can be modified by a cheater.
- **shared** — config, locales, pure helpers. Loaded on both sides; the client gets a copy, so never put secrets, webhooks or API keys in shared/config.

Entity handles are local integers and meaningless on another machine. Send **network IDs** (`NetworkGetNetworkIdFromEntity` / `NetworkGetEntityFromNetworkId`) or server IDs across the wire. Functions and userdata can't be serialized; tables, numbers, strings, booleans and vectors can (msgpack).

## 4. Events and callbacks

Naming: `resourceName:side:action` — e.g. `fd-robberies:server:start`, `fd-robberies:client:ended`. Consistency makes it obvious which side handles what and avoids collisions with other resources.

```lua
-- server
RegisterNetEvent('fd-robberies:server:start', function(robberyId)
    local src = source              -- capture FIRST: `source` is a global that changes after any yield (await, Wait)
    if type(robberyId) ~= 'string' or not Config.Robberies[robberyId] then return end
    ...
end)
```

- `RegisterNetEvent` + handler = callable from the other side (i.e. by any cheater). Use `AddEventHandler` alone for same-side events so the other side can't trigger them.
- `TriggerClientEvent(name, target, ...)`; target `-1` = everyone. Broadcast only what every client should see.
- For request/response use callbacks instead of event ping-pong. If `ox_lib` is loaded, `lib.callback.register` (server) + `lib.callback.await` (client) is the cleanest; `QBCore.Functions.CreateCallback` / `TriggerCallback` is fine when the file already uses it — match what's there rather than mixing both styles in one file.
- Every `RegisterNUICallback` handler must call `cb(...)` on every path, or the JS `fetch` hangs forever.
- Exports: `exports('GetCrew', function(src) ... end)` → `exports['fd-robberies']:GetCrew(src)`.

## 5. Threads and performance (resmon)

Target: idle ≈ 0.00–0.01 ms, active ≲ 0.10 ms in `resmon`. A resource that sits at 0.3 ms idle gets removed from servers.

- `Wait(0)` (every frame) only while you are actually drawing, reading controls or doing per-frame physics. Otherwise sleep 250–1500 ms. Use a dynamic `sleep` variable:
  ```lua
  CreateThread(function()
      while true do
          local sleep = 1000
          if running then
              local dist = #(GetEntityCoords(cache.ped) - target)
              if dist < 20.0 then sleep = 0; DrawMarker(...) end
          end
          Wait(sleep)
      end
  end)
  ```
- Prefer event-driven tools over polling: `lib.points` / `lib.zones` / target zones instead of distance loops; `RegisterKeyMapping` + `RegisterCommand` instead of `IsControlJustPressed` in a tick (players can rebind, and it costs nothing when idle).
- Distance: `#(a - b)` on vectors. Never `GetDistanceBetweenCoords` (slow native call).
- Hashes: CfxLua backtick literals compile to joaat at load time — `` `prop_atm_01` `` — instead of calling `GetHashKey` in loops.
- Cache per-tick values (`local ped = PlayerPedId()` once per iteration, or `cache.ped` with ox_lib).
- Don't `SendNUIMessage` every frame; send on change (see how the mission timer only sends when the second changes).
- Anything created dynamically (zones, blips, peds, props, ropes, threads with flags) needs a matching removal — a loop that keeps adding target zones per entity without removing them leaks memory over a long session.

## 6. Entities, models, animations

```lua
local function loadModel(model)            -- or lib.requestModel(model, 5000)
    model = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    return model
end
```

- Always time out load loops (models, anim dicts, ptfx, rope textures); an unbounded `while not HasModelLoaded` hangs the thread forever on a bad model name.
- `SetModelAsNoLongerNeeded` / `RemoveAnimDict` after use.
- Local-only peds for decoration (`CreatePed(..., false, true)` — isNetwork=false) — each client spawns its own; cheap and no ownership fights. Networked entities when every player must see the same physical object (towed ATM, loot bag); ideally create them server-side under OneSync so the server owns the lifecycle.
- Before modifying a networked entity: request control with a timeout (`NetworkRequestControlOfEntity` loop), check `NetworkHasControlOfEntity`.
- Cleanup on `onResourceStop` (check `resourceName == GetCurrentResourceName()`): delete peds/props/ropes, remove blips and zones, release NUI focus, clear tasks. Otherwise a `restart` during a live server leaves ghosts.
- Also handle the player's own death/unload (`QBCore:Client:OnPlayerUnload`, `playerDropped` on server) so state doesn't stay stuck.

## 7. Player-facing polish that RP servers expect

- Progress bars with animation + `disable = { move, car, combat }`, cancellable, and the result handled on both branches.
- Notifications through the server's configured notify system, typed (`success`/`error`/`primary|inform`).
- Blips with a name (`BeginTextCommandSetBlipName('STRING')`…) and removal on end; routes only for the active objective.
- Police dispatch through a configurable resource with a sane fallback.
- Keybinds via `RegisterKeyMapping` so players see them in Settings → Key Bindings → FiveM.
- All tunables (times, rewards, coords, items, job names, police count, cooldowns) in `config.lua`; all text in a locale table — escrowed files can't be edited by customers (see `fivem-escrow-release`).

See `references/modern-lua.md` for current syntax/API replacements and `references/natives-cheatsheet.md` for copy-ready snippets (blips, markers, 3D text, anims, ptfx, ropes, control IDs, peds).

## 8. Modern syntax — write current CfxLua, not 2019 FiveM

Lua has no arrow functions; `function() ... end` is correct and current. "Modern" in FiveM means the following, and all new code should follow it (full list with before/after from this repo in `references/modern-lua.md` — read it before writing or refactoring a sizeable chunk):

- Backtick hashes `` `prop_atm_01` `` instead of `GetHashKey(...)`; compound operators `count += 1`; safe navigation `player?.PlayerData?.job?.onduty`; `<const>` for constants; `vec3()` and `#(a - b)`.
- `CreateThread` / `Wait` (not `Citizen.*`); `RegisterNetEvent(name, handler)` in one call (not `RegisterServerEvent` + `AddEventHandler`).
- Current native names (`BeginTextCommandDisplayText`… not `SetTextEntry`/`DrawText`).
- With ox_lib loaded (it is here): `lib.callback.await`, `lib.progressBar`, `lib.requestModel`, `lib.points`/`lib.zones`, `lib.addKeybind`, `cache.ped` — sequential code instead of nested callback pyramids.
- `QBCore.Functions.GetQBPlayers` / `GetPlayersOnDuty`, not the deprecated `GetPlayers` loop.
- One statement per line, 4-space indent, guard clauses, files split by domain (`client/`, `server/`, `shared/`, `bridge/`).

## 9. Style and file hygiene

- Files are UTF-8 **without BOM** (Hebrew strings are stored raw). In PowerShell, read with `-Encoding utf8` or use the Read tool — the default ANSI read shows mojibake, which is a display problem, not file corruption. Never "fix" it by re-saving in another encoding.
- The existing `client.lua`/`server.lua` are dense one-liners in legacy style. For a one-line fix inside such a line, keep the edit minimal so the diff stays reviewable. Anything new — a new function, handler, or a block you're rewriting anyway — is written in the modern style from §8, even if the neighbours aren't. Offer a full modernization refactor as a separate task rather than doing it silently in a feature change.
- `local` everything (globals leak across the whole resource runtime and are slower).
- Guard optional integrations: `if GetResourceState('cm-notification') == 'started' then ... else fallback end`.
- `print` with color codes `^1` red `^2` green `^3` yellow `^5` blue `^7` reset; gate verbose logs behind `Config.Debug`.
