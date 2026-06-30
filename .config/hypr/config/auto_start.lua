local globals = require("config.globals")

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function()
	hl.exec_cmd("nm-applet")
	hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
	hl.exec_cmd("dunst")
	hl.exec_cmd("waybar")
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd(globals.terminal, { workspace = "9 silent" })
	hl.exec_cmd("zen-browser", { workspace = "10 silent" })
	hl.exec_cmd("hypridle")
	hl.exec_cmd("hyprsunset")
	hl.exec_cmd([[tmux setenv -g HYPRLAND_INSTANCE_SIGNATURE "$HYPRLAND_INSTANCE_SIGNATURE"]])
	hl.exec_cmd([[~/.config/hypr/scripts/battery-popup.sh -n -N -m "Battery Low!!" -t "3m"]])
	hl.exec_cmd("blueberry-tray")

	-- Clipboard manager
	hl.exec_cmd("wl-paste --type text --watch cliphist -max-items 50 store")
	hl.exec_cmd("wl-paste --type image --watch cliphist -max-items 50 store")
end)
