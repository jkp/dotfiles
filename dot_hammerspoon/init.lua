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

-- Watch for changes (restart watcher on wake since FSEvents can break)
local layerWatcher = nil

local function startLayerWatcher()
    if layerWatcher then layerWatcher:stop() end
    layerWatcher = hs.pathwatcher.new(layerFile, updateLayerIndicator)
    layerWatcher:start()
end

hs.caffeinate.watcher.new(function(event)
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
end):start()

-- Initial setup
startLayerWatcher()
updateLayerIndicator()

-- Audio control mode: "spotify" or "hqp"
local audioMode = "spotify"

local function showAudioMode()
    local icon = audioMode == "spotify" and "🎵" or "🎧"
    local name = audioMode == "spotify" and "Spotify" or "HQP"
    hs.alert.show(icon .. " " .. name, 0.8)
end

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

-- Unified transport controls (route based on audioMode)
local transportIcons = {
    play = "⏯",
    next = "⏭",
    prev = "⏮",
}

local function spotifyTransport(cmd)
    local applescriptCmd = {
        play = 'tell application "Spotify" to playpause',
        next = 'tell application "Spotify" to next track',
        prev = 'tell application "Spotify" to previous track',
    }
    if applescriptCmd[cmd] then
        hs.osascript.applescript(applescriptCmd[cmd])
        hs.alert.show("🎵 " .. transportIcons[cmd], 0.5)
    end
end

local function hqpTransport(cmd)
    local _, status = hs.execute("/Users/jkp/.local/bin/jplay-ctl " .. cmd, true)
    if status then
        hs.alert.show("🎧 " .. transportIcons[cmd], 0.5)
    else
        hs.alert.show("JPlay not available", 1)
    end
end

-- Cmd+F8: Play/Pause
hs.hotkey.bind({"cmd"}, "f8", function()
    if audioMode == "spotify" then
        spotifyTransport("play")
    else
        hqpTransport("play")
    end
end)

-- Cmd+F9: Next track
hs.hotkey.bind({"cmd"}, "f9", function()
    if audioMode == "spotify" then
        spotifyTransport("next")
    else
        hqpTransport("next")
    end
end)

-- Cmd+F7: Previous track
hs.hotkey.bind({"cmd"}, "f7", function()
    if audioMode == "spotify" then
        spotifyTransport("prev")
    else
        hqpTransport("prev")
    end
end)

-- Cmd+F10: Toggle audio mode
hs.hotkey.bind({"cmd"}, "f10", function()
    audioMode = audioMode == "spotify" and "hqp" or "spotify"
    showAudioMode()
end)

-- Volume controls
local function spotifyVolumeUp()
    local script = [[
        tell application "Spotify"
            set v to sound volume
            set newVol to (((v + 5) / 5) as integer) * 5
            if newVol > 100 then set newVol to 100
            set sound volume to newVol
            return newVol
        end tell
    ]]
    local ok, result = hs.osascript.applescript(script)
    if ok then
        hs.alert.show("🎵 🔊 " .. result .. "%", 0.5)
    end
end

local function spotifyVolumeDown()
    local script = [[
        tell application "Spotify"
            set v to sound volume
            set newVol to (((v - 5) / 5) as integer) * 5
            if newVol < 0 then set newVol to 0
            set sound volume to newVol
            return newVol
        end tell
    ]]
    local ok, result = hs.osascript.applescript(script)
    if ok then
        hs.alert.show("🎵 🔉 " .. result .. "%", 0.5)
    end
end

local function hqpVolumeUp()
    local output, status = hs.execute("curl -s -X POST http://orchestra.home:9100/volume/up", true)
    if status then
        hs.alert.show("🎧 🔊", 0.5)
    else
        hs.alert.show("HQP not available", 1)
    end
end

local function hqpVolumeDown()
    local output, status = hs.execute("curl -s -X POST http://orchestra.home:9100/volume/down", true)
    if status then
        hs.alert.show("🎧 🔉", 0.5)
    else
        hs.alert.show("HQP not available", 1)
    end
end

-- Cmd+F11: Volume down
hs.hotkey.bind({"cmd"}, "f11", function()
    if audioMode == "spotify" then
        spotifyVolumeDown()
    else
        hqpVolumeDown()
    end
end)

-- Cmd+F12: Volume up
hs.hotkey.bind({"cmd"}, "f12", function()
    if audioMode == "spotify" then
        spotifyVolumeUp()
    else
        hqpVolumeUp()
    end
end)

-- Cmd+F6: Device/profile chooser
hs.hotkey.bind({"cmd"}, "f6", function()
    if audioMode == "spotify" then
        -- Spotify device chooser
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
    else
        -- HQP profile chooser
        local output, status = hs.execute("curl -s http://orchestra.home:9100/profiles", true)
        if not status then
            hs.alert.show("HQP not available", 1)
            return
        end

        local data = hs.json.decode(output)
        if not data or not data.profiles or #data.profiles == 0 then
            hs.alert.show("No profiles found", 1)
            return
        end

        local choices = {}
        for _, profile in ipairs(data.profiles) do
            local icon = profile.current and "▶ " or "  "
            table.insert(choices, {
                text = icon .. profile.name,
                profile_name = profile.name
            })
        end

        local chooser = hs.chooser.new(function(choice)
            if choice then
                local encoded = hs.http.encodeForQuery(choice.profile_name)
                hs.execute("curl -s -X POST 'http://orchestra.home:9100/profiles/" .. encoded .. "?wait=false'", true)
                hs.alert.show("🎧 " .. choice.profile_name, 1)
            end
        end)
        chooser:choices(choices)
        chooser:show()
    end
end)