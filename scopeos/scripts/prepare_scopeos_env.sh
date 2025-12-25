#!/bin/bash
set -euo pipefail

# Master Script to Prepare ScopeOS Environment
# This script is intended to be run INSIDE the chroot of the ISO builder (e.g., Cubic terminal).

# Check for root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# Variables
SCOPEOS_DIR="/opt/scopeos"

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

# Helper function for adding repo keys securely
add_repo_key() {
    local url="$1"
    local keyring="$2"
    # Ensure curl and gpg are available
    if ! command -v curl >/dev/null || ! command -v gpg >/dev/null; then
        echo "Error: curl or gpg not found in add_repo_key." >&2
        return 1
    fi
    # Download key
    curl -fsSL "$url" | gpg --dearmor --yes -o "$keyring"
}

# 1. Initial Update and Essential Dependencies
echo "Installing initial dependencies..."
apt-get update
# Install essentials needed for adding repositories
apt-get install -y software-properties-common curl gpg

# 2. Configure Repositories
echo "Configuring repositories..."

# Enable Universe
# Manually enable universe repo if add-apt-repository fails or isn't enough in chroot
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

# Add Third-Party Repositories
echo "Adding third-party repositories..."
mkdir -p /etc/apt/keyrings

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
# Clean up potential existing GPG error causes
rm -f /etc/apt/sources.list.d/spotify.list /etc/apt/keyrings/spotify.gpg
add_repo_key "https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg" "/etc/apt/keyrings/spotify.gpg"
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/spotify.gpg] http://repository.spotify.com stable non-free" | tee /etc/apt/sources.list.d/spotify.list


# 3. Main System Update & Install
echo "Updating system and installing main components..."
# Clear lists to ensure we get fresh data especially for new repos in chroot
rm -rf /var/lib/apt/lists/*
apt-get update
apt-get upgrade -y

# Remove Ubuntu Installers
echo "Removing Ubuntu Installers..."
remove_if_installed "ubiquity*"
remove_if_installed "ubuntu-desktop-installer"
remove_if_installed "ubuntu-desktop-bootstrap"

# Install Dependencies
echo "Installing main packages..."
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

# 6. Setup ScopeOS Files
echo "Setting up ScopeOS files..."
mkdir -p "$SCOPEOS_DIR"

# 4. Install Themes
if [ -f "$SCOPEOS_DIR/scripts/download_themes.sh" ]; then
    bash "$SCOPEOS_DIR/scripts/download_themes.sh"
else
    echo "Error: Theme download script not found at $SCOPEOS_DIR/scripts/download_themes.sh" >&2
    exit 1
fi

# 5. Install Apps (Theme Switcher & Welcome)
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
Icon=/usr/share/scopeos/assets/scopeos-logo.png
Terminal=false
Type=Application
Categories=System;
EOF

# Copy Installer Shortcut to Skeleton Desktop
mkdir -p /etc/skel/Desktop
cp /usr/share/applications/install-scopeos.desktop /etc/skel/Desktop/
chmod +x /etc/skel/Desktop/install-scopeos.desktop

# 6. Configure Calamares
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

# 7. Privacy Cleanup
if [ -f "$SCOPEOS_DIR/scripts/privacy_cleanup.sh" ]; then
    bash "$SCOPEOS_DIR/scripts/privacy_cleanup.sh"
else
    echo "Warning: Privacy cleanup script not found."
fi

# 8. Set Default Wallpaper, Theme, and Boot Logo
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

# 9. Clean up
apt-get autoremove -y
apt-get clean

echo "=== ScopeOS Preparation Complete ==="
