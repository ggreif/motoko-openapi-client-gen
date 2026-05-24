#!/bin/bash
# Regenerate Motoko client from Spotify OpenAPI spec
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CONFIG="$REPO_ROOT/bin/configs/motoko-spotify.yaml"
GENERATED="$SCRIPT_DIR/generated"

cd "$REPO_ROOT"

echo "Generating Motoko client from Spotify OpenAPI spec..."

# Use the out-of-tree Motoko plugin against nixpkgs's vanilla
# openapi-generator-cli JAR.  Override OPENAPI_GENERATOR_JAR /
# MOTOKO_PLUGIN_JAR if either lives elsewhere on your system.
OPENAPI_GENERATOR_JAR="${OPENAPI_GENERATOR_JAR:-$(command -v openapi-generator-cli >/dev/null && readlink -f "$(dirname "$(command -v openapi-generator-cli)")/../share/java/openapi-generator-cli.jar")}"
MOTOKO_PLUGIN_JAR="${MOTOKO_PLUGIN_JAR:-$REPO_ROOT/modules/motoko-client-plugin/target/motoko-client-plugin-1.0.0-SNAPSHOT.jar}"

[ -r "$OPENAPI_GENERATOR_JAR" ] || { echo "openapi-generator-cli.jar not found at $OPENAPI_GENERATOR_JAR"; exit 1; }
[ -r "$MOTOKO_PLUGIN_JAR" ] || { echo "motoko-client-plugin JAR not found at $MOTOKO_PLUGIN_JAR — run 'mvn -DskipTests package' in modules/motoko-client-plugin/"; exit 1; }

java -cp "$OPENAPI_GENERATOR_JAR:$MOTOKO_PLUGIN_JAR" \
  org.openapitools.codegen.OpenAPIGenerator generate \
  -c "$CONFIG"

# --- mops.toml: add `ic` package ---
# icp-cli-mode clients pull management canister bindings (aaaaa-aa)
# from the `ic` mops package via `mo:ic/Types`.  The mustache
# template's [dependencies] block doesn't include it yet (back-port
# when it does), so patch in a single line under the [dependencies]
# header.
MOPS_TOML="$GENERATED/mops.toml"
if [ -r "$MOPS_TOML" ] && ! grep -qE '^ic[[:space:]]*=' "$MOPS_TOML"; then
  awk '
    /^\[dependencies\][[:space:]]*$/ { print; print "ic = \"4.0.0\""; next }
    { print }
  ' "$MOPS_TOML" > "$MOPS_TOML.new" && mv "$MOPS_TOML.new" "$MOPS_TOML"
  echo "mops.toml: added 'ic = \"4.0.0\"' to [dependencies] (icp-cli mode: mo:ic bindings for aaaaa-aa)"
fi

echo "Client generation complete!"
echo "Generated files in: $GENERATED/"
