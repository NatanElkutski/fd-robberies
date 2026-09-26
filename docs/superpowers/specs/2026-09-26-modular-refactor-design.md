# FD-robberies — modular refactor design

- **Date:** 2026-09-26
- **Branch:** `refactor/modular-structure`
- **Target version:** 4.0.0 (major: customer config layout changes)
- **Status:** approved in conversation, pending written-spec review

## 1. Goal

Replace the current single-file layout (`client.lua` 345 lines, `server.lua` 175 lines of dense one-liners, `config.lua` with stacked override layers, `html/app.js` + an 841-line `style.css`) with a strict, feature-based structure modelled on the most-used open-source FiveM resources, so features can be maintained and added independently.

### In scope
- New folder structure and strict rules (§3, §4), documented in `CLAUDE.md`.
- Modernizing the Lua per the project skills: ox_lib callbacks/progress/model loading, current native names, readable formatting, `FD.<Module>` namespaces.
- All user-facing text moved to `locales/*.json`; config split by side.
- NUI rewritten as React + TypeScript + Vite in `web/`.
- Repo tooling: `.editorconfig`, `.luarc.json`, `.vscode/extensions.json`, `.gitignore`, GitHub lint/build workflow, `tools/check.mjs`.
- README, CHANGELOG, version bump, project skill updates.

### Out of scope (explicitly)
- **Security fixes.** Known holes are listed in §9 and left as-is so gameplay behaviour is unchanged; they're a follow-up task.
- New gameplay, balance changes, new frameworks (qbx/esx adapters): the structure allows them, but only the QBCore adapter is implemented.
- Image compression (the 28 MB of avatar PNGs) — follow-up.

### Behaviour contract
Every network event name, callback purpose, NUI flow, command, keybind, target option, DB column and effective config value behaves as today. Allowed differences:
1. Config file layout (values preserved; the conflicting crew-size layers collapse to their current effective result).
2. QBCore callbacks → `lib.callback` (internal transport only; names kept).
3. QBCore progressbar → `lib.progressBar` through the bridge (same durations/anims/disable flags).
4. React escapes text, which removes the NUI XSS as a side effect.
5. Dead UI code removed (filter menu bound to non-existent elements, `MutationObserver` lock hack, `#startHeist` timer patch); the locked-card overlay becomes part of the card and shows the required level.
6. Unused `Config.RobberyImages` remote URLs removed (the UI already uses local images).

## 2. Reference projects

| Repo | Adopted pattern |
|---|---|
| overextended/ox_inventory | `modules/<feature>/{client,server,shared}.lua`; `modules/bridge/<framework>/`; `locales/*.json`; React UI in `web/` built to `web/build` |
| Qbox-project/qbx_core, qbx_police, qbx_truckrobbery | `config/{client,server,shared}.lua` returning tables — server config never downloaded by clients; `ox_lib 'locale'`; `shared/types.lua`; `.editorconfig`, `.vscode`, lint workflow (`iLLeniumStudios/fivem-lua-lint-action`) |
| overextended/ox_doorlock, project-error/fivem-react-boilerplate-lua | `web/src/{layouts,components,hooks,providers,store,utils,theme}`, `useNuiEvent`, `useExitListener`, `fetchNui`, `debugData`, `VisibilityProvider` |

**Deliberate deviation:** ox/Qbox load gameplay modules with `require` (ox_lib `lib.require`, which reads source text via `LoadResourceFile`). Escrowed files are encrypted, so gameplay modules are loaded through ordered `fxmanifest.lua` script lists instead. Only the open (escrow_ignore) config files are `require`d Qbox-style.

## 3. Structure

```
fd-robberies/
├─ fxmanifest.lua
├─ config/                 open — `return { ... }` tables, loaded with require
│  ├─ shared.lua           robbery catalogue: id, label, subtitle, description, level, coords, radius,
│  │                       crew {min,max}, minPolice, duration, briefing, dispatch, kind, sprite
│  ├─ client.lua           open command/key, hub NPC, target resource & distances, ATM models/rope physics,
│  │                       store ped/register/shelf/safe coords, outfits, clothing event
│  └─ server.lua           rewards, xpReward, XP per level, max level, cooldowns, required job, dirty-money
│                          items, shop items & prices, ATM item requirements, store reward ranges, method times
├─ locales/he.json en.json open — every Lua and UI string (UI keys under "ui.*")
├─ bridge/                 open
│  ├─ qb/client.lua        QBCore client adapter (player data, closest vehicle)
│  ├─ qb/server.lua        QBCore server adapter (player, identifier, charinfo, job/duty, items, money)
│  ├─ client.lua           Notify, Progress, Target (qb-target API), Dispatch, Clothing
│  └─ server.lua           Notify, Inventory/Money (via adapter), OnDuty police count
├─ shared/
│  ├─ types.lua            LuaLS annotations for config and state shapes
│  ├─ init.lua             `FD = {}` namespace, `FD.Config`, locale init
│  ├─ events.lua           `FD.Events` — every event/callback name constant
│  └─ utils.lua            pure helpers (clamp, sanitizeText, levelFromXp, …)
├─ modules/                escrowed — one folder per feature
│  ├─ core/        client.lua (NUI open/close/focus, message helper, cleanup) server.lua (DB schema, banner)
│  ├─ progress/    server.lua (XP, level, criminal profile, getData payload)  client.lua (profile NUI cb)
│  ├─ crew/        client.lua server.lua   (invite/accept/leave, nearby players, refresh)
│  ├─ chat/        client.lua server.lua   (lobby chat)
│  ├─ contracts/   client.lua server.lua   (start, active state, members, timer, blip, end/exit/cancel,
│  │                                        cooldowns, expiry thread, playerDropped, death)
│  ├─ shop/        client.lua server.lua   (equipment purchase)
│  ├─ location/    client.lua server.lua   (generic "location" robberies)
│  ├─ store/       client.lua server.lua   (clerk peds, aim-to-surrender, registers, shelves, safe code)
│  └─ atm/         client/{menu,drill,explosive,rope}.lua  server.lua
├─ web/                    React + TS + Vite source; output web/build (gitignored)
├─ sql/install.sql
├─ tools/check.mjs         consistency checks (§6)
├─ README.md CHANGELOG.md CLAUDE.md LICENSE.txt ITEMS_TO_ADD.lua KEYMASTER-UPLOAD.txt
└─ .editorconfig .luarc.json .gitignore .vscode/extensions.json .github/workflows/lint.yml
```

Values the UI must display but that live in `config/server.lua` (per-robbery `xpReward`, `xpPerLevel`, shop items with label/price/description/image key) are sent by the server in the `getData` callback payload; the client never reads `config/server.lua`.

Load order in `fxmanifest.lua`: `@ox_lib/init.lua` → `shared/*` (init, events, utils, types) → `bridge/qb/*` → `bridge/{client,server}.lua` → `modules/core` → `modules/progress` → `crew` → `chat` → `contracts` → feature modules. `files` lists `config/client.lua`, `config/shared.lua`, `locales/*.json`, and `web/build/**`; `config/server.lua` is **not** in `files`.

`escrow_ignore`: `config/**`, `locales/**`, `bridge/**`, `sql/**`, `ITEMS_TO_ADD.lua`, docs, license.

## 4. Strict rules (Lua)

1. **Module = folder** under `modules/`. It contains only `client.lua`, `server.lua`, optional `shared.lua`; when a side exceeds ~250 lines it becomes a `client/` or `server/` folder of role files (e.g. `atm/client/rope.lua`).
2. **Public API only through the namespace:** each module side declares `FD.<Module> = {}` and exposes functions there. Everything else is `local`. A module never reads or writes another module's state tables.
3. **Handlers only in module files**, never in `shared/` or `bridge/`. Server handlers: capture `local src = source` first, validate type/shape of args, then call module functions.
4. **Event and callback names only via `FD.Events.*`.** String values stay identical to today (`fd-robberies:server:start`, …).
5. **No framework or third-party resource call outside `bridge/`** (QBCore, qb-target, cm-notification, tk_dispatch, qb-clothing, inventory/money).
6. **No user-facing string outside `locales/`**; use `locale('key', ...)`.
7. **No tunable number, coordinate or item name outside `config/`.**
8. **File layout order:** header comment → locals/state → private functions → public `FD.<Module>` functions → event/callback/NUI handlers → threads → cleanup (`onResourceStop`, `playerDropped`).
9. **Modern style** per `.claude/skills/fivem-lua-scripting` (`references/modern-lua.md`): one statement per line, 4-space indent, guard clauses, backtick hashes, compound operators, `?.` where it clarifies, `lib.*` helpers, no `Citizen.` prefixes, no deprecated natives.
10. Files ≤ ~250 lines; UTF-8 without BOM.

## 5. UI (web/)

```
web/
├─ package.json  vite.config.ts (base './', outDir 'build')  tsconfig*.json  eslint.config.js  index.html
├─ public/assets/          heists/, avatars/, shop/ images (moved unchanged from html/assets)
└─ src/
   ├─ main.tsx  App.tsx    App mounts: <HubLayout/> (focused menu), <HudLayout/> (mission overlay),
   │                       <AtmMenu/>, <SafeKeypad/>, <ProfileModal/>
   ├─ layouts/hub/         HubLayout, Header, Tabs, HeistsPage, ShopPage
   ├─ layouts/hud/         HudLayout (mission timer/objective/briefing, pointer-events none)
   ├─ features/<name>/     components/*.tsx + *.module.css, api.ts (only place calling fetchNui),
   │                       types.ts, index.ts (public exports)
   │     heists/ crew/ chat/ profile/ shop/ mission/ atm/ safe/
   ├─ components/          shared presentational UI (Button, Modal, Panel, Avatar, Badge, Section)
   ├─ hooks/               useNuiEvent, useExitListener, useInterval
   ├─ providers/           VisibilityProvider, LocaleProvider (locale dictionary sent from Lua)
   ├─ store/               context + reducer: config, progress, robberies, crew, chat, nearby, shop, mission
   ├─ utils/               fetchNui, debugData (browser mocks), format (money, mm:ss), assets (image paths)
   ├─ types/protocol.ts    discriminated union of every NUI message and callback payload
   └─ theme/               tokens.css (colours, radii, spacing), base.css (reset, RTL, fonts)
```

UI rules:
1. Features import only from `components/`, `hooks/`, `providers/`, `store/`, `utils/`, `types/`, `theme/` and other features' `index.ts` — never another feature's internals.
2. Only `features/*/api.ts` calls `fetchNui`; only `hooks/useNuiEvent` listens to `message`.
3. Every message/callback name and payload is typed in `types/protocol.ts` and matches the Lua side.
4. Styling via CSS modules + `theme/tokens.css`; logical properties for RTL; no inline styles except dynamic background images.
5. No runtime dependency beyond `react`/`react-dom`.
6. Text only through `useLocale()` (dictionary delivered by Lua from `locales/*.json`, with Hebrew fallback bundled for browser dev).
7. Visual parity with the current UI: port the final effective styles of `style.css` (last-wins across its override layers).

NUI protocol (unchanged action names):
- Lua→UI: `open`, `close`, `dataRefresh`, `nearby`, `lobbyMessage`, `mission`, `timer`, `toggleBrief`, `atmMenu`, `safeInput`.
- UI→Lua: `close`, `start`, `endMission`, `buyItem`, `saveCriminalProfile`, `crewInvite`, `crewAccept`, `crewLeave`, `lobbyMessage`, `chatFocus`, `refreshNearby`, `safeCancel`, `safeSubmit`, `atmChoose`, `atmCancel`.
- `open` additionally carries `locale` (UI dictionary).

## 6. Verification

1. **Lua syntax:** parse every `.lua` file with a CfxLua-aware parser (StyLua with CfxLua syntax, or the lint action's luacheck) — zero errors.
2. **`tools/check.mjs`** (Node, no deps):
   - every `FD.Events` name has a handler registered on the expected side and every trigger uses a defined name;
   - every `locale('…')` key in Lua and every UI key exists in both `he.json` and `en.json`;
   - every `.lua` file under `shared/ bridge/ modules/ config/` is referenced by `fxmanifest.lua` (or `require`);
   - NUI action names in Lua `SendNUIMessage`/`RegisterNUICallback` match `types/protocol.ts`.
3. **UI:** `npm run typecheck`, `npm run lint`, `npm run build` pass; `npm run dev` renders every screen with `debugData` mocks.
4. **Parity inventory** (written before moving code, checked item by item after):
   - server net events (17): saveCriminalProfile, crewInvite, crewAccept, crewLeave, lobbyMessage, releaseATMMethod, explosiveReady, consumeATMItem, start, storeAction, buyItem, registerRopeATM, ropeLootable, ropeLoot, complete, exitMission, cancel;
   - server callbacks (3): getData, checkMethod, getSafeHint;
   - client events (12): notify, crewRefresh, lobbyMessage, started, ended, openATMMethods, lootBlastedATM, lootTowedATM, crewRopeATM, crewRopeLootable, detachRopeAfterLoot, ropeAllLooted;
   - NUI callbacks (15) and messages (10) listed in §5;
   - commands/keys: `/robberies` + F6, `+robberybrief` + B;
   - targets: hub NPC (4 options), ATM models (3 options), close-range ATM zones, store register/shelf/safe zones, location zones;
   - DB table `fd_robbery_progress` columns unchanged.
5. **In-game checklist** (run by the owner on a dev server before release): hub open/close/ESC; profile save; crew invite/accept/leave/disband; chat; shop buy with cash item and bank, full-inventory refund; store robbery (aim, registers, shelves, safe hint + code); ATM drill / explosive / rope (hook, two pulls, tow, drop, both members loot); location robbery; exit contract → XP; cooldown display; timeout; death cancel; leader disconnect; `restart fd-robberies` mid-robbery leaves no peds/ropes/focus.

## 7. Work order (one commit each)

1. Tooling & rules: `CLAUDE.md`, `.editorconfig`, `.luarc.json`, `.gitignore`, `.vscode/extensions.json`, lint workflow.
2. `config/` split + `locales/he.json` (all extracted strings) + `locales/en.json`.
3. `shared/` + `bridge/`.
4. Modules: core, progress, crew, chat, contracts.
5. Modules: store, atm, location, shop; new `fxmanifest.lua`; delete `client.lua`, `server.lua`, `config.lua`.
6. `web/` scaffold + infrastructure, then features one by one; delete `html/`.
7. `tools/check.mjs`, README, CHANGELOG, version 4.0.0.
8. Update project skills and `CLAUDE.md` with the final structure.

## 8. Migration note for customers (goes in CHANGELOG)

4.0.0 replaces `config.lua` with `config/shared.lua`, `config/client.lua`, `config/server.lua`, and hardcoded Hebrew with `locales/*.json` (select with `setr ox:locale he` in server.cfg). Old configs must be re-applied to the new files; DB and item names are unchanged.

## 8b. Implementation notes (as built)

- Two extra modules emerged: `modules/hub` (menu payload, NPC, open command) and `modules/rewards` (dirty-money payout). Kind-specific completion is routed with `FD.Contracts.OnComplete(kind, handler)`; client modules hook missions with `FD.Mission.OnStart/OnEnd`.
- UI: a tiny `features/hub` holds `closeUi` so only `api.ts` files call `fetchNui`; `providers/` contains only `LocaleProvider` (visibility lives in the store).
- `?[` safe-index is avoided (StyLua can't parse it); `?.` is used.
- Target option callbacks run inside `CreateThread` in the bridge so progress bars / callbacks can yield.

## 9. Known security issues (not fixed in this refactor)

- `server:complete` (location/drill) pays without server-side distance or elapsed-time checks.
- `server:consumeATMItem` is a separate client-triggered event; the reward path doesn't require it.
- `server:lobbyMessage`, `server:crewInvite`, `server:buyItem` have no rate limit.
- `server:storeAction` has no server-side proximity check to the store.
- `server:cancel` lets any member end the contract for everyone.
- Config (including reward ranges) is currently sent to clients — fixed structurally by §3 (`config/server.lua`).
