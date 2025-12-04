-- Keymapp window styling
hs.window.filter.new("Keymapp")
  :subscribe(hs.window.filter.windowCreated, function(win)
    win:setAlpha(0.7)
    win:setLevel(hs.drawing.windowLevels.floating)
  end)

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

-- Watch for changes (restart on wake to handle sleep/wake cycles)
local layerWatcher = nil

local function startLayerWatcher()
    if layerWatcher then layerWatcher:stop() end
    layerWatcher = hs.pathwatcher.new(layerFile, updateLayerIndicator)
    layerWatcher:start()
end

hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake then
        startLayerWatcher()
        updateLayerIndicator()
    end
end):start()

-- Initial setup
startLayerWatcher()
updateLayerIndicator()