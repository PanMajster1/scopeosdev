#!/bin/bash
set -euo pipefail

# Master Script to Prepare ScopeOS Environment
# This script is intended to be run INSIDE the chroot of the ISO builder (e.g., Cubic terminal).

# Variables
SCOPEOS_DIR="/opt/scopeos"
KEYRINGS_DIR="/etc/apt/keyrings"

echo "=== Starting ScopeOS System Preparation ==="

export DEBIAN_FRONTEND=noninteractive

# Helper function for adding repo keys securely
add_repo_key() {
    local url="$1"
    local keyring_path="$2"
    local temp_key
    temp_key=$(mktemp)

    # Download first to catch connection errors
    if curl -fsSL "$url" -o "$temp_key"; then
        # Dearmor safely
        gpg --dearmor --yes -o "$keyring_path" < "$temp_key"
        rm -f "$temp_key"
    else
        echo "Error: Failed to download key from $url" >&2
        rm -f "$temp_key"
        return 1
    fi
}

# 1. Initial Update and Essential Tools
echo "Updating system and installing base tools..."
apt-get update
# Install tools needed for adding repos and managing keys
apt-get install -y --no-install-recommends \
    software-properties-common \
    gpg \
    curl \
    ca-certificates \
    apt-transport-https

# 2. Repository Management
echo "Configuring repositories..."
mkdir -p "$KEYRINGS_DIR"

# 2.1 Enable Universe
# Handle Ubuntu 24.04 DEB822 format (ubuntu.sources)
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    if ! grep -q "universe" /etc/apt/sources.list.d/ubuntu.sources; then
        echo "Enabling universe in ubuntu.sources..."
        sed -i 's/Components: main restricted/Components: main restricted universe/g' /etc/apt/sources.list.d/ubuntu.sources
    fi
elif [ -f /etc/apt/sources.list ]; then
    # Legacy format fallback
    if grep -q "^deb " /etc/apt/sources.list && ! grep -qE "^deb .*universe" /etc/apt/sources.list; then
        echo "Enabling universe in sources.list..."
        sed -i 's/main restricted/main restricted universe/g' /etc/apt/sources.list
    fi
fi
# Redundant safety net
add-apt-repository universe -y || true

# 2.2 Third-Party Repositories (Google Chrome, VS Code, Spotify)
# Google Chrome
if [ ! -f "$KEYRINGS_DIR/google-chrome.gpg" ]; then
    echo "Adding Google Chrome repo..."
    add_repo_key "https://dl.google.com/linux/linux_signing_key.pub" "$KEYRINGS_DIR/google-chrome.gpg"
    echo "deb [arch=amd64 signed-by=$KEYRINGS_DIR/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
fi

# VS Code
if [ ! -f "$KEYRINGS_DIR/packages.microsoft.gpg" ]; then
    echo "Adding VS Code repo..."
    add_repo_key "https://packages.microsoft.com/keys/microsoft.asc" "$KEYRINGS_DIR/packages.microsoft.gpg"
    echo "deb [arch=amd64,arm64,armhf signed-by=$KEYRINGS_DIR/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
fi

# Spotify
if [ ! -f "$KEYRINGS_DIR/spotify.gpg" ]; then
    echo "Adding Spotify repo..."
    add_repo_key "https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg" "$KEYRINGS_DIR/spotify.gpg"
    echo "deb [arch=amd64 signed-by=$KEYRINGS_DIR/spotify.gpg] http://repository.spotify.com stable non-free" > /etc/apt/sources.list.d/spotify.list
fi

# 3. Consolidated System Update
echo "Refreshing package lists..."
# Clear lists to ensure we get fresh data especially for new repos
rm -rf /var/lib/apt/lists/*
apt-get update

# 4. Package Removal (Clean up installers)
echo "Removing unwanted packages..."
# We use 'purge' to remove config files too. We ignore errors if packages aren't installed.
# Using array for readability
PACKAGES_TO_REMOVE=(
    "ubiquity*"
    "ubuntu-desktop-installer"
    "ubuntu-desktop-bootstrap"
)
# Check if any exist before trying to purge to avoid scary errors
for pkg in "${PACKAGES_TO_REMOVE[@]}"; do
    # Only try to purge if dpkg sees it installed
    if dpkg -l | grep -q "^ii  $pkg"; then
         apt-get purge -y "$pkg" || true
    fi
done

# 5. Package Installation
echo "Installing dependencies..."
apt-get install -y \
    calamares \
    calamares-settings-ubuntu-common \
    python3-gi \
    python3-gi-cairo \
    gir1.2-gtk-4.0 \
    gir1.2-adw-1 \
    git \
    gnome-shell-extension-manager \
    gnome-shell-extensions \
    gnome-shell-extension-dash-to-dock \
    gnome-shell-extension-dash-to-panel \
    dconf-cli

# Update system packages
apt-get upgrade -y

# 6. Setup ScopeOS Files
echo "Setting up ScopeOS files..."
mkdir -p "$SCOPEOS_DIR"

if [ -f "$SCOPEOS_DIR/scripts/download_themes.sh" ]; then
    bash "$SCOPEOS_DIR/scripts/download_themes.sh"
else
    echo "Error: Theme download script not found at $SCOPEOS_DIR/scripts/download_themes.sh" >&2
    exit 1
fi

# Install Apps
echo "Installing Control Center and Welcome App..."
cp "$SCOPEOS_DIR/theme-switcher/scopeos-control-center.py" /usr/local/bin/scopeos-control-center
cp "$SCOPEOS_DIR/scripts/scopeos-welcome.py" /usr/local/bin/scopeos-welcome
chmod +x /usr/local/bin/scopeos-control-center
chmod +x /usr/local/bin/scopeos-welcome

# Create Desktop Entries
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

# Copy Installer Shortcut to Skeleton Desktop
mkdir -p /etc/skel/Desktop
cp /usr/share/applications/install-scopeos.desktop /etc/skel/Desktop/
chmod +x /etc/skel/Desktop/install-scopeos.desktop

# 7. Configure Calamares
echo "Configuring Calamares..."
if [ -d "$SCOPEOS_DIR/calamares-config" ]; then
    mkdir -p /etc/calamares
    cp -r "$SCOPEOS_DIR/calamares-config/settings.conf" /etc/calamares/ || echo "Warning: settings.conf missing"
    cp -r "$SCOPEOS_DIR/calamares-config/modules" /etc/calamares/ || echo "Warning: modules dir missing"
fi

# Branding
mkdir -p /usr/share/calamares/branding/scopeos
if [ -f "$SCOPEOS_DIR/calamares-config/branding.desc" ]; then
    cp "$SCOPEOS_DIR/calamares-config/branding.desc" /usr/share/calamares/branding/scopeos/
fi
if [ -f "$SCOPEOS_DIR/assets/scopeos-logo.png" ]; then
    cp "$SCOPEOS_DIR/assets/scopeos-logo.png" /usr/share/calamares/branding/scopeos/
fi

# 8. Privacy Cleanup
if [ -f "$SCOPEOS_DIR/scripts/privacy_cleanup.sh" ]; then
    bash "$SCOPEOS_DIR/scripts/privacy_cleanup.sh"
else
    echo "Warning: Privacy cleanup script not found."
fi

# 9. Set Default Wallpaper, Theme, and Boot Logo
echo "Setting defaults..."

# Boot Logo
if [ -f "$SCOPEOS_DIR/assets/scopeos-logo.png" ]; then
    echo "Updating Plymouth Boot Logo..."
    if [ -d "/usr/share/plymouth/themes/spinner" ]; then
        cp "$SCOPEOS_DIR/assets/scopeos-logo.png" /usr/share/plymouth/themes/spinner/watermark.png
        cp "$SCOPEOS_DIR/assets/scopeos-logo.png" /usr/share/plymouth/themes/spinner/bgrt-fallback.png
    fi
    if [ -d "/usr/share/plymouth/themes/ubuntu-logo" ]; then
        cp "$SCOPEOS_DIR/assets/scopeos-logo.png" /usr/share/plymouth/themes/ubuntu-logo/ubuntu-logo.png
        cp "$SCOPEOS_DIR/assets/scopeos-logo.png" /usr/share/plymouth/themes/ubuntu-logo/ubuntu-logo16.png
    fi
    update-initramfs -u
fi

# Dconf Defaults
mkdir -p /etc/dconf/db/local.d/
cat <<EOF > /etc/dconf/db/local.d/10-scopeos-theme
[org/gnome/desktop/interface]
gtk-theme='WhiteSur-Light'
icon-theme='WhiteSur'
color-scheme='prefer-light'

[org/gnome/shell]
enabled-extensions=['user-theme@gnome-shell-extensions.gcampax.github.com', 'ubuntu-dock@ubuntu.com', 'ding@rastersoft.com']

[org/gnome/shell/extensions/user-theme]
name='WhiteSur-Light'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/macos-wallpaper.jpg'
picture-uri-dark='file:///usr/share/backgrounds/macos-wallpaper.jpg'
EOF

if command -v dconf >/dev/null; then
    dconf update
else
    echo "Warning: dconf not found."
fi

# 10. Final Cleanup
apt-get autoremove -y
apt-get clean

echo "=== ScopeOS Preparation Complete ==="
