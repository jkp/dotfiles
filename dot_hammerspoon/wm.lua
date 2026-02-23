-- Codex: tiling + virtual workspaces + scratch floating WM
local show_hud = false -- set true to show overlay on workspace switch
local _t0 = hs.timer.absoluteTime()
local function _ms(since) return math.floor((hs.timer.absoluteTime() - since) / 1e6) end

local Codex = hs.loadSpoon("Codex")
print(string.format("[wm] loadSpoon: %dms", _ms(_t0)))

Codex.window_gap = 10
Codex.window_ratios = { 1/3, 1/2, 2/3, 4/5, 1.0 }

local _t1 = hs.timer.absoluteTime()
Codex:start()
print(string.format("[wm] Codex:start(): %dms", _ms(_t1)))

local _t2 = hs.timer.absoluteTime()
Codex.workspaces.setup({
    workspaces = {
        "personal",
        "work",
        "utility",
        { name = "scratch", layout = "unmanaged" },
    },
    toggleBack = false,

    apps = {
        Safari   = { workspace = "personal", jump = "browser", focusFollows = true },
        Claude   = { workspace = "personal", jump = "llm" },
        Messages = { workspace = "personal", jump = "comms" },

        Helium            = { workspace = "work", jump = "browser" },
        ChatGPT           = { workspace = "work", jump = "llm" },
        WhatsApp          = { workspace = "work", jump = "comms" },
        ["Google Chrome"] = { workspace = "work" },

        Spotify  = { workspace = "utility" },
        JPLAY    = { workspace = "utility" },
        Obsidian = { workspace = "utility" },

        WezTerm = {
            { workspace = "personal", jump = "terminal", title = "^%[personal%]",
              launch = { "/Applications/WezTerm.app/Contents/MacOS/wezterm", "connect", "personal" } },
            { workspace = "work", jump = "terminal", title = "^%[work%]",
              launch = { "/Applications/WezTerm.app/Contents/MacOS/wezterm", "connect", "work" } },
        },
    },
})
print(string.format("[wm] workspaces.setup(): %dms", _ms(_t2)))

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
print(string.format("[wm] hotkey setup start: %dms", _ms(_t0)))

---------------------------------------------------------------------------
-- RIGHT HAND — Meh = navigate, Hyper = mutate
---------------------------------------------------------------------------

-- Meh home row: scroll + app jumps
-- m=scroll left, n=browser, e=terminal, i=scroll right, o=comms, '=LLM
hs.hotkey.bind(meh, "m", Codex:dispatch(function() scratch.focus("left") end, actions.focus_left))
hs.hotkey.bind(meh, "n", function() Codex.workspaces.jumpToApp("browser") end)
hs.hotkey.bind(meh, "e", function() Codex.workspaces.jumpToApp("terminal") end)
hs.hotkey.bind(meh, "i", Codex:dispatch(function() scratch.focus("right") end, actions.focus_right))
hs.hotkey.bind(meh, "o", function() Codex.workspaces.jumpToApp("comms") end)
hs.hotkey.bind(meh, "'", function() Codex.workspaces.jumpToApp("llm") end)

-- Meh top row: workspace switch
-- l=personal, u=work, y=utility, ;=toggle scratch
hs.hotkey.bind(meh, "l", function() Codex.workspaces.switchTo("personal") end)
hs.hotkey.bind(meh, "u", function() Codex.workspaces.switchTo("work") end)
hs.hotkey.bind(meh, "y", function() Codex.workspaces.switchTo("utility") end)
hs.hotkey.bind(meh, ";", function() Codex.workspaces.switchTo("scratch") end)

-- Meh misc
hs.hotkey.bind(meh, "tab", function() Codex.workspaces.toggleJump() end)

-- Hyper home row: resize/structure — dispatched for tiled/scratch
-- m=swap left, n=slurp, e=barf, i=swap right, o=cycle width, '=cycle height
hs.hotkey.bind(hyper, "m", Codex:dispatch(function() scratch.snap("left") end, actions.swap_left))
hs.hotkey.bind(hyper, "n", actions.slurp_in)
hs.hotkey.bind(hyper, "e", Codex:dispatch(function() scratch.cycle_center() end, actions.barf_out))
hs.hotkey.bind(hyper, "i", Codex:dispatch(function() scratch.snap("right") end, actions.swap_right))
hs.hotkey.bind(hyper, "o", Codex:dispatch(function() scratch.cycle_width() end, actions.cycle_width))
hs.hotkey.bind(hyper, "'", Codex:dispatch(function() scratch.cycle_height() end, cycle_stack_height))

-- Hyper top row: move window to workspace
-- l=personal, u=work, y=utility, ;=scratch
hs.hotkey.bind(hyper, "l", function() Codex.workspaces.moveWindowTo("personal") end)
hs.hotkey.bind(hyper, "u", function() Codex.workspaces.moveWindowTo("work") end)
hs.hotkey.bind(hyper, "y", function() Codex.workspaces.moveWindowTo("utility") end)
hs.hotkey.bind(hyper, ";", function() Codex.workspaces.moveWindowTo("scratch") end)

-- Hyper bottom row: layout mutations
hs.hotkey.bind(hyper, "k", actions.toggle_floating)
hs.hotkey.bind(hyper, "h", Codex:dispatch(function() scratch.center() end, actions.center_window))

-- Hyper misc
hs.hotkey.bind(hyper, "j", reflow_workspace)

---------------------------------------------------------------------------
-- LEFT HAND
---------------------------------------------------------------------------

-- Debug (Meh + left bottom row)
hs.hotkey.bind(meh, "d", function() Codex.workspaces.dump(); Codex.state.dump() end)

---------------------------------------------------------------------------
-- Workspace indicator
---------------------------------------------------------------------------

local menubar = hs.menubar.new()
local function updateMenubar(name)
    if not menubar then return end
    menubar:setTitle(name)
    local items = {}
    for _, wsName in ipairs({"personal", "work", "utility", "scratch"}) do
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
    if show_hud then
        hs.alert.closeAll(0)
        hs.alert.show(name, indicator_style, hs.screen.mainScreen(), 0.6)
    end
    updateMenubar(name)
end
print(string.format("[wm] total sync: %dms", _ms(_t0)))
hs.timer.doAfter(1.5, function() Codex.workspaces.onSwitch(Codex.workspaces.currentSpace()) end)
