#!/usr/bin/env bash
# install-collections.sh
# Works around the ansible-core 2.12.x ansible-galaxy bug
#   (ansible/ansible #77911, #78325) that crashes while resolving the long
#   version list of large collections from Galaxy NG.
# Strategy: download PINNED artifacts directly, then install the LOCAL files.
set -euo pipefail

GALAXY="https://galaxy.ansible.com/download"
DEST="${ANSIBLE_COLLECTIONS_PATH:-$HOME/.ansible/collections}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# namespace-name-version  (versions compatible with ansible-core 2.12)
COLLECTIONS=(
  "ansible-posix-1.5.4"
  "community-general-6.6.0"
)

echo ">> Downloading collection artifacts..."
for c in "${COLLECTIONS[@]}"; do
  echo "   - ${c}.tar.gz"
  curl -fL --retry 3 --retry-delay 2 -o "${WORK}/${c}.tar.gz" "${GALAXY}/${c}.tar.gz"
done

# Optional integrity check if scripts/collections.sha256 exists
if [[ -f "${SCRIPT_DIR}/collections.sha256" ]]; then
  echo ">> Verifying checksums..."
  ( cd "$WORK" && sha256sum -c "${SCRIPT_DIR}/collections.sha256" )
fi

echo ">> Installing from local tarballs (bypasses Galaxy version query)..."
ansible-galaxy collection install "${WORK}"/*.tar.gz -p "$DEST" --no-deps --force

echo ">> Installed collections:"
ansible-galaxy collection list

# RHEL System Roles come from an RPM, not Galaxy:
if command -v dnf >/dev/null 2>&1 && grep -qiE 'red hat|rocky|almalinux' /etc/os-release; then
  echo ">> Installing rhel-system-roles RPM (redhat.rhel_system_roles)..."
  sudo dnf install -y rhel-system-roles || true
fi

echo ">> Done."
