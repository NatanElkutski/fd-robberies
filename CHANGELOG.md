# Changelog

## 4.1.1 — ATM rope fixes

### Fixed
- The `[E]` prompt at the vehicle showed boxes: GTA's native text can't render Hebrew. Prompts now use the on-screen text UI (NUI) and show Hebrew.
- The rope never attached (it hung in the air): GTA can't tie ropes to map ATMs. The wall ATM is now swapped for an identical networked ATM as soon as the rope is tied, and every rope attaches to it.
- Ripping the ATM made it vanish together with the ATM next to it: only the exact wall ATM is hidden now; neighbours are untouched.
- The ATM and rope now stay until the crew has taken the money, then both are removed. The wall stays empty until the contract ends.

### Changed
- Pulls: drive forward hard until the rope goes taut (counts as a pull), reverse a little to give slack, repeat. Config: `atm.rope.pullSlack` replaces `pullDistance`, `pullResetSpeed`, `pullResetMs`.
- Key-binding descriptions (GTA settings menu) are English — the game font can't show Hebrew.

## 4.1.0 — ATM robbery overhaul

### Fixed
- Taking the money from a ripped-out ATM never worked (map ATMs aren't networked, so the ATM was never registered) and the console was spammed with `NETWORK_GET_NETWORK_ID_FROM_ENTITY: no net object for entity`.
- The towed ATM floated rigidly behind the car (or stayed standing in the street) instead of falling and dragging.
- Only the crew leader could make the ripped ATM lootable; now whoever ripped it does.
- Only the player who planted the charge could loot a blasted ATM; now the whole crew can.
- Cancelling the rope attach kept the ATM locked for the rest of the crew.

### New
- Rope tow with real physics: when the ATM breaks off, the map ATM is hidden for every player and replaced by a networked ATM that tips, crashes to the ground, drags, bounces and throws sparks while towed. A watchdog keeps it behind the car if physics lose it.
- The crew sees the tow rope too; players who join mid-robbery see the ATM removed from the wall.
- Stop far enough away and the ATM unhooks and settles; every member loots their share with a cash-grab animation (server checks they're next to it).
- If the tow vehicle is lost, the ATM stays on the ground and can be hooked to another vehicle (or looted if already far enough).
- Drill and explosive methods got proper animations and props (heist drill with sparks, thermite charge, short fire after the blast).
- When the contract ends, the ATM prop is removed and the wall ATM restored.

### Config (config/client.lua → atm.rope)
- Added `towRopeLength`, `ripImpulse`, `stopToDropMs`, `sparksMinSpeed`, `rescueExtraDistance`, `looseRehookDistance`.

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
