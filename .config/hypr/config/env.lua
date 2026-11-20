-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("GDK_SCALE", "1")

-- Login zsh never sources ~/.profile, so add personal scripts to the session
-- PATH here; vicinae, binds and exec-once all inherit it. Guarded so a config
-- reload doesn't prepend it again.
local scripts = os.getenv("HOME") .. "/.local/scripts"
local path = os.getenv("PATH") or ""
if not (":" .. path .. ":"):find(":" .. scripts .. ":", 1, true) then
	hl.env("PATH", scripts .. ":" .. path)
end
