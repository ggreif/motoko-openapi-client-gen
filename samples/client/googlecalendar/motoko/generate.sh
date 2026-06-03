#!/bin/bash
# Regenerate Motoko client from Google Calendar API OpenAPI spec
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CONFIG="$REPO_ROOT/bin/configs/motoko-googlecalendar.yaml"
GENERATED="$SCRIPT_DIR/generated"

cd "$REPO_ROOT"

echo "Generating Motoko client from Google Calendar API OpenAPI spec..."

# Use the out-of-tree Motoko plugin against nixpkgs's vanilla
# openapi-generator-cli JAR.  Override OPENAPI_GENERATOR_JAR /
# MOTOKO_PLUGIN_JAR if either lives elsewhere on your system.
OPENAPI_GENERATOR_JAR="${OPENAPI_GENERATOR_JAR:-$(command -v openapi-generator-cli >/dev/null && readlink -f "$(dirname "$(command -v openapi-generator-cli)")/../share/java/openapi-generator-cli.jar")}"
MOTOKO_PLUGIN_JAR="${MOTOKO_PLUGIN_JAR:-$REPO_ROOT/modules/motoko-client-plugin/target/motoko-client-plugin-1.0.0-SNAPSHOT.jar}"

[ -r "$OPENAPI_GENERATOR_JAR" ] || { echo "openapi-generator-cli.jar not found at $OPENAPI_GENERATOR_JAR"; exit 1; }
[ -r "$MOTOKO_PLUGIN_JAR" ] || { echo "motoko-client-plugin JAR not found at $MOTOKO_PLUGIN_JAR — run 'nix develop --command mvn -DskipTests package' in modules/motoko-client-plugin/"; exit 1; }

# --- focusApis pre-processing ---
# TMDb's spec is untagged, so every operation lands in DefaultApi.mo.
# To prune, we filter the spec itself: keep only paths whose operationId
# prefix (text before the first '-') is in the focusApis list.  Anything
# dropped from .paths is no longer reachable, so openapi-generator emits
# only the Models its remaining operations need — much smaller surface.
INPUT_SPEC="$REPO_ROOT/$(grep -E '^inputSpec:' "$CONFIG" | sed 's/^inputSpec:[[:space:]]*//; s/[[:space:]]*$//')"
FOCUS_APIS=()
IN_FOCUS=false
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*focusApis: ]]; then
    IN_FOCUS=true; continue
  fi
  if $IN_FOCUS; then
    if [[ "$line" =~ ^[[:space:]]+- ]]; then
      api=$(echo "$line" | sed 's/^[[:space:]]*- *//')
      FOCUS_APIS+=("$api")
    else
      break
    fi
  fi
done < "$CONFIG"

EFFECTIVE_SPEC="$INPUT_SPEC"
if [ ${#FOCUS_APIS[@]} -gt 0 ]; then
  echo "focusApis pruning: keeping operations whose operationId starts with: ${FOCUS_APIS[*]}"
  FOCUS_JSON=$(printf '%s\n' "${FOCUS_APIS[@]}" | jq -R . | jq -s .)
  FILTERED_SPEC=$(mktemp -t gcal-focus.XXXXXX).json
  jq --argjson focus "$FOCUS_JSON" '
    def is_op($k): ["get","post","put","delete","patch"] | index($k) != null;
    def keep($id): ($id // "") | split("-")[0] as $p | ($focus | index($p)) != null;
    .paths |= (
      with_entries(
        .value |= with_entries(
          if is_op(.key)
          then if keep(.value.operationId) then . else empty end
          else .
          end
        )
      )
      | with_entries(
          select(.value | to_entries | map(select(is_op(.key))) | length > 0)
        )
    )
  ' "$INPUT_SPEC" > "$FILTERED_SPEC"
  COUNT_OPS='def is_op($k): ["get","post","put","delete","patch"] | index($k) != null; [.paths | to_entries[] | .value | to_entries[] | select(is_op(.key))] | length'
  KEPT=$(jq "$COUNT_OPS" "$FILTERED_SPEC")
  TOTAL=$(jq "$COUNT_OPS" "$INPUT_SPEC")
  echo "  Kept $KEPT of $TOTAL operations"
  EFFECTIVE_SPEC="$FILTERED_SPEC"
fi

java -cp "$OPENAPI_GENERATOR_JAR:$MOTOKO_PLUGIN_JAR" \
  org.openapitools.codegen.OpenAPIGenerator generate \
  -c "$CONFIG" \
  -i "$EFFECTIVE_SPEC"

# --- prune stale generated files ---
# openapi-generator writes new files but never deletes ones it no longer
# emits.  After a focusApis-driven shrink, leftovers from prior wider runs
# (or from the upstream's larger surface) still sit under src/Models/.
# Use the freshly-written .openapi-generator/FILES manifest as the source
# of truth: anything under src/ that isn't listed is stale.
FILES_LIST="$GENERATED/.openapi-generator/FILES"
if [ -f "$FILES_LIST" ]; then
  KEEP=$(mktemp)
  grep -E '^src/' "$FILES_LIST" | sort -u > "$KEEP"
  REMOVED=0
  while IFS= read -r f; do
    rel=${f#$GENERATED/}
    if ! grep -qxF "$rel" "$KEEP"; then
      rm "$f"
      REMOVED=$((REMOVED + 1))
    fi
  done < <(find "$GENERATED/src" -type f -name '*.mo')
  rm -f "$KEEP"
  echo "stale-prune: removed $REMOVED .mo files not in $(basename "$FILES_LIST")"
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
