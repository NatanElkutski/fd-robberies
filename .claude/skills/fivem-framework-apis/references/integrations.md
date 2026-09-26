# Integrations: targets, inventories, notify, dispatch, clothing

## Targets

ox_target ships a qb-target compatibility layer, so qb-target-style calls usually work on ox_target servers too — but native ox_target calls are cleaner when you know it's installed. Keep `Config.TargetResource` and wrap calls in a bridge.

### qb-target
```lua
exports['qb-target']:AddTargetEntity(ped, { options = {
    { icon = 'fas fa-mask', label = 'Open robbery menu', action = function(entity) end,
      canInteract = function(entity, distance, data) return true end, job = 'police' --[[optional]], item = 'drill' --[[optional]] },
    { type = 'client', event = 'res:client:x', icon = 'fas fa-bomb', label = 'Plant' },
}, distance = 2.5 })
exports['qb-target']:AddTargetModel({ `prop_atm_01`, `prop_atm_02` }, { options = {...}, distance = 2.0 })
exports['qb-target']:AddCircleZone(name, vector3(x,y,z), radius, { name = name, useZ = true, debugPoly = false }, { options = {...}, distance = 2.0 })
exports['qb-target']:AddBoxZone(name, vector3(x,y,z), length, width, { name = name, heading = h, minZ = z-1, maxZ = z+1 }, { options = {...}, distance = 2.0 })
exports['qb-target']:RemoveZone(name)
exports['qb-target']:RemoveTargetEntity(entity, { 'Label A' })
exports['qb-target']:RemoveTargetModel(models, { 'Label A' })
```
Zone names are global across all resources — prefix them with your resource name.

### ox_target
```lua
exports.ox_target:addLocalEntity(ped, { {
    name = 'fd_open_menu', label = 'Open robbery menu', icon = 'fa-solid fa-mask', distance = 2.5,
    canInteract = function(entity, distance, coords, name, bone) return true end,
    onSelect = function(data) --[[data.entity, data.coords]] end,
    -- alternatives to onSelect: event = 'res:client:x', serverEvent = 'res:server:x', command = 'x'
    groups = { police = 0 }, items = 'drill',
} })
exports.ox_target:addModel({ `prop_atm_01` }, options)
local id = exports.ox_target:addSphereZone({ coords = vec3(x,y,z), radius = 0.8, debug = false, options = options })
local id = exports.ox_target:addBoxZone({ coords = vec3(x,y,z), size = vec3(1,1,1), rotation = h, options = options })
exports.ox_target:removeZone(id); exports.ox_target:removeLocalEntity(ped, 'fd_open_menu'); exports.ox_target:removeModel(models, names)
```
`serverEvent` sends the event with `data` directly — still validate it on the server like any net event.

## Inventories
### qb-inventory
Through the Player object (`Player.Functions.AddItem/RemoveItem`) — works across versions. v2 also exposes `exports['qb-inventory']:AddItem(src, item, amount, slot, info, reason)`, `RemoveItem`, `HasItem`, `CanAddItem(src, item, amount)`.
Dirty money: `markedbills` with `info = { worth = amount }`.

### ox_inventory (server)
```lua
exports.ox_inventory:CanCarryItem(src, 'drill', 1)
exports.ox_inventory:AddItem(src, 'black_money', amount)                --> success, response
exports.ox_inventory:RemoveItem(src, 'thermite', 1)                     --> bool
exports.ox_inventory:GetItemCount(src, 'drill')                         --> number
exports.ox_inventory:Search(src, 'count', 'drill')
```
Items defined in `ox_inventory/data/items.lua`: `['rope'] = { label = 'Robbery Rope', weight = 1500, stack = true, close = true, description = '...' }`. Images in `ox_inventory/web/images/<name>.png`. Client usage via `client = { export = 'res.useRope' }` or `exports('useRope', ...)`.

Detect which one is running and route through `Bridge.AddItem/RemoveItem/HasItem`. Ship item snippets for both formats.

## Notifications
Common: QBCore `QBCore.Functions.Notify`, ox_lib `lib.notify`, `okokNotify` (`exports['okokNotify']:Alert(title, msg, ms, type)`), `cm-notification` (`exports['cm-notification']:Alert(title, msg, ms, type)`), `mythic_notify`. Map your internal types (`success`, `error`, `primary/inform`, `warning`) in one bridge function.

## Police dispatch
Each resource has its own API — keep it in an open bridge function `Bridge.Dispatch(data)` with Config switch and a default fallback (send blip + notify to on-duty police from the server). Examples to support:
- **ps-dispatch**: `exports['ps-dispatch']:CustomAlert({ coords = coords, message = 'Fleeca Robbery', dispatchCode = '10-90', code = '10-90', icon = 'fas fa-vault', priority = 2, jobs = { 'leo' } })` (client), plus specific helpers like `exports['ps-dispatch']:FleecaBankRobbery(camId)`.
- **cd_dispatch**: client `TriggerServerEvent('cd_dispatch:AddNotification', { job_table = {'police'}, coords = coords, title = '10-90 - Robbery', message = msg, flash = 0, unique_id = tostring(math.random(0000000,9999999)), blip = { sprite = 431, scale = 1.2, colour = 3, flashes = false, text = 'Robbery', time = 5, radius = 0 } })`.
- **tk_dispatch**, **core_dispatch**, **qs-dispatch**, **rcore_dispatch** — check the installed resource's README; don't guess field names.
Trigger dispatch after the server has approved the start, not from a client-only path the cheater controls.

## Clothing / appearance
- qb-clothing: `TriggerEvent('qb-clothing:client:openMenu')`; illenium-appearance: `exports['illenium-appearance']:startPlayerCustomization(cb, config)` or its qb-clothing compatible events; fivem-appearance similar.
- Setting a robbery outfit directly: `SetPedComponentVariation(ped, component, drawable, texture, 0)` for components (1 mask, 3 arms, 4 legs, 6 shoes, 8 undershirt, 11 torso) and `SetPedPropIndex` for props (0 hat, 1 glasses). Detect gender with `GetEntityModel(ped) == \`mp_f_freemode_01\``. Offer a way to restore the previous outfit (save components first).
