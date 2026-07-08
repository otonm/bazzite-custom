#!/bin/bash

set -eoux pipefail

### Ship this image's OWN cosign verification config.
# The images are cosign-signed in CI (build.yml), but the Bazzite base only trusts
# ublue-os' keys — so `ostree-image-signed:docker://ghcr.io/otonm/bazzite-custom:<tag>`
# (the second, verified step of the README rebase) has no policy to check against and
# fails, leaving machines stuck on `ostree-unverified-registry`. Baking the pubkey +
# policy here makes the signed rebase work and keeps future updates signature-verified.
# Shared by build.sh and build-beelink.sh so both tags carry an identical policy.
# cosign.pub is staged into the build context by the Containerfile (`COPY cosign.pub`).

KEY_DST=/etc/pki/containers/otonm-bazzite-custom.pub
install -Dm644 /ctx/cosign.pub "${KEY_DST}"

# Read cosign sigstore attachments for our registry namespace.
cat > /etc/containers/registries.d/otonm-bazzite-custom.yaml <<'YAML'
docker:
  ghcr.io/otonm/bazzite-custom:
    use-sigstore-attachments: true
YAML

# Require a valid cosign signature for our images (mirrors ublue-os' own policy entry).
POLICY=/etc/containers/policy.json
jq --arg key "${KEY_DST}" \
    '.transports.docker["ghcr.io/otonm/bazzite-custom"] = [
        { "type": "sigstoreSigned", "keyPath": $key, "signedIdentity": { "type": "matchRepository" } }
    ]' "${POLICY}" > "${POLICY}.tmp"
mv "${POLICY}.tmp" "${POLICY}"
