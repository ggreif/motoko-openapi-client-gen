#!/bin/bash
# Typecheck all generated Motoko files using mops-managed dependencies

cd "$(dirname "$0")"

# Get package flags from mops
PACKAGE_FLAGS=$(npx ic-mops sources)

echo "Typechecking generated Motoko files..."
echo ""

FAILED=0
PASSED=0

for file in src/Config.mo src/Models/*.mo src/Apis/*.mo; do
  echo "Checking $file..."
  if moc --check $PACKAGE_FLAGS "$file" 2>&1; then
    echo "✓ OK"
    ((PASSED++))
  else
    echo "✗ FAILED"
    ((FAILED++))
  fi
  echo ""
done

echo "Summary: $PASSED passed, $FAILED failed"
exit $FAILED
