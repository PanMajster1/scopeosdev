#!/bin/bash
set -euo pipefail

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

for pkg in "${PACKAGES_TO_REMOVE[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg"; then
        echo "Purging $pkg..."
        apt-get remove --purge -y "$pkg" || echo "Warning: Failed to purge $pkg"
    else
        echo "Package $pkg not installed."
    fi
done

# 2. Disable Telemetry Services (if any remain)
echo "Disabling telemetry services..."
SERVICES=(
    "apport.service"
    "whoopsie.service"
)

for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$service" || systemctl is-enabled --quiet "$service"; then
        echo "Disabling $service..."
        systemctl disable --now "$service" 2>/dev/null || echo "Warning: Failed to disable $service"
    fi
done

# 3. Configure Privacy Settings (gsettings defaults for new users)
echo "Configuring privacy defaults..."
mkdir -p /etc/dconf/db/local.d/

cat <<EOF > /etc/dconf/db/local.d/99-scopeos-privacy
[org/gnome/desktop/privacy]
report-technical-problems=false
send-software-usage-stats=false
remember-recent-files=false
remember-app-usage=false
EOF

# Update dconf database
if command -v dconf >/dev/null; then
    dconf update
else
    echo "Warning: dconf command not found, skipping update."
fi

echo "Privacy cleanup complete."
