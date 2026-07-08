# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Not an application — a build definition for two custom [Bazzite](https://bazzite.gg) OS images (bootc/OSTree Fedora Atomic). There is no runtime code or unit tests. GitHub Actions builds, signs, and publishes both images to GHCR (`ghcr.io/otonm/bazzite-custom`); users rebase their machines onto them.

| Tag | Containerfile | Build script | Base image | Desktop / GPU |
|---|---|---|---|---|
| `:latest` | `Containerfile` | `build_files/build.sh` | `bazzite-gnome-nvidia:stable` | GNOME / NVIDIA |
| `:beelink` | `Containerfile.beelink` | `build_files/build-beelink.sh` | `bazzite:stable` | KDE / AMD (no nvidia) |

## Architecture

Each Containerfile is a thin shell: stage `build_files/` via `FROM scratch AS ctx`, `FROM` the Bazzite base, run the one build script, then `bootc container lint`. **All customization lives in `build_files/*.sh`, not the Containerfiles.** The two scripts mirror each other — keep them consistent. Non-obvious rules:

- Removing an RPM is not enough to let a user reinstall the Flatpak. Bazzite has two separate lists: `/usr/share/ublue-os/flatpak-blocklist` (runtime block — `sed`-strip to unblock Steam/Lutris) and `/usr/share/ublue-os/bazzite/flatpak/install` (default install list — strip to stop shipping while leaving it Flathub-installable).
- **OpenRazer is baked into the `:beelink` image** (built from source at image-build time, not layered at runtime). `ujust install-openrazer` cannot work here for two independent reasons: (1) rpm-ostree runs the DKMS `%posttrans` in a sandbox with read-only `/var`, so `dkms install` can't write `/var/lib/dkms` ([bazzite#5084](https://github.com/ublue-os/bazzite/issues/5084)); and (2) OpenRazer 3.12.4 doesn't compile on the `-ogc` 7.0.9 kernel — its guard enables the 6-arg `hid_report_raw_event()` only at 7.0.10, but this kernel backported it at 7.0.9 ([openrazer#2821](https://github.com/openrazer/openrazer/issues/2821)). The build script sidesteps both: at *build* time `/var` is writable and `kernel-devel`/`gcc`/`make` already ship in the base, so it installs the `-dkms` source with `tsflags=noscripts`, `sed`-patches the guard, `make`s the four `.ko`s against the image's own kernel into `/usr/lib/modules/$KVER/extra/openrazer`, and `depmod`s. The module is rebuilt every image build so it always matches the kernel. The `sed` guard patch is a no-op once upstream ships a fix — drop it then. `openrazer-daemon` also refuses to start unless the user is in `plugdev`, which on atomic isn't in `/etc/group` (so the `gpasswd` it suggests fails); the baked `openrazer-plugdev.service` (`build_files/openrazer-plugdev-setup`) seeds the group and adds human users at boot, so no manual step is needed.
- Both scripts `systemctl enable tailscaled` (preinstalled but disabled in the base).
- **`:beelink` extras (not in `:latest`):** removes the Steam autostart shipped in `/etc/skel/.config/autostart/steam.desktop` (Steam is removed from this image); sets firewalld `DefaultZone=trusted` in `/etc/firewalld/firewalld.conf` (trusted-LAN mini-PC).
- **Both tags build from `main`** (via `build.yml`'s matrix) because GitHub runs `cron` workflows only on the default branch — that's what keeps both auto-rebuilding daily. Don't move a variant to its own branch.
- Signing is mandatory (builds fail without it): `cosign.pub` is committed, the private key is the `SIGNING_SECRET` repo secret, `cosign.key` is gitignored — never commit it. Both Containerfiles `COPY cosign.pub` into the build context and both build scripts run the shared `build_files/setup-signing.sh`, which bakes the pubkey (`/etc/pki/containers/otonm-bazzite-custom.pub`) + a `registries.d` entry + a `policy.json` transport entry into the image. Without this the base only trusts ublue-os' keys, so the README's `ostree-image-signed:` rebase has no policy to verify against and machines stay on `ostree-unverified-registry`.
- **`file://` GPG keys break the ISO build.** `bootc-image-builder`'s depsolve runs isolated and resolves `gpgkey=file:///…` against its *own* root, not the image's, so any repo shipping a local key (Bazzite's **Terra**; **rpmfusion** on beelink) fails the anaconda-iso build with `Curl error (37) … cannot depsolve` ([bib#1188](https://github.com/osbuild/bootc-image-builder/issues/1188), archived/unfixed). Both scripts end with a loop that sets `gpgcheck=0` and comments out the `file://` key on such repos — **keep it last** (after all repos are added) and mirrored. If you add a repo with a local key, this already covers it; if the ISO still fails on a new repo, extend that loop.

## CI workflows (`.github/workflows/`)

- **`build.yml`** — matrix build + sign + push both tags. Triggers: push to `main`, daily cron, dispatch, PR (PRs build but don't push/sign).
- **`build-disk.yml`** — dispatch build of the amd64 Anaconda installer ISOs (amd64-only, ISO-only) via `bootc-image-builder`. `iso-gnome.toml` → `:latest`, `iso-kde.toml` → `:beelink`. **It pulls the already-published GHCR image, not the branch's Containerfile** — so a build-script fix only reaches the ISO after it's merged and `build.yml` has republished the tag. Dispatching before the republish tests the *old* image. Output: `output/bootiso/install.iso` per variant (job artifacts `default-anaconda-iso` / `beelink-anaconda-iso`); optional S3 upload via `upload-to-s3=true`.
- **`dependabot-automerge.yml`** — auto-merges Dependabot PRs.

## Building & verifying

No local build tooling here (`podman`/`just` are not installed) and no test suite. Building, signing, and verification all happen in CI: `bootc container lint` runs inside every build, and PRs run `build.yml` without pushing — open a PR and let the build workflow validate the change. (`Justfile` recipes exist for contributors who do have `podman`, but don't rely on running them in this environment.)

## Working conventions

- **Keep only `main`.** After any branch is merged, delete it (local and remote) so `main` is the sole branch. Never leave feature/topic branches behind.
- **Always commit and push all changes** when done. `main` is protected (required status checks), so pushing means: branch → commit → push → open a PR → merge it → delete the branch. Don't leave work uncommitted.
