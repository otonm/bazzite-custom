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
- **OpenRazer is deliberately never baked in** — its DKMS module can only build against a running kernel. Left to the post-install `ujust install-openrazer`. Don't try to layer it at build time.
- Both scripts `systemctl enable tailscaled` (preinstalled but disabled in the base).
- **Both tags build from `main`** (via `build.yml`'s matrix) because GitHub runs `cron` workflows only on the default branch — that's what keeps both auto-rebuilding daily. Don't move a variant to its own branch.
- Signing is mandatory (builds fail without it): `cosign.pub` is committed, the private key is the `SIGNING_SECRET` repo secret, `cosign.key` is gitignored — never commit it.

## CI workflows (`.github/workflows/`)

- **`build.yml`** — matrix build + sign + push both tags. Triggers: push to `main`, daily cron, dispatch, PR (PRs build but don't push/sign).
- **`build-disk.yml`** — dispatch build of the amd64 Anaconda installer ISOs (amd64-only, ISO-only) via `bootc-image-builder`. `iso-gnome.toml` → `:latest`, `iso-kde.toml` → `:beelink`.
- **`dependabot-automerge.yml`** — auto-merges Dependabot PRs.

## Commands (local, via `just` + `podman`)

```bash
just build                                       # :latest  -> localhost/bazzite-custom:latest
just build-beelink                               # :beelink -> localhost/bazzite-custom:beelink
just build-iso-gnome localhost/bazzite-custom latest    # ISO -> output/bootiso/install.iso
just build-iso-beelink localhost/bazzite-custom beelink
just run-vm-iso localhost/bazzite-custom beelink # smoke-test an ISO in a QEMU VM
just check      # Justfile syntax   | just lint = shellcheck *.sh | just clean = remove artifacts
```

No test suite — verification is `bootc container lint` (inside the build) plus a successful `just build`.

## Working conventions

- **Keep only `main`.** After any branch is merged, delete it (local and remote) so `main` is the sole branch. Never leave feature/topic branches behind.
- **Always commit and push all changes** when done. `main` is protected (required status checks), so pushing means: branch → commit → push → open a PR → merge it → delete the branch. Don't leave work uncommitted.
