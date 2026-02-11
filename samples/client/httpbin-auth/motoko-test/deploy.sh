#!/bin/bash
# Deploy to local dfx and test authentication

cd "$(dirname "$0")"

# Check for moc-wrapper and add to PATH if needed
if ! command -v moc-wrapper &> /dev/null; then
  # Try common locations for moc-wrapper
  COMMON_PATHS=(
    "$HOME/motoko/node_modules/.bin"
    "./node_modules/.bin"
    "../node_modules/.bin"
  )

  MOC_WRAPPER_FOUND=false
  for path in "${COMMON_PATHS[@]}"; do
    if [ -x "$path/moc-wrapper" ]; then
      export PATH="$path:$PATH"
      MOC_WRAPPER_FOUND=true
      break
    fi
  done

  if [ "$MOC_WRAPPER_FOUND" = false ]; then
    echo "Error: moc-wrapper not found in PATH"
    echo "Please install it with: npm install -g ic-mops"
    echo "Or ensure it's available in your PATH"
    exit 1
  fi
fi

echo "Starting local dfx replica..."
dfx start --clean --background

echo
echo "Deploying httpbin_auth_test canister..."
if ! dfx deploy httpbin_auth_test; then
    echo "Error: dfx deploy failed"
    exit 1
fi

echo
echo "Adding cycles to canister for HTTP outcalls..."
# First, fund the wallet canister with ICP (which gets converted to cycles)
WALLET_ID=$(dfx identity get-wallet)
dfx ledger fabricate-cycles --canister "$WALLET_ID" --amount 10
# Then deposit cycles from wallet to the httpbin_auth_test canister
dfx canister deposit-cycles 100_000_000_000_000 httpbin_auth_test

echo
echo "=== Running Authentication Tests ==="

echo
echo "Running all authentication tests..."
dfx canister call httpbin_auth_test runAllTests

echo
echo "=== Tests Complete ==="
echo
echo "To stop dfx: dfx stop"
echo "To view logs: dfx canister logs httpbin_auth_test"
