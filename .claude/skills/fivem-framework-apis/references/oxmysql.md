# oxmysql

Server only. Requires `server_script '@oxmysql/lib/MySQL.lua'` before your server files. Docs: https://overextended.dev/oxmysql

## API
Every function has a callback form `MySQL.x(sql, params, cb)` and a blocking-in-coroutine form `MySQL.x.await(sql, params)`. Use `.await` inside event handlers/threads (they already run in coroutines) — and capture `local src = source` before it.

| Call | Returns |
|---|---|
| `MySQL.query.await(sql, p)` | array of rows |
| `MySQL.single.await(sql, p)` | first row or nil |
| `MySQL.scalar.await(sql, p)` | first column of first row or nil |
| `MySQL.insert.await(sql, p)` | insertId |
| `MySQL.update.await(sql, p)` | affectedRows |
| `MySQL.prepare.await(sql, p)` | prepared statement; row/value/rows depending on query; faster for hot queries |
| `MySQL.rawExecute.await(sql, p)` | raw result |
| `MySQL.transaction.await({ {query=, values=}, ... })` | boolean, all-or-nothing |
| `MySQL.ready(fn)` | runs fn once the connection is ready |

Placeholders: `?` positional (`{ a, b }`) or named `@name` / `:name` (`{ name = x }`). Never build SQL from strings containing player input.

## Patterns
```lua
-- upsert in one round trip (preferred over SELECT-then-INSERT)
MySQL.prepare.await([[INSERT INTO fd_robbery_progress (citizenid, xp, completed) VALUES (?, ?, 1)
    ON DUPLICATE KEY UPDATE xp = xp + VALUES(xp), completed = completed + 1]], { cid, xp })

-- batch XP for a crew atomically
local queries = {}
for _, cid in ipairs(cids) do queries[#queries+1] = { query = 'UPDATE fd_robbery_progress SET xp = xp + ? WHERE citizenid = ?', values = { xp, cid } } end
MySQL.transaction.await(queries)
```

## Schema / migrations
- Ship `install.sql` with `CREATE TABLE IF NOT EXISTS`, `utf8mb4` + `utf8mb4_unicode_ci` (Hebrew/emoji names), primary key on the framework identifier (`citizenid` / `identifier`).
- Auto-create on start inside `MySQL.ready` is convenient. For added columns, check `information_schema.COLUMNS` (or use `ADD COLUMN IF NOT EXISTS` on MariaDB) rather than `pcall`-ing an ALTER that errors every start and spams the console.
- Index columns you filter on. Don't store large JSON blobs you query by field.
- Cache hot per-player data in a Lua table keyed by identifier during the session; write on change or on drop, not on every UI open.
