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

# Expand the array to list of arguments
echo "Removing telemetry packages: ${PACKAGES_TO_REMOVE[*]}"
# Using "|| true" to ensure script doesn't fail if some packages are already missing
apt-get remove --purge -y "${PACKAGES_TO_REMOVE[@]}" || true

# 2. Disable Telemetry Services (if any remain)
systemctl disable --now apport.service 2>/dev/null || true
systemctl disable --now whoopsie.service 2>/dev/null || true

# 3. Configure Privacy Settings (gsettings defaults for new users)
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
