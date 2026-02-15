local wezterm = require("wezterm")
local shared = require("shared")
local config = {}

shared.apply(config)

local home = wezterm.home_dir

config.unix_domains = {
  {
    name = "personal",
    socket_path = home .. "/.local/share/wezterm-personal/sock",
  },
}

config.daemon_options = {
  pid_file = home .. "/.local/share/wezterm-personal/pid",
  stdout = home .. "/.local/share/wezterm-personal/log",
  stderr = home .. "/.local/share/wezterm-personal/log",
}

return config
