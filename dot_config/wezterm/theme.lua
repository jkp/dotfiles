local wezterm = require("wezterm")

-- wezterm.gui is not available to the mux server, so take care to
-- do something reasonable when this config is evaluated by the mux
local function get_appearance()
  if wezterm.gui then
    return wezterm.gui.get_appearance()
  end
  return "Dark"
end

local function scheme_for_appearance(appearance)
  if appearance:find("Dark") then
    return "Material Darker (base16)"
  else
    return "dayfox"
  end
end

-- Return a function that returns the color scheme name
return function()
  return scheme_for_appearance(get_appearance())
end
