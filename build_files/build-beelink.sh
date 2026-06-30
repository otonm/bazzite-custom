#!/bin/bash

set -eoux pipefail

### Remove gaming packages not wanted in this image
dnf5 remove -y --no-autoremove \
    steam \
    steam-devices \
    lutris \
    sunshine

# Waydroid may be absent depending on the base — suppress failure if so
dnf5 remove -y --no-autoremove waydroid waydroid-selinux 2>/dev/null || true

# Remove leftover desktop entries for removed packages and the Discourse
# community launcher shipped by the base image (exact name matched via glob).
rm -f \
    /usr/share/applications/waydroid-container-restart.desktop \
    /usr/share/applications/bazzite-steam-bpm.desktop \
    /usr/share/applications/*discourse*.desktop

dnf5 autoremove -y

### Trim default Flatpaks (emulation + game launchers).
# These are removed from the default *install* list, NOT the blocklist, so the
# user can still install them from Flathub later. Locate whichever ublue-os
# system flatpak list contains them, then drop the entries.
FLATPAK_LIST=$(grep -rls 'net\.retrodeck\.retrodeck' /usr/share/ublue-os /etc/ublue-os 2>/dev/null | head -1)
if [[ -n "${FLATPAK_LIST}" ]]; then
    sed -i \
        -e '/net\.retrodeck\.retrodeck/d' \
        -e '/org\.es_de\.frontend/d' \
        -e '/com\.heroicgameslauncher\.hgl/d' \
        -e '/com\.usebottles\.bottles/d' \
        -e '/net\.davidotek\.pupgui2/d' \
        "${FLATPAK_LIST}"
fi

### Install AMD monitoring/diagnostic tools (drivers already ship in the base)
dnf5 install -y --setopt=install_weak_deps=False \
    radeontop \
    nvtop \
    vulkan-tools \
    libva-utils

### Razer Basilisk V3 Pro support (OpenRazer + Polychromatic)
# Kernel module: prebuilt against the ogc kernel via the akmods stage. No DKMS.
dnf5 install -y --setopt=install_weak_deps=False \
    /tmp/akmods-rpms/kmods/kmod-openrazer-*.rpm

# Userspace daemon + GUI from the OpenRazer OBS repo. Never install
# openrazer-meta — it would pull the DKMS kmod, which fails on atomic.
dnf5 config-manager addrepo --from-repofile=https://openrazer.github.io/hardware:razer.repo
dnf5 install -y --setopt=install_weak_deps=False \
    openrazer-daemon \
    python3-openrazer \
    polychromatic
# Remove the repo file so a rebased user machine never tries to layer the DKMS kmod.
rm -f /etc/yum.repos.d/*azer*.repo
# openrazer-daemon is a per-user D-Bus service auto-started by Polychromatic —
# do NOT enable a system service. The openrazer group + udev rules ship with the
# packages; add your user at first boot: `sudo usermod -aG openrazer $USER`.

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
