#!/bin/bash
set -euo pipefail

# ScopeOS Theme Downloader
# Fetches themes for MacOS (WhiteSur), Windows 10/11, and others.

# Check for root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

echo "Downloading ScopeOS Themes..."

# Directories
THEMES_DIR="/usr/share/themes"
ICONS_DIR="/usr/share/icons"
BACKGROUNDS_DIR="/usr/share/backgrounds"

# Ensure directories exist
mkdir -p "$THEMES_DIR" "$ICONS_DIR" "$BACKGROUNDS_DIR"

# Helper to clone and install from git
install_git_theme() {
    local REPO_URL="$1"
    local DEST_NAME="$2"
    local INSTALL_CMD="$3"

    echo "Processing $DEST_NAME..."
    local TEMP_DIR
    TEMP_DIR=$(mktemp -d)

    # Ensure cleanup happens even if something fails
    # Trap needs to be careful about not overwriting previous traps if nested,
    # but here we are linear.
    trap 'rm -rf "$TEMP_DIR"' RETURN

    if git clone --depth 1 "$REPO_URL" "$TEMP_DIR"; then
        pushd "$TEMP_DIR" > /dev/null
        # Execute the command in the temporary directory
        echo "Installing $DEST_NAME..."
        if bash -c "$INSTALL_CMD"; then
             echo "Successfully installed $DEST_NAME."
        else
             echo "Error: Installation command failed for $DEST_NAME." >&2
             popd > /dev/null
             return 1
        fi
        popd > /dev/null
    else
        echo "Error: Failed to clone $REPO_URL" >&2
        rm -rf "$TEMP_DIR"
        return 1
    fi
    rm -rf "$TEMP_DIR"
}

# Wrapper to run install_git_theme and log output to a temp file for parallel execution
run_install_bg() {
    local logfile
    logfile=$(mktemp)
    if install_git_theme "$1" "$2" "$3" > "$logfile" 2>&1; then
        cat "$logfile"
        rm "$logfile"
        return 0
    else
        cat "$logfile" >&2
        rm "$logfile"
        return 1
    fi
}

echo "Starting theme downloads in parallel..."
pids=""

# 1. MacOS Theme (WhiteSur)
run_install_bg "https://github.com/vinceliuice/WhiteSur-gtk-theme.git" "WhiteSur" "./install.sh -d \"$THEMES_DIR\" -t all -N stable" &
pids="$pids $!"

run_install_bg "https://github.com/vinceliuice/WhiteSur-icon-theme.git" "WhiteSur-Icons" "./install.sh -d \"$ICONS_DIR\"" &
pids="$pids $!"

# 2. Windows 10 Theme
echo "Installing Windows 10 Theme..."
# Clean destination first to avoid errors
install_git_theme "https://github.com/B00merang-Project/Windows-10.git" "Windows-10" "rm -rf \"$THEMES_DIR/Windows-10\" && mkdir -p \"$THEMES_DIR/Windows-10\" && mv * \"$THEMES_DIR/Windows-10/\""
install_git_theme "https://github.com/B00merang-Project/Windows-10-Icons.git" "Windows-10-Icons" "rm -rf \"$ICONS_DIR/Windows-10\" && mkdir -p \"$ICONS_DIR/Windows-10\" && mv * \"$ICONS_DIR/Windows-10/\""

# 3. Windows 11 Theme
run_install_bg "https://github.com/vinceliuice/Fluent-gtk-theme.git" "Fluent-gtk-theme" "./install.sh -d \"$THEMES_DIR\"" &
pids="$pids $!"

run_install_bg "https://github.com/vinceliuice/Fluent-icon-theme.git" "Fluent-icon-theme" "./install.sh -d \"$ICONS_DIR\"" &
pids="$pids $!"

# 4. Backgrounds
download_file() {
    local URL="$1"
    local DEST="$2"
    if curl -fsSL -o "$DEST" "$URL"; then
        echo "Downloaded $DEST"
    else
        echo "Failed to download $URL" >&2
        return 1
    fi
}

# Run downloads in parallel
pids=""
download_file "https://raw.githubusercontent.com/vinceliuice/WhiteSur-wallpapers/main/4k/Monterey-light.jpg" "$BACKGROUNDS_DIR/macos-wallpaper.jpg" &
pids="$pids $!"
# Changed URL to a more direct/reliable source if possible, or kept same but parallelized
download_file "https://wallpapercave.com/download/windows-10-hero-wallpapers-wp4439149" "$BACKGROUNDS_DIR/win10-wallpaper.jpg" &
pids="$pids $!"
download_file "https://4kwallpapers.com/images/wallpapers/windows-11-blue-stock-white-background-light-official-3840x2160-5616.jpg" "$BACKGROUNDS_DIR/win11-wallpaper.jpg" &
pids="$pids $!"

# Wait for all downloads
# Capture exit codes from background jobs
failed=0
for pid in $pids; do
    if ! wait "$pid"; then
        failed=1
    fi
done

if [ "$failed" -eq 1 ]; then
    echo "Warning: Some wallpapers failed to download."
fi

# Verify downloads
for f in "$BACKGROUNDS_DIR/macos-wallpaper.jpg" "$BACKGROUNDS_DIR/win10-wallpaper.jpg" "$BACKGROUNDS_DIR/win11-wallpaper.jpg"; do
    if [ ! -s "$f" ]; then
        echo "Warning: Wallpaper $f is empty or missing."
    fi
done

# Fallback for Ubuntu wallpaper
if [ -f "/usr/share/backgrounds/warty-final-ubuntu.png" ]; then
    cp "/usr/share/backgrounds/warty-final-ubuntu.png" "$BACKGROUNDS_DIR/ubuntu-wallpaper.jpg"
fi
