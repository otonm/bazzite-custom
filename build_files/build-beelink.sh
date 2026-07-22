#!/bin/bash

set -euo pipefail
trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG
log() { echo "=== $* ==="; }

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

# The base ships a Steam autostart entry in /etc/skel, so every new user gets
# Steam launching at each login. Steam is removed from this image, so drop it.
# (Users created before this landed keep a stale copy in ~/.config/autostart —
# that per-home file must be deleted by hand; the image can't reach into $HOME.)
rm -f /etc/skel/.config/autostart/steam.desktop

### Remove unwanted base desktop extras (beelink)
# Foreground Booster (plasma-foreground-booster-dmemcg): keep the package — the
# helper runs automatically as the static `plasma-foreground-booster` user
# service — but drop its app-menu launcher; it's a background CPU-weight helper,
# nothing to open by hand. Package, /usr/bin/foreground_booster and the service
# stay put.
rm -f /usr/share/applications/org.kde.foreground-booster.desktop
# Bazzite's bundled offline documentation: 72M of pre-rendered html plus a
# serve.sh that spins up a local http.server, reached via the "Documentation"
# app-menu shortcut. All are unpackaged files baked in by the base, so remove
# them directly.
rm -rf /usr/share/ublue-os/docs
rm -f /usr/share/applications/bazzite-documentation.desktop

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

# More non-AMD hardware support the base bundles for other GPUs. On AMD, VAAPI
# resolves through mesa's radeonsi and OpenCL through rusticl/ROCm, so the Intel
# GPU userspace media/compute stack is never selected — it's pure dead weight.
# Guarded remove-if-installed so a base that stops shipping any of these can't
# fail the build; orphaned deps (e.g. intel-gmmlib) are swept by autoremove below.
prune=(
    # Intel GPU userspace media/compute
    intel-media-driver intel-mediasdk onevpl-intel-gpu
    intel-compute-runtime libva-intel-driver igt-gpu-tools
    # Intel-only platform daemon (no-op on AMD)
    thermald
)
installed=()
for p in "${prune[@]}"; do rpm -q "$p" &>/dev/null && installed+=("$p"); done
[[ ${#installed[@]} -gt 0 ]] && dnf5 remove -y --no-autoremove "${installed[@]}"

# Non-AMD GPU firmware (GPU microcode only — distinct from the iwlwifi / Intel-BT /
# MediaTek RADIO firmware we keep). Fedora pulls these via weak Supplements, but a
# linux-firmware(-all) meta may hard-Require them, and removing one would then
# cascade up to the meta and possibly the kernel. So only remove a firmware package
# when nothing installed still requires it; otherwise skip (no size win, no risk).
for fw in intel-gpu-firmware nvidia-gpu-firmware; do
    rpm -q "$fw" &>/dev/null || continue
    reqs="$(dnf5 repoquery --installed --whatrequires "$fw" 2>/dev/null || true)"
    if [[ -z "$reqs" ]]; then
        dnf5 remove -y --no-autoremove "$fw"
    else
        echo "keeping $fw — still required by: $(echo "$reqs" | tr '\n' ' ')"
    fi
done

# Guard: the AMD GPU firmware and kernel must survive the pruning above.
rpm -q amd-gpu-firmware kernel-core >/dev/null

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

### OpenRazer for the Razer Basilisk V3 Pro — baked into the image.
# Previously deferred to `ujust install-openrazer`, but that recipe cannot work on
# this image, for two independent reasons:
#   1. rpm-ostree runs the DKMS %posttrans in a bwrap sandbox with read-only /var,
#      so `dkms install` fails to create /var/lib/dkms (ublue-os/bazzite#5084);
#   2. OpenRazer 3.12.4 doesn't compile on this kernel — its guard enables the 6-arg
#      hid_report_raw_event() only at 7.0.10, but the -ogc kernel backported it at
#      7.0.9 (openrazer/openrazer#2821).
# Building at image-build time fixes both: /var is writable here and we patch the
# guard. kernel-devel/gcc/make already ship in the Bazzite base, and the module is
# rebuilt on every image build so it always matches the image's own kernel.
KVER=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | sort -V | tail -1)
curl -Lo /etc/yum.repos.d/hardware_razer.repo https://openrazer.github.io/hardware:razer.repo
# Install the -dkms package for its module SOURCE + udev rules only, skipping its
# %posttrans (a `dkms install` targeting a non-existent running kernel that would fail
# the build), then recreate the plugdev group its skipped %pre would have made.
dnf5 install -y --setopt=tsflags=noscripts openrazer-kernel-modules-dkms
getent group plugdev >/dev/null || groupadd -r plugdev
# Userspace: daemon + python lib. The kmod dep is already satisfied above, so this
# triggers no DKMS build.
dnf5 install -y openrazer-daemon python3-openrazer
# Patch the kernel-version guard for this kernel's 7.0.9 backport (openrazer#2821).
# Harmless no-op once upstream ships the fix or the kernel moves past this window.
sed -i \
    's/KERNEL_VERSION(7, 0, 10) && LINUX_VERSION_CODE < KERNEL_VERSION(7, 1, 0)/KERNEL_VERSION(7, 0, 9) \&\& LINUX_VERSION_CODE < KERNEL_VERSION(7, 1, 0)/' \
    /usr/src/openrazer-driver-*/driver/razerkbd_driver.c
# Build the four modules against THIS image's kernel and install them into its tree.
ORZ_SRC=$(ls -d /usr/src/openrazer-driver-*)
KERNELDIR="/usr/lib/modules/${KVER}/build" make -C "${ORZ_SRC}" driver
install -d "/usr/lib/modules/${KVER}/extra/openrazer"
install -m0644 "${ORZ_SRC}"/driver/*.ko "/usr/lib/modules/${KVER}/extra/openrazer/"
depmod -a "${KVER}"
# Auto-start the (dbus-activated) daemon at login for all users so RGB/DPI apply
# without opening a GUI first.
systemctl --global enable openrazer-daemon.service
# openrazer-daemon refuses to run unless the user is in plugdev, and on atomic that
# group isn't in /etc/group (so the `gpasswd` it suggests fails). Ship a boot service
# that seeds plugdev into /etc/group and adds human users, so it works with no manual
# step. See openrazer-plugdev-setup / .service.
install -Dm755 /ctx/openrazer-plugdev-setup /usr/libexec/openrazer-plugdev-setup
install -Dm644 /ctx/openrazer-plugdev.service /usr/lib/systemd/system/openrazer-plugdev.service
systemctl enable openrazer-plugdev.service

### Shared steps (podman, Brave, tailscale, flatpak unblock) — see common.sh
/ctx/common.sh

### ISO file:// gpgkey workaround — must run after all repos are added
### (Terra, rpmfusion, OpenRazer, Brave). See fix-iso-gpgcheck.sh.
/ctx/fix-iso-gpgcheck.sh

### Firewall: make "trusted" the default zone for all interfaces.
# This is a trusted-LAN mini-PC; default all NICs to the trusted zone (allow all)
# instead of Fedora's default FedoraWorkstation zone. Interfaces not pinned to a
# specific zone by NetworkManager inherit DefaultZone.
sed -i 's/^DefaultZone=.*/DefaultZone=trusted/' /etc/firewalld/firewalld.conf

### Bake in cosign signature verification for this image (see setup-signing.sh).
/ctx/setup-signing.sh

### Final cleanup + container commit (see cleanup.sh) — keep last.
/ctx/cleanup.sh
