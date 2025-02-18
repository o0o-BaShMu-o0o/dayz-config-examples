#!/bin/bash

# The beginning of a Linux DayZ Server startup script

# Color ANSI escape codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color (reset)

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

echo -e "${BLUE}*******************************************${NC}"
echo -e "${BLUE}**${NC} DayZ Server Script 0.1 Beta             "
echo -e "${BLUE}*******************************************${NC}"
echo " "

# Debug running script as user
echo -e "${YELLOW}Script is running as user: $(whoami)${NC}"
echo ""
echo -e "${BLUE}*******************************************${NC}"
echo " "

echo -e "${YELLOW}Get latest server build ID from steam & installed server build ID.${NC}"
echo " "
# Get the latest build ID from Steam
LATEST_BUILD_ID=$($STEAMCMD_PATH +login anonymous +app_info_print "$DAYZ_SERVER_APP_ID" +quit | grep '"buildid"' | head -n 1 | awk '{print $2}' | tr -d '"')

# Get the installed build ID
INSTALLED_BUILD_ID=$(grep -Po '"buildid"\s+"\K[0-9]+' "$SERVER_DIR/steamapps/appmanifest_$DAYZ_SERVER_APP_ID.acf")

echo "Check if both build IDs exist."
# Check if both build IDs exist
if [ -z "$LATEST_BUILD_ID" ]; then
    echo "Error: Could not retrieve latest build ID from Steam."
    exit 1
fi

if [ -z "$INSTALLED_BUILD_ID" ]; then
    echo "Installed build ID not found. Assuming update is needed."
    NEEDS_UPDATE=1
else
    echo "Installed: $INSTALLED_BUILD_ID | Latest: $LATEST_BUILD_ID"
    if [ "$LATEST_BUILD_ID" != "$INSTALLED_BUILD_ID" ]; then
        NEEDS_UPDATE=1
    else
        NEEDS_UPDATE=0
    fi
fi

# If an update is needed, perform the update
if [ "$NEEDS_UPDATE" -eq 1 ]; then
    echo "Update available! Updating server."
    $STEAMCMD_PATH +force_install_dir "$DAYZ_SERVER_PATH" +login anonymous +app_update "$DAYZ_SERVER_APP_ID" validate +quit
    echo "Update complete."
else
    echo "No update needed."
fi

echo ""
echo -e "${BLUE}*******************************************${NC}"
echo " "

echo -e "${YELLOW}Generate SteamCMD script for mod updates.${NC}"
echo ""
# Ensure the modlist file exists
echo "Checking modlist.txt exists."
if [ ! -f "$MODLIST_FILE" ]; then
    echo "Error: modlist.txt not found!"
    exit 1
fi
echo "Found modlist.txt."

echo "Generating SteamCMD script for mod updates."
STEAMCMD_SCRIPT="$SERVER_DIR/update_mods.txt"
echo "force_install_dir $SERVER_DIR" >> "$STEAMCMD_SCRIPT"
echo "login $STEAM_USERNAME" > "$STEAMCMD_SCRIPT"

MODS=""

# Read modlist and add each mod to the SteamCMD script
echo "Read modlist.txt and add each mod to the SteamCMD script"

while IFS= read -r MOD_ID || [[ -n "$MOD_ID" ]]; do
    MOD_ID=$(echo "$MOD_ID" | tr -d '\r')  # Remove any Windows-style CR characters
    if [[ -z "$MOD_ID" || "$MOD_ID" =~ ^# ]]; then
        continue  # Skip empty lines and comments
    fi
    echo "workshop_download_item $DAYZ_APP_ID $MOD_ID" >> "$STEAMCMD_SCRIPT"
    echo "Added mod to SteamCMD script: $MOD_ID"
done < "$MODLIST_FILE"

echo "quit" >> "$STEAMCMD_SCRIPT"

echo " "

# Show what is being passed to SteamCMD
echo -e "${YELLOW}SteamCMD script content:${NC}"
echo " "
cat "$STEAMCMD_SCRIPT"

echo " "
echo -e "${BLUE}*******************************************${NC}"
echo " "

# Run SteamCMD once to install/update all mods
echo -e "${YELLOW}Run steamcmd once to install/update all mods.${NC}"
echo " "
$STEAMCMD_PATH +runscript "$STEAMCMD_SCRIPT"
echo " "
echo -e "${BLUE}*******************************************${NC}"
echo " "
echo -e "${YELLOW}Processing downloaded mods.${NC}"
echo " "
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

echo " "
echo -e "${BLUE}*******************************************${NC}"
echo " "
echo -e "${YELLOW}Starting DayZ Server.${NC}"
echo " "
cd "$SERVER_DIR" || exit

echo "Command: $SERVER_EXECUTABLE -config=$CONFIG_FILE -port=$GAME_PORT -mod=$MODS -BEpath=$BATTLEYE_PATH -profiles=$PROFILES_PATH -dologs -adminlog -netlog -freezecheck"
echo " "

# Run the DayZ server with the correct mods
"$SERVER_EXECUTABLE" "-config=$CONFIG_FILE" "-port=$GAME_PORT" "-mod=$MODS" "-BEpath=$BATTLEYE_PATH" "-profiles=$PROFILES_PATH" -dologs -adminlog -netlog -freezecheck
