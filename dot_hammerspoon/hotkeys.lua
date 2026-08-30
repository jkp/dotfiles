-- Hotkey usage stats.
--
-- Wraps hs.hotkey.bind so every binding is registered and every press is
-- counted. Bindings that are never pressed show up with a count of 0, and
-- counts for bindings that have since been removed are kept and flagged
-- [unbound] — so dead keys become visible instead of quietly rotting.
--
-- Require this BEFORE anything that binds hotkeys.
--   hs -c 'require("hotkeys").report()'

local M = {}

local KEY <const> = "hotkey_stats"
local FLUSH_INTERVAL <const> = 300

local stats = hs.settings.get(KEY) or {} -- label -> { n = presses, last = epoch }
local bound = {}                         -- labels registered this session

---stable label for a binding: modifiers lowercased and sorted, then the key
---@param mods string|string[]
---@param key string
---@return string
local function label(mods, key)
    if type(mods) == "string" then mods = { mods } end
    local m = {}
    for _, mod in ipairs(mods or {}) do m[#m + 1] = mod:lower() end
    table.sort(m)
    m[#m + 1] = tostring(key)
    return table.concat(m, "+")
end

local original_bind <const> = hs.hotkey.bind

-- hs.hotkey.bind(mods, key, [message,] pressedfn, [releasedfn, repeatfn]) —
-- wrap the first function argument, whichever position the message pushes it to
hs.hotkey.bind = function(mods, key, ...)
    local id = label(mods, key)
    bound[id] = true
    stats[id] = stats[id] or { n = 0, last = 0 }

    local args = table.pack(...)
    for i = 1, args.n do
        if type(args[i]) == "function" then
            local pressed <const> = args[i]
            args[i] = function(...)
                local s = stats[id]
                s.n, s.last = s.n + 1, os.time()
                return pressed(...)
            end
            break
        end
    end

    return original_bind(mods, key, table.unpack(args, 1, args.n))
end

---write counts to settings so they survive a reload
function M.flush()
    hs.settings.set(KEY, stats)
end

---raw counts, keyed by label
function M.stats()
    return stats
end

---usage report, least-used first
---@return string
function M.report()
    local rows = {}
    for id, s in pairs(stats) do
        rows[#rows + 1] = { id = id, n = s.n, last = s.last }
    end
    table.sort(rows, function(a, b)
        if a.n ~= b.n then return a.n < b.n end
        return a.id < b.id
    end)

    local now = os.time()
    local out = { string.format("=== Hotkey usage (%d bindings) ===", #rows) }
    for _, r in ipairs(rows) do
        out[#out + 1] = string.format("%6d  %-10s  %-26s%s",
            r.n,
            r.last > 0 and string.format("%dd ago", math.floor((now - r.last) / 86400)) or "never",
            r.id,
            bound[r.id] and "" or "  [unbound]")
    end
    return table.concat(out, "\n")
end

hs.timer.doEvery(FLUSH_INTERVAL, M.flush)

local previous_shutdown <const> = hs.shutdownCallback
hs.shutdownCallback = function()
    M.flush()
    if previous_shutdown then previous_shutdown() end
end

return M
