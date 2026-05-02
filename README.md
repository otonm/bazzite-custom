# Custom Bazzite Image Setup Guide

Custom image based on `bazzite-gnome-nvidia` with Steam, Lutris, and Waydroid removed.
Built and published via GitHub Actions to GHCR, auto-rebuilds when the upstream Bazzite image updates.

---

## Overview

The approach uses [`ublue-os/image-template`](https://github.com/ublue-os/image-template) as a starting point. The workflow:

1. Your GitHub repo holds a `Containerfile` and `build.sh`
2. GitHub Actions builds a new OCI image and pushes it to GHCR daily
3. Each build pulls the latest `bazzite-gnome-nvidia:stable` digest, so upstream changes are automatically incorporated
4. `wei/pull` keeps the build infrastructure (GitHub Actions workflow files) in sync with the upstream template
5. Your running system rebases to your custom image and updates normally via Bazzite's built-in update mechanism

---

## Prerequisites

- A GitHub account
- `cosign` installed locally ([install instructions](https://docs.sigstore.dev/cosign/system_config/installation/))
- A machine running Bazzite (or any Fedora Atomic desktop) for the final rebase step

---

## Step 1 — Create the repository

1. Go to [https://github.com/ublue-os/image-template](https://github.com/ublue-os/image-template)
2. Click **Use this template** → **Create a new repository**
3. Name it whatever you want (e.g. `my-bazzite`). Keep all other settings as-is.
4. Go to the **Actions** tab of the new repo and click the button to enable workflows.
5. Clone the repo locally:

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME
cd YOUR_REPO_NAME
```

---

## Step 2 — Generate cosign signing keys

Container signing is required — builds will fail without it.

```bash
cosign generate-key-pair
# Do NOT enter a password when prompted, just press Enter.
# This produces cosign.key (private) and cosign.pub (public).
```

Add the private key to GitHub:

- Go to your repo → **Settings** → **Secrets and Variables** → **Actions**
- Click **New repository secret**
- Name: `SIGNING_SECRET`
- Value: paste the full contents of `cosign.key`

Commit the public key (never commit `cosign.key`):

```bash
git add cosign.pub
# Do NOT git add cosign.key
```

---

## Step 3 — Edit the Containerfile

The template uses a multi-stage build pattern where `build_files` are mounted into the build context via a `scratch` stage rather than copied into the final image layer. Only the base image `FROM` line needs to change:

```dockerfile
# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bazzite-gnome-nvidia:stable

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
```

The `scratch AS ctx` stage holds your `build_files` and mounts them at `/ctx` during the `RUN` step without adding them as a layer in the final image. The `--mount=type=cache` directives prevent dnf cache directories from bloating the image layer. `bootc container lint` at the end catches any writes to ostree-managed paths that would silently break on deploy.

---

## Step 4 — Edit build.sh

This is where all package customisation lives. The file is `build_files/build.sh`. Note the ordering convention: remove unwanted packages first, then install new ones, then clean.

```bash
#!/bin/bash

set -eoux pipefail

### Remove gaming packages not wanted in this image
dnf5 remove -y --no-autoremove \
    steam \
    steam-devices \
    lutris

# Waydroid is not present on Nvidia builds — suppress failure if absent
dnf5 remove -y --no-autoremove waydroid 2>/dev/null || true

### Install packages / enable services
dnf5 install -y tmux

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

dnf5 clean all
```

**Why remove before install:** if a remove fails mid-run, the install has not yet dirtied the layer. It also makes intent clearer — strip what is unwanted, then add what is needed.

**Why `--no-autoremove`:** DNF5 would otherwise cascade-remove auto-installed dependencies. This flag restricts removal to only the named packages, protecting shared libraries used by other parts of the image.

**Why `|| true` for waydroid:** Older Bazzite documentation marked Waydroid as unavailable on Nvidia builds. The package may not be present, so the command is allowed to fail silently.

**Why edit the flatpak-blocklist:** Bazzite ships `/usr/share/ublue-os/flatpak-blocklist` which `bazzite-flatpak-manager` reads at every boot to block certain Flatpaks from Flathub. Without removing these entries, Steam and Lutris would still be blocked from Flathub installation even after the RPMs are removed. Omit the `sed` lines if you want them blocked entirely.

---

## Step 5 — Configure the build workflow

The `on:` triggers in the workflow are already correct as-is from the template — `pull_request` builds without pushing (safe for review), the daily cron picks up upstream Bazzite changes, `push` to `main` triggers on your own changes, and `workflow_dispatch` allows manual runs.

The one cleanup worth making is in the `concurrency` block. The template references `inputs.brand_name` and `inputs.stream_name` which are only populated for `workflow_call` events, not used here. They evaluate to empty strings harmlessly but leave two trailing hyphens in the group name:

```yaml
# Before (template default — works but untidy)
concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}-${{ inputs.brand_name}}-${{ inputs.stream_name }}
  cancel-in-progress: true

# After (clean)
concurrency:
  group: ${{ github.workflow }}-${{ github.ref || github.run_id }}
  cancel-in-progress: true
```

### Update the image metadata

The `env:` block at the top of `build.yml` contains metadata used for ArtifactHub listings and OCI image labels. Update the three fields that still have template defaults:

```yaml
env:
  IMAGE_DESC: "My custom Bazzite image based on bazzite-gnome-nvidia, without Steam, Lutris, and Waydroid. Tailscale enabled by default."
  IMAGE_KEYWORDS: "bootc,ublue,universal-blue,bazzite,nvidia,gnome"
  IMAGE_LOGO_URL: "https://avatars.githubusercontent.com/u/YOUR_GITHUB_USER_ID"  # your GitHub avatar, or any public image URL
  IMAGE_NAME: "${{ github.event.repository.name }}"  # leave as-is — derived from repo name automatically
  IMAGE_REGISTRY: "ghcr.io/${{ github.repository_owner }}"  # leave as-is
  DEFAULT_TAG: "latest"  # leave as-is
```

`IMAGE_LOGO_URL` only affects your listing on [artifacthub.io](https://artifacthub.io) if you choose to register there. Your GitHub avatar URL follows the pattern `https://avatars.githubusercontent.com/u/YOUR_NUMERIC_USER_ID`. Find your numeric user ID at `https://api.github.com/users/YOUR_USERNAME`.

---

## Step 6 — Set up wei/pull for template sync

`wei/pull` keeps your build infrastructure (`.github/workflows/build.yml` and related files) in sync with the upstream `ublue-os/image-template` when they push improvements.

**This is separate from tracking Bazzite image updates** — the daily cron handles that. `wei/pull` is about keeping the CI/CD tooling itself current.

### Install the app

Install the [Pull GitHub App](https://github.com/apps/pull) and grant it access to your repo.

### Add the config

Create `.github/pull.yml`:

```yaml
version: "1"
rules:
  - base: main
    upstream: ublue-os:image-template:main
    mergeMethod: merge   # creates a PR for you to review before merging
    mergeUnstable: false
```

**Use `mergeMethod: merge`, not `hardreset`.** The `hardreset` method would overwrite your `Containerfile` and `build.sh` whenever the upstream template changes. With `merge`, you get a PR that you can review and resolve conflicts against your customisations manually.

**wei/pull also replaces the keepalive workflow.** GitHub suspends scheduled workflows after 60 days of repo inactivity. Since wei/pull creates automated PRs periodically, it counts as activity and keeps the cron alive. You do not need a separate keepalive workflow.

---

## Step 7 — Verify package names on the actual image

Before pushing, confirm the package names exist in `bazzite-gnome-nvidia`. Run this against the live image:

```bash
podman run --rm ghcr.io/ublue-os/bazzite-gnome-nvidia:stable \
    rpm -qa | grep -E 'steam|lutris|waydroid'
```

Expected output should include `steam`, `steam-devices`, `lutris`. If any name differs, update `build.sh` accordingly.

---

## Step 8 — Push and verify the build

Commit and push everything:

```bash
git add Containerfile build_files/build.sh .github/workflows/build.yml .github/pull.yml cosign.pub
git commit -m "Initial setup: bazzite-gnome-nvidia without Steam, Lutris, Waydroid; Tailscale enabled"
git push
```

Go to the **Actions** tab of your repo. The workflow should trigger immediately on the push. Wait for a green checkmark — this confirms your image has been built and pushed to GHCR at:

```
ghcr.io/YOUR_USERNAME/YOUR_REPO_NAME:latest
```

---

## Step 9 — Rebase your system to the custom image

From a running Bazzite install, perform a two-step rebase. The first step installs your signing key; the second switches to the verified signed image.

```bash
# Step 1 — rebase to unsigned to pull in your signing key
rpm-ostree rebase ostree-unverified-registry:ghcr.io/YOUR_USERNAME/YOUR_REPO_NAME:latest

# Reboot
systemctl reboot

# Step 2 — switch to the signed image
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/YOUR_USERNAME/YOUR_REPO_NAME:latest

# Reboot
systemctl reboot
```

After the second reboot, confirm with:

```bash
rpm-ostree status
# Should show: ostree-image-signed:docker://ghcr.io/YOUR_USERNAME/YOUR_REPO_NAME:latest
```

Then authenticate Tailscale:

```bash
sudo tailscale up
# Follow the URL printed to add this device to your tailnet
```

---

## How updates work after setup

| What changes | How it propagates |
|---|---|
| Bazzite base image (kernel, NVIDIA drivers, packages) | Daily GHA cron rebuilds your image on top of the new `bazzite-gnome-nvidia:stable` digest |
| Your `build.sh` customisations | Re-applied on every rebuild — always baked fresh into the new layer |
| Template build infrastructure (`build.yml` etc.) | `wei/pull` opens a PR when upstream `image-template` changes |
| Your running system | Bazzite's built-in update mechanism fetches the new `:latest` from GHCR on its normal schedule |

---

## Repository file summary

```
YOUR_REPO/
├── .github/
│   ├── pull.yml                  # wei/pull config — syncs template upstream
│   └── workflows/
│       └── build.yml             # GHA workflow — daily rebuild + push to GHCR
├── build_files/
│   └── build.sh                  # YOUR CUSTOMISATIONS — mounted via scratch stage, not copied into final image
├── Containerfile                 # scratch AS ctx + FROM bazzite-gnome-nvidia:stable + calls build.sh
├── cosign.pub                    # Public signing key — committed to repo
└── Justfile                      # Change first line to your image name
```

**`cosign.key` must never be committed.** It should be in `.gitignore` by default from the template. Double-check with `git status` before pushing.

---

## Troubleshooting

**Build fails at `dnf5 remove`**
Run the package verification command from Step 7 to confirm exact names. A package not present in the base image will cause a non-zero exit unless you add `|| true`.

**`wei/pull` is overwriting my Containerfile**
Switch `mergeMethod` from `hardreset` to `merge` in `.github/pull.yml`. Never use `hardreset` when your customisation branch and the tracked branch are the same.

**Scheduled builds stop running**
GitHub suspends cron workflows after 60 days of repo inactivity. `wei/pull` prevents this by generating periodic PR activity. If you removed `wei/pull`, add a keepalive workflow or make occasional commits.

**System not picking up new image version**
Run `ujust update` or `rpm-ostree upgrade` manually. The system checks for updates on its own schedule; this forces an immediate check.