local global = require("config.globals")

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

local function mod(suffix)
	return mainMod .. " + " .. suffix
end

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mod("RETURN"), hl.dsp.exec_cmd(global.terminal))
hl.bind(mod("Q"), hl.dsp.window.close())
hl.bind(mod("E"), hl.dsp.exec_cmd(global.fileManager))
hl.bind(mod("D"), hl.dsp.exec_cmd(global.menu))
hl.bind(mod("P"), hl.dsp.window.pseudo())
hl.bind(mod("F"), hl.dsp.window.fullscreen())

-- Move focus with mainMod + arrow keys
hl.bind(mod("h"), hl.dsp.focus({ direction = "l" }))
hl.bind(mod("j"), hl.dsp.focus({ direction = "d" }))
hl.bind(mod("k"), hl.dsp.focus({ direction = "u" }))
hl.bind(mod("l"), hl.dsp.focus({ direction = "r" }))

-- Move active window with mainMod + arrow keys
hl.bind(mod("SHIFT + H"), hl.dsp.window.move({ direction = "l" }))
hl.bind(mod("SHIFT + J"), hl.dsp.window.move({ direction = "d" }))
hl.bind(mod("SHIFT + K"), hl.dsp.window.move({ direction = "u" }))
hl.bind(mod("SHIFT + L"), hl.dsp.window.move({ direction = "r" }))

hl.bind(
	mod("CTRL + C"),
	hl.dsp.exec_cmd([[sel=$(cliphist list | rofi -dmenu -i); [ -n "$sel" ] && cliphist decode <<< "$sel" | wl-copy]])
)

hl.bind(
	mod("SHIFT + E"),
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
	hl.bind(mod(key), hl.dsp.focus({ workspace = i }))
	hl.bind(mod("SHIFT + " .. key), hl.dsp.window.move({ workspace = i }))
end

-- Move workspace to another monitor with control + maimode + alt + left/right
hl.bind(mod("CTRL + ALT + comma"), hl.dsp.workspace.move({ monitor = "left" }))
hl.bind(mod("CTRL + ALT + period"), hl.dsp.workspace.move({ monitor = "right" }))

-- Switch focus between floating and tiling windows
hl.bind(mod("SHIFT + SPACE"), hl.dsp.window.float({ action = "toggle" }))

hl.bind(mod("SPACE"), function()
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
hl.bind(mod("S"), hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod("SHIFT + S"), hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mod("mouse_down"), hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod("mouse_up"), hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mod("mouse:272"), hl.dsp.window.drag(), { mouse = true })
hl.bind(mod("mouse:273"), hl.dsp.window.resize(), { mouse = true })

-- Microphone controls
hl.bind(
	mod("XF86AudioRaiseVolume"),
	hl.dsp.exec_cmd("pactl set-source-volume @DEFAULT_SOURCE@ +5%"),
	{ locked = true, repeating = true }
)
hl.bind(
	mod("XF86AudioLowerVolume"),
	hl.dsp.exec_cmd("pactl set-source-volume @DEFAULT_SOURCE@ -5%"),
	{ locked = true, repeating = true }
)
hl.bind(
	mod("XF86AudioMute"),
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
	mod("Print"),
	hl.dsp.exec_cmd(
		[[filepath=~/Pictures/Screenshots/$(date +"%Y-%m-%d_%H-%M").png && mkdir -p ~/Pictures/Screenshots && slurp | grim -g "$(cat)" "$filepath" && swappy -f "$filepath"]]
	)
)

hl.bind(
	mod("SHIFT + Print"),
	hl.dsp.exec_cmd(
		[[filepath=~/Pictures/Screenshots/$(date +"%Y-%m-%d_%H-%M").png && mkdir -p ~/Pictures/Screenshots && grim "$filepath" && swappy -f "$filepath"]]
	)
)

hl.bind(mod("SHIFT + W"), hl.dsp.exec_cmd("~/.config/hypr/scripts/random-wallpaper.sh"))
