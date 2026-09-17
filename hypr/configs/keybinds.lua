local mod = "SUPER"
local mod2 = "ALT"
local ctrl = "CTRL"

local terminal = "foot"
local file_manager = "thunar"
local browser = "zen-browser"

-- App launchers
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + E", hl.dsp.exec_cmd(file_manager))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(ctrl .. " + SPACE", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))

-- Volume
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("noctalia msg volume-up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("noctalia msg volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("noctalia msg volume-mute"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("noctalia msg mic-mute"), { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("noctalia msg brightness-up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("noctalia msg brightness-down"), { locked = true, repeating = true })

-- Media
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("noctalia msg media toggle"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("noctalia msg media next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("noctalia msg media previous"), { locked = true })

-- Session
hl.bind(mod .. " + L", hl.dsp.exec_cmd("noctalia msg session lock"))

-- Window management
hl.bind(mod .. " + T", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.resize({ x = 1280, y = 800 }))
    hl.dispatch(hl.dsp.window.center())
end)

-- True fullscreen
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({
    mode = "fullscreen",
    action = "toggle"
}))

-- Maximized / monocle-like
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({
    mode = "maximized",
    action = "toggle"
}))
hl.bind(mod .. " + P", hl.dsp.window.pin())
hl.bind(mod .. " + V", hl.dsp.layout("togglesplit"))

-- To switch between windows in a floating workspace:
hl.bind(mod .. " + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())    -- Change focus to another window
    hl.dispatch(hl.dsp.window.bring_to_top()) -- Bring it to the top
end)

-- Focus navigation (arrows)
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Window movement
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- Workspace cycling across monitors
-- Workspace cycling (active windows only via script)
hl.bind(mod .. " + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/cycle-active-workspaces.sh next"))
hl.bind(mod .. " + A", hl.dsp.exec_cmd("~/.config/hypr/scripts/cycle-active-workspaces.sh prev"))

-- Move active window across screens
hl.bind(mod .. " + " .. ctrl .. " + D", hl.dsp.window.move({ monitor = "+1" }))
hl.bind(mod .. " + " .. ctrl .. " + A", hl.dsp.window.move({ monitor = "-1" }))

-- Resizing windows
hl.bind(mod .. " + " .. ctrl .. " + right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + " .. ctrl .. " + left", hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + " .. ctrl .. " + up", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true })
hl.bind(mod .. " + " .. ctrl .. " + down", hl.dsp.window.resize({ x = 0, y = 20, relative = true }), { repeating = true })
hl.bind(mod .. " + SHIFT + D", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind(mod .. " + SHIFT + A", hl.dsp.window.move({ workspace = "e-1" }))

-- Workspaces 1-5 only (1=browsers, 2=coding, 3=chat, 4=office, 5=gaming)
for i = 1, 5 do
    local key = tostring(i)
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special workspace
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + S", function()
    hl.dispatch(hl.dsp.window.float({ set = true }))
    hl.dispatch(hl.dsp.window.resize({ x = 1280, y = 800 }))
    hl.dispatch(hl.dsp.window.center())
    hl.dispatch(hl.dsp.window.move({ workspace = "special:magic" }))
end)

-- Mouse binds
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Reload
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/reload.sh"))

-- Zoom
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 3.0 then
        hl.config({ cursor = { zoom_factor = 3.0 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind(mod .. " + Minus", function() zoomfunction(-0.3) end, { repeating = true})
hl.bind(mod .. " + Plus", function() zoomfunction(0.3) end, { repeating = true })

--# Zoom with keypad
hl.bind(mod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mod .. " + code:86", function() zoomfunction(0.3) end, { repeating = true })

-- Screenshot (annotate → copy + save)
hl.bind(mod2 .. " + S", hl.dsp.exec_cmd("grabit -e -c"))

-- Screenshot fullscreen (annotate → copy + save)
hl.bind(mod2 .. " + SHIFT + S", hl.dsp.exec_cmd("grabit -e -F -c"))

-- Region recording toggle
hl.bind(mod2 .. " + R", hl.dsp.exec_cmd("grabit --record"))

-- Fullscreen recording toggle
hl.bind(mod2 .. " + SHIFT + R", hl.dsp.exec_cmd("grabit --record --fullscreen"))

-- OCR region → clipboard
hl.bind(mod2 .. " + T", hl.dsp.exec_cmd("grabit --tesseract")) 

-- Bar Toggle
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("noctalia msg bar-toggle"))

-- OLED warm shader disabled by default to allow direct_scanout + tearing (SUPER+W to toggle if needed)
local SHADER_PATH = "~/.config/hypr/shaders/oled_warm.frag"
hl.bind(mod .. " + W", function()
    local shader = hl.get_config("decoration:screen_shader")
    if shader == "" then
        hl.config({ decoration = { screen_shader = SHADER_PATH } })
    else
        hl.config({ decoration = { screen_shader = "" } })
    end
end)
