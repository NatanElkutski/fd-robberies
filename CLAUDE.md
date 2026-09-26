# fd-robberies — project rules

Paid FiveM (GTA V) resource by FIVE DEV, shipped through Cfx.re Asset Escrow. Stack: QBCore, ox_lib, oxmysql, qb-target, React + TypeScript NUI.
Before writing code, load the matching project skill in `.claude/skills/` (fivem-lua-scripting, fivem-server-security, fivem-framework-apis, fivem-nui, fivem-escrow-release).

## Layout

```
config/     shared.lua client.lua server.lua   open to customers; `return { ... }`, loaded with require
locales/    he.json en.json                    open; every Lua and UI string
bridge/     qb/{client,server}.lua             framework adapter (only place QBCore is touched)
            client.lua server.lua              notify, progress, target, clothing, inventory/money wrappers
shared/     init.lua events.lua utils.lua types.lua
modules/    <feature>/client.lua server.lua    escrowed gameplay, one folder per feature
web/        React + TS + Vite source           built to web/build (gitignored, build before release)
sql/        install.sql
tools/      check.mjs                          consistency checks
```

## Lua rules (strict)

1. **A feature is a folder in `modules/`** with `client.lua` / `server.lua` (optional `shared.lua`). When a side grows past ~250 lines it becomes a `client/` or `server/` folder of role files (see `modules/atm/client/`).
2. **Public API only through `FD.<Module>`.** Everything else is `local`. Never read or write another module's state — call its functions.
3. **Handlers live only in module files.** Server handlers start with `local src = source`, validate argument types, then call module functions.
4. **Event and callback names only via `FD.Events.*`** (`shared/events.lua`). Never type an event string anywhere else.
5. **No framework or third-party resource call outside `bridge/`** (QBCore, qb-target, notify, clothing, inventory, money).
6. **No user-facing string outside `locales/`** — use `locale('key', ...)`. Add the key to both `he.json` and `en.json`.
7. **No tunable number, coordinate or item name outside `config/`.** Values only the server needs go in `config/server.lua` (never downloaded by players).
8. **File order:** header comment → requires/locals/state → private functions → public `FD.<Module>` functions → handlers → threads → cleanup.
9. **Modern CfxLua style** (see `.claude/skills/fivem-lua-scripting/references/modern-lua.md`): one statement per line, 4-space indent, guard clauses, backtick hashes, `+=`, `?.`, `lib.*` helpers, no `Citizen.` prefix, no deprecated natives.
10. Load order is explicit in `fxmanifest.lua` (gameplay files are escrowed, so they are NOT loaded with `require`). A new module = new folder + its files added to the manifest in dependency order.

## UI rules (strict)

1. `web/src/features/<name>/` holds `components/`, `api.ts` (the only place calling `fetchNui`), `types.ts`, `index.ts` (public exports). Features import other features only through `index.ts`.
2. Shared code lives in `components/`, `hooks/`, `providers/`, `store/`, `utils/`, `types/`, `theme/`. Screens live in `layouts/`.
3. Every NUI message and callback is typed in `types/protocol.ts` and must match the Lua `FD.Nui.Send` / `RegisterNUICallback` names.
4. CSS modules per component + `theme/tokens.css`; logical properties (RTL); no runtime dependency beyond react/react-dom.
5. Text only through `useLocale()`; keys live in `locales/*.json` under `ui.*`.

## Commands

```bash
npx @johnnymorganz/stylua-bin .                 # format Lua (stylua.toml sets CfxLua syntax)
npx @johnnymorganz/stylua-bin --check .         # parse + format check
node tools/check.mjs                            # events / locales / manifest / NUI protocol consistency
npm --prefix web install
npm --prefix web run dev                        # UI in the browser with mock data
npm --prefix web run build                      # → web/build (required before testing in game or releasing)
```

## Don'ts

- Don't add `modules/**` files to `escrow_ignore`; don't put secrets in `config/shared.lua` or `config/client.lua`.
- Don't rename event strings, NUI actions or DB columns without a major version bump and CHANGELOG entry.
- Security issues listed in `docs/superpowers/specs/2026-09-26-modular-refactor-design.md` §9 are known and pending — fix them only as a dedicated task.
