---
name: fivem-server-security
description: Server-authoritative security rules for FiveM / GTA V RP resources — validating RegisterNetEvent and callback input, never trusting client amounts/coords/timers, server-side proximity and timing checks, item consumption, mission state machines, rate limiting, netId validation, SQL safety and exploit logging. Use this whenever writing or reviewing ANY server event, callback, reward, payout, shop purchase, XP/level change, inventory add/remove, money change, cooldown, robbery/heist/job completion, or admin action in a FiveM script, and whenever the user asks about exploits, cheaters, "executors", mod menus, dupes or anticheat. Apply it proactively even when the user only asks for a feature.
---

# FiveM server security

Every `RegisterNetEvent` handler and server callback is a public API that any player with a Lua executor can call with any arguments, at any rate, from anywhere on the map. Mod menus scan resources for events named like `*:reward`, `*:complete`, `*:buyItem` and spam them. The client is a UI; the server is the game.

So the question for every server handler is: **"If a cheater calls this directly with hostile arguments, what's the worst outcome?"** If the answer involves money, items, XP, killing/moving players or spawning entities, the handler must prove the action is legitimate using only server-side data.

## The checklist

Apply to every net event and server callback you write or touch:

1. **Capture `local src = source` on the first line.** `source` is a global that is overwritten after any yield (`MySQL.*.await`, `lib.callback.await`, `Wait`).
2. **Player exists**: `local Player = QBCore.Functions.GetPlayer(src); if not Player then return end`.
3. **Type-check and bound every argument.** `tonumber()`, `type(x) == 'string'`, `#str <= N`, `math.floor`, ranges, `pattern:match`. Client arguments can be tables, nil, huge numbers, negative numbers, NaN (`x ~= x`) or strings with HTML/SQL.
4. **Whitelist, never pass through.** Clients send *keys* (`robberyId`, `itemName`, `method`); the server looks up price, reward, item, time and XP in `Config`. Never accept `amount`, `price`, `reward`, `xp`, `label` or `coords` from the client and use them as truth.
5. **State machine, not triggers.** Keep server state per mission/crew/player (`Active[id] = { stage=..., members=..., startedAt=..., actions={} }`). An event is valid only if the current stage allows it, the caller is a member, and it hasn't already been done (one-time flags like `a.actions[key]`). Advance stage server-side.
6. **Proximity from the server.** With OneSync, `GetEntityCoords(GetPlayerPed(src))` is authoritative enough. Check against configured coords with a tolerance (e.g. radius + 5.0) before paying out or starting location-bound actions.
7. **Timing from the server.** Progress bars run on the client and can be skipped. Record `startedAt = os.time()` (or `GetGameTimer()` server-side) when the server approves the start of an action, and on completion reject if `elapsed < configuredDuration - tolerance`.
8. **Consume required items in the same handler that grants the reward** (or that approves the start), after re-checking the player still has them. A separate "consumeItem" event the client is supposed to call can simply be skipped. Check `RemoveItem` returned true before granting.
9. **Atomic payouts.** Mark done *before* yielding / paying, roll back if the payout fails (prevents double-pay from spam during an await).
10. **Rate limit spammable events** (chat, buy, invite, refresh) per `src`:
    ```lua
    local last = {}
    local function throttled(src, key, ms)
        local now = GetGameTimer(); last[src] = last[src] or {}
        if (last[src][key] or 0) + ms > now then return true end
        last[src][key] = now; return false
    end
    ```
    and clear `last[src]` on `playerDropped`.
11. **Validate netIds / entities.** `local ent = NetworkGetEntityFromNetworkId(netId)`; check `DoesEntityExist(ent)`, expected model (`GetEntityModel(ent) == \`prop_atm_01\``), and distance to the player, and that it is the entity registered in the mission state.
12. **Permissions server-side**: job/duty from `Player.PlayerData.job`, admin via `IsPlayerAceAllowed(src, 'command.x')` or `QBCore.Functions.HasPermission`. `canInteract` in a target is cosmetic, not a check.
13. **Police count, cooldowns, levels, crew size** are all computed on the server at start time — never received.
14. **SQL**: always parameterized (`?` or `@name`). Never concatenate client text into queries.
15. **Text from players** (names, chat, notes): trim, strip control chars, cap length on the server; escape at render time in NUI (see `fivem-nui`). Player names from `GetPlayerName` are attacker-controlled.
16. **Cleanup** on `playerDropped` and resource stop so a disconnected player can't leave a mission locked or be re-used.
17. **Don't broadcast secrets.** Safe codes, loot positions, other crews' data go only to the members who need them.
18. **Log suspicious calls** with identifiers instead of silently failing, so owners can ban:
    ```lua
    local function flag(src, reason)
        print(('^3[%s] suspicious %s (%s): %s^7'):format(GetCurrentResourceName(), GetPlayerName(src), GetPlayerIdentifierByType(src, 'license') or '?', reason))
        -- optional: TriggerEvent to the server's anticheat/log resource, or Config.OnExploit(src, reason) in an open file
    end
    ```
    Don't auto-ban on borderline checks (latency, tolerance edges); auto-drop only on impossible input (negative amounts, unknown robbery id, not a member).

## Patterns that look safe but aren't

| Pattern | Why it's exploitable | Do instead |
|---|---|---|
| `TriggerServerEvent('x:complete', id)` pays the reward after a client progress bar | Executor calls it instantly and repeatedly | Server checks stage, membership, distance, elapsed time, one-time flag |
| Client calls `x:consumeItem` then `x:complete` | Cheater skips consume | Remove item inside the server step that approves/pays |
| `canInteract = function() return PlayerData.job.name == 'police' end` | Client-side only | Re-check job in the server handler |
| Item/price list sent to NUI and the chosen price sent back | Price is client data | Client sends item name; server reads price from Config |
| `TriggerClientEvent('...', -1, fullState)` | Leaks codes/positions to all | Send to members only |
| Reward keyed by `source` stored before `await` | `source` changed after yield | `local src = source` first |
| `MySQL.query('... WHERE name = "'..name..'"')` | SQL injection | `MySQL.query('... WHERE name = ?', { name })` |

## Minimal hardened handler

```lua
RegisterNetEvent('fd-robberies:server:complete', function(robberyId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src); if not Player then return end
    if type(robberyId) ~= 'string' then return flag(src, 'complete: bad id type') end
    local cfg, a = Config.Robberies[robberyId], Active[robberyId]
    if not cfg or not a or not a.members[src] then return flag(src, 'complete: not in mission ' .. tostring(robberyId)) end
    if a.stage ~= 'working' or a.workerSrc ~= src then return end
    if os.time() - (a.workStartedAt or 0) < cfg.workSeconds - 2 then return flag(src, 'complete: too fast') end
    if #(GetEntityCoords(GetPlayerPed(src)) - cfg.coords) > cfg.radius + 5.0 then return flag(src, 'complete: too far') end

    a.stage = 'looted'                                   -- mark before paying (spam-safe)
    local amount = math.random(cfg.rewards.min, cfg.rewards.max)
    if not Player.Functions.AddItem(Config.DirtyMoneyItem, amount) then
        a.stage = 'working'                              -- roll back so the player can retry
        return notify(src, Lang.inventory_full, 'error')
    end
end)
```

## When reviewing existing code

Walk every `RegisterNetEvent` / `CreateCallback` / `lib.callback.register` in `server.lua`, and for each ask: who can call it, what does it grant, and which of the checks above it's missing. Report concrete findings (event name, the missing check, the exploit in one sentence, the fix). Don't rewrite escrowed gameplay wholesale without asking — propose targeted fixes.
