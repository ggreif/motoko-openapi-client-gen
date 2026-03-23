#!/bin/bash
# Regenerate Motoko client from Twilio API v2010 OpenAPI spec

cd "$(dirname "$0")"
cd ../../..  # Go to repo root

echo "Generating Motoko client from Twilio API v2010 OpenAPI spec..."
java -jar modules/openapi-generator-cli/target/openapi-generator-cli.jar generate \
  -c bin/configs/motoko-twilio.yaml

echo "Client generation complete!"
echo "Generated files in: samples/client/twilio/motoko/generated/"
