# FD-robberies Modular Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure fd-robberies into config/locales/bridge/shared/modules + a React/TS NUI, keeping gameplay behaviour identical.

**Architecture:** Qbox-style side-split config loaded with ox_lib `require`; ox_inventory-style `modules/<feature>/{client,server}.lua` loaded in explicit fxmanifest order (escrow-safe) sharing an `FD` namespace per side; all framework/third-party calls behind `Bridge`; React UI in `web/` built to `web/build`.

**Tech Stack:** CfxLua 5.4, ox_lib (callback, locale, progressBar, requestModel), oxmysql, QBCore, qb-target; React 18 + TypeScript + Vite; StyLua (CfxLua syntax) for format + parse; Node 22 for `tools/check.mjs`.

**Spec:** `docs/superpowers/specs/2026-09-26-modular-refactor-design.md`

## Global Constraints

- Event/callback string values unchanged (`fd-robberies:server:*`, `fd-robberies:client:*`).
- NUI action names unchanged (spec §5); `open` also carries `locale`.
- DB table `fd_robbery_progress` and its columns unchanged.
- Effective config values unchanged; crew sizes: store min 3 max 3, atm min 1 max 2; others min only, no max: house 2, container 2, vehicle 2, fleeca 3, jewelry 3, warehouse 3, armored 3, yacht 4, humane 4, bobcat 4, paleto 4, casino 5, pacific 6.
- No runtime UI dependency beyond react/react-dom.
- Every Lua file parses with `npx @johnnymorganz/stylua-bin --syntax CfxLua --check` after formatting.
- Security issues in spec §9 are NOT fixed.
- Files UTF-8 without BOM, LF in repo.

## Shared interfaces (names every task uses)

```lua
-- shared/init.lua (both sides)
FD = { Resource = GetCurrentResourceName(), IsServer = IsDuplicityVersion() }

-- shared/events.lua
FD.Events.Server.<Name>   -- 17 net events, e.g. Start = 'fd-robberies:server:start'
FD.Events.Client.<Name>   -- 12 events, e.g. Ended = 'fd-robberies:client:ended'
FD.Events.Callback.<Name> -- GetData, CheckMethod, GetSafeHint

-- shared/utils.lua
FD.Utils.levelFromXp(xp, xpPerLevel, maxLevel) -> integer
FD.Utils.trim(s) -> string
FD.Utils.formatCountdown(seconds) -> 'm:ss'

-- bridge (server)
Bridge.GetPlayer(src) -> table|nil            -- framework player object (opaque outside bridge)
Bridge.GetIdentifier(src) -> string|nil
Bridge.GetCharacterName(src) -> string
Bridge.GetPlayers() -> integer[]              -- loaded player sources
Bridge.CountOnDuty(jobName) -> integer
Bridge.ItemExists(name) -> boolean
Bridge.ResolveItemName(name) -> string|nil     -- exact or lower-case match in the item list
Bridge.GetItemCount(src, name) -> integer
Bridge.AddItem(src, name, amount) -> boolean
Bridge.RemoveItem(src, name, amount) -> boolean
Bridge.GetMoney(src, account) -> number
Bridge.AddMoney(src, account, amount, reason) -> boolean
Bridge.RemoveMoney(src, account, amount, reason) -> boolean
Bridge.Notify(src, message, kind)             -- kind: 'primary'|'success'|'error'

-- bridge (client)
Bridge.Notify(message, kind)
Bridge.Progress({ label, duration, anim = { dict, clip, flag } }) -> boolean  -- blocking
Bridge.GetClosestVehicle(coords) -> integer
Bridge.OpenClothing()
Bridge.Target.AddEntity(entity, options, distance)
Bridge.Target.AddModel(models, options, distance)
Bridge.Target.AddCircleZone(name, coords, radius, options, distance)
Bridge.Target.RemoveZone(name)
--   option = { icon, label, canInteract = fun(entity, distance): boolean, onSelect = fun(entity) }

-- modules (server)
FD.Progress.Get(identifier) -> { xp, completed, criminal_name, criminal_avatar, level }
FD.Progress.AddCompletion(identifier, xp)
FD.Progress.DisplayName(src) -> string
FD.Rewards.GiveDirtyMoney(src, amount) -> boolean, string|nil
FD.Crew.Get(src) -> leaderSrc, crew { leader, members = { [src] = true } }
FD.Crew.Count(crew) -> integer
FD.Crew.Payload(src) -> { leader, members, invites, isLeader }
FD.Contracts.Active -- { [robberyId] = activeState }  (read-only outside contracts)
FD.Contracts.Get(id) -> activeState|nil
FD.Contracts.FindByMember(src) -> robberyId|nil
FD.Contracts.IsMember(id, src) -> boolean
FD.Contracts.States() -> { [id] = { active, cooldown, requiredLevel } }
FD.Contracts.Payout(src, id) -> amount|nil      -- random dirty-money payout in robbery range

-- modules (client)
FD.Nui.Send(action, payload)
FD.Nui.Focus(enabled)
FD.Nui.OpenHub()
FD.Mission.Current() -> { id, ends }|nil
FD.Mission.Is(id) -> boolean
FD.Mission.OnStart(fn(id)) ; FD.Mission.OnEnd(fn(id))
FD.Actions.Run(label, durationMs, anim?) -> boolean   -- busy-guarded Bridge.Progress
FD.Actions.Busy() -> boolean
```

---

### Task 1: Tooling and rules
**Files:** Create `CLAUDE.md`, `.editorconfig`, `.luarc.json`, `.gitignore`, `.gitattributes`, `.vscode/extensions.json`, `stylua.toml`, `.github/workflows/lint.yml`; add existing `.claude/skills/**`.
- [ ] Write `CLAUDE.md` with spec §4 rules + §5 UI rules + commands (`npm --prefix web run build`, `node tools/check.mjs`, stylua).
- [ ] `stylua.toml`: `syntax = "CfxLua"`, 4 spaces, 120 cols, single quotes preferred.
- [ ] `.gitattributes`: `* text=auto eol=lf`, binaries marked.
- [ ] `.gitignore`: `web/node_modules/`, `web/build/`, `*-workspace/`, `*.zip`.
- [ ] Workflow: StyLua check + `node tools/check.mjs` + web build.
- [ ] Commit `chore: add repo tooling, rules and FiveM skills`.

### Task 2: Config split + locales
**Files:** Create `config/shared.lua`, `config/client.lua`, `config/server.lua`, `locales/he.json`, `locales/en.json`, `sql/install.sql` (moved). Old `config.lua` stays until Task 5.
- [ ] Move every value from `config.lua` to the side that reads it (shared: robbery catalogue incl. effective crew sizes; client: command/key, HubNPC, ATM models/target distances/rope, store coords & times, outfits; server: XP, job, money items, rewards, xpReward, cooldowns, shop, ATM items, store rewards).
- [ ] Extract every Hebrew string from `client.lua`, `server.lua`, `config.lua` and `html/*` to `locales/he.json` with dotted keys; placeholders `%s`/`%d`; English translation in `en.json`.
- [ ] Verify parse with StyLua; `node -e` JSON parse both locales.
- [ ] Commit `refactor: split config by side and extract locales`.

### Task 3: shared + bridge
**Files:** `shared/{init,events,utils,types}.lua`, `bridge/qb/{client,server}.lua`, `bridge/{client,server}.lua`.
- [ ] Implement interfaces above; QBCore specifics only inside `bridge/qb`; notify prefers `cm-notification` then QBCore (current behaviour); progress = `lib.progressBar`.
- [ ] Commit `refactor: add shared namespace, event registry and QBCore bridge`.

### Task 4: modules core/progress/rewards/crew/chat/contracts
Port from `server.lua` lines 1-126, 149-174 and `client.lua` lines 10-43, 70-83, 294-310, 344 into the module files with identical logic.
- [ ] Commit `refactor: move core, progress, crew, chat and contracts into modules`.

### Task 5: modules shop/location/store/atm + fxmanifest
Port `server.lua` 114-118, 127-148 and `client.lua` 44-69, 84-293, 306, 311-343. New `fxmanifest.lua` (`fx_version 'cerulean'`, `ox_lib 'locale'`, ordered lists, `files`, `escrow_ignore`). Delete `client.lua`, `server.lua`, `config.lua`, root `install.sql`.
- [ ] Parity inventory check (spec §6.4) by grep.
- [ ] Commit `refactor: move shop, location, store and ATM into modules; new manifest`.

### Task 6: React UI
`web/` scaffold (Vite react-ts, ESLint), `utils/fetchNui`, `utils/debugData`, `hooks/useNuiEvent`, `hooks/useExitListener`, `providers/{Visibility,Locale}Provider`, `store/`, `types/protocol.ts`, `theme/`, then features heists, crew, chat, profile, shop, mission(HUD), atm, safe, porting final effective CSS. Move `html/assets` → `web/public/assets`; delete `html/`.
- [ ] `npm run typecheck && npm run lint && npm run build` pass.
- [ ] Commit `feat(ui): rebuild NUI in React + TypeScript`.

### Task 7: checks, docs, version
`tools/check.mjs` (spec §6.2), README rewrite, CHANGELOG 4.0.0 + migration note, `version '4.0.0'`, KEYMASTER guide updated for new layout.
- [ ] `node tools/check.mjs` passes.
- [ ] Commit `docs: 4.0.0 docs, changelog and consistency checks`.

### Task 8: skills + CLAUDE.md final
Update `.claude/skills/fivem-lua-scripting` §1 repo notes and `fivem-escrow-release` escrow list to the new structure; finalize CLAUDE.md.
- [ ] Commit `docs: align project skills with the modular structure`.
