#!/bin/bash
set -e

echo "Starting ScopeOS Privacy Cleanup..."

# 1. Remove Telemetry Packages
PACKAGES_TO_REMOVE=(
    "ubuntu-report"
    "whoopsie"
    "apport"
    "popcon"
)

for pkg in "${PACKAGES_TO_REMOVE[@]}"; do
    if dpkg -l | grep -q "$pkg"; then
        echo "Removing $pkg..."
        apt-get remove --purge -y "$pkg" || echo "Failed to remove $pkg"
    fi
done

# 2. Disable Telemetry Services (if any remain)
systemctl disable --now apport.service || true
systemctl disable --now whoopsie.service || true

# 3. Configure Privacy Settings (gsettings defaults for new users)
# This usually requires creating a dconf override file
mkdir -p /etc/dconf/db/local.d/

cat <<EOF > /etc/dconf/db/local.d/99-scopeos-privacy
[org/gnome/desktop/privacy]
report-technical-problems=false
send-software-usage-stats=false
remember-recent-files=false
remember-app-usage=false
EOF

# Update dconf database
dconf update

echo "Privacy cleanup complete."
