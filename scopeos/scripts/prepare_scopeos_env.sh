#!/bin/bash
set -euo pipefail

# Master Script to Prepare ScopeOS Environment
# This script is intended to be run INSIDE the chroot of the ISO builder (e.g., Cubic terminal).

# Variables
SCOPEOS_DIR="/opt/scopeos"
# REPO_URL="https://github.com/PanMajster1/scopeosdev.git" # Unused in this context if we assume local copy

echo "=== Starting ScopeOS System Preparation ==="

export DEBIAN_FRONTEND=noninteractive

# Helper function to remove packages only if they are installed
remove_if_installed() {
    local pkg="$1"
    # Check if package is installed (status 'ii')
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        echo "Removing $pkg..."
        apt-get purge -y "$pkg"
    else
        echo "Package $pkg not installed, skipping."
    fi
}

# 0. System Updates
echo "Updating system..."
apt-get update
apt-get upgrade -y

# 0.1 Remove Ubuntu Installers
echo "Removing Ubuntu Installers..."
remove_if_installed "ubiquity*"
remove_if_installed "ubuntu-desktop-installer"
remove_if_installed "ubuntu-desktop-bootstrap"

# 1. Install Dependencies
echo "Installing initial dependencies and enabling universe..."
# Install software-properties-common to get add-apt-repository
apt-get install -y software-properties-common

# Manually enable universe repo if add-apt-repository fails or isn't enough in chroot
if ! grep -qE "^deb .*universe" /etc/apt/sources.list; then
    echo "Manually enabling universe repository..."
    sed -i 's/main restricted/main restricted universe/g' /etc/apt/sources.list
fi
# Also try standard command to be safe
add-apt-repository universe -y || true

apt-get update

# Combined installation for optimization and added dconf-cli
echo "Installing main dependencies..."
apt-get install -y \
    calamares \
    calamares-settings-ubuntu-common \
    python3-gi \
    python3-gi-cairo \
    gir1.2-gtk-4.0 \
    gir1.2-adw-1 \
    git \
    curl \
    gnome-shell-extension-manager \
    gnome-shell-extensions \
    gnome-shell-extension-dash-to-dock \
    gnome-shell-extension-dash-to-panel \
    gpg \
    dconf-cli

# 2. Setup Directory & Repositories (for Netinstall apps)
echo "Adding third-party repositories..."
mkdir -p /etc/apt/keyrings

# Helper function for adding repo keys securely
add_repo_key() {
    local url="$1"
    local keyring="$2"
    # Although we don't have hardcoded checksums (urls change), we ensure pipe safety
    curl -fsSL "$url" | gpg --dearmor --yes -o "$keyring"
}

# Google Chrome
if [ ! -f /etc/apt/keyrings/google-chrome.gpg ]; then
    add_repo_key "https://dl.google.com/linux/linux_signing_key.pub" "/etc/apt/keyrings/google-chrome.gpg"
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list
fi

# VS Code
if [ ! -f /etc/apt/keyrings/packages.microsoft.gpg ]; then
    add_repo_key "https://packages.microsoft.com/keys/microsoft.asc" "/etc/apt/keyrings/packages.microsoft.gpg"
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
fi

# Spotify
if [ ! -f /etc/apt/keyrings/spotify.gpg ]; then
    add_repo_key "https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg" "/etc/apt/keyrings/spotify.gpg"
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/spotify.gpg] http://repository.spotify.com stable non-free" | tee /etc/apt/sources.list.d/spotify.list
fi

# Update to ensuring lists are valid
apt-get update

mkdir -p "$SCOPEOS_DIR"

# 3. Install Themes
if [ -f "$SCOPEOS_DIR/scripts/download_themes.sh" ]; then
    bash "$SCOPEOS_DIR/scripts/download_themes.sh"
else
    echo "Error: Theme download script not found at $SCOPEOS_DIR/scripts/download_themes.sh" >&2
    exit 1
fi

# 4. Install Apps (Theme Switcher & Welcome)
echo "Installing Control Center and Welcome App..."
cp "$SCOPEOS_DIR/theme-switcher/scopeos-control-center.py" /usr/local/bin/scopeos-control-center
cp "$SCOPEOS_DIR/scripts/scopeos-welcome.py" /usr/local/bin/scopeos-welcome
chmod +x /usr/local/bin/scopeos-control-center
chmod +x /usr/local/bin/scopeos-welcome

# Create Desktop Entry for Control Center
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

# Create Desktop Entry for Welcome App (Autostart)
mkdir -p /etc/xdg/autostart
cat <<EOF > /etc/xdg/autostart/scopeos-welcome.desktop
[Desktop Entry]
Name=Welcome to ScopeOS
Comment=Welcome to ScopeOS
Exec=scopeos-welcome
Icon=system-help
Terminal=false
Type=Application
Categories=Utility;
X-GNOME-Autostart-enabled=true
EOF

# Create Desktop Entry for Installer
cat <<EOF > /usr/share/applications/install-scopeos.desktop
[Desktop Entry]
Name=Install ScopeOS
Comment=Install ScopeOS to your drive
Exec=pkexec calamares
Icon=/opt/scopeos/assets/scopeos-logo.png
Terminal=false
Type=Application
Categories=System;
EOF

# Copy Installer Shortcut to Skeleton Desktop (for new users/live user)
mkdir -p /etc/skel/Desktop
cp /usr/share/applications/install-scopeos.desktop /etc/skel/Desktop/
chmod +x /etc/skel/Desktop/install-scopeos.desktop

# 5. Configure Calamares
echo "Configuring Calamares..."
# Copy main configs to /etc/calamares
if [ -d "$SCOPEOS_DIR/calamares-config" ]; then
    cp -r "$SCOPEOS_DIR/calamares-config/settings.conf" /etc/calamares/
    cp -r "$SCOPEOS_DIR/calamares-config/modules" /etc/calamares/
else
    echo "Warning: Calamares config not found."
fi

# Configure Branding
# Calamares expects branding in /usr/share/calamares/branding/<brand_name>
mkdir -p /usr/share/calamares/branding/scopeos
if [ -f "$SCOPEOS_DIR/calamares-config/branding.desc" ]; then
    cp "$SCOPEOS_DIR/calamares-config/branding.desc" /usr/share/calamares/branding/scopeos/
fi
if [ -f "$SCOPEOS_DIR/assets/scopeos-logo.png" ]; then
    cp "$SCOPEOS_DIR/assets/scopeos-logo.png" /usr/share/calamares/branding/scopeos/
fi

# 6. Privacy Cleanup
if [ -f "$SCOPEOS_DIR/scripts/privacy_cleanup.sh" ]; then
    bash "$SCOPEOS_DIR/scripts/privacy_cleanup.sh"
else
    echo "Warning: Privacy cleanup script not found."
fi

# 7. Set Default Wallpaper, Theme, and Boot Logo
echo "Setting defaults..."

# Boot Logo (Plymouth)
if [ -f "$SCOPEOS_DIR/assets/scopeos-logo.png" ]; then
    echo "Updating Plymouth Boot Logo..."
    # Replace default spinner watermark and fallback
    if [ -d "/usr/share/plymouth/themes/spinner" ]; then
        cp "$SCOPEOS_DIR/assets/scopeos-logo.png" /usr/share/plymouth/themes/spinner/watermark.png
        cp "$SCOPEOS_DIR/assets/scopeos-logo.png" /usr/share/plymouth/themes/spinner/bgrt-fallback.png
    fi
    # Also attempt to replace ubuntu-logo theme assets if present
    if [ -d "/usr/share/plymouth/themes/ubuntu-logo" ]; then
        cp "$SCOPEOS_DIR/assets/scopeos-logo.png" /usr/share/plymouth/themes/ubuntu-logo/ubuntu-logo.png
        cp "$SCOPEOS_DIR/assets/scopeos-logo.png" /usr/share/plymouth/themes/ubuntu-logo/ubuntu-logo16.png
    fi
    # Update initramfs to apply changes
    update-initramfs -u
fi

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

# Update dconf if possible, warn otherwise
if command -v dconf >/dev/null; then
    dconf update
else
    echo "Warning: dconf not found, skipping schema update."
fi

# 8. Clean up
apt-get autoremove -y
apt-get clean

echo "=== ScopeOS Preparation Complete ==="
echo "You can now proceed to repack the ISO."
