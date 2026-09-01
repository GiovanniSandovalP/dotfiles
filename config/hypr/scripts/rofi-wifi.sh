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

# --- ROFI COMMAND EXECUTION ---
# Added alt+x for manual disconnect
ROFI_CMD="rofi -dmenu -i -p \"  Network\" -theme ~/.config/rofi/network-menu.rasi \
-mesg \"󰌌 [Enter] Conn/Disc  |  [Alt+D] Forget  |  [Alt+X] Disconnect  |  [Alt+I] Info\" \
-kb-custom-1 alt+d -kb-custom-2 alt+i -kb-custom-3 alt+x"

if [ $ACTIVE_INDEX -ge 0 ]; then
    CHOSEN_NETWORK=$(echo -e "$FULL_LIST" | eval $ROFI_CMD -a "$ACTIVE_INDEX")
else
    CHOSEN_NETWORK=$(echo -e "$FULL_LIST" | eval $ROFI_CMD)
fi

ROFI_EXIT=$?

# If user pressed Escape (exit code 1) or nothing was selected
if [ $ROFI_EXIT -eq 1 ] || [ -z "$CHOSEN_NETWORK" ]; then
    exit 0
fi

# Extract clean SSID immediately
TARGET_SSID=$(echo "$CHOSEN_NETWORK" | sed -e "s/^ *//g" -e "s/^$ICON_WIFI //" -e "s/^$ICON_CHECK //" -e "s/ $ICON_LOCK$//" -e "s/ $ICON_UNLOCK$//")

# --- CUSTOM KEYBINDING LOGIC ---

# Action: Forget Network (Alt + D)
if [ $ROFI_EXIT -eq 10 ]; then
    if nmcli -t -f NAME connection show | grep -Fxq "$TARGET_SSID"; then
        nmcli connection delete "$TARGET_SSID" >/dev/null 2>&1
    fi
    exec "$0" # Reload script
fi

# Action: Show Info (Alt + I)
if [ $ROFI_EXIT -eq 11 ]; then
    INFO_IP=$(nmcli -g IP4.ADDRESS connection show "$TARGET_SSID" 2>/dev/null | head -n 1)
    [ -z "$INFO_IP" ] && INFO_IP="Not active or no IP"
    INFO_GW=$(nmcli -g IP4.GATEWAY connection show "$TARGET_SSID" 2>/dev/null | head -n 1)
    [ -z "$INFO_GW" ] && INFO_GW="Not active"
    
    # Use dmenu instead of rofi -e to ensure compatibility with your theme
    echo -e "SSID: $TARGET_SSID\nIP Address: $INFO_IP\nGateway: $INFO_GW" | rofi -dmenu -p " Info" -theme ~/.config/rofi/network-menu.rasi
    exec "$0" # Reload script after viewing info
fi

# Action: Explicit Disconnect (Alt + X)
if [ $ROFI_EXIT -eq 12 ]; then
    WIFI_IFACE=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi" {print $1}' | head -n 1)
    nmcli dev disconnect "$WIFI_IFACE" >/dev/null 2>&1
    exec "$0" # Reload script
fi

# --- NORMAL SELECTION LOGIC (Enter / Click - Exit Code 0) ---

if [[ "$CHOSEN_NETWORK" == *"$ICON_SCAN"* ]]; then
    nmcli dev wifi rescan
    exec "$0"
fi

if [[ "$CHOSEN_NETWORK" == *"$ICON_ETH"* ]]; then
    exit 0
fi

# Disconnect current network via Enter key
if [[ "$CHOSEN_NETWORK" == *"$ICON_CHECK"* ]]; then
    WIFI_IFACE=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi" {print $1}' | head -n 1)
    nmcli dev disconnect "$WIFI_IFACE" >/dev/null 2>&1
    exit 0
fi

# Connect Logic
if nmcli -t -f NAME connection show | grep -Fxq "$TARGET_SSID"; then
    nmcli connection up "$TARGET_SSID" >/dev/null 2>&1
else
    if [[ "$CHOSEN_NETWORK" == *"$ICON_LOCK"* ]]; then
        PASSWORD=$(echo "" | rofi -dmenu -p " Password for $TARGET_SSID" -theme ~/.config/rofi/network-menu.rasi -password -theme-str 'listview {enabled: false;} inputbar {orientation: vertical;}')
        if [ -n "$PASSWORD" ]; then
            nmcli dev wifi connect "$TARGET_SSID" password "$PASSWORD" >/dev/null 2>&1
        fi
    else
        nmcli dev wifi connect "$TARGET_SSID" >/dev/null 2>&1
    fi
fi
