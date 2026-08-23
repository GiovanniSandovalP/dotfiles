#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/Wallpapers"
ROFI_THEME="$HOME/.config/rofi/theme-selector.rasi"
THEME_MANAGER="$HOME/.scripts/theme/theme_manager.sh"

[ ! -d "$WALL_DIR" ] && exit 1

SELECTED=$(for img in "$WALL_DIR"/*.{jpg,jpeg,png,webp}; do
    [ -f "$img" ] || continue
    echo -en "$(basename "$img")\0icon\x1f${img}\n"
done | rofi -dmenu -i -show-icons -p "Wallpaper" -theme "$ROFI_THEME")

if [ -n "$SELECTED" ]; then
    WALLPAPER_PATH="$WALL_DIR/$SELECTED"
    
    # Clear RAM, preload new image, and apply to all monitors
    hyprctl hyprpaper unload all 2>/dev/null
    hyprctl hyprpaper preload "$WALLPAPER_PATH" 2>/dev/null
    
    for monitor in $(hyprctl monitors | awk '/Monitor/{print $2}'); do
        hyprctl hyprpaper wallpaper "$monitor,$WALLPAPER_PATH" 2>/dev/null
    done
    
    # Execute theme manager
    [ -f "$THEME_MANAGER" ] && bash "$THEME_MANAGER" "$WALLPAPER_PATH"
fi
