---@diagnostic disable

-- Captured calls for assertions
local captured = {}

local function reset_captured()
    captured = {
        alerts = {},
        applescripts = {},
        executions = {},
        settings_set = {},
        notifications = {},
    }
end

-- Mock hs global before requiring audio
local function init_mocks(opts)
    opts = opts or {}
    reset_captured()

    _G.hs = {
        settings = {
            get = function(key)
                if key == "audioMode" then return opts.mode or "spotify" end
                return nil
            end,
            set = function(key, value)
                captured.settings_set[key] = value
            end,
        },
        execute = function(cmd, use_shell)
            table.insert(captured.executions, { cmd = cmd, use_shell = use_shell })
            if opts.execute_fn then return opts.execute_fn(cmd) end
            return "", true
        end,
        osascript = {
            applescript = function(script)
                table.insert(captured.applescripts, script)
                if opts.applescript_fn then return opts.applescript_fn(script) end
                return true, "50"
            end,
        },
        alert = {
            show = function(msg, duration)
                table.insert(captured.alerts, { msg = msg, duration = duration })
            end,
            closeAll = function() end,
        },
        json = {
            decode = function(s)
                if not s or s == "" then return nil end
                if opts.json_decode_fn then return opts.json_decode_fn(s) end
                return {}
            end,
        },
        chooser = {
            new = function(callback)
                return {
                    choices = function(self, c) self._choices = c end,
                    show = function(self) end,
                    _callback = callback,
                }
            end,
        },
        notify = {
            new = function(params)
                table.insert(captured.notifications, params)
                return { send = function() end }
            end,
        },
        http = {
            encodeForQuery = function(s) return s:gsub(" ", "+") end,
        },
        application = {
            launchOrFocus = function(name)
                table.insert(captured.alerts, { msg = "_launchOrFocus:" .. name })
            end,
        },
        eventtap = {
            keyStroke = function(mods, key)
                table.insert(captured.alerts, { msg = "_keyStroke:" .. key })
            end,
        },
        timer = {
            doAfter = function(delay, fn) fn() end,
        },
    }
end

-- Helper: reload audio module fresh (clears package cache)
local function load_audio(opts)
    init_mocks(opts)
    package.loaded["audio"] = nil
    -- audio.lua is one directory up from spec/
    package.path = "./?.lua;" .. package.path
    local audio = require("audio")
    return audio, captured
end

describe("audio module", function()
    describe("module structure", function()
        it("exports all expected public functions", function()
            local audio = load_audio()
            local expected = { "play", "next", "prev", "volumeUp", "volumeDown",
                               "deviceChooser", "like", "search", "toggleMode" }
            for _, name in ipairs(expected) do
                assert.is_function(audio[name], "missing function: " .. name)
            end
        end)

        it("does not export private functions", function()
            local audio = load_audio()
            -- These should be local, not on the module table
            assert.is_nil(audio.spotifyTransport)
            assert.is_nil(audio.hqpTransport)
            assert.is_nil(audio.logError)
            assert.is_nil(audio.execWithPath)
        end)
    end)

    describe("mode dispatch", function()
        it("defaults to spotify mode", function()
            local audio, cap = load_audio({ mode = nil })
            audio.play()
            -- Should trigger AppleScript (Spotify), not curl (HQP)
            assert.is_true(#cap.applescripts > 0 or #cap.executions == 0
                or not cap.executions[1].cmd:match("jplay"))
        end)

        it("routes play to Spotify in spotify mode", function()
            local audio, cap = load_audio({ mode = "spotify" })
            audio.play()
            assert.is_true(#cap.applescripts > 0)
            assert.truthy(cap.applescripts[1]:match("Spotify"))
            assert.truthy(cap.applescripts[1]:match("playpause"))
        end)

        it("routes play to HQP in hqp mode", function()
            local audio, cap = load_audio({ mode = "hqp" })
            audio.play()
            assert.is_true(#cap.executions > 0)
            assert.truthy(cap.executions[1].cmd:match("jplay%-ctl"))
            assert.truthy(cap.executions[1].cmd:match("play"))
        end)

        it("routes next to Spotify in spotify mode", function()
            local audio, cap = load_audio({ mode = "spotify" })
            audio.next()
            assert.truthy(cap.applescripts[1]:match("next track"))
        end)

        it("routes next to HQP in hqp mode", function()
            local audio, cap = load_audio({ mode = "hqp" })
            audio.next()
            assert.truthy(cap.executions[1].cmd:match("jplay%-ctl next"))
        end)

        it("routes prev to Spotify in spotify mode", function()
            local audio, cap = load_audio({ mode = "spotify" })
            audio.prev()
            assert.truthy(cap.applescripts[1]:match("previous track"))
        end)

        it("routes prev to HQP in hqp mode", function()
            local audio, cap = load_audio({ mode = "hqp" })
            audio.prev()
            assert.truthy(cap.executions[1].cmd:match("jplay%-ctl prev"))
        end)
    end)

    describe("toggleMode", function()
        it("switches from spotify to hqp", function()
            local audio, cap = load_audio({ mode = "spotify" })
            audio.toggleMode()
            assert.are.equal("hqp", cap.settings_set["audioMode"])
            assert.truthy(cap.alerts[1].msg:match("HQP"))
        end)

        it("switches from hqp to spotify", function()
            local audio, cap = load_audio({ mode = "hqp" })
            audio.toggleMode()
            assert.are.equal("spotify", cap.settings_set["audioMode"])
            assert.truthy(cap.alerts[1].msg:match("Spotify"))
        end)
    end)

    describe("spotify volume", function()
        it("volumeUp sends AppleScript with +5 delta", function()
            local audio, cap = load_audio({ mode = "spotify" })
            audio.volumeUp()
            assert.is_true(#cap.applescripts > 0)
            assert.truthy(cap.applescripts[1]:match("v %+ 5"))
            assert.truthy(cap.applescripts[1]:match("100"))
        end)

        it("volumeDown sends AppleScript with -5 delta", function()
            local audio, cap = load_audio({ mode = "spotify" })
            audio.volumeDown()
            assert.is_true(#cap.applescripts > 0)
            assert.truthy(cap.applescripts[1]:match("v %- 5"))
            assert.truthy(cap.applescripts[1]:match("< 0"))
        end)

        it("volumeUp shows alert with volume percentage", function()
            local audio, cap = load_audio({
                mode = "spotify",
                applescript_fn = function() return true, "55" end,
            })
            audio.volumeUp()
            assert.truthy(cap.alerts[1].msg:match("55%%"))
            assert.truthy(cap.alerts[1].msg:match("🔊"))
        end)

        it("volumeDown shows alert with volume percentage", function()
            local audio, cap = load_audio({
                mode = "spotify",
                applescript_fn = function() return true, "45" end,
            })
            audio.volumeDown()
            assert.truthy(cap.alerts[1].msg:match("45%%"))
            assert.truthy(cap.alerts[1].msg:match("🔉"))
        end)
    end)

    describe("hqp volume", function()
        it("volumeUp curls the HQP volume/up endpoint", function()
            local audio, cap = load_audio({ mode = "hqp" })
            audio.volumeUp()
            assert.is_true(#cap.executions > 0)
            assert.truthy(cap.executions[1].cmd:match("orchestra%.home:9100/volume/up"))
        end)

        it("volumeDown curls the HQP volume/down endpoint", function()
            local audio, cap = load_audio({ mode = "hqp" })
            audio.volumeDown()
            assert.is_true(#cap.executions > 0)
            assert.truthy(cap.executions[1].cmd:match("orchestra%.home:9100/volume/down"))
        end)

        it("shows alert on HQP failure", function()
            local audio, cap = load_audio({
                mode = "hqp",
                execute_fn = function() return "", false end,
            })
            audio.volumeUp()
            assert.truthy(cap.alerts[1].msg:match("HQP not available"))
        end)
    end)

    describe("spotify transport alerts", function()
        it("shows play icon on play", function()
            local audio, cap = load_audio({ mode = "spotify" })
            audio.play()
            assert.truthy(cap.alerts[1].msg:match("⏯"))
        end)

        it("shows next icon on next", function()
            local audio, cap = load_audio({ mode = "spotify" })
            audio.next()
            assert.truthy(cap.alerts[1].msg:match("⏭"))
        end)

        it("shows prev icon on prev", function()
            local audio, cap = load_audio({ mode = "spotify" })
            audio.prev()
            assert.truthy(cap.alerts[1].msg:match("⏮"))
        end)
    end)

    describe("hqp transport alerts", function()
        it("shows play icon on successful play", function()
            local audio, cap = load_audio({ mode = "hqp" })
            audio.play()
            assert.truthy(cap.alerts[1].msg:match("⏯"))
        end)

        it("shows failure alert when jplay-ctl fails", function()
            local audio, cap = load_audio({
                mode = "hqp",
                execute_fn = function() return "", false end,
            })
            audio.play()
            assert.truthy(cap.alerts[1].msg:match("JPlay not available"))
        end)
    end)

    describe("HQP base URL", function()
        -- Characterization: all HQP endpoints use orchestra.home:9100
        it("volume up hits orchestra.home:9100", function()
            local audio, cap = load_audio({ mode = "hqp" })
            audio.volumeUp()
            assert.truthy(cap.executions[1].cmd:match("orchestra%.home:9100"))
        end)

        it("volume down hits orchestra.home:9100", function()
            local audio, cap = load_audio({ mode = "hqp" })
            audio.volumeDown()
            assert.truthy(cap.executions[1].cmd:match("orchestra%.home:9100"))
        end)

        it("device chooser hits orchestra.home:9100/profiles", function()
            local audio, cap = load_audio({
                mode = "hqp",
                execute_fn = function(cmd)
                    if cmd:match("profiles") then
                        return '{"profiles":[]}', true
                    end
                    return "", true
                end,
                json_decode_fn = function(s)
                    if s:match("profiles") then
                        return { profiles = {} }
                    end
                    return {}
                end,
            })
            audio.deviceChooser()
            local found = false
            for _, ex in ipairs(cap.executions) do
                if ex.cmd:match("orchestra%.home:9100/profiles") then found = true end
            end
            assert.is_true(found)
        end)
    end)

    describe("spotify search", function()
        it("launches Spotify and sends cmd+k", function()
            local audio, cap = load_audio({ mode = "spotify" })
            audio.search()
            -- timer.doAfter fires immediately in mock, so both should be captured
            local found_launch = false
            local found_keystroke = false
            for _, a in ipairs(cap.alerts) do
                if a.msg and a.msg:match("_launchOrFocus:Spotify") then found_launch = true end
                if a.msg and a.msg:match("_keyStroke:k") then found_keystroke = true end
            end
            assert.is_true(found_launch)
            assert.is_true(found_keystroke)
        end)
    end)

    describe("PATH handling", function()
        it("uses mise shims PATH for spotify-ctl commands", function()
            local audio, cap = load_audio({ mode = "spotify" })
            -- toggle-like uses execWithPath
            audio.like()
            -- The execution should include mise shims in PATH
            assert.is_true(#cap.executions > 0)
            assert.truthy(cap.executions[1].cmd:match("mise/shims"))
        end)

        it("uses mise shims PATH for jplay-ctl commands", function()
            local audio, cap = load_audio({ mode = "hqp" })
            audio.like()
            assert.is_true(#cap.executions > 0)
            assert.truthy(cap.executions[1].cmd:match("mise/shims"))
        end)
    end)
end)
