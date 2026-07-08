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

### Work around bootc-image-builder ISO depsolve, which cannot read gpgkey=file://
### keys from inside the image (osbuild/bootc-image-builder#1188 — archived/unfixed).
### Disable gpgcheck on any repo whose key is a local file:// path (Terra) so the
### anaconda-iso depsolve doesn't try — and fail — to fetch it. Only affects manual
### dnf layering on the installed system; the image is cosign-signed and its packages
### were already GPG-verified at build time.
for repo in /etc/yum.repos.d/*.repo; do
    if grep -q 'gpgkey=file://' "${repo}"; then
        sed -i \
            -e 's/^gpgcheck=1/gpgcheck=0/' \
            -e 's/^repo_gpgcheck=1/repo_gpgcheck=0/' \
            -e 's|^gpgkey=file://|#gpgkey=file://|' \
            "${repo}"
    fi
done

### Bake in cosign signature verification for this image (see setup-signing.sh).
/ctx/setup-signing.sh

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