#!/bin/bash
# Regenerate Motoko client from Twilio Messaging API v1 OpenAPI spec

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CONFIG="$REPO_ROOT/bin/configs/motoko-twilio-messaging.yaml"
GENERATED="$SCRIPT_DIR/generated"

cd "$REPO_ROOT"

# --- mergeCommand (optional, runs before the Java generator) ---
# If the YAML declares a `mergeCommand:`, we shell out to it first to
# (re)build the merged spec at inputSpec.  The command is captured
# verbatim — paths inside it are interpreted relative to $REPO_ROOT.
# spec-merge itself lives in tools/spec-merge/ and is built by the
# top-level flake (nix build .#spec-merge → ./result/bin/spec-merge).
MERGE_COMMAND=$(awk '
  /^[[:space:]]*mergeCommand:[[:space:]]*>-?[[:space:]]*$/ {
    in_block = 1; indent = ""; next
  }
  /^[[:space:]]*mergeCommand:[[:space:]]+/ {
    sub(/^[[:space:]]*mergeCommand:[[:space:]]+/, ""); print; exit
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
' "$CONFIG" | tr '\n' ' ' | sed 's/[[:space:]]\+$//')

if [ -n "$MERGE_COMMAND" ]; then
  echo "Running spec merge: $MERGE_COMMAND"
  # If spec-merge isn't on PATH yet (devShell not entered), fall back
  # to the nix-built artifact at ./result/bin/.
  if ! command -v spec-merge >/dev/null 2>&1 && [ -x "./result/bin/spec-merge" ]; then
    MERGE_COMMAND="./result/bin/${MERGE_COMMAND}"
  fi
  eval "$MERGE_COMMAND"
fi

echo "Generating Motoko client from Twilio Messaging API v1 OpenAPI spec..."
# --skip-validate-spec is required because Twilio's two upstream specs
# share operationIds (FetchShortCode, ListShortCode) for endpoints that
# live in different APIs.  Within the generator's per-tag module
# emission this is harmless — IDs only need to be unique inside a tag —
# but the up-front validator hard-fails.  Skipping validation gates only
# the structural pre-check, not the actual codegen.
java -jar modules/openapi-generator-cli/target/openapi-generator-cli.jar generate \
  --skip-validate-spec \
  -c "$CONFIG"

# --- focusApis pruning ---
# Parse the focusApis: list from the YAML (under additionalProperties so
# README.mustache can also see it).  If absent, keep the full surface.
# Tag names match the *Api.mo filename prefix exactly.
FOCUS_APIS=()
IN_FOCUS=false
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*focusApis: ]]; then
    IN_FOCUS=true
    continue
  fi
  if $IN_FOCUS; then
    # Skip comment / blank lines inside the focusApis section so
    # inline annotations don't terminate the parse early.
    if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line//[[:space:]]/}" ]]; then
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]+- ]]; then
      api=$(echo "$line" | sed 's/^[[:space:]]*- *//' | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//')
      [ -n "$api" ] && FOCUS_APIS+=("$api")
    else
      break
    fi
  fi
done < "$CONFIG"

if [ ${#FOCUS_APIS[@]} -gt 0 ]; then
  echo ""
  echo "focusApis pruning: keeping ${#FOCUS_APIS[@]} APIs"

  # 1. Delete *Api.mo files whose tag isn't listed
  APIS_DIR="$GENERATED/src/Apis"
  KEPT_APIS=()
  REMOVED_APIS=0
  for api_file in "$APIS_DIR"/*.mo; do
    [ -f "$api_file" ] || continue
    tag=$(basename "$api_file" .mo)
    tag=${tag%Api}
    found=false
    for focus in "${FOCUS_APIS[@]}"; do
      if [ "$focus" = "$tag" ]; then
        found=true
        break
      fi
    done
    if $found; then
      KEPT_APIS+=("$api_file")
    else
      rm "$api_file"
      ((REMOVED_APIS++)) || true
    fi
  done
  echo "  Removed $REMOVED_APIS API files, kept ${#KEPT_APIS[@]}"

  # 2. Transitive-closure of Models referenced by the kept APIs + Config
  MODELS_DIR="$GENERATED/src/Models"
  if [ -d "$MODELS_DIR" ] && ls "$MODELS_DIR"/*.mo >/dev/null 2>&1; then
    collect_imports() {
      # APIs use "../Models/Foo"; Models use "./Foo".  Either way we want
      # just the model name.
      grep -hE 'import.*"(\.\./Models/|\./)' "$@" 2>/dev/null \
        | sed -E 's#.*"(\.\./Models/|\./)([^"]+)".*#\2#' \
        | sort -u
    }
    NEEDED=$(mktemp)
    collect_imports "${KEPT_APIS[@]}" "$GENERATED/src/Config.mo" > "$NEEDED"
    PREV=0
    while true; do
      CUR=$(wc -l < "$NEEDED" | tr -d ' ')
      [ "$CUR" -eq "$PREV" ] && break
      PREV=$CUR
      MODEL_FILES=()
      while IFS= read -r name; do
        f="$MODELS_DIR/$name.mo"
        [ -f "$f" ] && MODEL_FILES+=("$f")
      done < "$NEEDED"
      if [ ${#MODEL_FILES[@]} -gt 0 ]; then
        { cat "$NEEDED"; collect_imports "${MODEL_FILES[@]}"; } | sort -u > "${NEEDED}.tmp"
        mv "${NEEDED}.tmp" "$NEEDED"
      fi
    done

    # 3. Delete unreferenced Models
    REMOVED_MODELS=0
    for model_file in "$MODELS_DIR"/*.mo; do
      [ -f "$model_file" ] || continue
      name=$(basename "$model_file" .mo)
      if ! grep -qx "$name" "$NEEDED"; then
        rm "$model_file"
        ((REMOVED_MODELS++)) || true
      fi
    done
    rm "$NEEDED"
    KEPT_MODELS=$(ls "$MODELS_DIR"/*.mo 2>/dev/null | wc -l | tr -d ' ')
    echo "  Kept $KEPT_MODELS models (removed $REMOVED_MODELS unreferenced)"
  fi

  # 4. Drop pruned entries from .openapi-generator/FILES so mops doesn't
  #    complain about missing referenced files at publish time.
  FILES_LIST="$GENERATED/.openapi-generator/FILES"
  if [ -f "$FILES_LIST" ]; then
    TMPFILES=$(mktemp)
    while IFS= read -r entry; do
      path="$GENERATED/$entry"
      if [ -f "$path" ] || [ -d "$path" ]; then
        echo "$entry"
      fi
    done < "$FILES_LIST" > "$TMPFILES"
    mv "$TMPFILES" "$FILES_LIST"
  fi
fi

# --- skill / SKILL.md ---
# Two mutually-exclusive ways to declare the skill in the generator YAML:
#   skillFile: <path>     (relative to the YAML's directory)
#   skill: |              (inline YAML literal block)
#     # ... markdown body ...
# Whenever either is set, the body is written to SKILL.md at the package
# root (alongside README.md / mops.toml) and the just-emitted mops.toml's
# `files = [...]` line is patched to include it so `mops publish` ships
# the file. Dormant when neither is set.
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
  # Inject "SKILL.md" at the front of the files glob (mops auto-includes
  # README.md / LICENSE / mops.toml at root but not other root files —
  # SKILL.md still has to be enumerated explicitly).
  sed -i.bak 's|files = \["src/Config.mo",|files = ["SKILL.md", "src/Config.mo",|' "$GENERATED/mops.toml"
  rm -f "$GENERATED/mops.toml.bak"
  echo "skill: wrote SKILL.md from $SKILL_FROM, patched mops.toml"
fi

echo "Client generation complete!"
echo "Generated files in: $GENERATED/"
