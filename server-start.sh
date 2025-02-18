#!/bin/bash

# The beginning of a Linux DayZ Server startup script

# Color ANSI escape codes for colorized output in terminal
RED='\033[0;31m'    # Red color for error messages
GREEN='\033[0;32m'  # Green color for success messages
YELLOW='\033[1;33m' # Yellow color for warnings and informational messages
BLUE='\033[0;34m'   # Blue color for headers and section titles
NC='\033[0m'        # No Color (reset to default terminal color)

# Configuration Section: Paths and settings for SteamCMD, server files, and mods
STEAMCMD_PATH="$HOME/DayZ/DayZServers/Steamcmd/steamcmd.sh"       # Path to SteamCMD script
STEAM_USERNAME="your_steam_username"                              # Your Steam username (used for logging into Steam)
SERVER_DIR="$HOME/DayZ/DayZServers/DayZServerAlpha"               # Path to the DayZ server directory
MODLIST_FILE="$SERVER_DIR/server_manager/modlist.txt"             # File containing list of mods to update
DAYZ_APP_ID="221100"                                             # DayZ application ID (used for SteamCMD commands)
DAYZ_SERVER_APP_ID="223350"                                       # DayZ server application ID (used for SteamCMD commands)
WORKSHOP_DIR="$HOME/DayZ/DayZServers/DayZServerAlpha/steamapps/workshop/content/$DAYZ_APP_ID"  # Directory for Steam workshop content
KEYS_DIR="$SERVER_DIR/keys"                                       # Directory for mod keys
CONFIG_FILE="$SERVER_DIR/serverDZ.cfg"                           # Configuration file for the server
GAME_PORT="2302"                                                 # Game port for the server
BATTLEYE_PATH="$SERVER_DIR/battleye"                             # Path to Battleye directory
PROFILES_PATH="$SERVER_DIR/profiles"                             # Path to profiles directory
SERVER_EXECUTABLE="$SERVER_DIR/DayZServer"                       # Path to the DayZ server executable

# Printing header to indicate the start of the script
echo -e "${BLUE}*******************************************${NC}"
echo -e "${BLUE}**${NC} DayZ Server Script 0.1 Beta             "
echo -e "${BLUE}*******************************************${NC}"
echo " "

# Debug message showing which user is running the script
echo -e "${YELLOW}Script is running as user: $(whoami)${NC}"
echo ""
echo -e "${BLUE}*******************************************${NC}"
echo " "

# Fetch and compare the latest server build ID with the installed build ID
echo -e "${YELLOW}Get latest server build ID from steam & installed server build ID.${NC}"
echo " "
# Get the latest build ID from Steam (via SteamCMD)
LATEST_BUILD_ID=$($STEAMCMD_PATH +login anonymous +app_info_print "$DAYZ_SERVER_APP_ID" +quit | grep '"buildid"' | head -n 1 | awk '{print $2}' | tr -d '"')

# Get the installed build ID from the local manifest file
INSTALLED_BUILD_ID=$(grep -Po '"buildid"\s+"\K[0-9]+' "$SERVER_DIR/steamapps/appmanifest_$DAYZ_SERVER_APP_ID.acf")

echo "Check if both build IDs exist."
# Check if both the latest and installed build IDs are retrieved successfully
if [ -z "$LATEST_BUILD_ID" ]; then
    echo "Error: Could not retrieve latest build ID from Steam."
    exit 1
fi

if [ -z "$INSTALLED_BUILD_ID" ]; then
    echo "Installed build ID not found. Assuming update is needed."
    NEEDS_UPDATE=1
else
    echo "Installed: $INSTALLED_BUILD_ID | Latest: $LATEST_BUILD_ID"
    # If the installed build ID does not match the latest, set update flag to 1
    if [ "$LATEST_BUILD_ID" != "$INSTALLED_BUILD_ID" ]; then
        NEEDS_UPDATE=1
    else
        NEEDS_UPDATE=0
    fi
fi

# If an update is needed, perform the update using SteamCMD
if [ "$NEEDS_UPDATE" -eq 1 ]; then
    echo "Update available! Updating server."
    $STEAMCMD_PATH +force_install_dir "$DAYZ_SERVER_PATH" +login anonymous +app_update "$DAYZ_SERVER_APP_ID" validate +quit
    echo "Update complete."
else
    echo "No update needed."
fi

# Mod update section
echo ""
echo -e "${BLUE}*******************************************${NC}"
echo " "

echo -e "${YELLOW}Generate SteamCMD script for mod updates.${NC}"
echo ""
# Check if modlist.txt exists in the server directory
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

# Read the modlist file and add each mod ID to the SteamCMD update script
echo "Read modlist.txt and add each mod to the SteamCMD script"
while IFS= read -r MOD_ID || [[ -n "$MOD_ID" ]]; do
    MOD_ID=$(echo "$MOD_ID" | tr -d '\r')  # Remove any Windows-style CR characters
    if [[ -z "$MOD_ID" || "$MOD_ID" =~ ^# ]]; then
        continue  # Skip empty lines and comments in modlist
    fi
    echo "workshop_download_item $DAYZ_APP_ID $MOD_ID" >> "$STEAMCMD_SCRIPT"
    echo "Added mod to SteamCMD script: $MOD_ID"
done < "$MODLIST_FILE"

echo "quit" >> "$STEAMCMD_SCRIPT"

# Show the generated SteamCMD script content
echo " "
echo -e "${YELLOW}SteamCMD script content:${NC}"
echo " "
cat "$STEAMCMD_SCRIPT"

echo " "
echo -e "${BLUE}*******************************************${NC}"
echo " "

# Run SteamCMD script to install/update mods
echo -e "${YELLOW}Run steamcmd once to install/update all mods.${NC}"
echo " "
$STEAMCMD_PATH +runscript "$STEAMCMD_SCRIPT"
echo " "
echo -e "${BLUE}*******************************************${NC}"
echo " "
echo -e "${YELLOW}Processing downloaded mods.${NC}"
echo " "
# Loop through the mod list to process and link the mods in the server directory
while IFS= read -r MOD_ID || [[ -n "$MOD_ID" ]]; do
    MOD_ID=$(echo "$MOD_ID" | tr -d '\r')  # Remove any Windows-style CR characters
    if [[ -z "$MOD_ID" || "$MOD_ID" =~ ^# ]]; then
        continue
    fi

    # Extract base mod ID and suffix from mod ID (e.g., @CF for @CommunityOnlineTools)
    BASE_MOD_ID=$(echo "$MOD_ID" | sed 's/ @.*//')  # Remove suffix
    MOD_SUFFIX=$(echo "$MOD_ID" | sed 's/^[^ ]* //')  # Get suffix if exists

    # Check if the mod exists in the workshop directory
    if [ -d "$WORKSHOP_DIR/$BASE_MOD_ID" ]; then
        # If there is a suffix, link it using the suffix name
        if [[ -n "$MOD_SUFFIX" ]]; then
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
            # Avoid overwriting existing keys
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

# Remove leading semicolon from MODS
MODS="${MODS:1}"

# Final section: Start the DayZ server with the specified configuration and mods
echo " "
echo -e "${BLUE}*******************************************${NC}"
echo " "
echo -e "${YELLOW}Starting DayZ Server.${NC}"
echo " "
cd "$SERVER_DIR" || exit 1

# Print the command that will be used to start the server
echo "Command: $SERVER_EXECUTABLE -config=$CONFIG_FILE -port=$GAME_PORT -mod=$MODS -BEpath=$BATTLEYE_PATH -profiles=$PROFILES_PATH -dologs -adminlog -netlog -freezecheck"
echo " "

# Run the DayZ server executable with the configured parameters
"$SERVER_EXECUTABLE" "-config=$CONFIG_FILE" "-port=$GAME_PORT" "-mod=$MODS" "-BEpath=$BATTLEYE_PATH" "-profiles=$PROFILES_PATH" "-dologs" "-adminlog" "-netlog" "-freezecheck"
