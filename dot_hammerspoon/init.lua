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

-- Spotify controls (Super/Hyper key = Cmd+Ctrl+Alt+Shift)
local hyper = {"cmd", "ctrl", "alt", "shift"}

-- Super+1: Spotify device chooser
hs.hotkey.bind(hyper, "1", function()
    local output, status = hs.execute("/Users/jkp/.local/bin/spotify-ctl devices", true)
    if not status then
        hs.alert.show("Spotify not available", 1)
        return
    end

    local data = hs.json.decode(output)
    if not data or not data.devices or #data.devices == 0 then
        hs.alert.show("No devices found", 1)
        return
    end

    local choices = {}
    for _, device in ipairs(data.devices) do
        local icon = device.active and "▶ " or "  "
        table.insert(choices, {
            text = icon .. device.name,
            subText = device.type,
            device_name = device.name
        })
    end

    local chooser = hs.chooser.new(function(choice)
        if choice then
            hs.execute("/Users/jkp/.local/bin/spotify-ctl connect '" .. choice.device_name .. "'", true)
        end
    end)
    chooser:choices(choices)
    chooser:show()
end)

-- Super+2: Toggle like with visual feedback
hs.hotkey.bind(hyper, "2", function()
    local output, status = hs.execute("/Users/jkp/.local/bin/spotify-ctl toggle-like", true)
    if not status then
        hs.alert.show("Spotify not available", 1)
        return
    end

    local data = hs.json.decode(output)
    if not data then
        hs.alert.show("Failed to toggle like", 1)
        return
    end

    if data.error then
        hs.alert.show(data.error, 1)
    elseif data.liked then
        hs.alert.show("❤️ " .. data.liked, 0.8)
    elseif data.unliked then
        hs.alert.show("🤍 " .. data.unliked, 0.8)
    end
end)

-- Super+3: Spotify search (activate and send Cmd+K)
hs.hotkey.bind(hyper, "3", function()
    hs.application.launchOrFocus("Spotify")
    hs.timer.doAfter(0.1, function()
        hs.eventtap.keyStroke({"cmd"}, "k")
    end)
end)