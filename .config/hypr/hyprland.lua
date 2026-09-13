-- Hyprland configuration
-- Migrated from hyprland.conf to Hyprland's Lua config system (0.55+).
-- Split into vars.lua (shared variables), env.lua (environment) and
-- keybinds.lua (keybindings), same layout as the old .conf setup.

-- Disable auto monitor config; monitors.sh / lid.sh apply the real layout
-- at runtime via hyprctl (see the autostart block and switch binds below).
hl.monitor({ output = "", disabled = true })

hl.config({
    general = {
        gaps_in = 0,
        gaps_out = 2,
        border_size = 2,
        ["col.active_border"] = "rgba(88c0d0ff)",
        ["col.inactive_border"] = "rgba(444444aa)",
        -- layout = "dwindle",
    },

    decoration = {
        rounding = 4,
    },

    animations = {
        enabled = true,
    },

    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 1,
        accel_profile = "flat",
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        focus_on_activate = true,
    },
})

-- dwindle {
--     pseudotile = true,
--     preserve_split = true,
-- }

hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "default", style = "popin" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "default", style = "slide" })

-- Autostart (replaces exec-once)
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("quickshell -c ~/.config/quickshell")
    hl.exec_cmd("wlsunset -l 52.48 -L 13.43")
    hl.exec_cmd("~/.config/hypr/monitors.sh")
end)

require("env")
require("keybinds")

-- Lid switch handling (was `bindl`, so it also fires while the session is locked)
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/lid.sh open"), { locked = true })
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/lid.sh close"), { locked = true })

-- NOTE: the old config's top-level `auto_reload = false` was not a documented
-- Hyprland keyword (it isn't a valid key under any standard category), so it
-- had no effect and has been dropped here rather than guessed at.
