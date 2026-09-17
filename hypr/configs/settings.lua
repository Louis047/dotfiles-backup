hl.config({
    render = {
        direct_scanout = 1,
        use_fp16 = 1,
    },
    ecosystem = {
        no_donation_nag = true,
        no_update_news = true,
    },
    general = {
        gaps_in = 2,
        gaps_out = 4,
        layout = "dwindle",
        border_size = 0,
        allow_tearing = true,
    },
    decoration = {
        rounding = 0,
        
        blur = {
            enabled = false,
        },

        shadow = {
            enabled = false,
        },
        
        screen_shader = ""
    },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = -0.075,
        accel_profile = "flat",
        numlock_by_default = true,
        repeat_rate = 30,
        repeat_delay = 175,
        touchpad = {
            natural_scroll = true,
            scroll_factor = 0.65,
            drag_lock = 2,
        },
    },
    gestures = {
        workspace_swipe_distance = 300,
        workspace_swipe_min_speed_to_force = 20,
        workspace_swipe_cancel_ratio = 0.5,
    },
    misc = {
        disable_hyprland_logo = true,
        middle_click_paste = false,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color = 0x000000,
        vrr = 2,
        key_press_enables_dpms = true,
    },
    xwayland = {
        enabled = false,
    },
    dwindle = {
        preserve_split = true,
        force_split = 2
    },
    animations = {
        enabled = false
    }
})

-- Touchpad per-device overrides (preserves touchpad-specific sensitivity)
hl.device({ name = "elan1203:00-04f3:307a-touchpad", sensitivity = 0.15, accel_profile = "adaptive" })
hl.device({ name = "elan1203:00-04f3:307a-mouse", sensitivity = 0.15, accel_profile = "adaptive" })

-- Gestures
hl.gesture({ fingers = 3, direction = "horizontal", scale = 1.0, action = "workspace" })
hl.gesture({ fingers = 3, direction = "vertical", action = "special" })
