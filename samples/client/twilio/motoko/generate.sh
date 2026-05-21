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
java -jar modules/openapi-generator-cli/target/openapi-generator-cli.jar generate \
  -c "$CONFIG"

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
