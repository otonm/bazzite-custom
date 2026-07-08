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
#
# Brave installs into /opt, which on bootc is a symlink to /var/opt. Two problems
# that this handles (mirrors amyos's fix-opt.sh, needed here only because of Brave):
#   1. the RPM's cpio can't unpack unless the symlink target exists -> pre-create it;
#   2. /var is runtime state and gets wiped (cleanup.sh flush + ostree commit), so
#      anything left in /var/opt would vanish. After install, relocate it into the
#      immutable /usr/lib/opt and add a tmpfiles symlink recreating /var/opt/* at boot.
mkdir -p /var/opt
curl -Lo /etc/yum.repos.d/brave-browser.repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
dnf5 install -y brave-origin
mkdir -p /usr/lib/opt
for dir in /var/opt/*/; do
    [ -d "${dir}" ] || continue
    name=$(basename "${dir}")
    mv "${dir}" "/usr/lib/opt/${name}"
    echo "L+ /var/opt/${name} - - - - /usr/lib/opt/${name}" \
        >> /usr/lib/tmpfiles.d/bazzite-custom-opt.conf
done

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
