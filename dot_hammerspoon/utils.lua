-- Utility functions module
local M = {}

function M.newTerminal()
    hs.execute("wezterm cli spawn --new-window", true)
    hs.alert.show("💻 New terminal", 0.5)
end

return M
