-- Codex: tiling + virtual workspaces + scratch floating WM
local Codex = hs.loadSpoon("Codex")
Codex.window_gap = 10
Codex.window_ratios = { 1/3, 1/2, 2/3, 1.0 }
Codex:start()

Codex.workspaces.setup({"personal", "work", "global", "scratch"}, {
    Safari   = "personal",
    Claude   = "personal",
    Messages = "personal",

    ["Google Chrome"] = "work",
    ChatGPT  = "work",
    WhatsApp = "work",
    Helium   = "work",

    Spotify  = "global",
    JPLAY    = "global",
    Obsidian = "global",
})
Codex.scratch.setup("scratch")

---------------------------------------------------------------------------
-- Jump-to-app: workspace-aware app focusing
---------------------------------------------------------------------------

local jump_targets = {
    browser  = { personal = "Safari",        work = "Helium" },
    terminal = { personal = "WezTerm",       work = "WezTerm" },
    llm      = { personal = "Claude",        work = "ChatGPT" },
    comms    = { personal = "Messages",      work = "WhatsApp" },
}

local function jumpTo(category)
    local current_ws = Codex.workspaces.currentSpace()
    local targets = jump_targets[category]
    if not targets then return end
    local appName = targets[current_ws]
    if not appName then return end

    -- First: try to focus an existing window of this app on the current workspace
    local ws_ids = Codex.workspaces.windowIds()
    for id in pairs(ws_ids) do
        local win = hs.window.get(id)
        if win then
            local app = win:application()
            if app and app:title() == appName then
                win:focus()
                return
            end
        end
    end

    -- No window on this workspace: launch or focus the app
    hs.application.launchOrFocus(appName)
end

---------------------------------------------------------------------------
-- Custom actions
---------------------------------------------------------------------------

-- Cycle focused window's height proportion within a stack
local function cycle_stack_height()
    local win = hs.window.focusedWindow()
    if not win then return end
    local index = Codex.state.windowIndex(win)
    if not index then return end
    local space = hs.spaces.windowSpaces(win)[1]
    if not space then return end
    local column = Codex.state.windowList(space, index.col)
    if not column or #column < 2 then return end
    local canvas = Codex.windows.getCanvas(win:screen())
    local frame = win:frame()
    local current_ratio = frame.h / canvas.h
    local new_ratio = Codex.window_ratios[1]
    for _, r in ipairs(Codex.window_ratios) do
        if r > current_ratio + 0.02 then
            new_ratio = r
            break
        end
    end
    frame.h = math.floor(new_ratio * canvas.h)
    Codex.windows.moveWindow(win, frame)
    Codex:tileSpace(space)
end

-- Reflow current workspace: retile + raise all windows
local function reflow_workspace()
    local screen = hs.screen.mainScreen()
    if not screen then return end
    local space = hs.spaces.activeSpaces()[screen:getUUID()]
    if not space then return end
    for id in pairs(Codex.workspaces.windowIds()) do
        local win = hs.window.get(id)
        if win then win:raise() end
    end
    Codex.windows.refreshWindows()
    Codex:tileSpace(space)
    local focused = hs.window.focusedWindow()
    if focused then focused:focus() end
end

---------------------------------------------------------------------------
-- Keybindings
---------------------------------------------------------------------------

local meh = { "ctrl", "alt", "shift" }
local hyper = { "ctrl", "alt", "shift", "cmd" }
local actions = Codex.actions.actions()
local scratch = Codex.scratch

-- Navigate (Meh + home row) — dispatched
hs.hotkey.bind(meh, "m", Codex:dispatch(function() scratch.focus("left") end, actions.focus_left))
hs.hotkey.bind(meh, "n", Codex:dispatch(function() scratch.focus("down") end, actions.focus_down))
hs.hotkey.bind(meh, "e", Codex:dispatch(function() scratch.focus("up") end, actions.focus_up))
hs.hotkey.bind(meh, "i", Codex:dispatch(function() scratch.focus("right") end, actions.focus_right))

-- Swap/Snap (Hyper + home row) — dispatched
hs.hotkey.bind(hyper, "m", Codex:dispatch(function() scratch.snap("left") end, actions.swap_left))
hs.hotkey.bind(hyper, "n", Codex:dispatch(function() scratch.snap("bottom") end, actions.swap_down))
hs.hotkey.bind(hyper, "e", Codex:dispatch(function() scratch.snap("top") end, actions.swap_up))
hs.hotkey.bind(hyper, "i", Codex:dispatch(function() scratch.snap("right") end, actions.swap_right))

-- Jump to app (Meh + top row)
hs.hotkey.bind(meh, "l", function() jumpTo("terminal") end)
hs.hotkey.bind(meh, "u", function() jumpTo("browser") end)
hs.hotkey.bind(meh, "y", function() jumpTo("llm") end)
hs.hotkey.bind(meh, ";", function() jumpTo("comms") end)

-- Slurp/barf + resize (Hyper + top row) — dispatched where applicable
hs.hotkey.bind(hyper, "j", actions.slurp_in)
hs.hotkey.bind(hyper, "l", Codex:dispatch(function() scratch.cycle_width() end, actions.cycle_width))
hs.hotkey.bind(hyper, "u", Codex:dispatch(function() scratch.cycle_height() end, cycle_stack_height))
hs.hotkey.bind(hyper, "y", Codex:dispatch(function() scratch.cycle_center() end, actions.barf_out))

-- Workspace switch (Meh + bottom row)
hs.hotkey.bind(meh, "h", function() Codex.workspaces.switchTo("personal") end)
hs.hotkey.bind(meh, ",", function() Codex.workspaces.switchTo("work") end)
hs.hotkey.bind(meh, ".", function() Codex.workspaces.switchTo("global") end)
hs.hotkey.bind(meh, "o", function() Codex.workspaces.toggleScratch() end)

-- Move window to workspace (Hyper + bottom row)
hs.hotkey.bind(hyper, "h", function() Codex.workspaces.moveWindowTo("personal") end)
hs.hotkey.bind(hyper, ",", function() Codex.workspaces.moveWindowTo("work") end)
hs.hotkey.bind(hyper, ".", function() Codex.workspaces.moveWindowTo("global") end)
hs.hotkey.bind(hyper, "o", function() Codex.workspaces.moveWindowTo("scratch") end)

-- Layout — dispatched where applicable
hs.hotkey.bind(meh, "escape", actions.toggle_floating)
hs.hotkey.bind(meh, "c", Codex:dispatch(function() scratch.center() end, actions.center_window))
hs.hotkey.bind(meh, "f", Codex:dispatch(function() scratch.maximize() end, actions.full_width))
hs.hotkey.bind(meh, "r", reflow_workspace)
hs.hotkey.bind(meh, "d", function() Codex.workspaces.dump(); Codex.state.dump() end)

---------------------------------------------------------------------------
-- Workspace indicator
---------------------------------------------------------------------------

local menubar = hs.menubar.new()
local function updateMenubar(name)
    if not menubar then return end
    menubar:setTitle(name)
    local items = {}
    for _, wsName in ipairs({"personal", "work", "global", "scratch"}) do
        items[#items + 1] = {
            title = wsName,
            checked = (wsName == name),
            fn = function() Codex.workspaces.switchTo(wsName) end,
        }
    end
    menubar:setMenu(items)
end
updateMenubar("personal")

local indicator_style = {
    strokeWidth = 0,
    fillColor = { white = 0, alpha = 0.7 },
    textColor = { white = 1, alpha = 1 },
    textFont = ".AppleSystemUIFont",
    textSize = 28,
    radius = 10,
    padding = 20,
    fadeInDuration = 0,
    fadeOutDuration = 0.3,
    atScreenEdge = 0,
}
Codex.workspaces.onSwitch = function(name)
    hs.alert.closeAll(0)
    hs.alert.show(name, indicator_style, hs.screen.mainScreen(), 0.6)
    updateMenubar(name)
end
hs.timer.doAfter(1.5, function() Codex.workspaces.onSwitch(Codex.workspaces.currentSpace()) end)
