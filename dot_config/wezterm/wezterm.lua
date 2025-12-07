local wezterm = require("wezterm")
local theme = require("theme")
local config = {}

-- =============================================================================
-- APPEARANCE
-- =============================================================================

config.window_decorations = "RESIZE"
config.color_scheme = theme()
config.font = wezterm.font("JetBrains Mono")
config.font_size = 13.0

config.inactive_pane_hsb = {
  saturation = 0.2,
  brightness = 0.7,
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
-- STATUS BAR
-- =============================================================================

config.status_update_interval = 100

wezterm.on("update-status", function(window, pane)
  local key_table = window:active_key_table()
  local workspace = window:active_workspace()
  local mode_color = "#27AABB" -- Blue (matches aerospace border color)

  if key_table then
    local mode_text = string.upper(key_table:gsub("_", " "))
    window:set_left_status("")
    window:set_right_status(wezterm.format({
      { Background = { Color = mode_color } },
      { Foreground = { Color = "#000000" } },
      { Text = " " .. mode_text .. " | " .. workspace .. "   " },
    }))
  else
    window:set_left_status("")
    window:set_right_status(wezterm.format({
      { Foreground = { Color = "#888888" } },
      { Text = " " .. workspace .. "   " },
    }))
  end
end)

-- =============================================================================
-- HELPERS
-- =============================================================================

-- Block unused keys in a key table to prevent accidental typing
local function block_keys(key_table, keys_to_block)
  for _, key in ipairs(keys_to_block) do
    table.insert(key_table, { key = key, action = wezterm.action.Nop })
  end
end

-- Keys to block in modal key tables (all unused letters + punctuation)
local blocked_keys = {
  "b",
  "c",
  "d",
  "f",
  "g",
  "h",
  "j",
  "k",
  "l",
  "o",
  "p",
  "q",
  "t",
  "u",
  "v",
  "w",
  "x",
  "y",
  "z",
  ".",
  ",",
  ";",
  "/",
}

local workspace_switcher = wezterm.action_callback(function(window, pane)
  local choices = {
    { label = "+ Create new workspace", id = "new" },
  }

  for _, name in ipairs(wezterm.mux.get_workspace_names()) do
    table.insert(choices, { label = name, id = name })
  end

  window:perform_action(
    wezterm.action.InputSelector({
      title = "Switch/Create Workspace",
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
        if id == "new" then
          inner_window:perform_action(
            wezterm.action.PromptInputLine({
              description = "Enter new workspace name",
              action = wezterm.action_callback(function(w, p, line)
                if line and #line > 0 then
                  w:perform_action(wezterm.action.SwitchToWorkspace({ name = line }), p)
                end
              end),
            }),
            inner_pane
          )
        elseif id then
          inner_window:perform_action(wezterm.action.SwitchToWorkspace({ name = id }), inner_pane)
        end
      end),
    }),
    pane
  )
end)
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

  -- Pane Splitting (L/U = adjacent index/middle finger on top row)
  { key = "l", mods = "CMD", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "u", mods = "CMD", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },

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

  -- Tab Navigation (matches aerospace prev/next workspace)
  { key = ",", mods = "CMD", action = wezterm.action.ActivateTabRelative(-1) },
  { key = ".", mods = "CMD", action = wezterm.action.ActivateTabRelative(1) },

  -- Mode Entry (matches aerospace: R=resize, S=swap)
  {
    key = "r",
    mods = "CMD",
    action = wezterm.action.ActivateKeyTable({
      name = "resize_pane",
      one_shot = false,
      replace_current = true,
    }),
  },
  {
    key = "s",
    mods = "CMD",
    action = wezterm.action.ActivateKeyTable({
      name = "swap_pane",
      one_shot = false,
      replace_current = true,
    }),
  },

  -- Pane Zoom
  { key = "z", mods = "CMD", action = wezterm.action.TogglePaneZoomState },

  -- Clipboard
  { key = "c", mods = "CMD", action = wezterm.action.CopyTo("Clipboard") },
  { key = "v", mods = "CMD", action = wezterm.action.PasteFrom("Clipboard") },

  -- Search & Quick Select
  { key = "f", mods = "CMD", action = wezterm.action.Search({ CaseSensitiveString = "" }) },
  { key = "g", mods = "CMD", action = wezterm.action.QuickSelect },

  -- Font Sizing
  { key = "-", mods = "CMD", action = wezterm.action.DecreaseFontSize },
  { key = "+", mods = "CMD", action = wezterm.action.IncreaseFontSize },

  -- Buffer Management
  { key = "k", mods = "CMD|SHIFT", action = wezterm.action.ClearScrollback("ScrollbackAndViewport") },
  { key = "x", mods = "CMD|SHIFT", action = wezterm.action.ActivateCopyMode },

  -- Workspaces
  {
    key = "o",
    mods = "CMD",
    action = workspace_switcher,
  },

  -- Debug
  {
    key = "l",
    mods = "CTRL|SHIFT",
    action = wezterm.action.ShowDebugOverlay,
  },

  -- Reload config (useful after appearance change)
  { key = "r", mods = "CMD|SHIFT", action = wezterm.action.ReloadConfiguration },
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

  -- Colemak Home Row (M/N = shrink, E/I = grow) - bare or with CMD held
  { key = "m", action = wezterm.action.AdjustPaneSize({ "Left", 1 }) },
  { key = "n", action = wezterm.action.AdjustPaneSize({ "Down", 1 }) },
  { key = "e", action = wezterm.action.AdjustPaneSize({ "Up", 1 }) },
  { key = "i", action = wezterm.action.AdjustPaneSize({ "Right", 1 }) },
  { key = "m", mods = "CMD", action = wezterm.action.AdjustPaneSize({ "Left", 1 }) },
  { key = "n", mods = "CMD", action = wezterm.action.AdjustPaneSize({ "Down", 1 }) },
  { key = "e", mods = "CMD", action = wezterm.action.AdjustPaneSize({ "Up", 1 }) },
  { key = "i", mods = "CMD", action = wezterm.action.AdjustPaneSize({ "Right", 1 }) },

  -- Mode switching (matches aerospace) - bare or with CMD held
  {
    key = "s",
    action = wezterm.action.ActivateKeyTable({ name = "swap_pane", one_shot = false, replace_current = true }),
  },
  {
    key = "s",
    mods = "CMD",
    action = wezterm.action.ActivateKeyTable({ name = "swap_pane", one_shot = false, replace_current = true }),
  },

  -- Exit (A = left pinky, matches aerospace) - bare or with CMD held
  { key = "a", action = "PopKeyTable" },
  { key = "a", mods = "CMD", action = "PopKeyTable" },
  { key = "Escape", action = "PopKeyTable" },
}
block_keys(resize_pane_keys, blocked_keys)
-- Also block 'r' since we're already in resize mode
table.insert(resize_pane_keys, { key = "r", action = wezterm.action.Nop })

-- Swap Pane Mode: Move panes directionally
local swap_pane_keys = {
  -- Arrow Keys
  { key = "LeftArrow", action = wezterm.action.RotatePanes("CounterClockwise") },
  { key = "RightArrow", action = wezterm.action.RotatePanes("Clockwise") },

  -- Colemak Home Row - bare or with CMD held
  { key = "m", action = wezterm.action.RotatePanes("CounterClockwise") },
  { key = "i", action = wezterm.action.RotatePanes("Clockwise") },
  { key = "n", action = wezterm.action.RotatePanes("CounterClockwise") },
  { key = "e", action = wezterm.action.RotatePanes("Clockwise") },
  { key = "m", mods = "CMD", action = wezterm.action.RotatePanes("CounterClockwise") },
  { key = "i", mods = "CMD", action = wezterm.action.RotatePanes("Clockwise") },
  { key = "n", mods = "CMD", action = wezterm.action.RotatePanes("CounterClockwise") },
  { key = "e", mods = "CMD", action = wezterm.action.RotatePanes("Clockwise") },

  -- Mode switching (matches aerospace) - bare or with CMD held
  {
    key = "r",
    action = wezterm.action.ActivateKeyTable({ name = "resize_pane", one_shot = false, replace_current = true }),
  },
  {
    key = "r",
    mods = "CMD",
    action = wezterm.action.ActivateKeyTable({ name = "resize_pane", one_shot = false, replace_current = true }),
  },

  -- Exit (A = left pinky, matches aerospace) - bare or with CMD held
  { key = "a", action = "PopKeyTable" },
  { key = "a", mods = "CMD", action = "PopKeyTable" },
  { key = "Escape", action = "PopKeyTable" },
}
block_keys(swap_pane_keys, blocked_keys)
-- Also block 's' since we're already in swap mode
table.insert(swap_pane_keys, { key = "s", action = wezterm.action.Nop })

config.key_tables = {
  copy_mode = copy_mode_keys,
  search_mode = search_mode_keys,
  resize_pane = resize_pane_keys,
  swap_pane = swap_pane_keys,
}

return config
