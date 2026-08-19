#!/bin/bash

# Rofi visual overrides
ROFI_OVERRIDES="window {location: northeast; anchor: northeast; y-offset: 45px; x-offset: -15px; width: 350px;} listview {lines: 6;}"

notify-send "Network" "Scanning networks..." -t 2000
# Hide errors if rescan is called too frequently
nmcli dev wifi rescan >/dev/null 2>&1 || true

# 1. Get active Ethernet connections
ETH_CONNS=$(nmcli -t -f NAME,TYPE con show --active | awk -F: '/ethernet/ {print "[Ethernet] " $1}')

# 2. Get active Wi-Fi SSID
ACTIVE_SSID=$(nmcli -t -f IN-USE,SSID dev wifi | awk -F: '/^\*/ {print $2}' | head -n 1)

# 3. Get all other Wi-Fi networks (excluding the active one to avoid duplicates)
if [ -n "$ACTIVE_SSID" ]; then
    WIFI_LIST=$(nmcli -t -f SSID dev wifi | grep -v '^\s*$' | grep -vxF "$ACTIVE_SSID" | sort -u)
    # Add the active one at the top with a tag
    WIFI_LIST="[Connected] $ACTIVE_SSID\n$WIFI_LIST"
else
    WIFI_LIST=$(nmcli -t -f SSID dev wifi | grep -v '^\s*$' | sort -u)
fi

# 4. Combine Ethernet and Wi-Fi lists
if [ -n "$ETH_CONNS" ]; then
    FULL_LIST="$ETH_CONNS\n$WIFI_LIST"
else
    FULL_LIST="$WIFI_LIST"
fi

# 5. Display menu in Rofi
CHOSEN_NETWORK=$(echo -e "$FULL_LIST" | rofi -dmenu -i -p "  Network" -theme-str "$ROFI_OVERRIDES")

# Exit if no network is selected
if [ -z "$CHOSEN_NETWORK" ]; then
    exit 0
fi

# --- LOGIC HANDLING ---

# Handle Ethernet selection
if [[ "$CHOSEN_NETWORK" == \[Ethernet\]* ]]; then
    CLEAN_ETH_NAME="${CHOSEN_NETWORK#[Ethernet] }"
    notify-send "Network" "Ethernet is already active: $CLEAN_ETH_NAME"
    exit 0
fi

# Handle Wi-Fi DISCONNECT (If user clicks the currently connected network)
if [[ "$CHOSEN_NETWORK" == \[Connected\]* ]]; then
    CLEAN_WIFI_NAME="${CHOSEN_NETWORK#[Connected] }"
    notify-send "Wi-Fi" "Disconnecting from $CLEAN_WIFI_NAME..."
    
    # Get the active Wi-Fi interface (usually wlan0)
    WIFI_IFACE=$(nmcli -t -f DEVICE,TYPE dev | awk -F: '$2=="wifi" {print $1}' | head -n 1)
    
    # Disconnect the interface directly (100% reliable regardless of connection name)
    if nmcli dev disconnect "$WIFI_IFACE" >/dev/null 2>&1; then
        notify-send "Wi-Fi" "Disconnected from $CLEAN_WIFI_NAME"
    else
        notify-send "Wi-Fi" "Failed to disconnect"
    fi
    exit 0
fi

# Handle Wi-Fi CONNECT (New or saved networks)
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
