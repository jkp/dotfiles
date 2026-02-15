-- Workspace-scoped window cycling via Aerospace with visual overlay
local M = {}

-- =============================================================================
-- OVERLAY CONFIG
-- =============================================================================
local FONT_SIZE = 14
local CORNER_RADIUS = 8
local BG_COLOR = { red = 0.12, green = 0.12, blue = 0.14, alpha = 0.92 }
local DISMISS_DELAY = 0.8

local alertStyle = {
  strokeWidth = 2,
  strokeColor = { red = 0.15, green = 0.45, blue = 0.65, alpha = 0.8 },
  fillColor = BG_COLOR,
  textColor = { white = 1, alpha = 1 },
  textFont = "Menlo",
  textSize = FONT_SIZE,
  radius = CORNER_RADIUS,
  atScreenEdge = 0,
  fadeInDuration = 0,
  fadeOutDuration = 0.15,
  padding = 24,
}

-- =============================================================================
-- AEROSPACE CLI
-- =============================================================================
local AEROSPACE = "/opt/homebrew/bin/aerospace"

-- Single shell call: get focused ID and all workspace windows
local function getState()
  local cmd = AEROSPACE .. " list-windows --focused --format '%{window-id}' && " ..
              AEROSPACE .. " list-windows --workspace focused --format '%{window-id}|%{app-name}|%{window-title}'"
  local output = io.popen(cmd):read("*a")
  if not output or #output == 0 then return nil, {} end

  local lines = {}
  for line in output:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local focusedId = tonumber(lines[1])
  local windows = {}
  for i = 2, #lines do
    local id, app, title = lines[i]:match("^(%d+)|([^|]*)|(.*)$")
    if id then
      table.insert(windows, { id = tonumber(id), app = app, title = title })
    end
  end

  return focusedId, windows
end

-- Fire and forget focus command
local function focusWindow(windowId)
  hs.task.new(AEROSPACE, nil, { "focus", "--window-id", tostring(windowId) }):start()
end

-- =============================================================================
-- OVERLAY
-- =============================================================================
local function showOverlay(windows, focusedIndex)
  -- Check for duplicate app names
  local appCount = {}
  for _, w in ipairs(windows) do
    appCount[w.app] = (appCount[w.app] or 0) + 1
  end

  local parts = {}
  for i, w in ipairs(windows) do
    local label = w.app
    if appCount[w.app] > 1 and w.title and #w.title > 0 then
      local short = w.title
      if #short > 25 then short = short:sub(1, 22) .. "..." end
      label = label .. " - " .. short
    end

    if i == focusedIndex then
      label = "[ " .. label .. " ]"
    else
      label = "  " .. label .. "  "
    end
    table.insert(parts, label)
  end

  hs.alert.closeAll(0)
  hs.alert.show(table.concat(parts, "   "), alertStyle, hs.screen.mainScreen(), DISMISS_DELAY)
end

-- =============================================================================
-- CYCLING
-- =============================================================================
local function cycle(direction)
  local focusedId, windows = getState()
  if #windows <= 1 then return end

  local currentIndex = 1
  for i, w in ipairs(windows) do
    if w.id == focusedId then
      currentIndex = i
      break
    end
  end

  local nextIndex
  if direction == 1 then
    nextIndex = (currentIndex % #windows) + 1
  else
    nextIndex = ((currentIndex - 2) % #windows) + 1
  end

  focusWindow(windows[nextIndex].id)
  showOverlay(windows, nextIndex)
end

function M.cycleNext()
  cycle(1)
end

function M.cyclePrev()
  cycle(-1)
end

-- =============================================================================
-- EVENTTAP (intercept Cmd+Tab before macOS)
-- =============================================================================
M.tapCmdTab = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local keyCode = event:getKeyCode()
  local flags = event:getFlags()

  -- Tab keycode = 48
  if keyCode == 48 and flags:containExactly({ "cmd" }) then
    M.cycleNext()
    return true
  elseif keyCode == 48 and flags:containExactly({ "cmd", "shift" }) then
    M.cyclePrev()
    return true
  end

  return false
end)

M.tapCmdTab:start()

return M
