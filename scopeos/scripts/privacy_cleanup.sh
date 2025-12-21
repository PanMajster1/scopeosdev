#!/bin/bash
set -euo pipefail

# Check for root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

echo "Starting ScopeOS Privacy Cleanup..."

export DEBIAN_FRONTEND=noninteractive

# 1. Remove Telemetry Packages
PACKAGES_TO_REMOVE=(
    "ubuntu-report"
    "whoopsie"
    "apport"
    "popcon"
)

echo "Removing telemetry packages: ${PACKAGES_TO_REMOVE[*]}"
# Use remove_if_installed approach or simple loop to avoid failure if one is missing but others are present
# `apt-get remove` will fail if a package is not installed and you ask to remove it?
# Actually, apt-get remove ignores uninstalled packages unless you use wildcard, usually.
# But for safety, "|| true" is okay, BUT it masks real errors (like lock file).
# Better: check first.

for pkg in "${PACKAGES_TO_REMOVE[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        echo "Removing $pkg..."
        apt-get purge -y "$pkg"
    else
        echo "$pkg not installed, skipping."
    fi
done

# 2. Disable Telemetry Services (if any remain)
# Only try to disable if systemd is active (might not be in chroot)
# But `systemctl` usually fails gracefully or we can check.
# In a chroot (Cubic), systemd is not running as PID 1.
# We should mask the services so they don't start on boot.

echo "Masking telemetry services..."
systemctl mask apport.service 2>/dev/null || true
systemctl mask whoopsie.service 2>/dev/null || true

# 3. Configure Privacy Settings (gsettings defaults for new users)
mkdir -p /etc/dconf/db/local.d/

cat <<EOF > /etc/dconf/db/local.d/99-scopeos-privacy
[org/gnome/desktop/privacy]
report-technical-problems=false
send-software-usage-stats=false
remember-recent-files=false
remember-app-usage=false
EOF

# Update dconf database if dconf is installed
if command -v dconf >/dev/null; then
    dconf update
else
    echo "Warning: dconf not found. Skipping dconf update."
fi

echo "Privacy cleanup complete."
