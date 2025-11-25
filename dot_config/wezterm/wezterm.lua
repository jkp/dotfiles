local wezterm = require("wezterm")
local config = {}

-- =============================================================================
-- APPEARANCE
-- =============================================================================

config.window_decorations = "RESIZE"
config.color_scheme = "Github Dark (Gogh)"
config.font_size = 13.0

config.inactive_pane_hsb = {
  saturation = 0.5,
  brightness = 0.4,
}

-- =============================================================================
-- SHELL & DOMAINS
-- =============================================================================

config.default_prog = { "/opt/homebrew/bin/fish", "-l" }

-- =============================================================================
-- BEHAVIOR
-- =============================================================================

config.scrollback_lines = 10000
config.quick_select_alphabet = "arstqwfpzxcvneioluymdhgjbk"

-- Make Option act as Alt/Meta for terminal apps (not for typing special chars)
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

-- =============================================================================
-- KEY BINDINGS
-- =============================================================================

config.disable_default_key_bindings = true

config.keys = {
  -- Tab Management
  { key = "t", mods = "CMD", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
  { key = "w", mods = "CMD", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
  { key = "LeftArrow", mods = "CMD|ALT", action = wezterm.action.ActivateTabRelative(-1) },
  { key = "RightArrow", mods = "CMD|ALT", action = wezterm.action.ActivateTabRelative(1) },

  -- Direct Tab Access (CMD+1 through CMD+0)
  { key = "1", mods = "CMD", action = wezterm.action.ActivateTab(0) },
  { key = "2", mods = "CMD", action = wezterm.action.ActivateTab(1) },
  { key = "3", mods = "CMD", action = wezterm.action.ActivateTab(2) },
  { key = "4", mods = "CMD", action = wezterm.action.ActivateTab(3) },
  { key = "5", mods = "CMD", action = wezterm.action.ActivateTab(4) },
  { key = "6", mods = "CMD", action = wezterm.action.ActivateTab(5) },
  { key = "7", mods = "CMD", action = wezterm.action.ActivateTab(6) },
  { key = "8", mods = "CMD", action = wezterm.action.ActivateTab(7) },
  { key = "9", mods = "CMD", action = wezterm.action.ActivateTab(8) },
  { key = "0", mods = "CMD", action = wezterm.action.ActivateTab(9) },

  -- Pane Splitting
  { key = "-", mods = "CTRL|ALT|SHIFT", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "|", mods = "CTRL|ALT|SHIFT", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },

  -- Pane Navigation (Arrow Keys)
  { key = "LeftArrow", mods = "CMD", action = wezterm.action.ActivatePaneDirection("Left") },
  { key = "DownArrow", mods = "CMD", action = wezterm.action.ActivatePaneDirection("Down") },
  { key = "UpArrow", mods = "CMD", action = wezterm.action.ActivatePaneDirection("Up") },
  { key = "RightArrow", mods = "CMD", action = wezterm.action.ActivatePaneDirection("Right") },

  -- Pane Navigation (Colemak Home Row)
  { key = "m", mods = "CMD", action = wezterm.action.ActivatePaneDirection("Left") },
  { key = "n", mods = "CMD", action = wezterm.action.ActivatePaneDirection("Down") },
  { key = "e", mods = "CMD", action = wezterm.action.ActivatePaneDirection("Up") },
  { key = "i", mods = "CMD", action = wezterm.action.ActivatePaneDirection("Right") },
  -- Pane Resizing (enters resize mode)
  {
    key = "r",
    mods = "CMD",
    action = wezterm.action.ActivateKeyTable({
      name = "resize_pane",
      one_shot = false,
    }),
  },

  -- Clipboard
  { key = "c", mods = "CMD", action = wezterm.action.CopyTo("Clipboard") },
  { key = "v", mods = "CMD", action = wezterm.action.PasteFrom("Clipboard") },

  -- Search & Quick Select
  { key = "f", mods = "CMD", action = wezterm.action.Search({ CaseSensitiveString = "" }) },
  { key = "/", mods = "CMD", action = wezterm.action.QuickSelect },

  -- Font Sizing
  { key = "=", mods = "CMD", action = wezterm.action.IncreaseFontSize },
  { key = "-", mods = "CMD", action = wezterm.action.DecreaseFontSize },
  { key = "0", mods = "CMD", action = wezterm.action.ResetFontSize },

  -- Buffer Management
  { key = "k", mods = "CMD|SHIFT", action = wezterm.action.ClearScrollback("ScrollbackAndViewport") },

  -- Workspaces

  {
    key = "o",
    mods = "CMD", -- different mod to avoid conflict
    action = wezterm.action.ShowLauncherArgs({
      flags = "FUZZY|WORKSPACES",
    }),
  },

  { key = "x", mods = "CMD|SHIFT", action = wezterm.action.ActivateCopyMode },
}

-- =============================================================================
-- KEY TABLES (Modal Keybindings)
-- =============================================================================

-- Get default key tables and extend them
local default_keys = wezterm.gui.default_key_tables()

-- Copy Mode: Add Colemak home row navigation
local copy_mode_keys = default_keys.copy_mode or {}
local colemak_copy_mode = {
  { key = "m", mods = "NONE", action = wezterm.action.CopyMode("MoveLeft") },
  { key = "n", mods = "NONE", action = wezterm.action.CopyMode("MoveDown") },
  { key = "e", mods = "NONE", action = wezterm.action.CopyMode("MoveUp") },
  { key = "i", mods = "NONE", action = wezterm.action.CopyMode("MoveRight") },
}
for _, key in ipairs(colemak_copy_mode) do
  copy_mode_keys[#copy_mode_keys + 1] = key
end

-- Search Mode: Use defaults
local search_mode_keys = default_keys.search_mode or {}

-- Resize Pane Mode: Arrow keys and Colemak home row
local resize_pane_keys = {
  -- Arrow Keys
  { key = "LeftArrow", action = wezterm.action.AdjustPaneSize({ "Left", 1 }) },
  { key = "RightArrow", action = wezterm.action.AdjustPaneSize({ "Right", 1 }) },
  { key = "UpArrow", action = wezterm.action.AdjustPaneSize({ "Up", 1 }) },
  { key = "DownArrow", action = wezterm.action.AdjustPaneSize({ "Down", 1 }) },

  -- Colemak Home Row
  { key = "m", action = wezterm.action.AdjustPaneSize({ "Left", 1 }) },
  { key = "o", action = wezterm.action.AdjustPaneSize({ "Right", 1 }) },
  { key = "e", action = wezterm.action.AdjustPaneSize({ "Up", 1 }) },
  { key = "n", action = wezterm.action.AdjustPaneSize({ "Down", 1 }) },

  -- Exit resize mode
  { key = "Escape", action = "PopKeyTable" },
}

config.key_tables = {
  copy_mode = copy_mode_keys,
  search_mode = search_mode_keys,
  resize_pane = resize_pane_keys,
}

return config
