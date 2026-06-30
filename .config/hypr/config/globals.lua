---@class Globals
---@field terminal string
---@field fileManager string
---@field menu string

---@type Globals
local M = {
	terminal = "kitty",
	fileManager = "thunar",
	menu = [[rofi -show combi -combi-modes "drun,window,run" -modes combi -matching fuzzy]],
}

return M
