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

    # Clean up temp dir on return (signal or function exit)
    # Using RETURN trap in bash functions works well.
    trap 'rm -rf "$TEMP_DIR"' RETURN

    if git clone --depth 1 "$REPO_URL" "$TEMP_DIR"; then
        pushd "$TEMP_DIR" > /dev/null

        # Security check: If INSTALL_CMD involves a script file, ensure it exists and is executable
        # This is a heuristic, as INSTALL_CMD might be complex.
        local script_name=$(echo "$INSTALL_CMD" | awk '{print $1}')
        if [[ "$script_name" == "./"* ]]; then
             if [ -f "$script_name" ]; then
                 chmod +x "$script_name"
             else
                 echo "Warning: Script $script_name not found in repo."
             fi
        fi

        echo "Executing installation for $DEST_NAME..."
        if bash -c "$INSTALL_CMD"; then
            echo "Successfully installed $DEST_NAME."
        else
             echo "Error: Installation command failed for $DEST_NAME" >&2
             popd > /dev/null
             return 1
        fi
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
# Windows 10 theme doesn't have an install script, we move files manually.
install_git_theme "https://github.com/B00merang-Project/Windows-10.git" "Windows-10" "rm -rf \"$THEMES_DIR/Windows-10\" && mkdir -p \"$THEMES_DIR/Windows-10\" && cp -r * \"$THEMES_DIR/Windows-10/\""
install_git_theme "https://github.com/B00merang-Project/Windows-10-Icons.git" "Windows-10-Icons" "rm -rf \"$ICONS_DIR/Windows-10\" && mkdir -p \"$ICONS_DIR/Windows-10\" && cp -r * \"$ICONS_DIR/Windows-10/\""

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
    # Use -f to fail on 404/server errors, -L to follow redirects
    if curl -fsSL -o "$DEST" "$URL"; then
        echo "Downloaded $DEST"
    else
        echo "Failed to download $URL" >&2
        return 1
    fi
}

pids=""
download_file "https://raw.githubusercontent.com/vinceliuice/WhiteSur-wallpapers/main/4k/Monterey-light.jpg" "$BACKGROUNDS_DIR/macos-wallpaper.jpg" &
pids="$pids $!"
# Changed URL to a more direct/reliable source if possible, or kept same but parallelized
download_file "https://wallpapercave.com/download/windows-10-hero-wallpapers-wp4439149" "$BACKGROUNDS_DIR/win10-wallpaper.jpg" &
pids="$pids $!"
download_file "https://4kwallpapers.com/images/wallpapers/windows-11-blue-stock-white-background-light-official-3840x2160-5616.jpg" "$BACKGROUNDS_DIR/win11-wallpaper.jpg" &
pids="$pids $!"

# Wait for all downloads
# Capture exit codes from background jobs?
# wait only waits. If one fails, we might miss it, but for wallpapers it's non-critical.
wait $pids

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

echo "Theme installation complete."
