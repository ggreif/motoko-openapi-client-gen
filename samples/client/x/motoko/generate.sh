#!/bin/bash
# Regenerate Motoko client from X API OpenAPI spec

cd "$(dirname "$0")"
cd ../../..  # Go to repo root

echo "Generating Motoko client from X API OpenAPI spec..."
java -jar modules/openapi-generator-cli/target/openapi-generator-cli.jar generate \
  -c bin/configs/motoko-x.yaml

echo "Client generation complete!"
echo "Generated files in: samples/client/x/motoko/generated/"
