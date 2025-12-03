-- Keymapp window styling
hs.window.filter.new("Keymapp")
  :subscribe(hs.window.filter.windowCreated, function(win)
    win:setAlpha(0.7)
    win:setLevel(hs.drawing.windowLevels.floating)
  end)

-- Kanata layer indicator
local kanataMenu = hs.menubar.new()
local layerFile = os.getenv("HOME") .. "/.local/state/kanata/layer"

-- Style for non-default layers (white background, dark text like Aerospace)
local function styledText(text, isDefault)
    if isDefault then
        return text
    else
        -- Add spaces for padding since menubar doesn't support actual padding
        local padded = " " .. text .. " "
        return hs.styledtext.new(padded, {
            font = { name = "SF Pro", size = 12 },
            color = { white = 0.1 },
            backgroundColor = { white = 1.0, alpha = 0.9 },
            paragraphStyle = { alignment = "center" },
        })
    end
end

local function updateLayerIndicator()
    local f = io.open(layerFile, "r")
    if f then
        local layer = f:read("*l") or "?"
        f:close()
        local isDefault = (layer == "CDH")
        kanataMenu:setTitle(styledText(layer, isDefault))
    end
end

-- Watch for changes (instant, no polling)
hs.pathwatcher.new(os.getenv("HOME") .. "/.local/state/kanata/", updateLayerIndicator):start()

-- Initial read
updateLayerIndicator()