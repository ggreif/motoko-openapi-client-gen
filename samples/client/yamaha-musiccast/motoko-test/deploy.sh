#!/bin/bash
# Deploy to local dfx and test Yamaha MusicCast API
set -e

cd "$(dirname "$0")"

# --- PATH setup ---
# Ensure /bin and /usr/bin are present (dfx subprocesses need 'which', 'sh', etc.)
export PATH="/bin:/usr/bin:$PATH"

# Add moc-wrapper (from motoko dev install or node_modules)
for moc_dir in \
    "$HOME/motoko/node_modules/.bin" \
    "$(dirname "$0")/node_modules/.bin" \
    "./node_modules/.bin"; do
  if [ -x "$moc_dir/moc-wrapper" ]; then
    export PATH="$moc_dir:$PATH"
    break
  fi
done

# Add node/npx (needed for 'npx ic-mops sources' packtool)
if ! command -v npx &>/dev/null; then
  echo "Error: npx not found. Please install Node.js."
  exit 1
fi
NODE_BIN="$(dirname "$(command -v npx)")"
export PATH="$NODE_BIN:$PATH"

# Ensure dfx is on PATH (works around the space in 'Application Support')
if ! command -v dfx &>/dev/null; then
  DFX_BIN="$HOME/Library/Application Support/org.dfinity.dfx/bin"
  ln -sf "$DFX_BIN/dfx" /tmp/dfx
  export PATH="/tmp:$PATH"
fi

echo "Using dfx $(dfx --version)"
echo "Using moc-wrapper: $(command -v moc-wrapper)"
echo

# --- Start replica ---
if dfx ping &>/dev/null; then
  echo "dfx replica already running, reusing it."
else
  echo "ERROR: dfx replica is not running. Please start it first with:"
  echo "  dfx start --clean --background"
  exit 1
fi

# --- Deploy ---
echo
echo "Deploying yamaha_test canister..."
dfx deploy --no-wallet yamaha_test

# --- Run test ---
echo
echo "============================="
echo "Running Yamaha test sequence..."
echo "============================="
echo
dfx canister call yamaha_test testYamahaSequence

echo
echo "============================="
echo "Test complete!"
echo "============================="
