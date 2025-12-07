hs.pathwatcher.new(hs.configdir, hs.reload):start()

-- Kanata layer indicator
local kanataMenu = hs.menubar.new()
local layerFile = "/tmp/kanata-layer"

-- Style for non-default layers (white background, dark text like Aerospace)
local function styledText(text, isDefault)
  -- Add spaces for consistent width
  local padded = " " .. text .. " "
  if isDefault then
    return hs.styledtext.new(padded, {
      font = { name = "SF Mono", size = 12 },
    })
  else
    return hs.styledtext.new(padded, {
      font = { name = "SF Mono", size = 12 },
      color = { white = 0.1 },
      backgroundColor = { white = 1.0, alpha = 0.9 },
    })
  end
end

local function updateLayerIndicator()
  local f = io.open(layerFile, "r")
  if f then
    local layer = f:read("*l") or "?"
    f:close()
    local isDefault = (layer == "CDH")
    kanataMenu:setTitle(styledText(layer, isDefault))
  end
end

-- Watch for changes (restart watcher on wake since FSEvents can break)
local layerWatcher = nil

local function startLayerWatcher()
  if layerWatcher then
    layerWatcher:stop()
  end
  layerWatcher = hs.pathwatcher.new(layerFile, updateLayerIndicator)
  layerWatcher:start()
end

hs.caffeinate.watcher
  .new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake then
      -- Stagger restarts to let FSEvents recover
      hs.timer.doAfter(0.5, function()
        startLayerWatcher()
        updateLayerIndicator()
      end)
      hs.timer.doAfter(2, function()
        startLayerWatcher()
        updateLayerIndicator()
      end)
      hs.timer.doAfter(5, function()
        startLayerWatcher()
        updateLayerIndicator()
      end)
    end
  end)
  :start()

-- Initial setup
startLayerWatcher()
updateLayerIndicator()

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
