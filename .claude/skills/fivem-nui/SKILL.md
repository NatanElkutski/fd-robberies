---
name: fivem-nui
description: Building and editing FiveM NUI (in-game HTML/CSS/JS UI rendered by CEF) — ui_page setup, SendNUIMessage / RegisterNUICallback / fetch protocol, NUI focus and ESC handling, XSS-safe rendering of player names and chat, CEF performance and asset size, resolution scaling, and Hebrew/RTL layouts. Use this whenever touching html/, index.html, app.js, style.css, a React/Vue/Svelte NUI build, a HUD, menu, tablet, keypad, minigame, progress UI or any "UI"/"menu"/"panel"/"design" in a FiveM or GTA RP resource, even for purely visual tweaks.
---

# FiveM NUI

NUI is a Chromium (CEF) page layered over the game. It's fullscreen, transparent, runs on every client, and can't talk to the server directly — only to its own resource's client Lua. Treat it as a view: it displays state the client sends it and reports user intent back; it never decides outcomes.

## 1. Wiring

fxmanifest:
```lua
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js', 'html/assets/**' }  -- every file the page loads
```

Lua → JS:
```lua
SendNUIMessage({ action = 'open', data = payload })          -- JSON-serialized; send on change, not per frame
```
```js
window.addEventListener('message', ({ data: msg }) => {
  switch (msg.action) { case 'open': open(msg.data); break; /* ... */ }
});
```

JS → Lua:
```js
const post = (name, body = {}) =>
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body),
  }).then(r => r.json()).catch(() => null);
```
```lua
RegisterNUICallback('buyItem', function(data, cb)
    TriggerServerEvent('fd-robberies:server:buyItem', data.item, data.paymentMethod)   -- server re-validates everything
    cb({ ok = true })                                                                -- ALWAYS respond, on every path
end)
```
- `GetParentResourceName()` is injected by FiveM; outside the game (browser preview) stub it: `window.GetParentResourceName ??= () => 'fd-robberies'`.
- Use a single `action` string protocol and keep a list of actions in one place on both sides.
- NUI data is as untrusted as any client data — the Lua callback forwards keys/ids, the server looks up prices and rewards (see `fivem-server-security`).

## 2. Focus and closing

- Open: `SetNuiFocus(true, true)` (keyboard, mouse). HUD-only overlays (timers, objective panels): no focus, and `pointer-events: none` on the container so they never eat clicks.
- `SetNuiFocusKeepInput(true)` only if the player must keep walking/driving while the UI is open — then disable conflicting controls in a Wait(0) loop while open.
- Close from JS on ESC (`keydown` → `post('close')`) and from Lua; always pair with `SetNuiFocus(false, false)`. Also release focus on death, on mission end, and in `onResourceStop` — a stuck invisible focused NUI is the most common NUI bug report ("I can't move / my mouse is stuck").
- Toggle visibility with a class (`display:none`), don't destroy/rebuild the whole DOM each open.

## 3. XSS: never trust strings in innerHTML

Player names (`GetPlayerName` = their FiveM/Steam name), character names, chat, criminal aliases and item labels from other resources are attacker-controlled. A name like `<img src=x onerror=fetch('https://fd-robberies/buyItem',...)>` inside `innerHTML` executes in *every viewer's* NUI and can call your callbacks on their behalf.

- Prefer `textContent` / `createElement` for any dynamic text.
- If you use template strings for layout, escape every interpolated value:
  ```js
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c]));
  el.innerHTML = `<b>${esc(m.name)}</b><p>${esc(m.text)}</p>`;
  ```
- Only numbers/ids you control can go unescaped — and even ids in `data-*` attributes should be escaped.
- Server-side sanitizing (trim, length cap, strip `<>`) is defense in depth, not a replacement for escaping at render.

## 4. Performance in CEF

The NUI frame is composited over the game every frame; heavy pages cost FPS for everyone even when "idle".
- **Assets**: every file in `files` is downloaded by every player on join. Keep images small — WebP/JPG, sized to display size (a 120px avatar should be ≈10–40 KB, not 2 MB PNG). Aim for the whole `html/` folder in the low single-digit MB.
- Bundle fonts and images locally; avoid runtime CDN/Google Fonts/remote images (slow first load, fails offline, network stalls in CEF).
- Avoid `backdrop-filter: blur`, large animated `box-shadow`/`filter`, and infinite CSS animations while hidden; animate `transform`/`opacity` only.
- When closed: `display:none` the app, stop `requestAnimationFrame`/intervals.
- Throttle updates from Lua (timer once per second, not per frame); batch lists with `DocumentFragment`.
- Use event delegation (`container.addEventListener('click', e => e.target.closest('[data-accept]'))`) instead of re-binding handlers after every render.

## 5. Layout and scaling

Players run 1280×720 up to 3440×1440 ultrawide. Design at 1920×1080 and scale:
- sizes with `clamp()` / `vh` / `vw` or a root `font-size` in `vh` so the menu scales with resolution;
- test 1280×720, 1920×1080, 2560×1440 and 21:9; nothing important in the outer 5% (safe zone), HUDs anchored with fixed offsets;
- keep the HUD out of the default minimap corner (bottom-left) and chat (top-left) unless configurable.

## 6. Hebrew / RTL

This project's UI is Hebrew (`<html lang="he" dir="rtl">`, `<meta charset="UTF-8">`).
- Use logical CSS (`margin-inline-start`, `padding-inline-end`, `inset-inline-start`, `text-align: start`) so layouts flip correctly; avoid mixing `direction: ltr` wrappers unless a specific grid needs it.
- Wrap mixed-direction fragments (IDs, prices, English names, codes) in `<bdi>` or `unicode-bidi: isolate` so `ID 12` or `$1,500` doesn't render reversed.
- Numbers: `toLocaleString('he-IL')` or `'en-US'` consistently; currency symbol placement consistent.
- Pick a font with Hebrew glyphs and bundle it (e.g. Heebo, Assistant, Rubik as local woff2); `Inter` has no Hebrew and falls back unpredictably.
- Keep all UI text in one strings object (or received from Lua locale) so customers can translate without touching logic — NUI files are never escrowed, but a single dictionary is still much easier to edit.
- Files UTF-8 without BOM.

## 7. Modern JavaScript

CEF in current FiveM is a recent Chromium, so use modern ES (ES2022+) freely — no transpiler needed for vanilla JS:
- `const`/`let` (never `var`), arrow functions, template literals, destructuring, `?.` and `??`, `async`/`await` around `fetch` instead of `.then` chains, `for...of`, `Object.entries`.
- `<script type="module" src="app.js">` and split into ES modules (`api.js` for `post`/message routing, `render/*.js`, `strings.js`) once the file grows; modules are deferred automatically.
- `addEventListener` + event delegation instead of assigning `el.onclick = ...` after every render.
- Build DOM with `document.createElement` / `<template>` + `textContent`, or escaped templates (§3) — not raw string concatenation into `innerHTML`.
- Readable formatting (one statement per line). The current `app.js` is hand-minified one-liners; keep small fixes minimal, write new code formatted, and offer a formatting/refactor pass separately.
- CSS: custom properties (already used), logical properties for RTL, `clamp()`, grid/flex, `gap`, `aspect-ratio`, `:is()`/`:where()`. FiveM's bundled CEF can lag current Chrome by a couple of years, so avoid bleeding-edge features (native CSS nesting, `@container` style queries, View Transitions) unless you've tested them in-game.

## 8. Frameworks

This repo uses React + TypeScript + Vite in `web/` (structure and rules in `CLAUDE.md`: features with `api.ts`, typed `types/protocol.ts`, `useNuiEvent`, store + `useNuiSync`, CSS modules). Vanilla JS is fine for tiny UIs elsewhere. For React/Vue/Svelte via Vite: `base: './'`, build to `html/` (or `web/dist`), list the build output in `files`, and keep dev-only mocks for `GetParentResourceName` and `message` events so the UI runs in a normal browser.
