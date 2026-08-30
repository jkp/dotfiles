---@diagnostic disable

local captured

local function init_mocks(stored)
    captured = { binds = {}, settings_set = {}, shutdown = nil }
    _G.hs = {
        settings = {
            get = function(_) return stored end,
            set = function(k, v) captured.settings_set[k] = v end,
        },
        hotkey = {
            bind = function(mods, key, ...)
                local args = table.pack(...)
                captured.binds[#captured.binds + 1] = { mods = mods, key = key, args = args }
                return { _handle = true }
            end,
        },
        timer = { doEvery = function() return { stop = function() end } end },
    }
    package.loaded["hotkeys"] = nil
    return require("hotkeys")
end

---fire the pressed function that the module handed to the real bind
local function press(n)
    local b = captured.binds[n]
    for _, a in ipairs(b.args) do
        if type(a) == "function" then return a() end
    end
end

describe("hotkeys", function()
    it("passes through the return value of hs.hotkey.bind", function()
        init_mocks(nil)
        local hk = hs.hotkey.bind({ "cmd" }, "a", function() end)
        assert.is_true(hk._handle)
    end)

    it("counts presses and calls the original handler", function()
        local M = init_mocks(nil)
        local called = 0
        hs.hotkey.bind({ "ctrl", "alt", "shift" }, "u", function() called = called + 1 end)
        press(1); press(1)
        assert.equals(2, called)
        local s = M.stats()["alt+ctrl+shift+u"]
        assert.equals(2, s.n)
        assert.is_true(s.last > 0)
    end)

    it("normalizes modifier order and case so a label is stable", function()
        init_mocks(nil)
        hs.hotkey.bind({ "Shift", "ctrl", "alt" }, "u", function() end)
        hs.hotkey.bind({ "alt", "shift", "ctrl" }, "u", function() end)
        local M = require("hotkeys")
        local labels = {}
        for id in pairs(M.stats()) do labels[#labels + 1] = id end
        assert.equals(1, #labels)
        assert.equals("alt+ctrl+shift+u", labels[1])
    end)

    it("accepts a string modifier as well as a table", function()
        local M = init_mocks(nil)
        hs.hotkey.bind("cmd", "a", function() end)
        assert.is_not_nil(M.stats()["cmd+a"])
    end)

    it("skips the optional message argument when wrapping", function()
        local M = init_mocks(nil)
        local called = false
        hs.hotkey.bind({ "cmd" }, "b", "a message", function() called = true end)
        assert.equals("a message", captured.binds[1].args[1])
        press(1)
        assert.is_true(called)
        assert.equals(1, M.stats()["cmd+b"].n)
    end)

    it("registers a binding at zero so never-pressed keys are visible", function()
        local M = init_mocks(nil)
        hs.hotkey.bind({ "cmd" }, "c", function() end)
        local s = M.stats()["cmd+c"]
        assert.equals(0, s.n)
        assert.equals(0, s.last)
    end)

    it("resumes counts loaded from settings across a reload", function()
        local M = init_mocks({ ["cmd+d"] = { n = 7, last = 1000 } })
        hs.hotkey.bind({ "cmd" }, "d", function() end)
        press(1)
        assert.equals(8, M.stats()["cmd+d"].n)
    end)

    it("flushes counts to settings", function()
        local M = init_mocks(nil)
        hs.hotkey.bind({ "cmd" }, "e", function() end)
        press(1)
        M.flush()
        assert.equals(1, captured.settings_set["hotkey_stats"]["cmd+e"].n)
    end)

    it("reports a stored binding that is no longer bound", function()
        local M = init_mocks({ ["cmd+gone"] = { n = 3, last = 1000 } })
        hs.hotkey.bind({ "cmd" }, "here", function() end)
        local report = M.report()
        assert.is_truthy(report:match("cmd%+gone[^\n]*unbound"))
        assert.is_falsy(report:match("cmd%+here[^\n]*unbound"))
    end)

    it("reports never-pressed bindings first", function()
        local M = init_mocks({ ["cmd+hot"] = { n = 50, last = 1000 } })
        hs.hotkey.bind({ "cmd" }, "hot", function() end)
        hs.hotkey.bind({ "cmd" }, "cold", function() end)
        local report = M.report()
        assert.is_true(report:find("cmd%+cold") < report:find("cmd%+hot"))
    end)
end)
