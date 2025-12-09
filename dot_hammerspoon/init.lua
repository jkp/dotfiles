hs.pathwatcher.new(hs.configdir, hs.reload):start()

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
  - Hyper (Cmd+Ctrl+Alt+Shift) = general app/macro layer
  - Fill number keys 1-10 first, reconsider if we run out
  - F-keys are reserved for audio controls (Cmd or Meh modifiers)
]]

local utils = require("utils")

-- Hyper + number keys
hs.hotkey.bind(hyper, "1", audio.spotifyToggleLike) -- like/unlike
hs.hotkey.bind(hyper, "2", audio.spotifySearch) -- Spotify search
hs.hotkey.bind(hyper, "3", utils.newTerminal) -- new terminal
-- 4-0 available for future use
