#!/bin/bash
export SDL_VIDEODRIVER=wayland
export _JAVA_AWT_WM_NONREPARENTING=1
export QT_QPA_PLATFORM="wayland;xcb"
export QT_QPA_PLATFORMTHEME=qt5ct
export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_DESKTOP=sway
exec sway
