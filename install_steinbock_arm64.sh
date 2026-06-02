#!/usr/bin/env bash
set -euo pipefail

# install_steinbock_arm64.sh
# Purpose: Build and set up Steinbock (ARM64) on Apple Silicon (M1/M2/M4) using Docker.
# Usage: bash install_steinbock_arm64.sh
#
# What it does:
#  1) Checks Docker availability
#  2) Clones Steinbock if missing
#  3) Builds an ARM64 image via buildx
#  4) Sanity checks the CLI
#  5) (Optional) Adds a 'steinbock' convenience alias to ~/.zshrc

REPO_URL="https://github.com/BodenmillerGroup/steinbock.git"
REPO_DIR="${HOME}/steinbock"
IMAGE_TAG="steinbock-arm64"

echo ">>> [1/6] Checking Docker..."
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker is not installed or not on PATH."
  echo "Install Docker Desktop for Mac, launch it once, then re-run this script."
  exit 1
fi

# Ensure Docker daemon is reachable
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon not reachable. Please start Docker Desktop and try again."
  exit 1
fi

echo ">>> [2/6] Ensuring buildx is available..."
if ! docker buildx version >/dev/null 2>&1; then
  echo "ERROR: Docker buildx is unavailable. Update Docker Desktop to a recent version."
  exit 1
fi

echo ">>> [3/6] Cloning Steinbock repo (if needed) -> ${REPO_DIR}"
if [ ! -d "${REPO_DIR}/.git" ]; then
  git clone "${REPO_URL}" "${REPO_DIR}"
else
  echo "Repo already exists. Pulling latest..."
  git -C "${REPO_DIR}" pull --ff-only || true
fi

echo ">>> [4/6] Building ARM64 Docker image: ${IMAGE_TAG}"
cd "${REPO_DIR}"
docker buildx build --platform linux/arm64 -t "${IMAGE_TAG}" --load .

echo ">>> [5/6] Sanity check Steinbock CLI inside the image"
docker run --rm --entrypoint steinbock "${IMAGE_TAG}" --version
docker run --rm --entrypoint steinbock "${IMAGE_TAG}" --help | sed -n '1,40p'

# Offer to add a convenience alias
ZSHRC="${HOME}/.zshrc"
ALIAS_LINE="alias steinbock='docker run --rm --entrypoint steinbock -v \"\$PWD\":/data ${IMAGE_TAG}'"

echo ">>> [6/6] Creating a convenience alias (optional)"
if [ -f "${ZSHRC}" ]; then
  if ! grep -Fq "${ALIAS_LINE}" "${ZSHRC}"; then
    {
      echo ""
      echo "# Added by install_steinbock_arm64.sh on $(date)"
      echo "${ALIAS_LINE}"
    } >> "${ZSHRC}"
    echo "Alias added to ${ZSHRC}. Open a new terminal or run: source ${ZSHRC}"
  else
    echo "Alias already present in ${ZSHRC}."
  fi
else
  echo "Note: ${ZSHRC} not found. Create it and add this alias for convenience:"
  echo "${ALIAS_LINE}"
fi

echo ">>> Done. You can now run Steinbock like:"
echo "    docker run --rm --entrypoint steinbock -v \"\$PWD\":/data ${IMAGE_TAG} --help"
echo "or (after opening a new terminal):"
echo "    steinbock --help"
