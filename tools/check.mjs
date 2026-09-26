#!/usr/bin/env node
/**
 * Resource consistency checks (no dependencies). Run: node tools/check.mjs
 *  1. every event/callback in shared/events.lua is handled on the right side, and every use is defined
 *  2. every literal locale key used in Lua or the UI exists in both locales, and both locales have the same keys
 *  3. every Lua file under shared/bridge/modules is listed in fxmanifest.lua (and every listed file exists)
 *  4. NUI message/callback names match between Lua and web/src/types/protocol.ts
 */
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(fileURLToPath(import.meta.url), '..', '..');
const errors = [];
const read = (path) => readFileSync(join(root, path), 'utf8');
const rel = (path) => relative(root, path).split(sep).join('/');

function walk(dir, ext, out = []) {
  const abs = join(root, dir);
  if (!existsSync(abs)) return out;
  for (const name of readdirSync(abs)) {
    const full = join(abs, name);
    if (statSync(full).isDirectory()) walk(rel(full), ext, out);
    else if (full.endsWith(ext)) out.push(rel(full));
  }
  return out;
}

const matchAll = (text, regex) => [...text.matchAll(regex)].map((m) => m[1]);
const luaFiles = [...walk('shared', '.lua'), ...walk('bridge', '.lua'), ...walk('modules', '.lua')];
const sideOf = (file) => (/(^|\/)client(\/|\.lua$)/.test(file) ? 'client' : /(^|\/)server(\/|\.lua$)/.test(file) ? 'server' : 'shared');
const lua = Object.fromEntries(luaFiles.map((f) => [f, read(f)]));

// ---------- 1. events ----------
const eventsSource = read('shared/events.lua');
const defined = {};
for (const group of ['Server', 'Client', 'Callback']) {
  const block = eventsSource.match(new RegExp(`${group} = \\{([\\s\\S]*?)\\n    \\}`));
  defined[group] = new Set(block ? matchAll(block[1], /(\w+) = (?:server|client)\(/g) : []);
  if (!block) errors.push(`events: FD.Events.${group} block not found`);
}

const handled = { Server: new Set(), Client: new Set(), Callback: new Set() };
for (const [file, text] of Object.entries(lua)) {
  for (const [, group, name] of text.matchAll(/FD\.Events\.(Server|Client|Callback)\.(\w+)/g)) {
    if (!defined[group]?.has(name)) errors.push(`events: ${file} uses undefined FD.Events.${group}.${name}`);
  }
  const side = sideOf(file);
  for (const name of matchAll(text, /RegisterNetEvent\(FD\.Events\.Server\.(\w+)/g)) {
    if (side !== 'server') errors.push(`events: ${file} registers server event ${name} on the ${side} side`);
    handled.Server.add(name);
  }
  for (const name of matchAll(text, /RegisterNetEvent\(FD\.Events\.Client\.(\w+)/g)) {
    if (side !== 'client') errors.push(`events: ${file} registers client event ${name} on the ${side} side`);
    handled.Client.add(name);
  }
  for (const name of matchAll(text, /lib\.callback\.register\(FD\.Events\.Callback\.(\w+)/g)) {
    if (side !== 'server') errors.push(`events: ${file} registers callback ${name} on the ${side} side`);
    handled.Callback.add(name);
  }
}
for (const group of ['Server', 'Client', 'Callback']) {
  for (const name of defined[group]) {
    if (!handled[group].has(name)) errors.push(`events: FD.Events.${group}.${name} has no handler`);
  }
}

// ---------- 2. locales ----------
function flatten(obj, prefix = '', out = {}) {
  for (const [key, value] of Object.entries(obj)) {
    const full = prefix ? `${prefix}.${key}` : key;
    if (Array.isArray(value)) value.forEach((v, i) => (out[`${full}.${i + 1}`] = v));
    else if (value && typeof value === 'object') flatten(value, full, out);
    else out[full] = value;
  }
  return out;
}
const locales = Object.fromEntries(['he', 'en'].map((lang) => [lang, flatten(JSON.parse(read(`locales/${lang}.json`)))]));
for (const [a, b] of [['he', 'en'], ['en', 'he']]) {
  for (const key of Object.keys(locales[a])) if (!(key in locales[b])) errors.push(`locales: "${key}" is in ${a}.json but missing in ${b}.json`);
}

// Hebrew server: every he.json value must contain Hebrew, except decorative English tags / technical tokens.
// keys.* = RegisterKeyMapping descriptions, shown in GTA's own settings menu (game font: no Hebrew glyphs)
const ENGLISH_ALLOWED = [/\.subtitle$/, /\.kicker$/, /\.brand$/, /^ui\.heists\.xp$/, /^keys\./];

// GTA's native text renderer (DrawText, help text, subtitles, blip names) has no Hebrew glyphs and shows boxes.
// Player-facing text must go through NUI (notify, ox_lib text UI, progress bar, target, the menu).
const NATIVE_TEXT = /\b(BeginTextCommandDisplayText|BeginTextCommandDisplayHelp|BeginTextCommandPrint|BeginTextCommandSetBlipName|SetTextEntry|DrawText|DisplayHelpTextThisFrame)\s*\(/;
for (const [file, text] of Object.entries(lua)) {
  text.split('\n').forEach((line, index) => {
    if (NATIVE_TEXT.test(line)) errors.push(`native text: ${file}:${index + 1} uses GTA native text (no Hebrew) — use lib.showTextUI / Bridge.Notify`);
  });
}
for (const [key, value] of Object.entries(locales.he)) {
  if (typeof value === 'string' && !/[֐-׿]/.test(value) && !ENGLISH_ALLOWED.some((re) => re.test(key))) {
    errors.push(`locales: he.json "${key}" has no Hebrew ("${value}") — translate it or allowlist it in tools/check.mjs`);
  }
}

// Roleplay immersion: player-facing text never talks about game mechanics like "NPC".
const IMMERSION_BREAKERS = /\bNPC\b|\bNPCs\b|\bped\b/i;
for (const lang of ['he', 'en']) {
  for (const [key, value] of Object.entries(locales[lang])) {
    if (typeof value === 'string' && IMMERSION_BREAKERS.test(value)) {
      errors.push(`locales: ${lang}.json "${key}" breaks roleplay immersion ("${value}") — say "the contact" / "איש הקשר"`);
    }
  }
}

const usedKeys = new Map();
for (const [file, text] of Object.entries(lua)) {
  for (const key of matchAll(text, /locale\('([\w.]+)'/g)) usedKeys.set(key, file);
}
const uiFiles = walk('web/src', '.tsx').concat(walk('web/src', '.ts'));
for (const file of uiFiles) {
  for (const key of matchAll(read(file), /\bt\('([\w.]+)'/g)) usedKeys.set(key, file);
}
for (const [key, file] of usedKeys) {
  if (!(key in locales.en)) errors.push(`locales: ${file} uses missing key "${key}"`);
}

// ---------- 3. manifest ----------
const manifest = read('fxmanifest.lua');
const listed = new Set(matchAll(manifest, /'([^'@*]+\.lua)'/g));
for (const file of luaFiles) {
  if (!listed.has(file)) errors.push(`manifest: ${file} is not listed in fxmanifest.lua`);
}
for (const file of listed) {
  if (!existsSync(join(root, file)) && !file.startsWith('config/') && file !== 'ITEMS_TO_ADD.lua') {
    errors.push(`manifest: fxmanifest.lua lists missing file ${file}`);
  }
}
for (const config of ['shared', 'client', 'server']) {
  if (!existsSync(join(root, `config/${config}.lua`))) errors.push(`manifest: config/${config}.lua is missing`);
}
if (/'config\/server\.lua'/.test(manifest.split('escrow_ignore')[0])) {
  errors.push('manifest: config/server.lua must not be in files (players would download it)');
}

// ---------- 4. NUI protocol ----------
const protocol = read('web/src/types/protocol.ts');
const interfaceKeys = (name) => {
  const block = protocol.match(new RegExp(`export interface ${name} \\{([\\s\\S]*?)\\n\\}`));
  return new Set(block ? matchAll(block[1], /^\s{2}(\w+):/gm) : []);
};
const uiMessages = interfaceKeys('NuiMessages');
const uiCallbacks = interfaceKeys('NuiCallbacks');
const luaMessages = new Set();
const luaCallbacks = new Set();
for (const text of Object.values(lua)) {
  matchAll(text, /FD\.Nui\.Send\('(\w+)'/g).forEach((a) => luaMessages.add(a));
  matchAll(text, /RegisterNUICallback\('(\w+)'/g).forEach((a) => luaCallbacks.add(a));
}
const compare = (label, luaSet, uiSet) => {
  for (const name of luaSet) if (!uiSet.has(name)) errors.push(`nui: Lua ${label} "${name}" is not declared in protocol.ts`);
  for (const name of uiSet) if (!luaSet.has(name)) errors.push(`nui: protocol.ts ${label} "${name}" is never used by Lua`);
};
compare('message', luaMessages, uiMessages);
compare('callback', luaCallbacks, uiCallbacks);

// ---------- report ----------
if (errors.length) {
  console.error(`✖ ${errors.length} problem(s):\n  - ${errors.join('\n  - ')}`);
  process.exit(1);
}
console.log(
  `✔ resource consistent: ${luaFiles.length} Lua files, ` +
    `${defined.Server.size + defined.Client.size + defined.Callback.size} events/callbacks, ` +
    `${Object.keys(locales.en).length} locale keys, ${uiMessages.size} NUI messages, ${uiCallbacks.size} NUI callbacks`,
);
