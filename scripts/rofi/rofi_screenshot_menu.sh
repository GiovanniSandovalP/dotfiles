#!/usr/bin/env bash

opt_1="󰆞  Region"
opt_2="  Window"
opt_3="󰍹  Full Screen"

choice=$(echo -e "$opt_1\n$opt_2\n$opt_3" | rofi -dmenu -i -theme ~/.config/rofi/screenshot_menu.rasi)

case $choice in
    "$opt_1")
        sleep 0.2
        hyprshot -m region --raw | satty --filename -
        ;;
    "$opt_2")
        sleep 0.2
        hyprshot -m window --raw | satty --filename -
        ;;
    "$opt_3")
        sleep 0.2
        hyprshot -m output --raw | satty --filename -
        ;;
esac
