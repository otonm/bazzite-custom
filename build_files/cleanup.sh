#!/bin/bash

# Shared final step for BOTH images. Runs last (after setup-signing.sh) and
# before the Containerfile's `bootc container lint`. Flushes build-time cruft and
# commits the container layer — the BuildKit cache mounts only cover /var/cache
# and /var/log, so anything scripts wrote elsewhere under /var would otherwise
# leak into the image. On bootc, /var is runtime-populated and expected empty.

set -euo pipefail
trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG
log() { echo "=== $* ==="; }

log "Cleaning package cache"
dnf5 clean all

log "Flushing build-time /var"
# Remove everything under /var except the cache mount, then restore /var/tmp.
find /var/* -maxdepth 0 -type d \! -name cache -exec rm -fr {} \;
mkdir -p /var/tmp
chmod -R 1777 /var/tmp

log "Committing container"
ostree container commit
