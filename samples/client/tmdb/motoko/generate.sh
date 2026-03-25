#!/bin/bash
# Regenerate Motoko client from TMDb API OpenAPI spec

cd "$(dirname "$0")"
cd ../../..  # Go to repo root

echo "Generating Motoko client from TMDb API OpenAPI spec..."
java -jar modules/openapi-generator-cli/target/openapi-generator-cli.jar generate \
  -c bin/configs/motoko-tmdb.yaml

echo "Client generation complete!"
echo "Generated files in: samples/client/tmdb/motoko/generated/"
