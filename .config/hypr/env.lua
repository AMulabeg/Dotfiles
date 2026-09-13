-- Environment variables
-- Migrated from env.conf

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

hl.env("LIBVA_DRIVER_NAME", "iHD")
hl.env("VDPAU_DRIVER", "va_gl")

hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

hl.env("MOZ_ENABLE_WAYLAND", "1")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
