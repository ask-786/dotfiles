#!/bin/bash

# Directory to save downloaded images
DOWNLOAD_DIR="$HOME/Pictures/Wallpapers/Unsplash"

# Maximum number of wallpapers to keep
MAX_WALLPAPERS=5

# Check if there is an existing image in the folder
EXISTING_IMAGE=$(ls -1 "$DOWNLOAD_DIR" | grep "_wallpaper" | head -n 1)

if [ -n "$EXISTING_IMAGE" ]; then
    # Set the existing image as wallpaper using swaymsg
    swaymsg output '*' bg "$DOWNLOAD_DIR/$EXISTING_IMAGE" fill
else
    echo "No existing wallpapers found."
fi

while true; do
    # Set the URL of the website containing random images
    IMAGE_URL=$( \
        curl "https://source.unsplash.com/random/1920x1080/?tech,laptop,gadgets,nature,street,nature,cars,black,dark,bikes,motorcycles,formulaone,formula1,motogp" \
        | grep -o 'href="[^"]*"' \
        | cut -d'"' -f2 \
    )

    # Download a random image
    IMAGE_FILE="$DOWNLOAD_DIR/$(date +%s)_wallpaper.jpg"
    curl -o "$IMAGE_FILE" "$IMAGE_URL"

    # Set the downloaded image as wallpaper using swaymsg
    swaymsg output '*' bg "$IMAGE_FILE" fill

    # Delete the oldest wallpaper if the number of wallpapers exceeds the limit
    WALLPAPERS_COUNT=$(ls -1 "$DOWNLOAD_DIR" | grep "_wallpaper.jpg" | wc -l)
    if [ "$WALLPAPERS_COUNT" -gt "$MAX_WALLPAPERS" ]; then
        OLDEST_WALLPAPER=$(ls -1t "$DOWNLOAD_DIR" | grep "_wallpaper.jpg" | tail -n 1)
        rm "$DOWNLOAD_DIR/$OLDEST_WALLPAPER"
    fi

    # Sleep for 15 minutes before downloading and setting a new wallpaper
    sleep 900  # 900 seconds = 15 minutes
done
