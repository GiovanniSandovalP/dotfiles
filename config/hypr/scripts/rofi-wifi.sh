#!/bin/bash

# --- Icons ---
ICON_WIFI=""
ICON_ETH="󰈀"
ICON_SCAN="󰑐"
ICON_LOCK=""
ICON_UNLOCK=""
ICON_CHECK="󰄬"

# Background rescan to update cache
nmcli dev wifi rescan >/dev/null 2>&1 &

FULL_LIST=" $ICON_SCAN Scan networks\n"
CURRENT_LINE=1
ACTIVE_INDEX=-1

# Active Ethernet
ETH_CONNS=$(nmcli -t -f NAME,TYPE con show --active | awk -F: '/ethernet/ {print " '$ICON_ETH' [Ethernet] " $1}')
if [ -n "$ETH_CONNS" ]; then
    FULL_LIST="${FULL_LIST}${ETH_CONNS}\n"
    CURRENT_LINE=$((CURRENT_LINE + 1))
fi

# Extract and deduplicate Wi-Fi list
WIFI_RAW=$(nmcli -t -f IN-USE,SSID,SECURITY dev wifi list --rescan no)
WIFI_CLEAN=$(echo "$WIFI_RAW" | grep -v '^\s*$' | awk -F: '!seen[$2]++ {print}')

# Process each Wi-Fi network
while IFS=: read -r IN_USE SSID SECURITY; do
    [ -z "$SSID" ] && continue

    if [[ "$SECURITY" == "--" || -z "$SECURITY" ]]; then
        SEC_ICON="$ICON_UNLOCK"
    else
        SEC_ICON="$ICON_LOCK"
    fi

    # Check for connected network
    if [[ "$IN_USE" == "*" ]]; then
        ACTIVE_INDEX=$CURRENT_LINE
        LIST_ITEM="$ICON_CHECK $SSID $SEC_ICON"
    else
        LIST_ITEM=" $ICON_WIFI $SSID $SEC_ICON"
    fi

    FULL_LIST="${FULL_LIST}${LIST_ITEM}\n"
    CURRENT_LINE=$((CURRENT_LINE + 1))
done <<< "$WIFI_CLEAN"

FULL_LIST=$(echo -e "$FULL_LIST" | sed '/^$/d')

# Launch Rofi (highlighting the active network if any)
if [ $ACTIVE_INDEX -ge 0 ]; then
    CHOSEN_NETWORK=$(echo -e "$FULL_LIST" | rofi -dmenu -i -p "  Network" -theme ~/.config/rofi/network-menu.rasi -a "$ACTIVE_INDEX")
else
    CHOSEN_NETWORK=$(echo -e "$FULL_LIST" | rofi -dmenu -i -p "  Network" -theme ~/.config/rofi/network-menu.rasi)
fi

[ -z "$CHOSEN_NETWORK" ] && exit 0

# --- Selection Logic ---

if [[ "$CHOSEN_NETWORK" == *"$ICON_SCAN"* ]]; then
    nmcli dev wifi rescan
    exec "$0"
fi

if [[ "$CHOSEN_NETWORK" == *"$ICON_ETH"* ]]; then
    exit 0
fi

# Disconnect current network
if [[ "$CHOSEN_NETWORK" == *"$ICON_CHECK"* ]]; then
    WIFI_IFACE=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi" {print $1}' | head -n 1)
    nmcli dev disconnect "$WIFI_IFACE" >/dev/null 2>&1
    exit 0
fi

# Extract clean SSID
TARGET_SSID=$(echo "$CHOSEN_NETWORK" | sed -e "s/^ *//g" -e "s/^$ICON_WIFI //" -e "s/^$ICON_CHECK //" -e "s/ $ICON_LOCK$//" -e "s/ $ICON_UNLOCK$//")

if nmcli -t -f NAME connection show | grep -Fxq "$TARGET_SSID"; then
    # Known network
    nmcli connection up "$TARGET_SSID" >/dev/null 2>&1
else
    # New network, check for password based on lock icon
    if [[ "$CHOSEN_NETWORK" == *"$ICON_LOCK"* ]]; then
        # --- FIX: Agregamos 'inputbar { orientation: vertical; }' para apilar título y caja de texto ---
        PASSWORD=$(echo "" | rofi -dmenu -p " Password for $TARGET_SSID" -theme ~/.config/rofi/network-menu.rasi -password -theme-str 'listview {enabled: false;} inputbar {orientation: vertical;}')
        if [ -n "$PASSWORD" ]; then
            nmcli dev wifi connect "$TARGET_SSID" password "$PASSWORD" >/dev/null 2>&1
        fi
    else
        # Public network
        nmcli dev wifi connect "$TARGET_SSID" >/dev/null 2>&1
    fi
fi
