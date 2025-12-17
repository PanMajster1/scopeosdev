#!/bin/bash
set -euo pipefail

# ScopeOS Theme Downloader
# Fetches themes for MacOS (WhiteSur), Windows 10/11, and others.

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
    trap 'rm -rf "$TEMP_DIR"' RETURN

    if git clone --depth 1 "$REPO_URL" "$TEMP_DIR"; then
        pushd "$TEMP_DIR" > /dev/null
        # Execute the command in the temporary directory
        # We rely on the hardcoded INSTALL_CMD being safe.
        # Ideally, we would inspect the install script, but that's complex for automation.
        bash -c "$INSTALL_CMD"
        popd > /dev/null
    else
        echo "Error: Failed to clone $REPO_URL" >&2
        return 1
    fi
}

# 1. MacOS Theme (WhiteSur)
echo "Installing MacOS Theme (WhiteSur)..."
install_git_theme "https://github.com/vinceliuice/WhiteSur-gtk-theme.git" "WhiteSur" "./install.sh -d \"$THEMES_DIR\" -t all -N stable"
install_git_theme "https://github.com/vinceliuice/WhiteSur-icon-theme.git" "WhiteSur-Icons" "./install.sh -d \"$ICONS_DIR\""

# 2. Windows 10 Theme
echo "Installing Windows 10 Theme..."
install_git_theme "https://github.com/B00merang-Project/Windows-10.git" "Windows-10" "mkdir -p \"$THEMES_DIR/Windows-10\" && mv * \"$THEMES_DIR/Windows-10/\""
install_git_theme "https://github.com/B00merang-Project/Windows-10-Icons.git" "Windows-10-Icons" "mkdir -p \"$ICONS_DIR/Windows-10\" && mv * \"$ICONS_DIR/Windows-10/\""

# 3. Windows 11 Theme
echo "Installing Windows 11 Theme..."
install_git_theme "https://github.com/vinceliuice/Fluent-gtk-theme.git" "Fluent-gtk-theme" "./install.sh -d \"$THEMES_DIR\""
install_git_theme "https://github.com/vinceliuice/Fluent-icon-theme.git" "Fluent-icon-theme" "./install.sh -d \"$ICONS_DIR\""

# 4. Backgrounds
echo "Downloading Wallpapers..."

# Helper for downloading
download_file() {
    local URL="$1"
    local DEST="$2"
    # Use -f to fail on 404/server errors
    if curl -fsSL -o "$DEST" "$URL"; then
        echo "Downloaded $DEST"
    else
        echo "Failed to download $URL" >&2
        return 1
    fi
}

# Run downloads in parallel? For simplicity and reliability in chroot, serial is safer,
# but we can background them and wait.
pids=""
download_file "https://raw.githubusercontent.com/vinceliuice/WhiteSur-wallpapers/main/4k/Monterey-light.jpg" "$BACKGROUNDS_DIR/macos-wallpaper.jpg" &
pids="$pids $!"
download_file "https://upload.wikimedia.org/wikipedia/en/c/c2/Windows_10_Hero_Wallpaper_2020.png" "$BACKGROUNDS_DIR/win10-wallpaper.jpg" &
pids="$pids $!"
download_file "https://upload.wikimedia.org/wikipedia/commons/e/ec/Windows_11_Bloom_Wallpaper_Light.jpg" "$BACKGROUNDS_DIR/win11-wallpaper.jpg" &
pids="$pids $!"

# Wait for all downloads
wait $pids

# Fallback for Ubuntu wallpaper
if [ -f "/usr/share/backgrounds/warty-final-ubuntu.png" ]; then
    cp "/usr/share/backgrounds/warty-final-ubuntu.png" "$BACKGROUNDS_DIR/ubuntu-wallpaper.jpg"
fi

echo "Theme installation complete."
