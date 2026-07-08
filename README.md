# bazzite-custom

Two custom [Bazzite](https://bazzite.gg) images, built and signed by GitHub Actions, published to GHCR, and auto-rebuilt daily on top of the latest upstream Bazzite.

Both variants live in one GHCR package — `ghcr.io/otonm/bazzite-custom` — under different tags:

| Tag | Base image | Desktop / GPU | Built from |
|---|---|---|---|
| `:latest` | `bazzite-gnome-nvidia:stable` | GNOME / NVIDIA | `Containerfile` + `build_files/build.sh` |
| `:beelink` | `bazzite:stable` | KDE / AMD (no nvidia) | `Containerfile.beelink` + `build_files/build-beelink.sh` |

**`:latest`** — Steam, Lutris, Waydroid removed; Tailscale enabled.

**`:beelink`** — for Beelink (and other AMD) mini-PCs: KDE Plasma, full AMD CPU+iGPU stack, no nvidia. Adds AMD diagnostic tools (`radeontop`, `nvtop`, `vulkan-tools`, `libva-utils`). **Razer Basilisk V3 Pro** support (OpenRazer) is baked in — no post-install step (see below). Removes Steam, Lutris, Waydroid, and the default launcher Flatpak (ProtonUp — reinstallable from Flathub). The Discourse community launcher and the Steam login-autostart are removed. Firewall defaults to the `trusted` zone. Tailscale enabled.

---

## How it works

- **One matrix, both images** — `.github/workflows/build.yml` builds and signs both tags from `main` in a matrix. GitHub runs scheduled workflows only on the **default branch**, so building both from `main` is what lets both auto-rebuild.
- **OpenRazer** (`:beelink`) — baked into the image, built from source against the image's own kernel at build time. `ujust install-openrazer` can't work here (rpm-ostree's read-only-`/var` DKMS sandbox, and an OpenRazer/kernel version-guard mismatch), so the build script compiles the module directly instead. See [Razer Basilisk V3 Pro](#razer-basilisk-v3-pro-beelink).
- **Signing** — each image is signed with cosign (`cosign.pub` is committed; the private key lives in the `SIGNING_SECRET` repo secret), and each image also *ships* the matching verification policy so machines can rebase to the signed ref and have updates signature-verified.

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
2. Go to **Actions → Build disk images → Run workflow**.
3. When it finishes, download the artifact from the run:
   - **`beelink-anaconda-iso`** → the Beelink/KDE installer ISO
   - `default-anaconda-iso` → the GNOME/NVIDIA installer ISO

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
   ```

   **Razer Basilisk V3 Pro (beelink only)** — OpenRazer (daemon + kernel module) is baked into the image, and a boot service adds your user to the `plugdev` group that the daemon requires, so there's nothing to install. Just log in (the group is applied at login). Optionally install a GUI to configure the mouse: `flatpak install flathub app.polychromatic.controller` (Polychromatic) or `xyz.z3ntu.razergenie` (Razer Genie).

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

- OpenRazer is **baked into the image** — the `openrazer-daemon` and the kernel module (built from source against the image's own kernel) both ship in `:beelink`. There is no `ujust install-openrazer` step; that recipe can't work on this image (see below).
- **No manual setup.** `openrazer-daemon` refuses to run unless your user is in the `plugdev` group, and on an atomic system that group isn't in `/etc/group` (so the `sudo gpasswd -a $USER plugdev` the daemon's error suggests **fails** with "group does not exist"). A baked boot service (`openrazer-plugdev.service`) seeds `plugdev` into `/etc/group` and adds human users to it, so the daemon just works after you log in. If you ever need to do it by hand, use `sudo usermod -aG plugdev "$USER"` (which works, unlike `gpasswd`) and re-login.
- Optionally install a GUI: `flatpak install flathub app.polychromatic.controller` (**Polychromatic**) or `xyz.z3ntu.razergenie` (**Razer Genie**). The daemon is dbus-activated and enabled at login.
- The mouse works as a normal HID mouse out of the box; OpenRazer adds RGB/DPI/button control.
- OpenRazer controls the mouse over **wired USB or the 2.4 GHz dongle** (this mouse is PID `1532:00AB`) — **not** over Bluetooth.
- **Secure Boot:** the baked module is **unsigned**, so it loads only with Secure Boot **disabled** (the case on the target box). With Secure Boot enforcing, the kernel refuses unsigned modules and OpenRazer won't work until the module is signed with an enrolled MOK.
- **Why it's baked and not `ujust install-openrazer`:** two independent blockers make the runtime recipe fail on an immutable image — (1) rpm-ostree runs the DKMS `%posttrans` in a sandbox with read-only `/var`, so `dkms install` can't create `/var/lib/dkms` ([bazzite#5084](https://github.com/ublue-os/bazzite/issues/5084)); and (2) OpenRazer 3.12.4 doesn't compile on the `-ogc` 7.0.9 kernel — a version-guard off-by-one against a backported HID API change ([openrazer#2821](https://github.com/openrazer/openrazer/issues/2821)). Building at image-build time (writable `/var`, guard patched, module compiled against the image kernel) avoids both, and the module is rebuilt on every daily image so it always matches the kernel.

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
│   └── build-disk.yml        # build amd64 installer ISOs for both variants (manual dispatch)
├── build_files/
│   ├── build.sh              # default (GNOME/NVIDIA) customisations
│   └── build-beelink.sh      # beelink (KDE/AMD) customisations
├── disk_config/
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

**Razer mouse not detected / "OpenRazer daemon is not running".** The daemon needs your user in `plugdev`; the baked `openrazer-plugdev.service` handles this, but if you logged in before it ran, log out and back in. To check: `id -nG | grep plugdev` and `systemctl --user status openrazer-daemon`. If you must add it manually, use `sudo usermod -aG plugdev "$USER"` (the `gpasswd` command the daemon suggests fails on atomic). Confirm the mouse is on the dongle or cable (not Bluetooth) and shows up: `lsusb | grep 1532`. The kernel module is baked in and rebuilt on every daily image, so it always matches the running kernel — check it's loaded with `lsmod | grep razer` (or `modprobe razermouse`). If a future OpenRazer/kernel combo ever fails to build, the image build itself fails in CI (the tag simply won't update) rather than shipping a broken module.

**Build fails at `dnf5 remove`.** A package name may differ on the base image. Verify against the live image and adjust the relevant `build*.sh`:

```bash
podman run --rm ghcr.io/ublue-os/bazzite:stable rpm -qa | grep -iE 'steam|lutris|sunshine'
```

**System not picking up a new image.** Run `ujust update` (or `rpm-ostree upgrade`) to force an immediate check.

**Scheduled builds stopped.** GitHub suspends cron workflows after 60 days of inactivity; wei/pull activity normally prevents this. Otherwise push a commit or run the workflow manually.
