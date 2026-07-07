# Package diff: bazzite `:beelink` vs Fedora KDE

Generated 2026-07-07. Compares the **main (top-level) packages** of the custom
bazzite **`:beelink`** image against a stock **Fedora KDE** desktop.

| | Image | Total RPMs | Top-level ("main") |
|---|---|--:|--:|
| **beelink** | `ghcr.io/otonm/bazzite-custom:beelink` (Fedora 44) | 2465 | 538 |
| **Fedora KDE** | `fedora-kde-common` selection on `fedora:44` | 2105 | 236 |

- **Only in beelink (main): 229**
- **Only in Fedora KDE (main): 73**

## Method

"Main package" = a **leaf** of the dependency graph (`dnf5 repoquery --installed --leaves`):
a package nothing else installed pulls in. This is the requested granularity — e.g. `samba`
is kept but `samba-libs` (required by `samba`) is dropped.

The diff is computed as: a package is listed for a side only if it is **absent from the other
image entirely** *and* is a **leaf on this side**. Diffing full presence first (then filtering to
leaves) avoids two artefacts of naive leaf-diffing: a package present in both but a leaf in only
one (e.g. `dolphin`, pulled by a bazzite metapackage) does not show up, and low-level libraries
common to both Fedora bases (e.g. `alsa-lib`) cancel out.

- **beelink** side: read directly from the image's RPM database.
- **Fedora KDE** side: reconstructed from the official Fedora KDE spin kickstart selection
  (`@^kde-desktop-environment` + `@firefox @kde-apps @kde-media @kde-pim @libreoffice` and the
  spin's individual packages/exclusions), installed into a `fedora:44` `--installroot`. Live-ISO-only
  packages (`anaconda-live`, `dracut-live`, `livesys-scripts`, `mediawriter`) are omitted so the
  set represents an installed system.

### Caveats
- The recursive-leaf heuristic keeps a few packages whose only requirers are themselves leaves;
  such cases mostly cancel in the diff (present on both sides).
- The Fedora KDE side is a kickstart reconstruction resolved against current F44 repodata, so it
  approximates — not byte-identical to — a shipped Live ISO manifest.

## Highlights — what `:beelink` adds over Fedora KDE

- **Out-of-tree kernel modules (akmods):** `kmod-v4l2loopback`, `kmod-xone`, `kmod-kvmfr`,
  `kmod-framework-laptop`, `kmod-system76-driver`/`-io`, `hid-fanatecff-akmod-modules`,
  `hid-tmff2-akmod-modules`, `new-lg4ff-akmod-modules`, `zenergy-akmod-modules`, `sc0710`, `gcadapter_oc`.
- **AMD / GPU tooling:** `radeontop`, `amdsmi`, `ryzenadj`, `mesa-libOpenCL`, `intel-opencl`, `nvtop`.
- **Gaming stack:** `mangohud`, `vkBasalt`, `umu-launcher`/`umu-wrapper`, `terra-gamescope-libs`,
  `ScopeBuddy`, `vulkan-low-latency-layer`, `openxr`, `libFAudio`.
- **Containers / dev:** `distrobox`, `buildah`, `cosign`, `udica`, `slirp4netns`, `systemd-container`, `gdb`.
- **Cockpit web admin:** `cockpit-files`, `-podman`, `-networkmanager`, `-storaged`, `-selinux`.
- **ublue / bazzite tooling:** `ublue-os-just`, `ublue-os-akmods-addons`, `ublue-os-signing`,
  `ublue-os-udev-rules`, `bazzite-portal`, `uupd`, `topgrade`, `bootupd`, `greenboot-default-health-checks`,
  `steamdeck-kde-presets-desktop`, `jupiter-sd-mounting-btrfs`.
- **Peripherals / input:** `input-remapper`, `libratbag-ratbagd`, `solaar-udev`, `openrgb-udev-rules`,
  `oversteer-udev`, `xwiimote-ng`, `linuxconsoletools`, `ydotool`, `xdotool`.
- **Networking / VPN:** `tailscale`, `wireguard-tools`, `iwd`.
- **Storage / btrfs:** `btrfs-assistant`, `snapper`, `bees`, `lvm2`, `nvme-cli`.
- **CLI quality-of-life:** `fish`, `tmux`, `btop`, `fastfetch`, `fzf`, `glow`, `gum`, `duf`, `vim-enhanced`.
- **Input methods (fcitx5):** `fcitx5-*` family (chewing, mozc, hangul, unikey, chinese-addons, …).
- **OCR:** `tesseract-*` + many `tesseract-langpack-*`.
- **Security tokens:** `yubikey-manager`, `pam_yubico`, `pamu2fcfg`.

## Highlights — what stock Fedora KDE has that `:beelink` drops

Mostly default KDE apps and Fedora services the image trims: `firefox` (bazzite uses the Flatpak),
KDE games (`kmahjongg`, `kmines`, `kpat`), `kontact`/`akregator`/`kmail`-adjacent PIM, `kcalc`,
`okular`, `gwenview`, `kolourpaint`, `dragon`, `elisa-player`, `kamoso`, `neochat`, several
`libreoffice-*` components, and system bits like `abrt-*`, `cronie`, `rsyslog`, `setroubleshoot`.

---

## Only in beelink — main packages (229)

```
7zip-standalone
ScopeBuddy
alsa-firmware
alsa-tools-firmware
amdsmi
apr-util-lmdb
apr-util-openssl
bazaar
bazzite-portal
bees
bootupd
btop
btrfs-assistant
buildah
c2esp
cage
cicpoffs
cockpit-files
cockpit-networkmanager
cockpit-podman
cockpit-selinux
cockpit-storaged
cosign
displaylink
distrobox
dmemcg-booster
ds-inhibit
duf
dymo-cups-drivers
edk2-ovmf
efibootmgr
evtest
f3
fastfetch
fcitx5-chewing
fcitx5-chinese-addons
fcitx5-chinese-addons-data
fcitx5-configtool
fcitx5-gtk
fcitx5-gtk3
fcitx5-gtk4
fcitx5-hangul
fcitx5-libthai
fcitx5-m17n
fcitx5-mozc
fcitx5-qt
fcitx5-sayura
fcitx5-unikey
fedora-chromium-config
fedora-chromium-config-kde
fedora-repos-archive
fedora-workstation-backgrounds
ffmpeg
ffmpeg-libs
fira-code-fonts
fish
flatpak-spawn
framework-laptop-kmod-common
framework-system
fw-fanctrl
fzf
gcadapter_oc
gdb
git-core-doc
glow
gmodpatchtool
google-noto-sans-balinese-fonts
google-noto-sans-cjk-fonts
google-noto-sans-javanese-fonts
google-noto-sans-sundanese-fonts
greenboot-default-health-checks
grub2-pc
grub2-tools-extra
gstreamer1-plugins-good-qt
gum
hid-fanatecff-akmod-modules
hid-tmff2-akmod-modules
icoutils
input-remapper
intel-opencl
intel-vaapi-driver
iwd
jupiter-sd-mounting-btrfs
kate-krunner-plugin
kate-plugins
kcm-fcitx5
kernel
kernel-devel-matched
kf5-sonnet-hunspell
kio-extras-kf5
kmod-evdi
kmod-framework-laptop
kmod-gcadapter_oc
kmod-kvmfr
kmod-sc0710
kmod-system76-driver
kmod-system76-io
kmod-t150-driver
kmod-v4l2loopback
kmod-xone
krunner-bazaar
kvmfr
ladspa-caps-plugins
lato-fonts
libFAudio
libbluray-utils
libcamera-gstreamer
libcamera-tools
libcec
libimobiledevice-utils
libinput-utils
libratbag-ratbagd
libva-utils
libxcrypt-compat
linuxconsoletools
ls-iommu
lshw
lvm2
lzip
makemkv
mangohud
mesa-libOpenCL
mobile-broadband-provider-info
nerd-fonts
new-lg4ff-akmod-modules
nss-altfiles
nvme-cli
nvtop
obs-studio-plugin-vkcapture-hook-libs
openrgb-udev-rules
openxr
oversteer-udev
pam_afs_session
pam_yubico
pamu2fcfg
perl-IO-Compress-Brotli
perl-PerlIO-utf8_strict
phonon-qt5-backend-vlc
pipewire-libs-extra
pipewire-module-filter-chain-sofa
plasma-foreground-booster-dmemcg
powerstat
printer-driver-brlaser
ptouch-driver
python3-icoextract
python3-keyring+completion
python3-pip
qt
qt-common
qt5-qtimageformats
qt5-qtspeech-speechd
qt5-qttranslations
radeontop
rar
rom-properties-kf6
rom-properties-utils
ryzenadj
sc0710
scx-scheds
scx-tools
shim-ia32
shim-x64
slirp4netns
snapper
solaar-udev
splix
squashfs-tools
steamdeck-kde-presets-desktop
stress-ng
system76-driver
system76-io
systemd-container
t150-driver
tailscale
terra-gamescope-libs
terra-release
terra-release-extras
terra-release-mesa
tesseract-devel
tesseract-langpack-ces
tesseract-langpack-chi_sim
tesseract-langpack-chi_sim_vert
tesseract-langpack-chi_tra
tesseract-langpack-chi_tra_vert
tesseract-langpack-deu
tesseract-langpack-ell
tesseract-langpack-fra
tesseract-langpack-ita
tesseract-langpack-jpn
tesseract-langpack-jpn_vert
tesseract-langpack-nld
tesseract-langpack-pol
tesseract-langpack-por
tesseract-langpack-rus
tesseract-langpack-spa
tesseract-langpack-tur
tmux
topgrade
twitter-twemoji-fonts
ublue-os-akmods-addons
ublue-os-just
ublue-os-media-automount-udev
ublue-os-selinux-workarounds
ublue-os-signing
ublue-os-udev-rules
udica
uld
umu-launcher
umu-wrapper
usbip
uupd
v4l-utils
v4l2loopback
vim-enhanced
vkBasalt
vulkan-low-latency-layer
webapp-manager
wireguard-tools
wlr-randr
wmctrl
xdg-terminal-exec
xdotool
xone-kmod-common
xwiimote-ng
xwininfo
yad
ydotool
yubikey-manager
zenergy-akmod-modules
```

## Only in Fedora KDE — main packages (73)

```
NetworkManager-adsl
NetworkManager-l2tp
PackageKit-command-not-found
PackageKit-gstreamer-plugin
abrt-cli
abrt-desktop
akregator
akregator-libs
at
breeze-icon-theme-fedora
cronie
cronie-anacron
crontabs
cups-pk-helper
default-fonts-cjk-sans
deltarpm
dos2unix
dracut-config-rescue
dragon
ed
elisa-player
firefox
firefox-langpacks
gtk3-immodule-xim
gwenview
gwenview-libs
ibus-table-chinese-cangjie
imsettings-gsettings
imsettings-plasma
irqbalance
kamoso
kcalc
kcharselect
kde-l10n
kde-partitionmanager
kdepim-addons
kleopatra
kmahjongg
kmines
kmouth
kolourpaint
kolourpaint-libs
kontact
kontact-libs
kpat
libreoffice-calc
libreoffice-draw
libreoffice-emailmerge
libreoffice-gtk3
libreoffice-gtk4
libreoffice-impress
libreoffice-kf6
libreoffice-math
minicom
neochat
nmap-ncat
okular
pipewire-config-raop
plasma-discover-kns
plasma-discover-notifier
plasma-drkonqi
plasma-nm-l2tp
plasma-nm-openswan
plasma-nm-pptp
plasma-welcome-fedora
plocate
psacct
qrca
rsyslog
setroubleshoot
skanpage
sssd-proxy
system-config-language
```
