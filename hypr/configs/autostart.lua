hl.on("hyprland.start", function()
    -- xsettingsd removed: xwayland.enabled=false causes "Unable to open X server" crash; GTK falls back to portal+dconf
    hl.exec_cmd("noctalia")
    hl.exec_cmd("~/.config/hypr/scripts/cursor-sync.sh")
    hl.exec_cmd("uwsm app -- wl-paste --type text --watch cliphist store")
    hl.exec_cmd("uwsm app -- wl-paste --type image --watch cliphist store")
    -- Keep clipboard after source app closes (Wayland requires an owner; fixes copy→close→paste fails)
    -- wl-clip-persist 0.5+: persists both regular and primary selections
    hl.exec_cmd("uwsm app -- wl-clip-persist --clipboard regular --reconnect-tries 0 --all-mime-type-regex '^(?!x-kde-passwordManagerHint).*' 2>/dev/null || wl-clip-persist --clipboard regular --reconnect-tries 0 2>/dev/null &")
    hl.exec_cmd("uwsm app -- wl-clip-persist --clipboard primary --reconnect-tries 0 2>/dev/null || wl-clip-persist --clipboard primary --reconnect-tries 0 2>/dev/null &")
    -- Pre-warm Thunar daemon (cuts ~300ms cold start; static service so start directly)
    hl.exec_cmd("systemctl --user start --no-block thunar.service 2>/dev/null || /usr/bin/Thunar --daemon &")
end)
