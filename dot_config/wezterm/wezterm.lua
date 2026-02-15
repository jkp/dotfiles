local wezterm = require("wezterm")
local shared = require("shared")
local config = {}

shared.apply(config)

-- =============================================================================
-- DOMAINS
-- =============================================================================

local mux_server = "/Applications/WezTerm.app/Contents/MacOS/wezterm-mux-server"
local home = wezterm.home_dir
local config_dir = wezterm.config_dir

config.unix_domains = {
  {
    name = "personal",
    socket_path = home .. "/.local/share/wezterm-personal/sock",
    serve_command = {
      mux_server,
      "--daemonize",
      "--config-file",
      config_dir .. "/mux-personal.lua",
    },
  },
  {
    name = "work",
    socket_path = home .. "/.local/share/wezterm-work/sock",
    serve_command = {
      mux_server,
      "--daemonize",
      "--config-file",
      config_dir .. "/mux-work.lua",
    },
  },
}

return config
