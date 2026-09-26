---
name: fivem-escrow-release
description: Structuring, versioning and shipping paid FiveM resources through Cfx.re Asset Escrow (Keymaster / portal.cfx.re) and Tebex — which files get encrypted, escrow_ignore, open "editable/bridge" files, config and locale design for customers, README/changelog/version sync, install SQL and item snippets, and building the upload ZIP. Use this whenever adding a config option, user-facing text, integration hook, new file, version bump, release, changelog, README update or packaging step in a FiveM resource that is sold or escrowed (FIVE DEV products), or when the user mentions escrow, Keymaster, Tebex, "customer", "release", "upload" or "encrypted".
---

# Asset Escrow and release

This resource is a paid product (FIVE DEV, proprietary license). Customers receive an encrypted build tied to their Cfx.re account. Everything you design has to work for a customer who **cannot read or edit** the protected Lua.

## What escrow does

- Encrypts `.lua` script files (and stream models `.yft/.ydd/.ydr`) at upload on portal.cfx.re. Encryption happens on Cfx's side — never locally.
- **Never encrypted**: `fxmanifest.lua`, NUI files (`html/`), SQL, docs, images, and anything listed in `escrow_ignore`.
- Customers can't patch escrowed files, so a hardcoded string, coordinate or integration inside `client.lua`/`server.lua` is something they can never change — and a support ticket for you.

## Design rules for escrowed products

1. **Everything tunable goes in `config.lua`** (escrow_ignore): times, rewards, items, coords, job names, police counts, keybinds, feature toggles, resource names of integrations.
2. **Every user-facing string goes in a locale file** — this repo uses ox_lib `locales/*.json` (escrow_ignore), language chosen with `setr ox:locale "he"`. Code calls `locale('store.clerk_surrendered')`; the NUI receives the same dictionary. Customers translate/rephrase without you.
3. **Integrations live in open bridge files** (`bridge/client.lua`, `bridge/server.lua` or `editable/*.lua`, escrow_ignore): notify, dispatch, inventory add/remove/has, clothing, target, progress bar, minigames, logging, `OnExploit(src, reason)`. Escrowed gameplay only calls `Bridge.X`. This is the industry-standard answer to "does it support my dispatch/inventory?".
4. **Don't put secrets in open or client files**: no webhook URLs, license keys, or server-only logic in `config.lua` (it is also sent to clients as a shared script). Use a separate `server_config.lua` in `server_scripts` (escrow_ignore if the customer must set it) for webhooks.
5. **Security can't rely on obscurity.** Escrowed client code can still be traced at runtime and NUI is plain text; all authority stays on the server (see `fivem-server-security`).
6. Don't use `load()`/`loadstring` on config strings as a customization mechanism — it's fragile and escrow-hostile. Use functions in open bridge files instead.
7. Keep the resource folder name stable (`fd-robberies`); customers' `server.cfg` and other scripts' exports reference it. If you depend on it, read it with `GetCurrentResourceName()` rather than hardcoding.

fxmanifest pattern (this repo):
```lua
escrow_ignore {
    'config/*.lua',
    'bridge/*.lua',
    'bridge/**/*.lua',
    'locales/*.json',
    'sql/*.sql',
    'ITEMS_TO_ADD.lua',
    'README.md', 'CHANGELOG.md', 'LICENSE.txt',
}
```
Never add `modules/**` or `shared/**` to escrow_ignore. `config/server.lua` stays out of `files` so players never download it. The full build/upload checklist is in the repo's `KEYMASTER-UPLOAD.txt` (build `web/` first; ship `web/build`, not `web/src`).

## Versioning and docs

- Bump `version` in `fxmanifest.lua` on every release (semver: patch = fix, minor = feature, major = breaking config/DB change). The startup banner reads it via `GetResourceMetadata`.
- The version lives only in `fxmanifest.lua`; README points to it. Add a `## X.Y.Z` section to `CHANGELOG.md` describing player-visible changes and **any config keys added/renamed** (customers merging configs need this).
- When adding config keys, give them safe defaults in code (`Config.X or default`) so customers who keep their old `config.lua` don't crash.
- DB changes: additive migrations only, idempotent, and documented in `install.sql` + changelog.
- New items: add to `ITEMS_TO_ADD.lua` in both qb-core and ox_inventory formats, with an image name.

## Building the upload ZIP

1. Bump version, update README/changelog.
2. Zip the resource folder so the archive root is `fd-robberies/` containing `fxmanifest.lua`.
3. Exclude development files: `.git/`, `.claude/`, `*-workspace/`, `.vscode/`, `node_modules/`, NUI source if you build from a framework (ship only the built `html/`), `KEYMASTER-UPLOAD.txt` if it's internal.
   ```powershell
   # example (PowerShell) — stage a clean copy then compress
   $out = "$env:TEMP\fd-robberies"; Remove-Item $out -Recurse -Force -ErrorAction Ignore
   robocopy . $out /E /XD .git .claude node_modules .vscode /XF KEYMASTER-UPLOAD.txt | Out-Null
   Compress-Archive -Path $out -DestinationPath ".\fd-robberies-v$version.zip" -Force
   ```
4. Keep the unencrypted source private (it's in the private GitHub repo) — never upload the only copy.
5. Upload on portal.cfx.re → Created Assets, wait for processing, download and test the encrypted build on an entitled test server (fresh DB, missing optional deps, both languages), then link it to the Tebex package.

If a streamed `.ymap`/`.ybn` breaks after escrow, adding it to `escrow_ignore` is the known workaround.
