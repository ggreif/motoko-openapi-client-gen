#!/bin/bash
# Typecheck generated code

set -e
cd "$(dirname "$0")"
GEN_DIR="generated"
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

echo "Setting up dependencies (cloning repos for path deps)..."
clone_repo "https://github.com/caffeinelabs/motoko-core" "core" "refs/pull/468/head" ""
clone_repo "https://github.com/ggreif/serde" "serde" "core" "--recurse-submodules"
clone_repo "https://github.com/NatLabs/ByteUtils" "byte-utils" "refs/pull/3/head" ""

echo "Installing dependencies..."
(cd generated && npx ic-mops install)

echo ""
echo "Type checking generated client code..."

FAILED=0
PASSED=0

# Change to generated directory to run moc with correct relative paths
cd generated

for file in Models/*.mo Apis/*.mo; do
  if [ -f "$file" ]; then
    echo "Checking $file..."
    PACKAGE_FLAGS=$(npx ic-mops sources)
    if moc --check $PACKAGE_FLAGS "$file" 2>&1; then
      echo "✓ OK"
      ((PASSED++))
    else
      echo "✗ FAILED"
      ((FAILED++))
    fi
    echo ""
  fi
done

cd ..
echo "Summary: $PASSED passed, $FAILED failed"
exit $FAILED
