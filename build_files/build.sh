#!/bin/bash

set -eoux pipefail

### Remove gaming packages not wanted in this image
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

dnf5 clean all

# Tailscale is already installed in the bazzite base image but its systemd
# service is shipped disabled by default. Enable it here so it starts on boot.
# After first boot, run: sudo tailscale up
systemctl enable tailscaled

# Remove the Flatpak blocklist entries for Steam and Lutris.
# Without this, bazzite-flatpak-manager would still block these apps from Flathub
# at runtime even though the RPMs are gone.
sed -i \
    -e '/com\.valvesoftware\.Steam/d' \
    -e '/net\.lutris\.Lutris/d' \
    /usr/share/ublue-os/flatpak-blocklist 2>/dev/null || true