---@diagnostic disable

local executed, handler

local function init_mocks()
    executed, handler = {}, nil
    _G.hs = {
        execute = function(cmd) executed[#executed + 1] = cmd; return "", true end,
        caffeinate = {
            watcher = {
                sessionDidBecomeActive = 1, sessionDidResignActive = 2,
                systemWillPowerOff = 3, screensDidLock = 4, screensDidUnlock = 5,
                new = function(fn)
                    handler = fn
                    return { start = function(self) return self end }
                end,
            },
        },
    }
    package.loaded["kanata"] = nil
    return require("kanata")
end

local START = "/usr/bin/sudo -n /bin/launchctl kickstart system/com.kanata"
local STOP = "/usr/bin/sudo -n /bin/launchctl kill TERM system/com.kanata"

describe("kanata", function()
    it("starts kanata when Hammerspoon loads in this session", function()
        init_mocks().init()
        assert.same({ START }, executed)
    end)

    it("stops when the session resigns and starts when it's back", function()
        init_mocks().init()
        local w = hs.caffeinate.watcher
        handler(w.sessionDidResignActive)
        handler(w.sessionDidBecomeActive)
        assert.same({ START, STOP, START }, executed)
    end)

    it("stops on logout or shutdown", function()
        init_mocks().init()
        handler(hs.caffeinate.watcher.systemWillPowerOff)
        assert.same({ START, STOP }, executed)
    end)

    it("ignores locking the screen, since this user still owns the console", function()
        init_mocks().init()
        handler(hs.caffeinate.watcher.screensDidLock)
        handler(hs.caffeinate.watcher.screensDidUnlock)
        assert.same({ START }, executed)
    end)
end)
