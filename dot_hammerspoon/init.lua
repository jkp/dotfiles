require("hs.ipc")

-- Auto-reload on .lua changes, debounced to avoid spurious reloads
-- from git operations, log writes, etc.
local reload_timer = nil
hs.pathwatcher.new(hs.configdir, function(files)
    for _, file in ipairs(files) do
        if file:match("%.lua$") then
            if reload_timer then reload_timer:stop() end
            reload_timer = hs.timer.doAfter(1, hs.reload)
            return
        end
    end
end):start()

-- Codex: tiling + virtual workspaces + scratch WM
require("wm")

-- Audio controls
local audio = require("audio")

local hyper = { "cmd", "ctrl", "alt", "shift" }
local meh = { "ctrl", "alt", "shift" }

-- Bind same handler to multiple modifier sets
local function bindMulti(modifierSets, key, handler)
  for _, mods in ipairs(modifierSets) do
    hs.hotkey.bind(mods, key, handler)
  end
end

local audioMods = { { "cmd" }, meh }

-- Unified audio controls (cmd or meh + F-keys)
bindMulti(audioMods, "f6", audio.deviceChooser)
bindMulti(audioMods, "f7", audio.prev)
bindMulti(audioMods, "f8", audio.play)
bindMulti(audioMods, "f9", audio.next)
bindMulti(audioMods, "f10", audio.toggleMode)
bindMulti(audioMods, "f11", audio.volumeDown)
bindMulti(audioMods, "f12", audio.volumeUp)

--[[
  HOTKEY PHILOSOPHY:
  - Hyper (Cmd+Ctrl+Alt+Shift) = general app/macro shortcuts
  - Fill number keys 1-10 first, reconsider if we run out
  - F-keys are reserved for audio controls (Cmd or Meh modifiers)
]]

local utils = require("utils")

-- Hyper + number keys
hs.hotkey.bind(hyper, "1", utils.newTerminal) -- new terminal
hs.hotkey.bind(hyper, "2", audio.like) -- like/unlike
hs.hotkey.bind(hyper, "3", audio.search) -- search
-- 4-0 available for future use
