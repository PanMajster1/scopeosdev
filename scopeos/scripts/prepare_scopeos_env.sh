#!/bin/bash
set -e

# Master Script to Prepare ScopeOS Environment
# This script is intended to be run INSIDE the chroot of the ISO builder (e.g., Cubic terminal).

# Variables
SCOPEOS_DIR="/opt/scopeos"
REPO_URL="https://github.com/yourusername/scopeos.git" # Placeholder

echo "=== Starting ScopeOS System Preparation ==="

# 0. System Updates
apt-get update
apt-get upgrade -y

# 1. Install Dependencies
apt-get install -y \
    calamares \
    calamares-settings-ubuntu \
    python3-gi \
    python3-gi-cairo \
    gir1.2-gtk-4.0 \
    gir1.2-adw-1 \
    git \
    curl \
    gnome-shell-extension-manager \
    gnome-shell-extensions

# 2. Setup Directory & Repositories (for Netinstall apps)
echo "Adding third-party repositories..."
mkdir -p /etc/apt/keyrings

# Google Chrome
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list

# VS Code
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list

# Spotify
curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | gpg --dearmor --yes -o /etc/apt/keyrings/spotify.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/spotify.gpg] http://repository.spotify.com stable non-free" | tee /etc/apt/sources.list.d/spotify.list

# Update to ensuring lists are valid
apt-get update

mkdir -p "$SCOPEOS_DIR"
# In a real scenario, you might clone the repo here.
# For this script, we assume the 'scopeos' folder (from this repo) is copied to /opt/scopeos
# cp -r /path/to/local/scopeos/* "$SCOPEOS_DIR/"

# 3. Install Themes
bash "$SCOPEOS_DIR/scripts/download_themes.sh"

# 4. Install Theme Switcher App
# We'll install it as a python script executable from /usr/local/bin
cp "$SCOPEOS_DIR/theme-switcher/scopeos-control-center.py" /usr/local/bin/scopeos-control-center
chmod +x /usr/local/bin/scopeos-control-center

# Create Desktop Entry
cat <<EOF > /usr/share/applications/scopeos-control-center.desktop
[Desktop Entry]
Name=ScopeOS Control Center
Comment=Change themes and settings
Exec=scopeos-control-center
Icon=preferences-desktop-theme
Terminal=false
Type=Application
Categories=Settings;
EOF

# 5. Configure Calamares
# Copy main configs to /etc/calamares
cp -r "$SCOPEOS_DIR/calamares-config/settings.conf" /etc/calamares/
cp -r "$SCOPEOS_DIR/calamares-config/modules" /etc/calamares/

# Configure Branding
# Calamares expects branding in /usr/share/calamares/branding/<brand_name>
mkdir -p /usr/share/calamares/branding/scopeos
cp "$SCOPEOS_DIR/calamares-config/branding.desc" /usr/share/calamares/branding/scopeos/
cp "$SCOPEOS_DIR/assets/scopeos-logo.png" /usr/share/calamares/branding/scopeos/

# 6. Privacy Cleanup
bash "$SCOPEOS_DIR/scripts/privacy_cleanup.sh"

# 7. Set Default Wallpaper and Theme (MacOS Like)
# This sets the global default for new users
mkdir -p /etc/dconf/db/local.d/
cat <<EOF > /etc/dconf/db/local.d/10-scopeos-theme
[org/gnome/desktop/interface]
gtk-theme='WhiteSur-Light'
icon-theme='WhiteSur'
color-scheme='prefer-light'

# Enable User Themes Extension
[org/gnome/shell]
enabled-extensions=['user-theme@gnome-shell-extensions.gcampax.github.com', 'ubuntu-dock@ubuntu.com', 'ding@rastersoft.com']

[org/gnome/shell/extensions/user-theme]
name='WhiteSur-Light'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/macos-wallpaper.jpg'
picture-uri-dark='file:///usr/share/backgrounds/macos-wallpaper.jpg'
EOF

dconf update

# 8. Clean up
apt-get autoremove -y
apt-get clean

echo "=== ScopeOS Preparation Complete ==="
echo "You can now proceed to repack the ISO."
