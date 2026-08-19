#!/bin/bash

# Rofi visual overrides
ROFI_OVERRIDES="window {location: northeast; anchor: northeast; y-offset: 45px; x-offset: -15px; width: 350px;} listview {lines: 6;}"

notify-send "Network" "Scanning networks..." -t 2000
# Hide errors if rescan is called too frequently
nmcli dev wifi rescan >/dev/null 2>&1 || true

# Get active Ethernet connections
ETH_CONNS=$(nmcli -t -f NAME,TYPE con show --active | awk -F: '/ethernet/ {print "[Ethernet] " $1}')

# Get unique Wi-Fi SSIDs, excluding empty lines
WIFI_LIST=$(nmcli -t -f SSID dev wifi | grep -v '^$' | sort -u)

# Combine lists
if [ -n "$ETH_CONNS" ]; then
    FULL_LIST="$ETH_CONNS\n$WIFI_LIST"
else
    FULL_LIST="$WIFI_LIST"
fi

# Display menu
CHOSEN_NETWORK=$(echo -e "$FULL_LIST" | rofi -dmenu -i -p "  Network" -theme-str "$ROFI_OVERRIDES")

# Exit if no network is selected (e.g., user pressed Esc)
if [ -z "$CHOSEN_NETWORK" ]; then
    exit 0
fi

# Handle Ethernet selection (just notify, as it's already connected)
if [[ "$CHOSEN_NETWORK" == \[Ethernet\]* ]]; then
    CLEAN_ETH_NAME="${CHOSEN_NETWORK#[Ethernet] }"
    notify-send "Network" "Ethernet is already active: $CLEAN_ETH_NAME"
    exit 0
fi

# Handle Wi-Fi connection
# Check if the network is already a saved connection
if nmcli -t -f NAME connection show | grep -Fxq "$CHOSEN_NETWORK"; then
    notify-send "Wi-Fi" "Connecting to $CHOSEN_NETWORK..."
    if nmcli connection up "$CHOSEN_NETWORK" >/dev/null 2>&1; then
        notify-send "Wi-Fi" "Connected to $CHOSEN_NETWORK"
    else
        notify-send "Wi-Fi" "Failed to connect"
    fi
else
    # Prompt for password if it's a new network
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
