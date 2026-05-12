#!/bin/bash
# Regenerate Motoko client from WeatherAPI.com OpenAPI spec

cd "$(dirname "$0")"
cd ../../../..  # Go to repo root (samples/client/<name>/motoko → 4 levels up)

echo "Generating Motoko client from WeatherAPI.com OpenAPI spec..."
java -jar modules/openapi-generator-cli/target/openapi-generator-cli.jar generate \
  -c bin/configs/motoko-weatherapi.yaml

echo "Client generation complete!"
echo "Generated files in: samples/client/weatherapi/motoko/generated/"
