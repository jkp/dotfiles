-- kanata.mode = active-user (shared Macs): run the root kanata daemon only
-- while this session owns the console. setup-daemon.sh installs the sudoers
-- rule; its wrapper stops kanata anyway if this never gets to.
local M = {}

local function launchctl(args)
    local out, ok = hs.execute("/usr/bin/sudo -n /bin/launchctl " .. args)
    if not ok then print("[kanata] launchctl " .. args .. " failed: " .. (out or "")) end
end

function M.start() launchctl("kickstart system/com.kanata") end
function M.stop() launchctl("kill TERM system/com.kanata") end

function M.init()
    local w = hs.caffeinate.watcher
    M.watcher = w.new(function(event)
        if event == w.sessionDidBecomeActive then
            M.start()
        elseif event == w.sessionDidResignActive or event == w.systemWillPowerOff then
            M.stop()
        end
    end):start()
    M.start()
    return M
end

return M
