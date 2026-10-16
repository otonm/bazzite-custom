# CLAUDE.md

Build definition for two custom Bazzite (bootc) images, `:latest` (GNOME/NVIDIA) and `:beelink` (KDE/AMD), published to `ghcr.io/otonm/bazzite-custom`. All customization lives in `build_files/*.sh`; the Containerfiles are thin wrappers.

## Building & verifying

No local `podman`/`just` and no tests. Validate changes by opening a PR — CI builds both variants and runs `bootc container lint`.

## Conventions

- **Cross-variant changes go in the shared scripts** (`common.sh`, `fix-iso-gpgcheck.sh`, `setup-signing.sh`, `cleanup.sh`), not in both build scripts. `cleanup.sh` must stay last.
- **`fix-iso-gpgcheck.sh` must run after every repo is added.** bootc-image-builder resolves `gpgkey=file://` against its own root, so any repo with a local key breaks the ISO build ([bib#1188](https://github.com/osbuild/bootc-image-builder/issues/1188)).
- **Anything installing to `/opt` needs relocating.** `/opt` → `/var/opt` on bootc, and `/var` is wiped at commit. See the Brave handling in `common.sh`.
- **Unblocking a Flatpak takes two lists:** `/usr/share/ublue-os/flatpak-blocklist` (runtime block) and `/usr/share/ublue-os/bazzite/flatpak/install` (default install list). Removing the RPM alone isn't enough.
- **`/etc/skel` edits only affect new users**; existing homes must be fixed by hand.
- **Kernel modules can't use DKMS/`ujust` at runtime** (rpm-ostree sandboxes `%posttrans` with read-only `/var`). Build them at image-build time against the image's kernel, as OpenRazer does. Its `sed` guard patch ([openrazer#2821](https://github.com/openrazer/openrazer/issues/2821)) can be dropped once upstream fixes it.
- **RustDesk must be the `unattended-wayland` `.deb`.** The Fedora RPM lacks DRM capture, so it would prompt for consent on every connection. Bump `RD_VER` and `RD_SHA256` together. It's not an RPM, so it never appears in the release-notes package diff. Never bake its password or config into the image.
- **Signing:** never commit `cosign.key` (the private key is the `SIGNING_SECRET` secret). `setup-signing.sh` must stay in both builds, or machines can't use the `ostree-image-signed:` rebase.

## CI gotchas

- **Both tags build from `main`.** GitHub runs cron only on the default branch, so never move a variant to its own branch.
- **Merge PRs with squash.** On merge, `build.yml` parses the PR number from the squash commit to promote the PR's staging image (`:<variant>-pr-<N>`) instead of rebuilding. Without it, the merge falls back to a full rebuild.
- **Keep new values out of the build matrix.** Matrix values become job names, which are the required status-check names; changing them blocks merges.
- **Release notes: never date-match Bazzite releases against our build date** to fill a missing `dev.otonm.base.version` label. It silently drops releases; report the base as unknown instead.
- **`build-disk.yml` builds the ISO from the published GHCR image**, not the branch, so a fix reaches the ISO only after merge and republish.

## Working conventions

- **Keep only `main`.** `main` is protected, so work goes branch → commit → push → PR → merge → delete the branch (local and remote).
- **Always commit and push** finished work.
