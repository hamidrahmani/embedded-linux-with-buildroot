#!/usr/bin/env bash
set -Eeuo pipefail

# =============================================================================
# build_z2m_bundle.sh  (FINAL — with Docker Extract Mode)
#
# Supports TWO modes:
#
#   (A) Docker-extract mode (recommended):
#
#       ./build_z2m_bundle.sh \
#            --from-docker-tag 1.42.0 \
#            -b <buildroot> \
#            -n 18.20.1
#
#       → pulls ghcr.io/koenkk/zigbee2mqtt:<tag>
#       → extracts /app (prebuilt backend)
#       → removes image node_modules
#       → builds ARM node_modules + embeds ARM Node runtime
#
#   (B) Manual source mode:
#
#       ./build_z2m_bundle.sh -z /path/to/z2m_release -v <version> -n <node>
#
# =============================================================================

Z2M_DIR=""
BUILDROOT_DIR=""
Z2M_VERSION=""
NODE_VERSION="18.17.1"
ARCH="armv7"
DOCKER_TAG=""
TMP_DOCKER_DIR=""

usage() {
  cat <<EOF
Usage:
  Docker mode (recommended):
    $0 --from-docker-tag <version> -b <buildroot> -n <node-version>

  Manual mode:
    $0 -z <zigbee2mqtt dir> -b <buildroot> -v <z2m version> -n <node-version>

Example:
    $0 --from-docker-tag 1.42.0 -b ~/.../buildroot -n 18.20.1
EOF
}

# ----------------------------------------------------------------------------- 
# Parse arguments
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-docker-tag)
      DOCKER_TAG="$2"
      shift 2
      ;;
    -z)
      Z2M_DIR="$2"
      shift 2
      ;;
    -b)
      BUILDROOT_DIR="$2"
      shift 2
      ;;
    -v)
      Z2M_VERSION="$2"
      shift 2
      ;;
    -n)
      NODE_VERSION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

# ----------------------------------------------------------------------------- 
# Docker extract mode
# -----------------------------------------------------------------------------
if [[ -n "$DOCKER_TAG" ]]; then
  echo "[INFO] Docker extract mode enabled"
  echo "[INFO] Pulling ghcr.io/koenkk/zigbee2mqtt:$DOCKER_TAG ..."

  docker pull "ghcr.io/koenkk/zigbee2mqtt:$DOCKER_TAG"

  TMP_DOCKER_DIR="$(mktemp -d)"
  echo "[INFO] Created temp extraction dir: $TMP_DOCKER_DIR"

  docker create --name z2m_extract "ghcr.io/koenkk/zigbee2mqtt:$DOCKER_TAG" >/dev/null
  docker cp z2m_extract:/app "$TMP_DOCKER_DIR/z2m_release"
  docker rm z2m_extract >/dev/null

  echo "[INFO] Extracted /app into: $TMP_DOCKER_DIR/z2m_release"

  rm -rf "$TMP_DOCKER_DIR/z2m_release/node_modules"
  echo "[INFO] Deleted Alpine/musl node_modules from Docker image"

  Z2M_DIR="$TMP_DOCKER_DIR/z2m_release"
  if [[ -z "$Z2M_VERSION" ]]; then
    if command -v jq >/dev/null 2>&1; then
      Z2M_VERSION=$(jq -r '.version' "$Z2M_DIR/package.json")
    else
      Z2M_VERSION=$(grep '"version"' "$Z2M_DIR/package.json" | sed -E 's/.*"version": *"([^"]+)".*/\1/')
    fi
  fi

  echo "[INFO] Docker mode Z2M version detected: $Z2M_VERSION"
fi

# ----------------------------------------------------------------------------- 
# Manual mode sanity checks
# -----------------------------------------------------------------------------
if [[ -z "$Z2M_DIR" ]]; then
  echo "[ERROR] No Zigbee2MQTT directory. Provide -z or --from-docker-tag"
  exit 1
fi

Z2M_DIR=$(cd "$Z2M_DIR" && pwd)
WORK_DIR=$(dirname "$Z2M_DIR")

if [[ -z "$BUILDROOT_DIR" ]]; then
  echo "[WARN] Buildroot not set; bundle will not be copied automatically"
else
  BUILDROOT_DIR=$(cd "$BUILDROOT_DIR" && pwd)
fi

if [[ -z "$Z2M_VERSION" ]]; then
  echo "[ERROR] Cannot determine Zigbee2MQTT version. Use -v"
  exit 1
fi

# Paths
BUNDLE_DIR="$WORK_DIR/zigbee2mqtt-$ARCH"
OUT_TARBALL="$WORK_DIR/zigbee2mqtt-$Z2M_VERSION-$ARCH.tar.gz"
NODE_TARBALL="node-v${NODE_VERSION}-linux-armv7l.tar.xz"

echo "[INFO] ==============================================="
echo "[INFO] Z2M source   : $Z2M_DIR"
echo "[INFO] Buildroot    : ${BUILDROOT_DIR:-<none>}"
echo "[INFO] Version      : $Z2M_VERSION"
echo "[INFO] Node         : $NODE_VERSION"
echo "[INFO] Bundle dir   : $BUNDLE_DIR"
echo "[INFO] ==============================================="

# Verify dist/
if [[ ! -d "$Z2M_DIR/dist" ]]; then
  echo "[ERROR] dist/ not found — you MUST extract from Docker image"
  exit 1
fi

# ----------------------------------------------------------------------------- 
# Step 1 — Build ARM node_modules in Docker
# -----------------------------------------------------------------------------
echo "[INFO] Checking ARM emulation..."
if ! docker run --rm --platform=linux/arm/v7 alpine uname -m >/dev/null 2>&1; then
  echo "[ERROR] ARM emulation not working"
  exit 1
fi

(
  cd "$Z2M_DIR"
  echo "[INFO] Building ARM node_modules..."
  docker run --rm -it --platform=linux/arm/v7 \
    -v "$PWD":/work -w /work \
    node:18-bullseye bash -lc "
      set -Eeuo pipefail
      rm -rf node_modules
      npm ci --production || npm install --production
      node -p 'process.arch + \" / \" + process.platform'
    "
)

# ----------------------------------------------------------------------------- 
# Step 2 — Copy into bundle
# -----------------------------------------------------------------------------
rm -rf "$BUNDLE_DIR"
cp -a "$Z2M_DIR" "$BUNDLE_DIR"

# ----------------------------------------------------------------------------- 
# Step 3 — Embed ARM Node runtime
# -----------------------------------------------------------------------------
(
  cd "$WORK_DIR"
  if [[ ! -f "$NODE_TARBALL" ]]; then
    echo "[INFO] Downloading Node ARM runtime..."
    wget "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TARBALL}"
  fi

  rm -rf "node-v${NODE_VERSION}-linux-armv7l"
  tar xf "$NODE_TARBALL"
  rm -rf "$BUNDLE_DIR/node"
  mv "node-v${NODE_VERSION}-linux-armv7l" "$BUNDLE_DIR/node"
)

# ----------------------------------------------------------------------------- 
# Step 4 — Prune non-ARM binaries
# -----------------------------------------------------------------------------
echo "[INFO] Pruning invalid binaries..."
shopt -s globstar nullglob

rm -rf \
  "$BUNDLE_DIR"/node_modules/**/prebuilds/*x64* \
  "$BUNDLE_DIR"/node_modules/**/prebuilds/*arm64* \
  "$BUNDLE_DIR"/node_modules/**/prebuilds/android-* \
  "$BUNDLE_DIR"/node_modules/@serialport/bindings-cpp/prebuilds/linux-x64 \
  "$BUNDLE_DIR"/node_modules/@serialport/bindings-cpp/prebuilds/linux-arm64 \
  "$BUNDLE_DIR"/node_modules/@serialport/bindings-cpp/prebuilds/android-arm64 \
  "$BUNDLE_DIR"/node_modules/unix-dgram || true

# ----------------------------------------------------------------------------- 
# Step 5 — Create tarball
# -----------------------------------------------------------------------------
(
  cd "$WORK_DIR"
  tar -czf "$OUT_TARBALL" "$(basename "$BUNDLE_DIR")"
  echo "[INFO] Created tarball: $OUT_TARBALL"
)

# ----------------------------------------------------------------------------- 
# Step 6 — Copy to Buildroot/dl
# -----------------------------------------------------------------------------
if [[ -n "$BUILDROOT_DIR" ]]; then
  cp "$OUT_TARBALL" "$BUILDROOT_DIR/dl/"
  echo "[INFO] Copied bundle to: $BUILDROOT_DIR/dl/"
fi

# ----------------------------------------------------------------------------- 
# Step 7 — SHA
# -----------------------------------------------------------------------------
SHA=$(sha256sum "$OUT_TARBALL" | awk '{print $1}')
echo "[INFO] SHA256:"
echo "sha256  $SHA  $(basename "$OUT_TARBALL")"
echo "[INFO] Done."