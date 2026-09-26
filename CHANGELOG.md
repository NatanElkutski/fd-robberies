# Changelog

## 4.0.0

Complete restructure of the resource. Gameplay, rewards, events and the database are unchanged.

### Upgrade notes (customers)
- `config.lua` is replaced by three files: **`config/shared.lua`**, **`config/client.lua`**, **`config/server.lua`**. Re-apply your settings to the new files; names are grouped per feature (e.g. `Config.ATMMethodTime` → `config/client.lua` `atm.methodTime`, `Config.Robberies.<id>.rewards` → `config/server.lua` `robberies.<id>.reward`).
- All texts moved to **`locales/he.json`** / **`locales/en.json`**. Hebrew is the default; set `locale` in `config/shared.lua` to change it (the `ox:locale` convar is not used).
- Integrations (notifications, progress bar, target, clothing, framework) are in the open **`bridge/`** folder.
- The NUI moved from `html/` to `web/build/`.
- Database table and item names are unchanged.

### Changed
- Code split into feature modules (`modules/<feature>/client.lua` / `server.lua`) with a shared event registry.
- Server-only values (rewards, XP, cooldowns, shop prices) are no longer downloaded by players.
- Callbacks use ox_lib; progress bars use `lib.progressBar` through the bridge.
- The menu was rebuilt in React + TypeScript with the same design; player names and chat are always rendered as text.
- Heist cooldowns now count down live while the menu is open.
- Clicking a face on the home page now opens the identity editor with that face selected (before, saving kept the old face).
- Locked robbery cards show the required level.
- Database migration no longer logs errors on every start.
- `fx_version` corrected to `cerulean`.

### Removed
- Unused settings: `Config.UseTarget`, `Config.Dispatch`, `Config.DispatchResource`, `Config.StoreRegisterModels`, `Config.RobberyImages`, per-robbery `dispatch`/`sprite`/`items`, unused rope physics values (`maxTowDistance`, `towSlack`, `hardLimit`, `towForce`).

### Now honoured
- `hubNpc.enabled/invincible/frozen/blockEvents`, `clothing.enabled`, `shop.allowCashItem`, `shop.allowBank`, `atm.rope.pullResetSpeed/pullResetMs`.

## 3.6.8
- Last version with the single-file layout.
