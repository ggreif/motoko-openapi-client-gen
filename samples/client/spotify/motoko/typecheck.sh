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

for file in src/Models/*.mo src/Apis/*.mo; do
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
