#!/bin/bash

set -eoux pipefail

### Remove gaming packages not wanted in this image
# (Sunshine is not an RPM on the base — it's opt-in via `ujust setup-sunshine`,
# so there is nothing to remove for it.)
dnf5 remove -y --no-autoremove \
    steam \
    steam-devices \
    lutris

# Waydroid may be absent depending on the base — suppress failure if so
dnf5 remove -y --no-autoremove waydroid waydroid-selinux 2>/dev/null || true

# Remove leftover desktop entries for removed packages and the Discourse
# community launcher shipped by the base image (exact name matched via glob).
rm -f \
    /usr/share/applications/waydroid-container-restart.desktop \
    /usr/share/applications/bazzite-steam-bpm.desktop \
    /usr/share/applications/*discourse*.desktop

dnf5 autoremove -y

# Re-add the Bluetooth stack explicitly after autoremove so it is guaranteed
# present and marked user-installed (autoremove can otherwise sweep it).
dnf5 install -y --setopt=install_weak_deps=False \
    bluez \
    bluez-obexd \
    bluedevil

### Trim default Flatpaks (emulation + game launchers).
# Drop entries from Bazzite's default *install* list (consumed by
# `ujust _install-system-flatpaks`), NOT the blocklist, so the user can still
# install them from Flathub later. On the KDE desktop base only ProtonUp-Qt is
# actually in this list; the rest are kept as forward-compat no-ops (they ship
# only on the deck/handheld variant).
FLATPAK_LIST=/usr/share/ublue-os/bazzite/flatpak/install
if [[ -f "${FLATPAK_LIST}" ]]; then
    sed -i \
        -e '/net\.davidotek\.pupgui2/d' \
        -e '/net\.retrodeck\.retrodeck/d' \
        -e '/org\.es_de\.frontend/d' \
        -e '/com\.heroicgameslauncher\.hgl/d' \
        -e '/com\.usebottles\.bottles/d' \
        "${FLATPAK_LIST}"
fi

### Install AMD monitoring/diagnostic tools (drivers already ship in the base)
dnf5 install -y --setopt=install_weak_deps=False \
    radeontop \
    nvtop \
    vulkan-tools \
    libva-utils

# Razer Basilisk V3 Pro: OpenRazer is NOT installed here. Its kernel module is
# DKMS-only and can only build against the running kernel, which doesn't exist
# in a build container. After installing the system, run `ujust install-openrazer`
# once (pick Polychromatic) and reboot — see the README.

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
