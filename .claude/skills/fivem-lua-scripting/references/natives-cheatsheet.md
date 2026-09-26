# FiveM client natives cheatsheet

Copy-ready snippets. All client-side unless marked. Names follow https://docs.fivem.net/natives/ — check there when unsure of an argument list rather than guessing.

## Contents
1. Blips
2. Markers and 3D text
3. Animations and scenarios
4. Props attached to the player
5. Peds (NPCs)
6. Particle effects and camera shake
7. Ropes
8. Vehicles
9. Common control IDs
10. Help text / subtitles

## 1. Blips
```lua
local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
SetBlipSprite(blip, 161); SetBlipColour(blip, 1); SetBlipScale(blip, 0.9)
SetBlipAsShortRange(blip, true)
BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(label); EndTextCommandSetBlipName(blip)
SetBlipRoute(blip, true)                 -- GPS route, only for the active objective
-- radius blip for a search area
local area = AddBlipForRadius(coords.x, coords.y, coords.z, 60.0); SetBlipAlpha(area, 90); SetBlipColour(area, 1)
-- remove
if DoesBlipExist(blip) then RemoveBlip(blip) end
```
Police-only blips: send coords from server only to on-duty police (`TriggerClientEvent` per police source), never to `-1`.

## 2. Markers and 3D text
```lua
DrawMarker(2, x, y, z, 0,0,0, 0,180.0,0, 0.2,0.2,0.2, 255,140,0,200, false,true,2, false,nil,nil,false)

local function drawText3D(coords, text)
    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32); SetTextFont(4); SetTextCentre(true); SetTextOutline()
    SetTextColour(255, 255, 255, 215)
    BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(text); EndTextCommandDisplayText(sx, sy)
end
```
Both must be called every frame (`Wait(0)`) while visible — only do it when the player is close. Prefer ox_lib `lib.showTextUI('[E] ...')` / target systems for interactions. **Native text can't render Hebrew (or other non-Latin scripts) — it shows boxes; on Hebrew servers always use `lib.showTextUI` / NUI for text.**

## 3. Animations and scenarios
```lua
lib.requestAnimDict('mini@safe_cracking')           -- or RequestAnimDict + timed wait
TaskPlayAnim(ped, 'mini@safe_cracking', 'idle_base', 8.0, -8.0, -1, 49, 0, false, false, false)
-- flags (bitmask): 1 loop, 2 hold last frame, 16 upper body only, 32 player keeps control
--   common combos: 49 = loop + upper body + control (walk while animating), 1 = full-body loop
RemoveAnimDict('mini@safe_cracking')
ClearPedTasks(ped)

TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
TaskHandsUp(ped, durationMs, facingPed, -1, true)
```
Common dicts: `mini@repair`/`fixing_a_ped`, `anim@heists@ornate_bank@grab_cash`/`grab`, `anim@heists@ornate_bank@thermal_charge`/`thermal_charge`, `missheistfbisetup1`/`unlock_loop_janitor`, `mp_arresting`/`idle`.

## 4. Props attached to the player
```lua
local obj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.02, -0.02, -80.0, 10.0, 10.0, true, true, false, true, 1, true)
-- bones: 57005 right hand, 18905 left hand, 24818 spine, 31086 head
```
Delete on cancel, finish, death and resource stop.

## 5. Peds (NPCs)
```lua
local model = lib.requestModel(`g_m_m_armboss_01`)
local npc = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w, false, true)  -- false = not networked (local decoration)
SetEntityInvincible(npc, true); FreezeEntityPosition(npc, true)
SetBlockingOfNonTemporaryEvents(npc, true)      -- ignore gunshots/threats
SetPedFleeAttributes(npc, 0, false); SetPedCanRagdoll(npc, false)
SetModelAsNoLongerNeeded(model)
```
Coords from `/getcoords`-style tools are usually at foot level +1.0; subtract 1.0 for peds.

## 6. Particle effects and camera shake
```lua
lib.requestNamedPtfxAsset('core')
UseParticleFxAssetNextCall('core')
StartParticleFxNonLoopedAtCoord('ent_dst_concrete_large', x, y, z, 0.0, 0.0, 0.0, 1.0, false, false, false)
ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.2)
AddExplosion(x, y, z, 2, 1.0, true, false, 1.0)      -- type 2 = sticky bomb; networked explosions are visible to all
```
Explosions from clients may be blocked/flagged by server anticheat; for scripted explosions consider triggering via server-validated event.

## 7. Ropes
```lua
RopeLoadTextures()
local t = GetGameTimer() + 2000
while not RopeAreTexturesLoaded() and GetGameTimer() < t do Wait(0) end
local rope = AddRope(x, y, z, 0.0, 0.0, 0.0, length, 4, length, 1.0, 0.5, false, false, true, 1.0, false, 0)
AttachEntitiesToRope(rope, entA, entB, ax, ay, az, bx, by, bz, length, false, false, 0, 0)
-- cleanup
if DoesRopeExist(rope) then DeleteRope(rope) end
```
Ropes are local to the creating client; other players need their own rope created from a synced event.

## 8. Vehicles
```lua
local veh = GetVehiclePedIsIn(ped, false)            -- 0 if on foot
local plate = GetVehicleNumberPlateText(veh)
local closest = lib.getClosestVehicle(GetEntityCoords(ped), 5.0, false)
SetVehicleDoorsLocked(veh, 2)
-- server (OneSync): CreateVehicleServerSetter(model, 'automobile', x, y, z, h)
```
Keys: give via the server's key resource (`qb-vehiclekeys`: `TriggerEvent('vehiclekeys:client:SetOwner', plate)` in QBCore) — check what's installed.

## 9. Common control IDs (for IsControlJustPressed(0, id) / DisableControlAction)
| ID | Key | ID | Key |
|---|---|---|---|
| 38 | E | 47 | G |
| 44 | Q | 74 | H |
| 23 | F | 73 | X |
| 19 | LEFT ALT | 25 | RIGHT MOUSE (aim) |
| 24 | LEFT MOUSE (attack) | 200 | ESC (pause) |
| 322 | ESC | 177 | BACKSPACE |
| 21 | LEFT SHIFT | 22 | SPACE |

Prefer `RegisterKeyMapping` for anything the player triggers deliberately; use control IDs only inside short-lived Wait(0) interaction loops.

## 10. Help text / subtitles
```lua
BeginTextCommandDisplayHelp('STRING'); AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to hack'); EndTextCommandDisplayHelp(0, false, true, -1)
```
`~INPUT_CONTEXT~` renders the player's actual bound key for E.
