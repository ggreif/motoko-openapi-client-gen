#!/bin/bash
# Regenerate Motoko client from TMDb API OpenAPI spec
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CONFIG="$REPO_ROOT/bin/configs/motoko-tmdb.yaml"
GENERATED="$SCRIPT_DIR/generated"

cd "$REPO_ROOT"

echo "Generating Motoko client from TMDb API OpenAPI spec..."

# Use the out-of-tree Motoko plugin against nixpkgs's vanilla
# openapi-generator-cli JAR.  Override OPENAPI_GENERATOR_JAR /
# MOTOKO_PLUGIN_JAR if either lives elsewhere on your system.
OPENAPI_GENERATOR_JAR="${OPENAPI_GENERATOR_JAR:-$(command -v openapi-generator-cli >/dev/null && readlink -f "$(dirname "$(command -v openapi-generator-cli)")/../share/java/openapi-generator-cli.jar")}"
MOTOKO_PLUGIN_JAR="${MOTOKO_PLUGIN_JAR:-$REPO_ROOT/modules/motoko-client-plugin/target/motoko-client-plugin-1.0.0-SNAPSHOT.jar}"

[ -r "$OPENAPI_GENERATOR_JAR" ] || { echo "openapi-generator-cli.jar not found at $OPENAPI_GENERATOR_JAR"; exit 1; }
[ -r "$MOTOKO_PLUGIN_JAR" ] || { echo "motoko-client-plugin JAR not found at $MOTOKO_PLUGIN_JAR — run 'nix develop --command mvn -DskipTests package' in modules/motoko-client-plugin/"; exit 1; }

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

# --- skill / SKILL.md ---
# Two mutually-exclusive ways to declare the skill in the generator YAML:
#   skillFile: <path>     (relative to the YAML's directory)
#   skill: |              (inline YAML literal block)
SKILL_FILE=$(grep -E '^[[:space:]]*skillFile:' "$CONFIG" | head -1 | sed 's/^[[:space:]]*skillFile:[[:space:]]*//; s/[[:space:]]*$//' || true)
SKILL_INLINE=$(awk '
  /^[[:space:]]*skill:[[:space:]]*\|[-+]?[[:space:]]*$/ {
    in_block = 1; indent = ""; next
  }
  in_block {
    if (indent == "") {
      if (match($0, /^[[:space:]]+/) == 0) { in_block = 0; next }
      indent = substr($0, 1, RLENGTH)
    }
    if ($0 != "" && substr($0, 1, length(indent)) != indent) {
      in_block = 0; next
    }
    print substr($0, length(indent) + 1)
  }
' "$CONFIG")
if [ -n "$SKILL_FILE" ] && [ -n "$SKILL_INLINE" ]; then
  echo "skill: cannot set both 'skillFile:' and 'skill: |' — they are mutually exclusive" >&2
  exit 1
fi
SKILL_OUT="$GENERATED/SKILL.md"
SKILL_FROM=""
if [ -n "$SKILL_FILE" ]; then
  CONFIG_DIR="$(dirname "$CONFIG")"
  SKILL_SRC="$CONFIG_DIR/$SKILL_FILE"
  if [ ! -f "$SKILL_SRC" ]; then
    echo "skill: $SKILL_SRC not found" >&2
    exit 1
  fi
  cp "$SKILL_SRC" "$SKILL_OUT"
  SKILL_FROM="skillFile: $SKILL_FILE"
elif [ -n "$SKILL_INLINE" ]; then
  printf '%s\n' "$SKILL_INLINE" > "$SKILL_OUT"
  SKILL_FROM="inline 'skill: |' block"
fi
if [ -n "$SKILL_FROM" ]; then
  sed -i.bak 's|files = \["src/Config.mo",|files = ["SKILL.md", "src/Config.mo",|' "$GENERATED/mops.toml"
  rm -f "$GENERATED/mops.toml.bak"
  echo "skill: wrote SKILL.md from $SKILL_FROM, patched mops.toml"
fi

echo "Client generation complete!"
echo "Generated files in: $GENERATED/"
