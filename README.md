# FD-robberies | FIVE DEV

Exclusive QBCore robbery network by **FIVE DEV**: persistent XP and levels, crews, lobby chat, an equipment shop, 15 contracts (store holdups, ATM breaches with drill / explosive / rope-and-vehicle, and location heists up to Pacific Standard), individual cooldowns and server-side robbery locks.

## Requirements

- [qb-core](https://github.com/qbcore-framework/qb-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- qb-target (or ox_target through its qb-target compatibility) — set in `config/client.lua`
- optional: cm-notification (used automatically when running)
- OneSync, with `sv_entityLockdown` not set to `strict` (the ATM rope method spawns a networked ATM prop from the client)

## Installation

1. Put `fd-robberies` in your resources folder.
2. Ensure the dependencies start before it, then add `ensure fd-robberies` to `server.cfg`.
   The resource is in Hebrew by default; to switch to English set `locale = 'en'` in `config/shared.lua`.
3. The database table is created automatically on start (`sql/install.sql` is included if you prefer to run it manually).
4. Make sure every item used by the resource exists in your items list — see `ITEMS_TO_ADD.lua`.
5. Adjust the configuration (below).

## Configuration

| File | What it controls |
|---|---|
| `config/shared.lua` | Robbery catalogue: level, police required, duration, crew size, coordinates; convenience-store locations |
| `config/client.lua` | Menu command and keys, contact NPC, target resource, outfits, store/ATM timings, rope physics |
| `config/server.lua` | Rewards, XP, cooldowns, police job, dirty-money item, ATM item requirements, shop items and prices |
| `locales/*.json` | Every text shown to players (robbery names, briefings, notifications, the menu) |
| `bridge/` | Integrations: framework, notifications, progress bar, target, clothing — adapt these to your server |

`config/server.lua` is never sent to players.

## Usage

- `/robberies` or **F6** opens the hub; the contact NPC also opens it and lets the crew leader close the active contract.
- **B** toggles the robbery briefing while a contract is running.
- Rewards, XP, cooldowns and crew rules are enforced by the server.

## Product information

- Product: `FD-robberies` — Developer and publisher: `FIVE DEV`
- Version: see `fxmanifest.lua` / `CHANGELOG.md`
- Protected distribution: Cfx.re Asset Escrow

## License

Copyright (c) 2026 FIVE DEV. All rights reserved.

This software is proprietary. Purchase or delivery grants a limited right to use it only on entitled Cfx.re accounts and servers. Copying, reselling, redistributing, decompiling, bypassing Asset Escrow, removing FIVE DEV branding, or publishing protected source code without written permission is prohibited. See `LICENSE.txt`.

## Development (FIVE DEV only)

See `CLAUDE.md` for the project structure and rules, and `KEYMASTER-UPLOAD.txt` for building a release.
