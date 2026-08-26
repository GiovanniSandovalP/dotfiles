#!/usr/bin/env bash

WALL_DIR="$HOME/Pictures/Wallpapers"
ROFI_THEME="$HOME/.config/rofi/theme-selector.rasi"
THEME_MANAGER="$HOME/.scripts/theme/theme_manager.sh"

[ ! -d "$WALL_DIR" ] && exit 1

# Guardamos las imágenes en un arreglo
shopt -s nullglob
images=("$WALL_DIR"/*.{jpg,jpeg,png,webp})
shopt -u nullglob

[ ${#images[@]} -eq 0 ] && exit 1

# Generamos la lista formateada para Rofi
rofi_input=""
for img in "${images[@]}"; do
    filename=$(basename "$img")
    name="${filename%.*}"
    rofi_input+="${name}\0icon\x1f${img}\n"
done

# Obtiene el ÍNDICE (posición 0, 1, 2...) de la imagen elegida usando -format i
INDEX=$(echo -en "$rofi_input" | rofi -dmenu -i -format i -show-icons -p "Wallpaper" -theme "$ROFI_THEME")

if [ -n "$INDEX" ]; then
    # Obtenemos la ruta exacta usando el índice del arreglo
    WALLPAPER_PATH="${images[$INDEX]}"

    if [ -f "$WALLPAPER_PATH" ]; then
        # Clear RAM, preload new image, and apply to all monitors
        hyprctl hyprpaper unload all 2>/dev/null
        hyprctl hyprpaper preload "$WALLPAPER_PATH" 2>/dev/null

        for monitor in $(hyprctl monitors | awk '/Monitor/{print $2}'); do
            hyprctl hyprpaper wallpaper "$monitor,$WALLPAPER_PATH" 2>/dev/null
        done

        # Execute theme manager
        [ -f "$THEME_MANAGER" ] && bash "$THEME_MANAGER" "$WALLPAPER_PATH"
    fi
fi
