#!/bin/bash
set -e

# ScopeOS Theme Downloader
# Fetches themes for MacOS (WhiteSur), Windows 10/11, and others.

echo "Downloading ScopeOS Themes..."

# Directories
THEMES_DIR="/usr/share/themes"
ICONS_DIR="/usr/share/icons"
BACKGROUNDS_DIR="/usr/share/backgrounds"

mkdir -p "$THEMES_DIR" "$ICONS_DIR" "$BACKGROUNDS_DIR"

# Helper to clone and install from git
install_git_theme() {
    REPO_URL=$1
    DEST_NAME=$2
    INSTALL_CMD=$3

    echo "Processing $DEST_NAME..."
    TEMP_DIR=$(mktemp -d)
    git clone --depth 1 "$REPO_URL" "$TEMP_DIR"

    pushd "$TEMP_DIR"
    eval "$INSTALL_CMD"
    popd
    rm -rf "$TEMP_DIR"
}

# 1. MacOS Theme (WhiteSur)
# Using vinceliuice's WhiteSur-gtk-theme
echo "Installing MacOS Theme (WhiteSur)..."
install_git_theme "https://github.com/vinceliuice/WhiteSur-gtk-theme.git" "WhiteSur" "./install.sh -d $THEMES_DIR -t all -N stable"
install_git_theme "https://github.com/vinceliuice/WhiteSur-icon-theme.git" "WhiteSur-Icons" "./install.sh -d $ICONS_DIR"

# 2. Windows 10 Theme
echo "Installing Windows 10 Theme..."
# Using B00merang Project themes (often reliable) or others found on gnome-look
# For script stability, downloading release tarballs is often safer than scraping gnome-look.
# Assuming we use a known repo or direct link.
install_git_theme "https://github.com/B00merang-Project/Windows-10.git" "Windows-10" "mv * $THEMES_DIR/Windows-10"
install_git_theme "https://github.com/B00merang-Project/Windows-10-Icons.git" "Windows-10-Icons" "mv * $ICONS_DIR/Windows-10"

# 3. Windows 11 Theme
echo "Installing Windows 11 Theme..."
install_git_theme "https://github.com/yeyushengfan258/Windows-11-theme-linux.git" "Windows-11" "mkdir -p $THEMES_DIR/Windows-11 && cp -r gtk-4.0 $THEMES_DIR/Windows-11/"

# 4. Backgrounds
echo "Downloading Wallpapers..."
# Using reliable sources (GitHub raw content from trusted theme repos or Wikimedia)

# MacOS Big Sur Wallpaper (from WhiteSur repo or similar)
curl -L -o "$BACKGROUNDS_DIR/macos-wallpaper.jpg" "https://raw.githubusercontent.com/vinceliuice/WhiteSur-wallpapers/main/4k/Monterey-light.jpg"

# Windows 10 Wallpaper
curl -L -o "$BACKGROUNDS_DIR/win10-wallpaper.jpg" "https://upload.wikimedia.org/wikipedia/en/c/c2/Windows_10_Hero_Wallpaper_2020.png"

# Windows 11 Wallpaper
curl -L -o "$BACKGROUNDS_DIR/win11-wallpaper.jpg" "https://upload.wikimedia.org/wikipedia/commons/e/ec/Windows_11_Bloom_Wallpaper_Light.jpg"

# Gnome/Ubuntu defaults are usually already there, but let's ensure we have a fallback
cp /usr/share/backgrounds/warty-final-ubuntu.png "$BACKGROUNDS_DIR/ubuntu-wallpaper.jpg" || true

echo "Theme installation complete."
