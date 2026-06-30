# bazzite-custom

Two custom [Bazzite](https://bazzite.gg) images, built and signed by GitHub Actions, published to GHCR, and auto-rebuilt daily on top of the latest upstream Bazzite.

Both variants live in one GHCR package — `ghcr.io/otonm/bazzite-custom` — under different tags:

| Tag | Base image | Desktop / GPU | Built from |
|---|---|---|---|
| `:latest` | `bazzite-gnome-nvidia:stable` | GNOME / NVIDIA | `Containerfile` + `build_files/build.sh` |
| `:beelink` | `bazzite:stable` | KDE / AMD (no nvidia) | `Containerfile.beelink` + `build_files/build-beelink.sh` |

**`:latest`** — Steam, Lutris, Waydroid removed; Tailscale enabled.

**`:beelink`** — for Beelink (and other AMD) mini-PCs: KDE Plasma, full AMD CPU+iGPU stack, no nvidia. Adds AMD diagnostic tools (`radeontop`, `nvtop`, `vulkan-tools`, `libva-utils`). **Razer Basilisk V3 Pro** support is a one-command post-install step (`ujust install-openrazer` — see below). Removes Steam, Lutris, Waydroid, and the default launcher Flatpak (ProtonUp — reinstallable from Flathub). The Discourse community launcher is removed. Tailscale enabled.

---

## How it works

- **One matrix, both images** — `.github/workflows/build.yml` builds and signs both tags from `main` in a matrix. GitHub runs scheduled workflows only on the **default branch**, so building both from `main` is what lets both auto-rebuild.
- **OpenRazer** — not baked in. Its kernel module is DKMS-only and can only build against the running kernel (impossible in a build container), so the image leaves Razer support to Bazzite's supported `ujust install-openrazer`, run once after install.
- **Signing** — each image is signed with cosign (`cosign.pub` is committed; the private key lives in the `SIGNING_SECRET` repo secret).

### Automatic updates

- **Image-level (this repo):** the daily cron in `build.yml` (`0 6 * * *`) rebuilds **both** tags on the newest upstream Bazzite — kernel, drivers, security fixes.
- **System-level (your machine):** Bazzite auto-updates installed systems via `ublue-update` + staged `bootc`/`rpm-ostree` upgrades, on by default. Force a check with `ujust update`; inspect the timer with `systemctl status ublue-update.timer`.

---

## Building the image

### Via GitHub Actions (normal path)

Push to `main`, or trigger **Actions → Build container image → Run workflow**. On a green run both tags are published:

```
ghcr.io/otonm/bazzite-custom:latest
ghcr.io/otonm/bazzite-custom:beelink
```

(Pull requests build but do not push — safe for review.)

### Locally with podman

Requires `podman` and [`just`](https://github.com/casey/just).

```bash
just build                # default (GNOME/NVIDIA) -> localhost/bazzite-custom:latest
just build-beelink        # beelink  (KDE/AMD)     -> localhost/bazzite-custom:beelink
```

---

## Building an installer ISO

The ISO is an Anaconda installer produced by [bootc-image-builder](https://github.com/osbuild/bootc-image-builder). It embeds the chosen image and, on first boot, points the installed system at the registry tag for updates (see the kickstart in `disk_config/iso-kde.toml` / `iso-gnome.toml`).

### Option A — GitHub Actions (recommended)

1. Make sure the image is published first (the build above is green).
2. Go to **Actions → Build disk images → Run workflow**, choose platform **amd64**.
3. When it finishes, download the artifact from the run:
   - **`beelink-anaconda-iso`** → the Beelink/KDE installer ISO
   - `default-anaconda-iso` → the GNOME/NVIDIA installer ISO
   - (`*-qcow2` artifacts are VM disk images, not installers.)

### Option B — Locally with podman + just

Requires `podman`, `just`, and enough free disk (~20 GB). Build the container first, then the ISO:

```bash
# Beelink / KDE
just build-beelink
just build-iso-beelink localhost/bazzite-custom beelink
# -> output/bootiso/install.iso

# GNOME / NVIDIA
just build
just build-iso-gnome localhost/bazzite-custom latest
# -> output/bootiso/install.iso
```

You can smoke-test an ISO in a VM without writing it to USB:

```bash
just run-vm-iso localhost/bazzite-custom beelink   # opens a browser-based QEMU console
```

---

## Installing the system from the ISO

1. **Write the ISO to a USB stick** (replace `/dev/sdX` with your USB device — check with `lsblk`):

   ```bash
   sudo dd if=output/bootiso/install.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```

   Or use [Fedora Media Writer](https://fedoraproject.org/workstation/download), [Impression](https://flathub.org/apps/io.gitlab.adhami3310.Impression), or Ventoy.

2. **Boot the target machine from the USB** (you may need to disable Secure Boot, or enroll the ublue/akmods MOK key when prompted).

3. **Run through the Anaconda installer** — pick disk and timezone, create your user, install, then reboot and remove the USB. The installer lays down the embedded image and sets the system to track `ghcr.io/otonm/bazzite-custom:beelink` (or `:latest`) for future updates.

4. **First boot:**

   ```bash
   # Tailscale (both variants — already enabled, just authenticate)
   sudo tailscale up

   # Razer Basilisk V3 Pro (beelink only) — install OpenRazer + a GUI, then reboot
   ujust install-openrazer   # choose "Polychromatic" when prompted
   ```

   `ujust install-openrazer` adds the OpenRazer repo, layers `openrazer-daemon` (building the module against your running kernel), adds you to the `plugdev` group, and installs the Polychromatic Flatpak. Reboot, then launch **Polychromatic** to configure the mouse.

---

## Rebasing an existing Bazzite / Fedora Atomic system

If you already run Bazzite and just want to switch to one of these images, rebase in two steps (the first pulls in the signing key, the second switches to the verified signed image):

```bash
# Beelink (KDE/AMD). For the GNOME/NVIDIA image, use :latest instead of :beelink.
rpm-ostree rebase ostree-unverified-registry:ghcr.io/otonm/bazzite-custom:beelink
systemctl reboot

rpm-ostree rebase ostree-image-signed:docker://ghcr.io/otonm/bazzite-custom:beelink
systemctl reboot
```

Confirm:

```bash
rpm-ostree status   # should show ostree-image-signed:docker://ghcr.io/otonm/bazzite-custom:beelink
```

---

## Razer Basilisk V3 Pro (beelink)

- OpenRazer is **not baked into the image** — its kernel module is DKMS-only and can only build against the running kernel, which doesn't exist in a build container. Use Bazzite's supported recipe once, after install:
  ```bash
  ujust install-openrazer   # choose Polychromatic when prompted, then reboot
  ```
  This adds the OpenRazer repo, layers `openrazer-daemon` (DKMS builds the module against your real kernel), adds you to the `plugdev` group, and installs the **Polychromatic** GUI Flatpak.
- The mouse works as a normal HID mouse out of the box; the above adds RGB/DPI/button control.
- OpenRazer controls the mouse over **wired USB or the 2.4 GHz dongle** (this mouse is PID `1532:00AB`) — **not** over Bluetooth.

---

## Maintenance

### Signing key

Container signing is required — builds fail without it. The keypair was created with `cosign generate-key-pair` (no password); `cosign.pub` is committed, and the contents of `cosign.key` are stored as the repo secret **`SIGNING_SECRET`** (Settings → Secrets and variables → Actions). Never commit `cosign.key` (it's in `.gitignore`).

### Template sync (wei/pull)

`.github/pull.yml` keeps the build infrastructure in sync with upstream [`ublue-os/image-template`](https://github.com/ublue-os/image-template) via the [Pull app](https://github.com/apps/pull), opening a PR (`mergeMethod: merge`) rather than overwriting customisations. It also generates periodic activity that keeps the scheduled cron from being suspended after 60 days of inactivity.

---

## Repository layout

```
bazzite-custom/
├── .github/workflows/
│   ├── build.yml             # matrix build + sign + push BOTH tags (daily cron + push + dispatch)
│   └── build-disk.yml        # build QCOW2 + ISO for both variants (manual dispatch)
├── build_files/
│   ├── build.sh              # default (GNOME/NVIDIA) customisations
│   └── build-beelink.sh      # beelink (KDE/AMD) customisations
├── disk_config/
│   ├── disk.toml             # QCOW2/raw filesystem config
│   ├── iso-gnome.toml        # Anaconda ISO config — kickstart switches to :latest
│   └── iso-kde.toml          # Anaconda ISO config — kickstart switches to :beelink
├── Containerfile             # default image (FROM bazzite-gnome-nvidia)
├── Containerfile.beelink     # beelink image (FROM bazzite:stable)
├── Justfile                  # local build / ISO / VM recipes
├── cosign.pub                # public signing key (committed)
└── cosign.key                # private key — NEVER commit (gitignored)
```

---

## Troubleshooting

**Razer mouse not detected.** Confirm it's connected via the dongle or cable (not Bluetooth), that you ran `sudo usermod -aG plugdev $USER` and re-logged in, and that your PID shows up: `lsusb | grep 1532`. If the kernel module is missing after an upstream kernel bump, re-run `ujust install-openrazer` on the running system.

**Build fails at `dnf5 remove`.** A package name may differ on the base image. Verify against the live image and adjust the relevant `build*.sh`:

```bash
podman run --rm ghcr.io/ublue-os/bazzite:stable rpm -qa | grep -iE 'steam|lutris|sunshine'
```

**System not picking up a new image.** Run `ujust update` (or `rpm-ostree upgrade`) to force an immediate check.

**Scheduled builds stopped.** GitHub suspends cron workflows after 60 days of inactivity; wei/pull activity normally prevents this. Otherwise push a commit or run the workflow manually.
