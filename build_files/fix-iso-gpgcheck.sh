#!/bin/bash

# Shared by build.sh and build-beelink.sh. MUST run after every repo has been
# added (Terra on both; rpmfusion + Brave on beelink; Brave on latter — Brave's
# key is https so it's a no-op here, but keep this LAST so any future file://
# repo is covered).

set -euo pipefail
trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG
log() { echo "=== $* ==="; }

log "Working around bootc-image-builder file:// gpgkey ISO depsolve"
# bootc-image-builder's ISO depsolve runs isolated and cannot read
# gpgkey=file:// keys from inside the image (osbuild/bootc-image-builder#1188 —
# archived/unfixed). Disable gpgcheck on any repo whose key is a local file://
# path so the anaconda-iso depsolve doesn't try — and fail — to fetch it. Only
# affects manual dnf layering on the installed system; the image is cosign-signed
# and its packages were already GPG-verified at build time.
for repo in /etc/yum.repos.d/*.repo; do
    if grep -q 'gpgkey=file://' "${repo}"; then
        sed -i \
            -e 's/^gpgcheck=1/gpgcheck=0/' \
            -e 's/^repo_gpgcheck=1/repo_gpgcheck=0/' \
            -e 's|^gpgkey=file://|#gpgkey=file://|' \
            "${repo}"
    fi
done
