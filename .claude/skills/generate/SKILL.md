---
name: generate
description: Generate and typecheck Motoko samples from OpenAPI specs
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash
---

# Generate Motoko Samples

This skill helps generate Motoko client code from OpenAPI specifications and verify it typechecks correctly.

## Policy: Don't Check In Generated `.mo` Files

**IMPORTANT**: Generated `.mo` files should NOT be committed to the repository yet. They are still under development and the generator is being refined.

## Generation Workflow

1. **Build the generator** (if needed):
   ```bash
   mvn clean install -DskipTests
   ```

   **IMPORTANT**: Always rebuild after modifying templates (`.mustache` files) or generator code. A stale `openapi-generator-cli.jar` in `modules/openapi-generator-cli/target/` will cause generated code to not reflect your changes.

2. **Generate Motoko samples**:
   ```bash
   bin/generate-samples.sh bin/configs/motoko-petstore-new.yaml
   # or
   bin/generate-samples.sh bin/configs/motoko-petstore-nodfx.yaml
   ```

3. **Typecheck generated files**:

   **Primary method** - Use the generated convenience script:
   ```bash
   cd samples/client/<spec-name>/motoko

   # Install dependencies (first time or after mops.toml changes)
   npx ic-mops install

   # Run typecheck script
   ./typecheck.sh
   ```

   The `typecheck.sh` script is automatically generated and uses `mops` to manage dependencies and typecheck all files. It provides a nice summary with checkmarks for each file.

   **Manual method** - If you need to typecheck manually:
   ```bash
   cd samples/client/<spec-name>/motoko
   PACKAGE_FLAGS=$(npx ic-mops sources)
   for file in Models/*.mo Apis/*.mo; do
     echo "Checking $file..."
     moc --check $PACKAGE_FLAGS "$file"
   done
   ```

   Both approaches use the real `serde` library with all dependencies managed by mops.

   **Note about warnings**: Generated API files will show warnings about unused identifiers (parameters like `response`, `status`, etc. in stub implementations). These warnings are expected and should be ignored - they're parameters in the generated API stubs that aren't used yet.

## Motoko Core Library Reference

The Motoko core library is located at `/Users/ggreif/motoko-core/src` and contains:
- Pure data structures: `pure/Map.mo`, `pure/List.mo`, etc.
- Standard types and utilities: `Text.mo`, `Error.mo`, `Iter.mo`, etc.

You can read these files to understand the API and type signatures.

## Dependency Management

**Mops configuration** (automatically generated with `mops.toml.mustache`):
```toml
[package]
name = "<package-name>"
version = "1.0.0"

[dependencies]
core = "2.0.0"
serde = "https://github.com/ggreif/serde#<commit-hash>"
# ... plus transitive dependencies
```

This configuration uses:
- `core` published version for pure data structures and standard types
- `serde` from ggreif fork (temporary during motoko-core transition)
- All transitive dependencies explicitly listed to work around mops resolution

**NOTE**: The `github.com/ggreif/*` references are temporary forks. When upstreamed, replace with official published versions (see comment in mops.toml.mustache template).

## Current Generator Features

- **Map types**: Uses destructuring type imports `import { type Map } "mo:core/pure/Map"`
  - Generates `Map<K, V>` instead of `Map.Map<K, V>`
- **Array types**: Uses Motoko array syntax `[T]`
- **Model imports**: Uses destructuring `import { type ModelName } "./ModelName"`
- **DFX mode**: Optional `useDfx` flag for IC imports
- **Authentication**: Variant-based auth with bearer tokens, API keys, and Basic Auth ✅

## Authentication Support

### Bearer Token Authentication (OAuth 2.0) ✅

The generator now supports bearer token authentication for APIs that use OAuth 2.0 or similar bearer token schemes.

**OpenAPI Spec Example:**
```yaml
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT  # optional
security:
  - bearerAuth: []
```

**Generated Types:**
```motoko
public type Auth__ = {
    #bearer : Text;
    #apiKey : Text;
    #basicAuth : { user : Text; password : Text };
};

public type Config__ = {
    baseUrl : Text;
    auth : ?Auth__;
    max_response_bytes : ?Nat64;
    transform : ?TransformContext__;
    is_replicated : ?Bool;
    cycles : Nat;
};
```

**Usage in Your Code:**
```motoko
import { getUser; listPosts } "./generated/Apis/DefaultApi";

// Configure with bearer token
let config = {
    baseUrl = "https://api.example.com";
    auth = ?#bearer("your-bearer-token-here");
    max_response_bytes = null;
    transform = null;
    is_replicated = null;
    cycles = 30_000_000_000;
};

// All API calls will include: Authorization: Bearer your-bearer-token-here
let user = await* getUser(config);
let posts = await* listPosts(config);
```

**What It Does:**
- Detects `type: http` with `scheme: bearer` in OpenAPI security schemes
- Automatically adds `Authorization: Bearer {token}` header to all requests
- Token is optional (`?Text`) - requests without token won't include the header

**Supported APIs:**
- ✅ Spotify API (OAuth 2.0)
- ✅ GitHub API (Personal Access Tokens)
- ✅ OpenAI API (Bearer tokens)
- ✅ Any API using OAuth 2.0 bearer tokens

**Example: Generate Spotify API Client**
```bash
# 1. Get Spotify OpenAPI spec (or create one)
# 2. Add bearerAuth security scheme
# 3. Generate client
bin/generate-samples.sh bin/configs/motoko-spotify.yaml

# 4. Use in your canister
import { searchTracks } "./generated/Apis/DefaultApi";

let config = {
    baseUrl = "https://api.spotify.com/v1";
    auth = ?#bearer(spotifyAccessToken);  // From OAuth flow
    cycles = 30_000_000_000;
    // ...
};

let results = await* searchTracks(config, "query");
```

**Testing:**
See `samples/client/httpbin-auth/motoko-test/` for a complete working example with tests against httpbin.org.

### API Key Authentication (Header & Query Parameter) ✅

The generator supports API keys in both HTTP headers and query parameters.

**OpenAPI Spec Example:**
```yaml
components:
  securitySchemes:
    apiKeyHeader:
      type: apiKey
      in: header
      name: X-API-Key
    apiKeyQuery:
      type: apiKey
      in: query
      name: api_key
```

**Usage:**
```motoko
// API key in header (X-API-Key)
let config = {
    baseUrl = "https://api.example.com";
    auth = ?#apiKey("your-api-key-here");
    cycles = 30_000_000_000;
    // ...
};

// Same variant for query parameter - placement determined by OpenAPI spec
let config = {
    baseUrl = "https://api.example.com";
    auth = ?#apiKey("your-api-key-here");  // Will append ?api_key=...
    cycles = 30_000_000_000;
    // ...
};
```

**What It Does:**
- For header API keys: Adds custom header (e.g., `X-API-Key: your-key`)
- For query API keys: Appends to URL (e.g., `?api_key=your-key`)
- Automatically detects placement from OpenAPI spec
- Same `#apiKey` variant works for both - template logic handles the difference

### Basic Authentication (HTTP Basic Auth) ✅

The generator supports HTTP Basic Authentication with username and password.

**OpenAPI Spec Example:**
```yaml
components:
  securitySchemes:
    basicAuth:
      type: http
      scheme: basic
```

**Usage:**
```motoko
let config = {
    baseUrl = "https://api.example.com";
    auth = ?#basicAuth({ user = "username"; password = "password" });
    cycles = 30_000_000_000;
    // ...
};
```

**What It Does:**
- Encodes `username:password` as Base64
- Adds `Authorization: Basic {base64-encoded-credentials}` header
- Includes custom Base64 encoder in generated code

### No Authentication

For endpoints that don't require authentication:
```motoko
let config = {
    baseUrl = "https://api.example.com";
    auth = null;
    cycles = 30_000_000_000;
    // ...
};
```

**Testing:**
See `samples/client/httpbin-auth/motoko-test/` for complete working examples with all three authentication methods tested against httpbin.org.

### Coming Soon

- **Multiple Auth Schemes** (Phase 4) - Handle APIs with multiple authentication options
- **Secure Credential Storage** (Phase 5) - IC vetKeys for encrypted on-chain token storage (blocked on compiler enhancement)

## Common Issues

1. **Import errors**: If you see "package 'core' not defined", you either:
   - Forgot the `--package core /Users/ggreif/motoko-core/src` flag (when using manual moc)
   - Haven't run `npx ic-mops install` (when using mops)
2. **Type errors**: Often indicate issues in the generator logic, not the generated code
3. **Missing imports**: Check that parameterized types like `Map<K,V>` are filtered from model imports
4. **Unexpected generated code**: If generated files don't match template changes, the generator CLI JAR is likely stale. Rebuild with `mvn clean install -DskipTests` to update `modules/openapi-generator-cli/target/openapi-generator-cli.jar` with recent template modifications.
5. **Dependency conflicts**: When using the real `serde` library manually, you may hit transitive dependency version conflicts. Use `mops` to automatically resolve all dependencies correctly.

When invoked, help the user with:
- Generating samples from OpenAPI specs
- Typechecking generated Motoko code
- Debugging generator issues
- Understanding Motoko core library types
