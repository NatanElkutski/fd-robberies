---
name: fivem-framework-apis
description: Correct API usage for the FiveM ecosystem libraries — QBCore, Qbox (qbx_core), ESX, ox_lib (callbacks, notify, progress, zones, points, context menus, input dialogs, skill checks, locale, cache), oxmysql, qb-target / ox_target, qb-inventory / ox_inventory, notifications, dispatch and clothing integrations. Use this whenever code calls or should call any of these (Player.Functions.AddItem, AddMoney, lib.callback, lib.progressBar, MySQL.query, exports.ox_target, AddTargetEntity, etc.), when adding a bridge/compatibility layer between frameworks, or when the user asks to "support ESX/Qbox/ox_inventory" or "make it work with my framework".
---

# FiveM framework and library APIs

Pick the API the resource already depends on (see `fivem-lua-scripting` §1). When unsure of a signature, look at the dependency's source in the server's `resources/` folder or its docs rather than guessing — these libraries change between versions (e.g. qb-inventory v2 moved to exports).

Load only the reference you need:

| Topic | File |
|---|---|
| QBCore (server + client), Qbox differences, ESX equivalents | `references/frameworks.md` |
| ox_lib modules (callback, notify, progress, zones, points, menus, locale, cache) | `references/ox_lib.md` |
| oxmysql queries, transactions, schema/migrations | `references/oxmysql.md` |
| qb-target vs ox_target, inventories, notify, dispatch, clothing | `references/integrations.md` |

## Principles

- **Configurable integrations over hardcoded ones.** Customers run different notify/dispatch/target/inventory/clothing resources. Route each through one small wrapper function (a "bridge") driven by `Config.*`, placed in an escrow-ignored file so customers can adapt it:
  ```lua
  -- bridge/client.lua (escrow_ignore)
  function Bridge.Notify(msg, kind)
      if GetResourceState('ox_lib') == 'started' then
          return lib.notify({ description = msg, type = kind == 'primary' and 'inform' or kind })
      end
      QBCore.Functions.Notify(msg, kind)
  end
  ```
  Gameplay code then calls `Bridge.Notify` only. This is how commercial scripts ship "open editable files".
- **Check resource state before calling an optional export**: `GetResourceState(name) == 'started'`. Calling an export of a stopped resource throws.
- **Items must exist in the shared item list** (QBCore `QBShared.Items` / ox_inventory `data/items.lua`) or AddItem silently fails. Ship an `ITEMS_TO_ADD` snippet for both formats and check `QBCore.Shared.Items[name]` at start with a clear console warning.
- **Check return values.** `AddItem`, `RemoveItem`, `RemoveMoney` return false on full inventory / insufficient funds — branch on it and refund on partial failure.
- **Money types**: QBCore accounts `cash`, `bank`, `crypto`; many servers use an item for cash (`cash`) or dirty money (`markedbills` with `info.worth`, `black_money` in ESX, `dirtymoney` custom). Keep the item/account name in Config.
- **Jobs & duty**: police count = players whose job type/name matches Config and `onduty == true`. Keep the job list in Config (`{'police','sheriff'}`) — many servers have multiple LEO jobs.
- **Player lifecycle**: load data on `QBCore:Server:PlayerLoaded` / client `QBCore:Client:OnPlayerLoaded`, clear on unload/drop. Don't query the DB on every UI open if you can cache per session.
