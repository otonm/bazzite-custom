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

### Remove hardware/tooling not used on this AMD/KDE box
# Intel GPU drivers/utilities (AMD box), System76 laptop drivers, cockpit web
# admin stack, plus xwiimote and fish per owner preference. Intel *wifi*
# firmware is kept (re-added below) — only the Intel GPU drivers go.
dnf5 remove -y --no-autoremove \
    cockpit\* \
    xwiimote-ng \
    fish \
    intel-opencl \
    intel-vaapi-driver \
    system76-driver \
    system76-io \
    kmod-system76-driver \
    kmod-system76-io

dnf5 autoremove -y

# Re-add the Bluetooth stack explicitly after autoremove so it is guaranteed
# present and marked user-installed (autoremove can otherwise sweep it).
dnf5 install -y \
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
dnf5 install -y \
    radeontop \
    nvtop \
    vulkan-tools \
    libva-utils

### Desktop capabilities: printing, file sharing, Thunderbolt, AppImage, codecs
# cups*/ipp-usb = IPP / driverless printing (cups-pk-helper re-adds the KDE
# print-dialog auth the base drops); samba/cifs-utils = share hosting + mounting;
# iwlwifi-*-firmware = Intel wifi firmware; bolt+plasma-thunderbolt = TB daemon
# and KDE KCM; fuse-libs = FUSE2 for AppImages; PackageKit-gstreamer-plugin =
# on-demand codec install. Already-present packages are no-ops.
dnf5 install -y \
    cups cups-filters cups-pk-helper ipp-usb \
    samba samba-client cifs-utils \
    iwlwifi-mvm-firmware iwlwifi-dvm-firmware \
    bolt plasma-thunderbolt \
    fuse-libs \
    PackageKit-gstreamer-plugin

### Multimedia: enable rpmfusion, keep Terra's mesa, full ffmpeg, tainted firmware
# See https://rpmfusion.org/Howto/Multimedia . We deliberately do NOT install
# mesa-va-drivers-freeworld — Terra's mesa already provides freeworld VAAPI.
FEDORA=$(rpm -E %fedora)
dnf5 install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA}.noarch.rpm"
# Full ffmpeg over ffmpeg-free (likely already swapped by the base — guard as no-op)
dnf5 swap -y ffmpeg-free ffmpeg --allowerasing || true
# Additional redistributable firmware from the tainted repo
dnf5 install -y rpmfusion-nonfree-release-tainted
dnf5 install -y --repo=rpmfusion-nonfree-tainted "*-firmware" || true

### Work around bootc-image-builder ISO depsolve, which cannot read gpgkey=file://
### keys from inside the image (osbuild/bootc-image-builder#1188 — archived/unfixed).
### Disable gpgcheck on any repo whose key is a local file:// path (Terra, rpmfusion)
### so the anaconda-iso depsolve doesn't try — and fail — to fetch it. Only affects
### manual dnf layering on the installed system; the image is cosign-signed and its
### packages were already GPG-verified at build time.
for repo in /etc/yum.repos.d/*.repo; do
    if grep -q 'gpgkey=file://' "${repo}"; then
        sed -i \
            -e 's/^gpgcheck=1/gpgcheck=0/' \
            -e 's/^repo_gpgcheck=1/repo_gpgcheck=0/' \
            -e 's|^gpgkey=file://|#gpgkey=file://|' \
            "${repo}"
    fi
done

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
