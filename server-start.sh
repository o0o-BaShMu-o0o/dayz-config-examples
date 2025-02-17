#!/bin/bash

# The beginning of a Linux DayZ Server startup script

# Debug running script as user
#echo "Script is running as user: $(whoami)"

# Configuration
STEAMCMD_PATH="$HOME/DayZ/DayZServers/Steamcmd/steamcmd.sh"
STEAM_USERNAME="your_steam_username"
SERVER_DIR="$HOME/DayZ/DayZServers/DayZServerAlpha"
MODLIST_FILE="$SERVER_DIR/server_manager/modlist.txt"
DAYZ_APP_ID="221100"
DAYZ_SERVER_APP_ID="223350"
WORKSHOP_DIR="$HOME/DayZ/DayZServers/DayZServerAlpha/steamapps/workshop/content/$DAYZ_APP_ID"
KEYS_DIR="$SERVER_DIR/keys"
CONFIG_FILE="$SERVER_DIR/serverDZ.cfg"
GAME_PORT="2302"
BATTLEYE_PATH="$SERVER_DIR/battleye"
PROFILES_PATH="$SERVER_DIR/profiles"
SERVER_EXECUTABLE="$SERVER_DIR/DayZServer"

# Ensure the modlist file exists
if [ ! -f "$MODLIST_FILE" ]; then
    echo "Error: modlist.txt not found!"
    exit 1
fi

#echo "Updating DayZ server..."
#$STEAMCMD_PATH +force_install_dir "$SERVER_DIR" +login "$STEAM_USERNAME" +app_update "$DAYZ_SERVER_APP_ID" validate +quit

echo "Generating SteamCMD script for mod updates..."
STEAMCMD_SCRIPT="$SERVER_DIR/update_mods.txt"
echo "login $STEAM_USERNAME" > "$STEAMCMD_SCRIPT"
echo "force_install_dir $SERVER_DIR" >> "$STEAMCMD_SCRIPT"

MODS=""

# Read modlist and add each mod to the SteamCMD script
while IFS= read -r MOD_ID || [[ -n "$MOD_ID" ]]; do
    MOD_ID=$(echo "$MOD_ID" | tr -d '\r')  # Remove any Windows-style CR characters
    if [[ -z "$MOD_ID" || "$MOD_ID" =~ ^# ]]; then
        continue  # Skip empty lines and comments
    fi
    echo "workshop_download_item $DAYZ_APP_ID $MOD_ID" >> "$STEAMCMD_SCRIPT"
    echo "Added mod to SteamCMD script: $MOD_ID"
done < "$MODLIST_FILE"

echo "quit" >> "$STEAMCMD_SCRIPT"

# Debug: Show what is being passed to SteamCMD
echo "SteamCMD script content:"
cat "$STEAMCMD_SCRIPT"

# Run SteamCMD once to install/update all mods
$STEAMCMD_PATH +runscript "$STEAMCMD_SCRIPT"

echo "Processing downloaded mods..."
# Loop through mod list
while IFS= read -r MOD_ID || [[ -n "$MOD_ID" ]]; do
    MOD_ID=$(echo "$MOD_ID" | tr -d '\r')  # Remove any Windows-style CR characters
    if [[ -z "$MOD_ID" || "$MOD_ID" =~ ^# ]]; then
        continue
    fi

    # Extract base mod ID (without suffix)
    BASE_MOD_ID=$(echo "$MOD_ID" | sed 's/ @.*//')  # Remove suffix after '@'
    
    # Extract the suffix (if any)
    MOD_SUFFIX=$(echo "$MOD_ID" | sed 's/^[^ ]* //')  # Get the part after the first space (suffix)

    # Check if the mod exists in the workshop directory
    if [ -d "$WORKSHOP_DIR/$BASE_MOD_ID" ]; then
        # If there is a suffix, link it using the suffix name
        if [[ -n "$MOD_SUFFIX" ]]; then
            # Create symlink with the suffix only (e.g., @CF)
            ln -sT "$WORKSHOP_DIR/$BASE_MOD_ID" "$SERVER_DIR/$MOD_SUFFIX"
            echo "Linked mod: $MOD_SUFFIX -> $SERVER_DIR/$MOD_SUFFIX"
        else
            # If no suffix, link the base mod ID normally
            ln -sT "$WORKSHOP_DIR/$BASE_MOD_ID" "$SERVER_DIR/$BASE_MOD_ID"
            echo "Linked mod: $BASE_MOD_ID -> $SERVER_DIR/$BASE_MOD_ID"
        fi
    else
        echo "Warning: Mod $MOD_ID not found in workshop directory!"
    fi

    # Copy mod keys (if any)
    if [ -d "$WORKSHOP_DIR/$BASE_MOD_ID/keys" ]; then
        for key in "$WORKSHOP_DIR/$BASE_MOD_ID/keys/"*; do
            # Check if the key already exists to avoid overwriting
            if [ -e "$KEYS_DIR/$(basename "$key")" ]; then
                echo "Key $(basename "$key") already exists. Skipping."
            else
                ln -s "$key" "$KEYS_DIR/"
                echo "Copied keys for mod: $MOD_ID"
            fi
        done
    fi

    # Append mod suffix to the mod list for server launch
    if [[ -n "$MOD_SUFFIX" ]]; then
        MODS="$MODS;$MOD_SUFFIX"
    fi
done < "$MODLIST_FILE"

# Remove leading semicolon
MODS="${MODS:1}"

echo "Starting DayZ Server..."
cd "$SERVER_DIR" || exit

echo "$SERVER_EXECUTABLE" "-config=$CONFIG_FILE" "-port=$GAME_PORT" "-mod=$MODS" "-BEpath=$BATTLEYE_PATH" "-profiles=$PROFILES_PATH" -dologs -adminlog -netlog -freezecheck

# Run the DayZ server with the correct mods
"$SERVER_EXECUTABLE" "-config=$CONFIG_FILE" "-port=$GAME_PORT" "-mod=$MODS" "-BEpath=$BATTLEYE_PATH" "-profiles=$PROFILES_PATH" -dologs -adminlog -netlog -freezecheck
