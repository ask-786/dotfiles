local global = require("config.globals")

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(global.terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(global.fileManager))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(global.menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "r" }))

-- Move active window with mainMod + arrow keys
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))

hl.bind(
	mainMod .. " + CTRL + C",
	hl.dsp.exec_cmd([[sel=$(cliphist list | rofi -dmenu -i); [ -n "$sel" ] && cliphist decode <<< "$sel" | wl-copy]])
)

hl.bind(
	mainMod .. " + SHIFT + E",
	hl.dsp.exec_cmd([[
		chosen=$(printf "Yes\nNo" | rofi -dmenu -p "Exit Hyprland?") &&
		[ "$chosen" = "Yes" ] && {
			command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit
		}
	]])
)

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Move workspace to another monitor with control + maimode + alt + left/right
hl.bind(mainMod .. " + CTRL + ALT + comma", hl.dsp.workspace.move({ monitor = "left" }))
hl.bind(mainMod .. " + CTRL + ALT + period", hl.dsp.workspace.move({ monitor = "right" }))

-- Switch focus between floating and tiling windows
hl.bind(mainMod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))

hl.bind(mainMod .. " + SPACE", function()
	local w = hl.get_active_window()

	if not w then
		return
	end

	local action

	if w.floating ~= true then
		action = hl.dsp.focus({ window = "floating" })
	else
		action = hl.dsp.focus({ window = "tiled" })
	end

	hl.dispatch(action)
end)

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Microphone controls
hl.bind(
	mainMod .. " + XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("pactl set-source-volume @DEFAULT_SOURCE@ +5%"),
	{ locked = true, repeating = true }
)
hl.bind(
	mainMod .. " + XF86AudioLowerVolume",
	hl.dsp.exec_cmd("pactl set-source-volume @DEFAULT_SOURCE@ -5%"),
	{ locked = true, repeating = true }
)
hl.bind(
	mainMod .. " + XF86AudioMute",
	hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)

-- Laptop multimedia keys for volume and LCD brightness
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Screenshots
hl.bind(
	"Print",
	hl.dsp.exec_cmd(
		[[tempfile=$(mktemp /tmp/screenshot-XXXXXX.png) && slurp | grim -g "$(cat)" "$tempfile" && swappy -f "$tempfile" && rm "$tempfile"]]
	),
	{ locked = true }
)

hl.bind(
	mainMod .. " + Print",
	hl.dsp.exec_cmd(
		[[filepath=~/Pictures/Screenshots/$(date +"%Y-%m-%d_%H-%M").png && mkdir -p ~/Pictures/Screenshots && slurp | grim -g "$(cat)" "$filepath" && swappy -f "$filepath"]]
	)
)

hl.bind(
	mainMod .. "+ SHIFT + Print",
	hl.dsp.exec_cmd(
		[[filepath=~/Pictures/Screenshots/$(date +"%Y-%m-%d_%H-%M").png && mkdir -p ~/Pictures/Screenshots && grim "$filepath" && swappy -f "$filepath"]]
	)
)

hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/random-wallpaper.sh"))
