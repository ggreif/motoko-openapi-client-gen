# Plan: Enable PUT and DELETE HTTP Methods (Non-DFX Mode)

## Background

The IC management canister now supports PUT and DELETE HTTP methods, but **only in non-replicated
mode**. The reason: the IC doesn't rendezvous different boundary nodes when alternating these
idempotent methods, so race conditions may occur in replicated mode.

DFX doesn't know about these new methods yet, so all changes are confined to the `{{^useDfx}}`
branch of `api.mustache`.

## Pre-Existing State

- `http_method` type has `#put` and `#delete` commented out in **both** dfx and non-dfx branches
  with a TODO (`api.mustache` lines 31–35 and 53–57):
  ```
  // TODO: IC HTTP outcalls currently only support GET, HEAD, and POST.
  //   PUT and DELETE methods are not yet supported by the management canister.
  //   Once support is added, uncomment these:
  // #put;
  // #delete;
  ```
- Generated code for PUT/DELETE operations already emits `method = #put` / `method = #delete`
  (via `{{#lambda.lowercase}}{{httpMethod}}`), but those variants don't exist in the type →
  typecheck failure.
- Tracked in MEMORY.md as "Pre-existing failures".

## Changes Required

### 1. `api.mustache` — non-dfx section (lines 49–58)

**Resolve the TODO**: uncomment `#put` / `#delete` and replace the TODO comment:

```motoko
type http_method = {
    #get;
    #head;
    #post;
    #put;    // Non-replicated only (is_replicated forced to ?false in generated code)
    #delete; // Non-replicated only (is_replicated forced to ?false in generated code)
};
```

### 2. `api.mustache` — dfx section (lines 27–36)

**Update the TODO** to reflect current reality (dfx still pending, not "not yet supported by
management canister"):

```motoko
// TODO: PUT and DELETE are now supported by the management canister in non-replicated
//   mode, but dfx doesn't expose these methods yet. Uncomment once dfx support lands:
// #put;
// #delete;
```

### 3. `api.mustache` — force `is_replicated = ?false` for PUT/DELETE (non-dfx only)

In the `let request : http_request_args = { config with ... }` block (line 158), add an
`is_replicated` override **inside the non-dfx section** using Mustache's `isPut`/`isDelete`
boolean flags:

```mustache
let request : http_request_args = { config with
    url;
    method = #{{#lambda.lowercase}}{{httpMethod}}{{/lambda.lowercase}};
    headers;
    body = ...;
    {{#isPut}}is_replicated = ?false; // PUT requires non-replicated mode on IC{{/isPut}}
    {{#isDelete}}is_replicated = ?false; // DELETE requires non-replicated mode on IC{{/isDelete}}
};
```

This override is intentional and unconditional: PUT and DELETE only work in non-replicated
mode regardless of what the caller placed in `config.is_replicated`.

### 4. Update MEMORY.md

- Remove the "Pre-existing failures" bullet about `#delete`/`#put`.
- Add a note that PUT/DELETE are now supported in non-dfx generated code with forced
  `is_replicated = ?false`.

## Testing

**Goal: typecheck only.** Runtime testing is currently not possible because dfx doesn't support
PUT and DELETE in a local replica setting either. We can only verify that the generated code
passes the Motoko type checker.

1. Build the generator:
   ```bash
   ./mvnw install -DskipTests -Dmaven.test.skip=true -Dforbiddenapis.skip=true \
     -pl modules/openapi-generator-cli -am -q
   ```

2. Generate petstore non-dfx:
   ```bash
   bin/generate-samples.sh bin/configs/motoko-petstore-nodfx.yaml
   ```

3. Typecheck:
   ```bash
   cd samples/client/petstore/motoko-nodfx
   npx ic-mops install
   ./typecheck.sh
   ```

4. Verify: `deletePet`, `updatePet`, `deleteOrder`, `updateUser`, `deleteUser` no longer
   cause typecheck errors. The dfx variant remains broken as before (don't test it).

## Out of Scope

- DFX support (blocked upstream, TODO updated but not resolved)
- Runtime/integration testing (blocked: local dfx replica also doesn't support PUT/DELETE yet)
- Spotify or other specs (will benefit automatically once template is fixed)
- `PATCH` method (similar situation but not requested here)
