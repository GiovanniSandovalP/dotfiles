#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/Wallpapers"
ROFI_THEME="$HOME/.config/rofi/theme-selector.rasi"
THEME_MANAGER="$HOME/.scripts/theme/theme_manager.sh"

[ ! -d "$WALL_DIR" ] && exit 1

# Generate the list of images and FORCE icons in Rofi
SELECTED=$(for img in "$WALL_DIR"/*.{jpg,jpeg,png,webp}; do
    [ -f "$img" ] || continue
    echo -en "$(basename "$img")\0icon\x1f${img}\n"
done | rofi -dmenu -i -show-icons -p "Wallpaper" -theme "$ROFI_THEME")

if [ -n "$SELECTED" ]; then
    # Extract the path name
    WALLPAPER_PATH="$WALL_DIR/$SELECTED"
    FILENAME=$(basename "$WALLPAPER_PATH")
    THEME_NAME="${FILENAME%.*}"
    
    # Apply wallpaper with Hyprpaper
    hyprctl hyprpaper preload "$WALLPAPER_PATH"
    hyprctl hyprpaper wallpaper ",$WALLPAPER_PATH"
    
    # Execute theme manager
    [ -f "$THEME_MANAGER" ] && bash "$THEME_MANAGER" "$WALLPAPER_PATH"
fi
