#!/usr/bin/env bash

# Extract the path name
#WALLPAPER_PATH="$1"
FILENAME=$(basename "WALLPAPER_PATH")
THEME_NAME="${FILENAME%.*}"

# Dotfiles paths
WAYBAR_THEMES="$HOME/.config/waybar/themes"


# Waybar
if [ -f "$WAYBAR_THEMES/$THEME_NAME.css" ]; then
    ln -snf "$WAYBAR_THEMES/$THEME_NAME.css" "WAYBAR_THEMES/current.css"
    killall -SIGUSR2 waybar 2>/dev/null || (pkill waybar && waybar &)
fi


