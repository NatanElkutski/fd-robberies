# FD-robberies | FIVE DEV
Exclusive QBCore robbery network by **FIVE DEV**, with persistent XP/levels, crews, equipment shop, individual cooldowns and server-side active robbery locks.

## Requirements
- qb-core
- oxmysql
- qb-target (if Config.UseTarget=true)
- ox_inventory
- ox_lib
- optional: cm-notification, tk_dispatch

## Install
1. Put `fd-robberies` in resources.
2. Ensure dependencies before this resource.
3. Add `ensure fd-robberies` to server.cfg.
4. The SQL table is created automatically on resource start.
5. Ensure `dirtymoney` and optional reward items exist in QBCore shared items.
6. Edit every robbery in config.lua: coords, radius, levels, cooldown, duration, police and rewards.

## Product information
- Product: `FD-robberies`
- Developer and publisher: `FIVE DEV`
- Version: `2.0.0`
- Protected distribution: Cfx.re Asset Escrow

## License
Copyright (c) 2026 FIVE DEV. All rights reserved.

This software is proprietary. Purchase or delivery grants a limited right to use it only on entitled Cfx.re accounts and servers. Copying, reselling, redistributing, decompiling, bypassing Asset Escrow, removing FIVE DEV branding, or publishing protected source code without written permission is prohibited.

## Use
- `/robberies` or F6 opens the hub.
- A qb-target hub is also created at Config.MenuLocation.
- Player must physically be inside the configured robbery radius to press Start.

## Important
Rewards and XP are granted server-side. The same robbery cannot be started by multiple players simultaneously. Each robbery has an independent cooldown. Level 2+ robberies remain locked until enough XP has been earned.


V4 UI: enlarged menu, sorted unlocked robberies first, explicit required level labels, and unique image artwork for all 15 robbery cards.

## V5 additions
- The robbery timer stays on the left until time expires or the player returns to the robbery contact NPC and chooses **סיים / צא מהשוד הפעיל**.
- Store robbery: clerks are spawned at the configured GTA convenience stores. A player with the Store contract must AIM a firearm at the clerk until the clerk raises his hands. Only then do register/shelf/safe targets unlock for that specific store.
- Each store has register loot, black-money shelf loot, and a rear safe. The safe opens a custom 3-digit keypad with a generated hint; codes are randomized per active contract/store and validated server-side.
- ATM robbery: qb-target offers Drill / Explosive / Rope+Vehicle. The corresponding inventory item is required and consumed on success. Rope now requires the `rope` item.
- The main NUI has a second tab: **חנות ציוד לשודים**. Prices/items are in `Config.RobberyShop`.
- `ITEMS_TO_ADD.lua` contains the custom rope item definition. Make sure every item in `Config.RobberyShop.items` exists in your `qb-core/shared/items.lua`.
- Store coordinates are in `Config.StoreRobbery.stores`; adjust them if your server uses custom MLO interiors.
- Heist cards now use real GTA/FiveM gameplay preview image URLs with the existing local SVG as fallback. You can replace any URL under `Config.RobberyImages` with your own screenshots.


## V6 payment fix
The robbery equipment shop now supports two payment methods: inventory item `cash`/`CASH`, and QBCore bank balance. Configure `Config.RobberyShop.cashItem`. Each shop item has separate Cash and Bank buttons.

## V13 Performance
- Mission timer NUI updates reduced from every game frame to once per second.
- Crew refresh no longer reopens/rebuilds the entire NUI.
- Heist cards use bundled local images instead of remote web images to avoid CEF network stalls.
- Removed expensive backdrop blur / transform effects from scrolling areas.

## V15 - Unbreakable ATM tow
After the ATM is ripped from the wall, the actual tow connection uses AttachEntityToEntity so vehicle speed cannot break it. The visible GTA rope remains for appearance only. The ATM detaches only when the loot event releases it or the robbery ends/cancels.


## V16 ATM tow lock
After the ATM is ripped out, its position is hard-locked behind the towing vehicle every frame. GTA rope/attachment physics can no longer release it because of speed, turns, jumps or collisions. The visual rope remains, and the hard lock is removed only when the ATM loot event succeeds or the robbery ends/cancels.

## v2.4.0 ATM Duo / Tow Hook
- ATM robbery requires exactly 2 crew members (minimum 2, maximum 2).
- Rope method now gives the player a visible towing hook in-hand after attaching the rope to the ATM.
- Walk to the rear of the vehicle and press E to connect the hook; the hand prop is removed at that moment.
- ATM remains ground-physics towed with the visual rope during the escape.
- Rope is released only after both ATM crew members have collected their share, or when the contract ends/cancels.

## V2.5 Store Heist Update
- Store robbery requires exactly 3 crew members.
- Clerk must be threatened with a weapon before registers/shelves/safe become available.
- Registers can be robbed after the clerk surrenders.
- Rear safe uses a dedicated 3-digit keypad UI with a per-store server-generated code and hint.
- Safe, register and shelf rewards remain server validated.

## V2.6.0 ATM contract changes
- ATM contract requires exactly 2 crew members.
- One ATM only per contract. After loot, return to the hub NPC and finish the contract to receive XP and start cooldown.
- Explosive method: plant charge, 5-second escape countdown, explosion, then target the ATM to collect the reward.
- Rope method: tow the ATM away; once the vehicle is stopped for ~1.5 seconds at the required distance, the ATM is stabilized on the ground for looting. Taking money detaches the rope/vehicle link.


## V2.7.0
- ATM rope requires two distinct vehicle pulls; vehicle must slow/stop between pulls.
- Added camera shake, dust/spark effects and staged rip-off.
- Professional local contract artwork for all robbery cards.
- Fixed criminal avatar assets in fxmanifest and refreshed 12 selectable avatars.
- ATM crew requirement restored to exactly 2.
