#!/bin/bash

set -euo pipefail
trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG
log() { echo "=== $* ==="; }

### Remove gaming packages not wanted in this image
log "Removing gaming packages"
dnf5 remove -y --no-autoremove \
    steam \
    steam-devices \
    lutris

# Waydroid is not present on Nvidia builds — suppress failure if absent
dnf5 remove -y --no-autoremove waydroid waydroid-selinux 2>/dev/null || true

# Remove leftover desktop entries for removed packages
rm -f \
    /usr/share/applications/waydroid-container-restart.desktop \
    /usr/share/applications/bazzite-steam-bpm.desktop

dnf5 autoremove -y

### Shared steps (podman, Brave, tailscale, flatpak unblock) — see common.sh
/ctx/common.sh

### ISO file:// gpgkey workaround — must run after all repos are added
/ctx/fix-iso-gpgcheck.sh

### Bake in cosign signature verification for this image (see setup-signing.sh).
/ctx/setup-signing.sh

### Final cleanup + container commit (see cleanup.sh) — keep last.
/ctx/cleanup.sh
