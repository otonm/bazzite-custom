#!/bin/bash

# Shared build steps common to BOTH images (:latest and :beelink).
# Called by build.sh and build-beelink.sh so the logic lives in one place.

set -euo pipefail
trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG
log() { echo "=== $* ==="; }

log "Installing podman compose stack"
# podman itself already ships in the Bazzite base; add the compose provider so
# `podman compose` works, plus the docker CLI compat shim (`docker` -> podman).
dnf5 install -y podman-compose podman-docker

log "Installing Brave Origin"
# Brave Origin (stripped-down Brave: no AI/rewards/wallet/VPN; free on Linux).
# Baked as an RPM, so it only updates when a new image is built AND the machine
# reboots (bootc deployments go live on reboot) — a Flatpak would update live.
# The repo ships an https gpgkey, so it does NOT trip the file:// ISO-depsolve
# workaround in fix-iso-gpgcheck.sh. Repo file added the same way as OpenRazer's.
curl -Lo /etc/yum.repos.d/brave-browser.repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
dnf5 install -y brave-origin

log "Enabling Tailscale"
# Tailscale is already installed in the Bazzite base but shipped disabled.
# Enable it here so it starts on boot. After first boot, run: sudo tailscale up
systemctl enable tailscaled

log "Unblocking Steam/Lutris flatpaks"
# Remove the Flatpak blocklist entries for Steam and Lutris. Without this,
# bazzite-flatpak-manager would still block these apps from Flathub at runtime
# even though the RPMs are gone.
sed -i \
    -e '/com\.valvesoftware\.Steam/d' \
    -e '/net\.lutris\.Lutris/d' \
    /usr/share/ublue-os/flatpak-blocklist 2>/dev/null || true
