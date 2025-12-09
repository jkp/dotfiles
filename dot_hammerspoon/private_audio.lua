-- Audio control module: Spotify and HQP (JPlay) integration
local M = {}

-- State (persisted via hs.settings)
local mode = hs.settings.get("audioMode") or "spotify"

-- Debug logging for failed commands
local function logError(context, output, status)
    print(string.format("[audio] %s failed - status: %s, output: %s", context, tostring(status), tostring(output)))
end

-- PATH setup for commands that need mise-managed tools
local PATH = "$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
local function execWithPath(cmd)
    return hs.execute(string.format("PATH=%s %s", PATH, cmd), false)
end

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
    local _, status = execWithPath("jplay-ctl " .. cmd)
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
    local _, status = hs.execute("curl -s -X POST http://orchestra.home:9100/volume/up", false)
    if status then
        hs.alert.show("🎧 🔊", 0.5)
    else
        hs.alert.show("HQP not available", 1)
    end
end

local function hqpVolumeDown()
    local _, status = hs.execute("curl -s -X POST http://orchestra.home:9100/volume/down", false)
    if status then
        hs.alert.show("🎧 🔉", 0.5)
    else
        hs.alert.show("HQP not available", 1)
    end
end

-- Spotify device chooser
local function showSpotifyDevices()
    local output, status = execWithPath("spotify-ctl devices")
    if not status then
        logError("spotify-ctl devices", output, status)
        hs.alert.show("Spotify not available", 1)
        return
    end
    -- Check if output looks like JSON before attempting decode
    if not output or not output:match("^%s*[{%[]") then
        logError("spotify-ctl devices (invalid JSON)", output, status)
        hs.alert.show("Spotify error - check console", 1)
        return
    end
    local data = hs.json.decode(output)
    if not data or not data.devices or #data.devices == 0 then
        logError("spotify-ctl devices (no devices)", output, status)
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
            execWithPath("spotify-ctl connect '" .. choice.device_name .. "'")
        end
    end)
    chooser:choices(choices)
    chooser:show()
end

-- HQP profile chooser
local function showHqpProfiles()
    local output, status = hs.execute("curl -s http://orchestra.home:9100/profiles", false)
    if not status then
        logError("HQP profiles", output, status)
        local lastLine = output and output:match("[^\n]+$") or "Unknown error"
        hs.notify.new({
            title = "HQP Error",
            informativeText = lastLine,
            withdrawAfter = 10
        }):send()
        return
    end
    -- Check if output looks like JSON before attempting decode
    if not output or not output:match("^%s*[{%[]") then
        logError("HQP profiles (invalid JSON)", output, status)
        local lastLine = output and output:match("[^\n]+$") or "No response"
        hs.notify.new({
            title = "HQP Profiles Error",
            informativeText = lastLine,
            withdrawAfter = 10
        }):send()
        return
    end
    local data = hs.json.decode(output)
    if not data or not data.profiles or #data.profiles == 0 then
        logError("HQP profiles (no profiles)", output, status)
        hs.notify.new({
            title = "HQP Profiles Error",
            informativeText = "No profiles found",
            withdrawAfter = 10
        }):send()
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
            hs.execute("curl -s -X POST 'http://orchestra.home:9100/profiles/" .. encoded .. "?wait=false'", false)
            hs.alert.show("🎧 " .. choice.profile_name, 1)
        end
    end)
    chooser:choices(choices)
    chooser:show()
end

-- Spotify-specific actions
local function spotifyToggleLike()
    local output, status = execWithPath("spotify-ctl toggle-like")
    if not status then
        logError("spotify-ctl toggle-like", output, status)
        hs.alert.show("Spotify not available", 1)
        return
    end
    -- Check if output looks like JSON before attempting decode
    if not output or not output:match("^%s*[{%[]") then
        logError("spotify-ctl toggle-like (invalid JSON)", output, status)
        hs.alert.show("Spotify error - check console", 1)
        return
    end
    local data = hs.json.decode(output)
    if not data then
        logError("spotify-ctl toggle-like (decode failed)", output, status)
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

local function spotifySearch()
    hs.application.launchOrFocus("Spotify")
    hs.timer.doAfter(0.1, function()
        hs.eventtap.keyStroke({"cmd"}, "k")
    end)
end

-- HQP like
local function hqpToggleLike()
    local _, status = execWithPath("jplay-ctl toggle-like")
    if status then
        hs.alert.show("🎧 ❤️", 0.5)
    else
        hs.alert.show("JPlay not available", 1)
    end
end

-- HQP search
local function hqpSearch()
    local _, status = execWithPath("jplay-ctl search")
    if not status then
        hs.alert.show("JPlay not available", 1)
    end
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

function M.like()
    if mode == "spotify" then spotifyToggleLike() else hqpToggleLike() end
end

function M.search()
    if mode == "spotify" then spotifySearch() else hqpSearch() end
end

function M.toggleMode()
    mode = mode == "spotify" and "hqp" or "spotify"
    hs.settings.set("audioMode", mode)
    local icon = mode == "spotify" and "🎵" or "🎧"
    local name = mode == "spotify" and "Spotify" or "HQP"
    hs.alert.show(icon .. " " .. name, 0.8)
end

return M
