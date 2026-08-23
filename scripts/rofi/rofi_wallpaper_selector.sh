#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/Wallpapers"
ROFI_THEME="$HOME/.config/rofi/theme-selector.rasi"
THEME_MANAGER="$HOME/.scripts/theme/theme_manager.sh"

[ ! -d "$WALL_DIR" ] && exit 1

SELECTED=$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" \) | sort | while read -r img; do
    echo -e "$(basename "$img")\0icon\x1f${img}"
done | rofi -dmenu -i -p "Wallpaper" -theme "$ROFI_THEME")

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
