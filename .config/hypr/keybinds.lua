-- Keybindings
-- Migrated from keybinds.conf

local vars = require("vars")
local mod = vars.mod
local terminal = vars.terminal
local browser = vars.browser

------------------------------------------------------------------------------
-- Terminal & apps
------------------------------------------------------------------------------
hl.bind(mod .. "+Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. "+T", hl.dsp.exec_cmd(browser))
hl.bind(mod .. "+Q", hl.dsp.window.kill())
hl.bind(mod .. "+SHIFT+E", hl.dsp.exit())

-- Launcher
hl.bind(mod .. "+Space", hl.dsp.exec_cmd("~/.config/rofi/launchers/type-1/launcher.sh"))

------------------------------------------------------------------------------
-- Window management
------------------------------------------------------------------------------
hl.bind(mod .. "+F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mod .. "+SHIFT+F", hl.dsp.window.float({ action = "toggle" }))

-- Focus movement
hl.bind(mod .. "+H", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. "+L", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. "+K", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. "+J", hl.dsp.focus({ direction = "down" }))

-- Move windows
hl.bind(mod .. "+SHIFT+H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. "+SHIFT+L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. "+SHIFT+K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. "+SHIFT+J", hl.dsp.window.move({ direction = "down" }))

------------------------------------------------------------------------------
-- Workspaces
------------------------------------------------------------------------------
for i = 1, 9 do
    hl.bind(mod .. "+" .. i, hl.dsp.focus({ workspace = tostring(i) }))
    hl.bind(mod .. "+SHIFT+" .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end
hl.bind(mod .. "+0", hl.dsp.focus({ workspace = "10" }))
hl.bind(mod .. "+SHIFT+0", hl.dsp.window.move({ workspace = "10" }))

------------------------------------------------------------------------------
-- Brightness
------------------------------------------------------------------------------
hl.bind(mod .. "+UP", hl.dsp.exec_cmd("brightnessctl --device='tpacpi::kbd_backlight' s 2"))
hl.bind(mod .. "+DOWN", hl.dsp.exec_cmd("brightnessctl --device='tpacpi::kbd_backlight' s 0"))

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s +5%"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"), { locked = true })

------------------------------------------------------------------------------
-- Audio
------------------------------------------------------------------------------
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +10%"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -10%"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"), { locked = true })

hl.bind("F6", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +10%"), { locked = true })
hl.bind("F5", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -10%"), { locked = true })
hl.bind("F8", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"), { locked = true })

------------------------------------------------------------------------------
-- Screenshots
------------------------------------------------------------------------------
-- Fullscreen screenshot (saved + copied + notification)
hl.bind(mod .. "+M", hl.dsp.exec_cmd(
    [[sh -c 'FILE=~/Pictures/$(date +"%Y-%m-%d_%H-%M-%S")_fullscreen.png; grim "$FILE" && wl-copy < "$FILE" && notify-send "Screenshot saved" "$FILE"']]
))

-- Screenshot of selected region (saved + copied + notification)
hl.bind(mod .. "+N", hl.dsp.exec_cmd(
    [[sh -c 'FILE=~/Pictures/$(date +"%Y-%m-%d_%H-%M-%S")_region.png; grim -g "$(slurp)" "$FILE" && wl-copy < "$FILE" && notify-send "Screenshot saved" "$FILE"']]
))

------------------------------------------------------------------------------
-- Custom scripts
------------------------------------------------------------------------------
hl.bind(mod .. "+SHIFT+A", hl.dsp.exec_cmd("~/.config/sway/scripts/wlsunset-toggle.sh"))
hl.bind(mod .. "+B", hl.dsp.exec_cmd("~/.config/sway/scripts/kill_bar.sh"))

------------------------------------------------------------------------------
-- TUI apps
------------------------------------------------------------------------------
hl.bind(mod .. "+SHIFT+B", hl.dsp.exec_cmd(terminal .. " -e bluetui"))
hl.bind(mod .. "+SHIFT+W", hl.dsp.exec_cmd(terminal .. " -e wifitui"))
hl.bind(mod .. "+SHIFT+P", hl.dsp.exec_cmd("hyprlock"))

hl.bind(mod .. "+W", hl.dsp.group.toggle())
