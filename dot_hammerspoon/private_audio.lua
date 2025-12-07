-- Audio control module: Spotify and HQP (JPlay) integration
local M = {}

-- State
local mode = "spotify"

local transportIcons = {
    play = "⏯",
    next = "⏭",
    prev = "⏮",
}

-- Spotify transport
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

-- HQP transport
local function hqpTransport(cmd)
    local _, status = hs.execute("/Users/jkp/.local/bin/jplay-ctl " .. cmd, true)
    if status then
        hs.alert.show("🎧 " .. transportIcons[cmd], 0.5)
    else
        hs.alert.show("JPlay not available", 1)
    end
end

-- Spotify volume
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

-- HQP volume
local function hqpVolumeUp()
    local _, status = hs.execute("curl -s -X POST http://orchestra.home:9100/volume/up", true)
    if status then
        hs.alert.show("🎧 🔊", 0.5)
    else
        hs.alert.show("HQP not available", 1)
    end
end

local function hqpVolumeDown()
    local _, status = hs.execute("curl -s -X POST http://orchestra.home:9100/volume/down", true)
    if status then
        hs.alert.show("🎧 🔉", 0.5)
    else
        hs.alert.show("HQP not available", 1)
    end
end

-- Spotify device chooser
local function showSpotifyDevices()
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
end

-- HQP profile chooser
local function showHqpProfiles()
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

-- Spotify-specific actions
function M.spotifyToggleLike()
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
end

function M.spotifySearch()
    hs.application.launchOrFocus("Spotify")
    hs.timer.doAfter(0.1, function()
        hs.eventtap.keyStroke({"cmd"}, "k")
    end)
end

-- Unified handlers (route based on mode)
function M.play()
    if mode == "spotify" then spotifyTransport("play") else hqpTransport("play") end
end

function M.next()
    if mode == "spotify" then spotifyTransport("next") else hqpTransport("next") end
end

function M.prev()
    if mode == "spotify" then spotifyTransport("prev") else hqpTransport("prev") end
end

function M.volumeUp()
    if mode == "spotify" then spotifyVolumeUp() else hqpVolumeUp() end
end

function M.volumeDown()
    if mode == "spotify" then spotifyVolumeDown() else hqpVolumeDown() end
end

function M.deviceChooser()
    if mode == "spotify" then showSpotifyDevices() else showHqpProfiles() end
end

function M.toggleMode()
    mode = mode == "spotify" and "hqp" or "spotify"
    local icon = mode == "spotify" and "🎵" or "🎧"
    local name = mode == "spotify" and "Spotify" or "HQP"
    hs.alert.show(icon .. " " .. name, 0.8)
end

return M
