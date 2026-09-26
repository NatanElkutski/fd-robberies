# fd-robberies — project rules

Paid FiveM (GTA V) resource by FIVE DEV, shipped through Cfx.re Asset Escrow. Stack: QBCore, ox_lib, oxmysql, qb-target, React + TypeScript NUI.
Before writing code, load the matching project skill in `.claude/skills/` (fivem-lua-scripting, fivem-server-security, fivem-framework-apis, fivem-nui, fivem-escrow-release).

## Layout

```
fxmanifest.lua                         explicit load order (gameplay files are escrowed → no require)
config/     shared.lua client.lua server.lua   open to customers; `return { ... }`, loaded with require('config.x')
locales/    he.json en.json            open; every Lua and UI string (nested JSON, loaded by shared/locale.lua)
bridge/     qb/client.lua qb/server.lua        framework adapter (only place QBCore is touched)
            client.lua server.lua              notify, progress, target, clothing wrappers
shared/     init.lua (FD namespace) locale.lua (locale(), FD.Locale) events.lua (FD.Events) utils.lua (FD.Utils) types.lua (annotations)
modules/    core/        NUI helpers, busy-guarded actions, banner, DB migration
            progress/    XP, levels, criminal profile
            rewards/     dirty-money payout with fallbacks (server)
            crew/  chat/ crews and lobby chat
            contracts/   start / active state / cooldowns / complete routing / close / expiry; client mission + HUD
            hub/         menu payload, contact NPC, open command
            shop/ location/ store/     one folder per feature
            atm/         server.lua + client/{state,rope,drill,explosive,menu}.lua
web/src/    React UI (see below) → web/build (committed so servers can run straight from git — rebuild and commit it with every web/src change)
sql/        install.sql
tools/      check.mjs  (events / locales / manifest / NUI protocol consistency)
```

## Language (strict) — this is a Hebrew FiveM server

- **Every text a player sees or acts on is Hebrew**: NPC/target options, menus, tabs, buttons, titles, section headings, placeholders, hints, notifications, progress-bar labels, keybinding descriptions, briefings, errors. Hebrew is the default (`config/shared.lua` → `locale = 'he'`), and `locales/he.json` must be complete.
- **English is allowed only for**: the brand (FIVE DEV, CRIMINAL NETWORK), GTA place/brand names (Vangelico, Paleto, Fleeca, Humane Labs…), technical tokens (ID, XP, ALT, E, GPS, USB, $), and small decorative code-name tags shown next to a Hebrew title (`robbery.*.subtitle`, `*.kicker`, `*.brand`). When unsure, use Hebrew.
- Every new key goes into **both** `he.json` (Hebrew) and `en.json` (English). `tools/check.mjs` fails on a `he.json` value without Hebrew unless its key is allowlisted there — extend the allowlist only for the categories above.
- The resource uses its own loader (`shared/locale.lua`), not ox_lib's `ox:locale` convar or per-player setting, so the configured language always wins.
- Layout stays RTL (`dir="rtl"`); wrap mixed-direction fragments (IDs, prices, English names) so they don't flip.

## Lua rules (strict)

1. **A feature is a folder in `modules/`** with `client.lua` / `server.lua`. When a side grows past ~250 lines it becomes a `client/` or `server/` folder of role files (see `modules/atm/client/`).
2. **Public API only through `FD.<Module>`.** Everything else is `local`. Never read or write another module's state — call its functions. Module-internal shared state (e.g. `FD.Atm`) is used only by that module's own files.
3. **Handlers live only in module files.** Server handlers start with `local src = source`, validate argument types, then act.
4. **Event and callback names only via `FD.Events.*`** (`shared/events.lua`). Never type an event string anywhere else. Robbery kinds hook into completion with `FD.Contracts.OnComplete(kind, handler)`; client modules react to missions with `FD.Mission.OnStart/OnEnd`.
5. **No framework or third-party resource call outside `bridge/`** (QBCore, qb-target, notify, clothing, inventory, money).
6. **No user-facing string outside `locales/`** — use `locale('key', ...)`; add the key to both `he.json` and `en.json`.
7. **No tunable number, coordinate or item name outside `config/`.** Values only the server needs go in `config/server.lua` (never downloaded by players); send what the UI must display through the `getData` payload.
8. **File order:** header comment → requires/locals/state → private functions → public `FD.<Module>` functions → handlers → threads → cleanup.
9. **Modern CfxLua style** (`.claude/skills/fivem-lua-scripting/references/modern-lua.md`): one statement per line, 4-space indent, guard clauses, backtick hashes, `+=`, `?.` (dot form only — `?[` is not supported by the tooling), `lib.*` helpers, no `Citizen.` prefix, no deprecated natives. Anything that yields (progress bars, `lib.callback.await`) runs in a thread/handler.
10. **A new module** = new folder + its files added to `fxmanifest.lua` in dependency order (shared → bridge → core → progress/rewards/crew/chat → contracts → features).

## UI rules (strict)

1. `web/src/features/<name>/` holds `components/` (`*.tsx` + `*.module.css`), `api.ts` (the only place calling `fetchNui`), optional `types.ts`, and `index.ts` (public exports). Features import other features only through `index.ts` (ESLint enforces it).
2. Shared code: `components/` (presentational), `hooks/` (`useNuiEvent` is the only `message` listener), `providers/` (`LocaleProvider`), `store/` (context + reducer; `useNuiSync` maps Lua messages to actions), `utils/`, `types/`, `theme/`. Screens live in `layouts/` (`hub/`, `hud/`).
3. Every NUI message and callback is typed in `types/protocol.ts` and must match Lua `FD.Nui.Send` / `RegisterNUICallback` names (checked by `tools/check.mjs`).
4. CSS modules + `theme/tokens.css`; the page background stays transparent; no runtime dependency beyond react/react-dom.
5. Text only through `useLocale()`; keys live in `locales/*.json` (`ui.*`, `shop.items.*`); never render strings as HTML.

## Commands

```bash
npx @johnnymorganz/stylua-bin .              # format Lua (stylua.toml: CfxLua syntax)
npx @johnnymorganz/stylua-bin --check .      # parse + format check
node tools/check.mjs                         # consistency checks
cd web && npm install                        # once
cd web && npm run dev                        # UI in a browser with mock data (utils/debugData.ts)
cd web && npm run typecheck && npm run lint && npm run build
```

Release steps: `KEYMASTER-UPLOAD.txt`. Every release bumps `version` in `fxmanifest.lua` and adds a `CHANGELOG.md` entry.

## Don'ts

- Don't add `modules/**` or `shared/**` to `escrow_ignore`; don't add `config/server.lua` to `files`.
- Don't rename event strings, NUI actions or DB columns without a major version bump and a CHANGELOG entry.
- Known security gaps are listed in `docs/superpowers/specs/2026-09-26-modular-refactor-design.md` §9 — fix them as dedicated tasks, not silently inside other changes.
