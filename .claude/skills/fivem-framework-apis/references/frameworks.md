# Frameworks: QBCore, Qbox, ESX

Verify signatures against the installed version when in doubt (`resources/[qb]/qb-core/server/player.lua`, `functions.lua`).

## QBCore — server
```lua
local QBCore = exports['qb-core']:GetCoreObject()

local Player = QBCore.Functions.GetPlayer(src)             -- nil if not loaded
local Player = QBCore.Functions.GetPlayerByCitizenId(cid)  -- online only
local players = QBCore.Functions.GetQBPlayers()            -- { [src] = Player }  (GetPlayers() is deprecated)
local list, count = QBCore.Functions.GetPlayersOnDuty('police')  -- if present in the installed version
QBCore.Functions.HasItem(src, 'drill', 1)
QBCore.Functions.HasPermission(src, 'admin')
QBCore.Functions.CreateUseableItem('thermite', function(src, item) ... end)
QBCore.Functions.CreateCallback('res:server:getData', function(src, cb, ...) cb(result) end)

-- Player.PlayerData
-- citizenid, license, source, name, charinfo{firstname,lastname,phone,gender(0/1),...}
-- money{cash,bank,crypto}, job{name,label,type,onduty,isboss,grade{level,name}}, gang{...}, metadata{...}, items{}

Player.Functions.AddMoney('bank', amount, 'reason')      --> bool
Player.Functions.RemoveMoney('cash', amount, 'reason')   --> bool (false if insufficient)
Player.Functions.GetMoney('bank')
Player.Functions.AddItem(name, amount, slot?, info?)     --> bool
Player.Functions.RemoveItem(name, amount, slot?)         --> bool
Player.Functions.GetItemByName(name)                     --> item table {amount, info, slot,...} | nil
Player.Functions.SetMetaData(key, value)
Player.Functions.SetJob(name, grade)

-- item box popup on the client after add/remove (qb-inventory; event name differs by version)
TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[name], 'add', amount)   -- v2
TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[name], 'add')              -- legacy
```
Server events: `QBCore:Server:PlayerLoaded` (Player), `QBCore:Server:OnPlayerUnload` (src), `QBCore:Server:OnJobUpdate`.

## QBCore — client
```lua
local PlayerData = QBCore.Functions.GetPlayerData()
QBCore.Functions.Notify(text, 'success'|'error'|'primary', ms)
QBCore.Functions.TriggerCallback('res:server:getData', function(result) end, ...)
QBCore.Functions.Progressbar(name, label, ms, useWhileDead, canCancel,
    { disableMovement=true, disableCarMovement=true, disableMouse=false, disableCombat=true },
    { animDict='mini@repair', anim='fixing_a_ped', flags=49 }, {}, {},
    function() --[[done]] end, function() --[[cancel]] end)
QBCore.Functions.GetClosestVehicle(coords)
QBCore.Functions.GetClosestPlayer(coords)   --> player, distance
```
Client events: `QBCore:Client:OnPlayerLoaded`, `QBCore:Client:OnPlayerUnload`, `QBCore:Client:OnJobUpdate` (job), `QBCore:Player:SetPlayerData` (data).
Keep a local `PlayerData` updated from these events instead of calling GetPlayerData in loops.

## Qbox (qbx_core)
- `exports.qbx_core:GetPlayer(src)` returns the same Player shape; `exports.qbx_core:GetPlayerData()` on client.
- Ships a qb-core compatibility bridge, so `exports['qb-core']:GetCoreObject()` usually still works — but Qbox servers always use **ox_inventory** and **ox_lib**, so inventory calls should go through `exports.ox_inventory` (see integrations.md).
- `exports.qbx_core:Notify(src, text, type)`; progress via `lib.progressBar`.

## ESX (es_extended ≥ 1.9)
```lua
local ESX = exports['es_extended']:getSharedObject()
local xPlayer = ESX.GetPlayerFromId(src)
xPlayer.identifier; xPlayer.getJob().name; xPlayer.job.onDuty (legacy may lack duty)
xPlayer.addInventoryItem(name, n); xPlayer.removeInventoryItem(name, n); xPlayer.getInventoryItem(name).count
xPlayer.canCarryItem(name, n)
xPlayer.addAccountMoney('black_money'|'bank'|'money', amt, reason); xPlayer.getAccount('bank').money
ESX.RegisterServerCallback / ESX.TriggerServerCallback
ESX.ShowNotification(msg) -- client
```
Identifier column: ESX `identifier` vs QBCore `citizenid` — keep a bridge function `Bridge.GetIdentifier(src)` if supporting both.

## Multi-framework bridge sketch
```lua
Bridge = {}
local fw = GetResourceState('qbx_core') == 'started' and 'qbx'
        or GetResourceState('qb-core') == 'started' and 'qb'
        or GetResourceState('es_extended') == 'started' and 'esx'
if fw == 'qb' or fw == 'qbx' then
    local QBCore = exports['qb-core']:GetCoreObject()
    function Bridge.GetIdentifier(src) local p = QBCore.Functions.GetPlayer(src); return p and p.PlayerData.citizenid end
    function Bridge.AddItem(src, item, n, meta) local p = QBCore.Functions.GetPlayer(src); return p and p.Functions.AddItem(item, n, nil, meta) end
elseif fw == 'esx' then
    local ESX = exports['es_extended']:getSharedObject()
    function Bridge.GetIdentifier(src) local x = ESX.GetPlayerFromId(src); return x and x.identifier end
    function Bridge.AddItem(src, item, n) local x = ESX.GetPlayerFromId(src); if x and x.canCarryItem(item, n) then x.addInventoryItem(item, n) return true end return false end
end
```
If ox_inventory is running, prefer `exports.ox_inventory:AddItem` regardless of framework.
