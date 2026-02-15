local wezterm = require("wezterm")
local shared = require("shared")
local config = {}

shared.apply(config)

local home = wezterm.home_dir

config.unix_domains = {
  {
    name = "work",
    socket_path = home .. "/.local/share/wezterm-work/sock",
  },
}

config.daemon_options = {
  pid_file = home .. "/.local/share/wezterm-work/pid",
  stdout = home .. "/.local/share/wezterm-work/log",
  stderr = home .. "/.local/share/wezterm-work/log",
}

return config
