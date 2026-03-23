#!/bin/bash
# Typecheck generated code

cd "$(dirname "$0")"

echo "Installing dependencies..."
(cd generated && npx ic-mops install)

echo ""
echo "Type checking generated client code..."

FAILED=0
PASSED=0

# Change to generated directory to run moc with correct relative paths
cd generated

for file in src/Config.mo src/Models/*.mo src/Apis/*.mo; do
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

echo ""
echo "Build testing with mops build..."
TMPBUILD=$(mktemp -d /tmp/spotify-build-test-XXXXXX)
GENERATED_ABS="$(pwd)/generated"
cat > "$TMPBUILD/mops.toml" << EOF
[toolchain]
moc = "1.3.0"

[package]
name = "spotify-build-test"
version = "0.0.1"

[dependencies]
spotify-client = "$GENERATED_ABS"

[canisters]
test = "Main.mo"
EOF
cat > "$TMPBUILD/Main.mo" << 'EOF'
import { getTrack } "mo:spotify-client/Apis/TracksApi";
persistent actor {
    public func test() : async Text { "ok" };
}
EOF
echo "Installing build test dependencies..."
(cd "$TMPBUILD" && npx ic-mops install) 2>&1

echo ""
echo "Dependency summary:"
SOURCES=$(cd "$TMPBUILD" && npx ic-mops sources 2>&1)
# Extract package names and paths, group by base name to spot multi-version deps
echo "$SOURCES" | awk '
/^--package / {
    alias=$2
    resolved=$3
    # extract resolved version from path like .mops/foo@1.2.3/src
    match(resolved, /\/([^\/]+)\/src$/, a)
    ver = a[1]
    # base name (strip @... alias qualifier)
    split(alias, parts, "@"); base=parts[1]
    aliases[base] = aliases[base] " " alias "=" ver
    count[base]++
}
END {
    for (b in aliases) {
        if (count[b] > 1)
            printf "  %-38s *** MULTI-VERSION:%s\n", b, aliases[b]
        else {
            # trim leading space
            sub(/^ /, "", aliases[b])
            printf "  %s\n", aliases[b]
        }
    }
}' | sort

echo ""
echo "Running mops build..."
if (cd "$TMPBUILD" && npx ic-mops build) 2>&1; then
    echo "✓ mops build OK"
else
    echo "✗ mops build FAILED"
    ((FAILED++))
fi
rm -rf "$TMPBUILD"

echo "Summary: $PASSED passed, $FAILED failed"
exit $FAILED
