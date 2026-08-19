#!/bin/bash

# Rofi visual overrides
ROFI_OVERRIDES="window {location: northeast; anchor: northeast; y-offset: 45px; x-offset: -15px; width: 350px;} listview {lines: 6;}"

# Background rescan to update cache silently
nmcli dev wifi rescan >/dev/null 2>&1 &

# Get active Ethernet
ETH_CONNS=$(nmcli -t -f NAME,TYPE con show --active | awk -F: '/ethernet/ {print "[Ethernet] " $1}')

# Get Wi-Fi list from cache
WIFI_RAW=$(nmcli -t -f IN-USE,SSID dev wifi list --rescan no)

ACTIVE_SSID=$(echo "$WIFI_RAW" | grep '^\*' | cut -d: -f2 | head -n 1)

if [ -n "$ACTIVE_SSID" ]; then
    # Exclude active network to prevent duplicates
    WIFI_LIST=$(echo "$WIFI_RAW" | grep -v '^\*' | cut -d: -f2 | grep -v '^\s*$' | sort -u)
    WIFI_LIST="[Connected] $ACTIVE_SSID\n$WIFI_LIST"
else
    WIFI_LIST=$(echo "$WIFI_RAW" | cut -d: -f2 | grep -v '^\s*$' | sort -u)
fi

if [ -n "$ETH_CONNS" ]; then
    FULL_LIST="$ETH_CONNS\n$WIFI_LIST"
else
    FULL_LIST="$WIFI_LIST"
fi

CHOSEN_NETWORK=$(echo -e "$FULL_LIST" | rofi -dmenu -i -p "  Network" -theme-str "$ROFI_OVERRIDES")

if [ -z "$CHOSEN_NETWORK" ]; then
    exit 0
fi

if [[ "$CHOSEN_NETWORK" == \[Ethernet\]* ]]; then
    CLEAN_ETH_NAME="${CHOSEN_NETWORK#[Ethernet] }"
    notify-send "Network" "Ethernet is already active: $CLEAN_ETH_NAME"
    exit 0
fi

if [[ "$CHOSEN_NETWORK" == \[Connected\]* ]]; then
    CLEAN_WIFI_NAME="${CHOSEN_NETWORK#[Connected] }"
    notify-send "Wi-Fi" "Disconnecting from $CLEAN_WIFI_NAME..."
    
    WIFI_IFACE=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi" {print $1}' | head -n 1)
    
    if nmcli dev disconnect "$WIFI_IFACE" >/dev/null 2>&1; then
        notify-send "Wi-Fi" "Disconnected from $CLEAN_WIFI_NAME"
    else
        notify-send "Wi-Fi" "Failed to disconnect"
    fi
    exit 0
fi

if nmcli -t -f NAME connection show | grep -Fxq "$CHOSEN_NETWORK"; then
    notify-send "Wi-Fi" "Connecting to $CHOSEN_NETWORK..."
    if nmcli connection up "$CHOSEN_NETWORK" >/dev/null 2>&1; then
        notify-send "Wi-Fi" "Connected to $CHOSEN_NETWORK"
    else
        notify-send "Wi-Fi" "Failed to connect"
    fi
else
    PASSWORD=$(rofi -dmenu -p " Password for $CHOSEN_NETWORK" -theme-str "$ROFI_OVERRIDES" -password)
    
    if [ -n "$PASSWORD" ]; then
        notify-send "Wi-Fi" "Connecting to $CHOSEN_NETWORK..."
        if nmcli dev wifi connect "$CHOSEN_NETWORK" password "$PASSWORD" >/dev/null 2>&1; then
            notify-send "Wi-Fi" "Connected to $CHOSEN_NETWORK"
        else
            notify-send "Wi-Fi" "Incorrect password or connection failed"
        fi
    fi
fi
