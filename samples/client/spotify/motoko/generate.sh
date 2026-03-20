#!/bin/bash
# Regenerate Motoko client from Spotify OpenAPI spec

set -e
cd "$(dirname "$0")"
cd ../../..  # Go to repo root

echo "Generating Motoko client from Spotify OpenAPI spec..."
./bin/generate-samples.sh bin/configs/motoko-spotify.yaml


# Temporary hack to clone GitHub dependencies for Mops publishing which doesn't support GitHub URLs.

echo "Setting up dependencies (cloning repos for path deps)..."
GEN_DIR="samples/client/spotify/motoko/generated"
DEPS="$GEN_DIR/dependencies"
mkdir -p "$DEPS"

clone_repo() {
  local url="$1"
  local dir="$2"
  local ref="${3:-}"
  local recurse="${4:-}"
  if [ -d "$DEPS/$dir/.git" ]; then
    echo "Already cloned: $dir"
    return
  fi
  echo "Cloning $dir..."
  git clone $recurse "$url" "$DEPS/$dir"
  if [ -n "$ref" ]; then
    (cd "$DEPS/$dir" && git fetch origin "$ref" && git checkout FETCH_HEAD)
  fi
}

clone_repo "https://github.com/caffeinelabs/motoko-core" "core" "refs/pull/468/head" ""
clone_repo "https://github.com/ggreif/serde" "serde" "core" "--recurse-submodules"
clone_repo "https://github.com/NatLabs/ByteUtils" "byte-utils" "refs/pull/3/head" ""

echo "Client generation complete!"
echo "Generated files in: $GEN_DIR/"
