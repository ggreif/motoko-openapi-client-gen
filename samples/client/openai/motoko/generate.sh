#!/bin/bash
# Regenerate Motoko client from OpenAI API OpenAPI spec
# Supports focusApis pruning: only keeps listed APIs + transitively imported Models.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CONFIG="$REPO_ROOT/bin/configs/motoko-openai.yaml"
GENERATED="$SCRIPT_DIR/generated"

cd "$REPO_ROOT"

echo "Generating Motoko client from OpenAI API OpenAPI spec..."
java -jar modules/openapi-generator-cli/target/openapi-generator-cli.jar generate \
  -c "$CONFIG" --skip-validate-spec

# --- fix HTML entities that leak from spec descriptions into code ---
find "$GENERATED/src" -name '*.mo' -exec \
  sed -i '' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&amp;/\&/g' {} +

# --- focusApis pruning ---
# Parse focusApis from the YAML config.  If the section is absent, skip pruning.
FOCUS_APIS=()
IN_FOCUS=false
while IFS= read -r line; do
  if [[ "$line" =~ ^focusApis: ]]; then
    IN_FOCUS=true
    continue
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

if [ ${#FOCUS_APIS[@]} -eq 0 ]; then
  echo "No focusApis section — keeping full API surface."
  echo "Generated files in: $GENERATED/"
  exit 0
fi

echo ""
echo "focusApis pruning: keeping ${#FOCUS_APIS[@]} APIs: ${FOCUS_APIS[*]}"

# 1. Delete API files not in the focus list
APIS_DIR="$GENERATED/src/Apis"
KEPT_APIS=()
REMOVED_APIS=0
for api_file in "$APIS_DIR"/*.mo; do
  [ -f "$api_file" ] || continue
  basename=$(basename "$api_file" .mo)
  tag=${basename%Api}  # e.g. ChatApi -> Chat
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
    ((REMOVED_APIS++))
  fi
done
echo "  Removed $REMOVED_APIS API files, kept ${#KEPT_APIS[@]}"

# 2. Collect transitively referenced Models
MODELS_DIR="$GENERATED/src/Models"
if [ ! -d "$MODELS_DIR" ] || [ -z "$(ls "$MODELS_DIR"/*.mo 2>/dev/null)" ]; then
  echo "  No Models directory — done."
  echo "Generated files in: $GENERATED/"
  exit 0
fi

# Seed: model names imported by the kept APIs and Config.mo
collect_imports() {
  # Extract model names from import lines.
  # APIs use:   "../Models/FooBar"
  # Models use: "./FooBar"
  grep -hE 'import.*"(\.\./Models/|\.\/)' "$@" 2>/dev/null \
    | sed -E 's|.*"(\.\./Models/\|\./)([^"]+)".*|\2|' \
    | sort -u
}

# Iterative transitive closure
NEEDED_MODELS=$(mktemp)
PREV_COUNT=0

# Seed from kept APIs + Config
collect_imports "${KEPT_APIS[@]}" "$GENERATED/src/Config.mo" > "$NEEDED_MODELS"

while true; do
  CUR_COUNT=$(wc -l < "$NEEDED_MODELS" | tr -d ' ')
  [ "$CUR_COUNT" -eq "$PREV_COUNT" ] && break
  PREV_COUNT=$CUR_COUNT

  # Expand: for each needed model, find what it imports from Models/
  MODEL_FILES=()
  while IFS= read -r name; do
    f="$MODELS_DIR/$name.mo"
    [ -f "$f" ] && MODEL_FILES+=("$f")
  done < "$NEEDED_MODELS"

  if [ ${#MODEL_FILES[@]} -gt 0 ]; then
    {
      cat "$NEEDED_MODELS"
      collect_imports "${MODEL_FILES[@]}"
    } | sort -u > "${NEEDED_MODELS}.tmp"
    mv "${NEEDED_MODELS}.tmp" "$NEEDED_MODELS"
  fi
done

NEEDED_COUNT=$(wc -l < "$NEEDED_MODELS" | tr -d ' ')

# 3. Delete unreferenced Models
REMOVED_MODELS=0
for model_file in "$MODELS_DIR"/*.mo; do
  [ -f "$model_file" ] || continue
  name=$(basename "$model_file" .mo)
  if ! grep -qx "$name" "$NEEDED_MODELS"; then
    rm "$model_file"
    ((REMOVED_MODELS++))
  fi
done
rm "$NEEDED_MODELS"

TOTAL_MODELS=$(ls "$MODELS_DIR"/*.mo 2>/dev/null | wc -l | tr -d ' ')
echo "  Kept $TOTAL_MODELS models (removed $REMOVED_MODELS unreferenced)"

# 4. Update .openapi-generator/FILES to reflect pruning
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

echo ""
echo "Client generation complete!"
echo "Generated files in: $GENERATED/"
