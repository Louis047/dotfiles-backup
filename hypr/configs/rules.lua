-- Global rules
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

-- Default size and centering for all floating windows (e.g., when manually toggled to float)
-- Note: XWayland context menus / tooltips (class="", title="") are excluded via the rule below
hl.window_rule({
    match = { class = ".+", float = true },
    size = { 1280, 800 },
    center = true,
})

-- PiP
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true, pin = true })

-- Special Workspaces: strictly floating-only
-- Static rule handles windows *opened* directly in special
hl.window_rule({ match = { workspace = "s[true]" }, float = true, size = { 1280, 800 }, center = true })

-- Dynamic enforcement: tiled windows moved to special become floating
-- Respects existing floating state (floating stays floating)
hl.on("window.move_to_workspace", function(win, ws)
	if ws and ws.special then
		if not win.floating then
			hl.dispatch(hl.dsp.window.float({ set = true, window = win }))
			hl.dispatch(hl.dsp.window.resize({ x = 1280, y = 800, window = win }))
			hl.dispatch(hl.dsp.window.center({ window = win }))
		end
	end
end)

-- Special Workspace Classes
local special_classes = {
	{ class = "org.cachyos.hello" },
	{ class = "dev.noctalia.Noctalia" },
	{ class = "^(org.cachyos.KernelManager)$" },
	{ class = "nwg-displays" },
	{ class = "nwg-look" },
	{ class = "localsend" },
	{ class = "com.shellyorg.shelly" }
}
for _, item in ipairs(special_classes) do
	hl.window_rule({ match = { class = item.class }, workspace = "special:magic" })
end

-- Float rules by class with specific dimensions
local float_classes = {
    -- Utility / Small windows (800x520)
    { class = "org.pulseaudio.pavucontrol", size = { 800, 520 } },
    { class = "^(blueman-manager)$", size = { 800, 520 } },
    
    -- Application / Medium windows (1100x700)
    { class = "mousepad", size = { 1100, 700 } },
    { class = "nwg-displays", size = { 1100, 700 } },
    { class = "nwg-look", size = { 1100, 700 } },
    { class = "org.cachyos.hello", size = { 1100, 700 } },
    { class = "com.github.wwmm.easyeffects", size = { 1280, 800 } },
    { class = "^(mpv)$", size = { 1280, 720 } }, -- 16:9 aspect ratio
    { class = "soffice", size = { 1280, 800 } },
    { class = "org.qbittorrent.qBittorrent", size = { 1280, 800 } },
    { class = "localsend", size = { 1100, 700 } },
    { class = "imv", size = { 1100, 700 } },
    { class = "^(org.cachyos.KernelManager)$", size = { 1100, 700 } },
    { class = "dev.faetalize.waytator", size = { 1100, 700 } },
    { class = "com.shellyorg.shelly", size = { 1100, 700 } },
    { class = "dev.noctalia.Noctalia", size = { 1100, 700 } }
}
for _, item in ipairs(float_classes) do
    hl.window_rule({ match = { class = item.class }, float = true, size = item.size })
end

-- Float rules by title with specific dimensions
local float_titles = {
    { title = "^(.*Network Manager.*)$", size = { 800, 520 } },
    { title = "^(.*- Thunar)$", size = { 1100, 700 } },
    { title = "^(Rename .*)$", size = { 480, 200 } },
    { title = "^(.*Open .*)$", size = { 1100, 700 } },
    { title = "^(.*Select .*)$", size = { 1100, 700 } },
    { title = "File Operation Progress", size = { 500, 200 } },
    { title = "Equicord QuickCSS Editor", size = { 1100, 700 } },
    { title = "Vencord QuickCSS Editor", size = { 1100, 700 } },
    { title = "btop", size = { 1280, 800 } },
    { title = "^(Zed .*)", size = { 1100, 700 } },
    { title = "about:blank - Helium", size = { 1100, 700 } }
}
for _, item in ipairs(float_titles) do
    hl.window_rule({ match = { title = item.title }, float = true, size = item.size })
end

-- App-specific float rules
hl.window_rule({ match = { class = "zen", title = "Library" }, float = true, size = { 1100, 700 } })
hl.window_rule({ match = { class = "zen-twilight", title = "Library" }, float = true, size = { 1100, 700 } })
hl.window_rule({ match = { class = "^(.*steam.*)$", title = "^(.* Settings)$" }, float = true, size = { 1100, 700 } })

-- Workspace assignments (1=browsers, 2=coding, 3=chat, 4=office, 5=gaming/entertainment)
local ws_rules = {
    [1] = { "firefox", "zen", "librewolf", "chrome", "vivaldi", "Chromium", "zen-twilight" },
    [2] = { "dev.zed.Zed", "codium", "^(.*code.*)$", "antigravity" },
    [3] = { "equibop", "discord", "vesktop", "legcord", "dorion", "^(.*gram)$" },
    [4] = { "^(libreoffice-.*)$", "soffice" },
    [5] = { "^(.*heroic.*)$", "^(.*steam.*)$", "Spotify", "com.obsproject.Studio" },
}
for ws, classes in pairs(ws_rules) do
    for _, c in ipairs(classes) do
        hl.window_rule({ match = { class = c }, workspace = ws })
    end
end

for i = 1, 5 do
    hl.workspace_rule({
        workspace = tostring(i),
        persistent = true,
    })
end


hl.bind("switch:on:LidSwitch", hl.dsp.exec_cmd("noctalia msg session lock-and-suspend"), { locked = true })

-- Immediate presentation rules for low-latency tearing in games (complements allow_tearing = true)
local tearing_apps = { "^(cs2)$", "^(gamescope)$", "^(hl2)$" }
for _, app_class in ipairs(tearing_apps) do
    hl.window_rule({ match = { class = app_class }, immediate = true })
end


hl.layer_rule({
  name = "noctalia",
  match = {
    namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
  },
  no_anim = true,
})
