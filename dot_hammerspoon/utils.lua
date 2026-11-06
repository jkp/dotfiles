-- Utility functions module
local M = {}

function M.newTerminal()
    local app = hs.application.get("Ghostty")
    if app then
        app:selectMenuItem({ "File", "New Window" })
    else
        hs.application.launchOrFocus("Ghostty")
    end
    hs.alert.show("💻 New terminal", 0.5)
end

return M
