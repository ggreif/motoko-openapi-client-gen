---
name: generate
description: Generate and typecheck Motoko samples from OpenAPI specs
disable-model-invocation: true
---

# Generate Motoko Samples

This skill helps regenerate Motoko client code from OpenAPI specifications
and verify it typechecks correctly.

## Two Kinds of Clients

### Test clients (in-tree, no submodule)

Used for generator development and regression testing. Generated `.mo` files
are committed directly into the repo under `samples/client/<name>/`:

| Config | Output dir | Notes |
|--------|-----------|-------|
| `motoko-petstore-new.yaml` | `samples/client/petstore/motoko` | useDfx=true — **currently unavailable** (see DFX note) |
| `motoko-petstore-nodfx.yaml` | `samples/client/petstore/motoko-nodfx` | main petstore reference |
| `motoko-enum-test.yaml` | `samples/client/enum-test/generated` | enum corner cases |
| `motoko-type-coverage-test.yaml` | `samples/client/type-coverage/motoko-test/generated` | type variety |
| `motoko-httpbin-auth-test.yaml` | `samples/client/httpbin-auth/motoko-test/generated` | auth flows |
| `motoko-jsonplaceholder-test.yaml` | `samples/client/jsonplaceholder/motoko-test/generated` | |
| `motoko-yamaha-test.yaml` | `samples/client/yamaha-musiccast/motoko-test/generated` | |

### Production clients (submodules)

Used for real API clients published to mops. Generated files live in a
separate git submodule under `samples/client/<name>/motoko/generated/`:

| Config | Submodule | mops package |
|--------|-----------|--------------|
| `motoko-spotify.yaml` | `caffeinelabs/spotify-client` | `spotify-client@0.2.0` |
| `motoko-x.yaml` | `caffeinelabs/x-client` | pending |
| `motoko-twilio.yaml` | `caffeinelabs/twilio-client` | pending |

## Build the Plugin (preferred path, when templates or Java changed)

The motoko codegen ships as an **out-of-tree plugin** at
`modules/motoko-client-plugin/`, loaded onto the classpath of
nixpkgs's vanilla `openapi-generator-cli` (7.22.0).  Build the
plugin alone — small, fast:

```bash
cd modules/motoko-client-plugin
mvn -DskipTests package
```

Output: `target/motoko-client-plugin-1.0.0-SNAPSHOT.jar`. About
1-2 seconds. Rebuild after any change to
`modules/motoko-client-plugin/src/main/{java,resources}/` — a
stale JAR silently produces outdated output.  The plugin JAR's
sources are mirrored from `modules/openapi-generator/src/main/`,
so when you edit one, also mirror the change to the other (a
sync utility is on the TODO list — for now, `cp` lock-stepped
the two `api.mustache` copies during the icp-cli backport).

The `nix develop` shell carries both `mvn` and the nixpkgs
`openapi-generator-cli`, so no other setup is needed.

## Generate

### Production clients — use the per-client `generate.sh`

```bash
nix develop --command bash samples/client/spotify/motoko/generate.sh
nix develop --command bash samples/client/twilio/motoko/generate.sh
nix develop --command bash samples/client/weatherapi/motoko/generate.sh
```

Each `generate.sh` already invokes the plugin path
(`java -cp $OPENAPI_GENERATOR_JAR:$MOTOKO_PLUGIN_JAR org.openapitools.codegen.OpenAPIGenerator ...`)
with `OPENAPI_GENERATOR_JAR` defaulting to nixpkgs's binary and
`MOTOKO_PLUGIN_JAR` to the locally built plugin. Either env var
can be overridden if the JARs live elsewhere.

The per-client script also handles post-generation steps that
codegen alone doesn't cover:

- writing `SKILL.md` from the YAML's `skill: |` / `skillFile:` block,
- patching `mops.toml` to include `SKILL.md` under `files = [...]`,
- adding mode-specific `mops.toml` dependencies (e.g. `ic = "4.0.0"`
  for `useIcp: true` clients),
- running `focusApis` pruning (twilio).

### Test clients

Test clients (under `bin/configs/motoko-{petstore-nodfx,enum-test,
type-coverage-test,httpbin-auth-test,jsonplaceholder-test,
yamaha-test}.yaml`) still use the **legacy monolithic** path
(see below) until they're migrated to plugin-aware shells. They're
for generator development; the slower fat-JAR build is acceptable
in the dev loop.

## Legacy: monolithic fat-JAR build (deprecated)

The original generator path built a fat
`modules/openapi-generator-cli/target/openapi-generator-cli.jar`
that included the Motoko codegen alongside ~150 other generators.
This still works but is **deprecated** for production-client use:

```bash
# fat-JAR build (slow, several minutes)
mvn install -DskipTests -Dmaven.test.skip=true -Dforbiddenapis.skip=true \
  -pl modules/openapi-generator-cli -am -q

# direct invocation
java -jar modules/openapi-generator-cli/target/openapi-generator-cli.jar generate \
  -c bin/configs/motoko-spotify.yaml

# or the wrapper that auto-builds-if-missing
bin/generate-samples.sh bin/configs/motoko-petstore-nodfx.yaml
```

Keep using this path **only** for:
- in-tree test clients listed above, and
- generator development where rebuilding 150 generators on every
  change isn't a problem.

Production-client `generate.sh` scripts no longer reference this
JAR; they exclusively use the plugin path.

### ⚠️ When regenerating for a version bump

If this regeneration accompanies an `artifactVersion:` bump in the
config YAML (i.e. you're shipping a new mops release), you must also
**append a `CHANGELOG.md` entry** in the submodule before tagging /
publishing:

```markdown
## [0.1.X](https://github.com/caffeinelabs/<name>-client/releases/tag/v0.1.X) — YYYY-MM-DD

### Changed / Added / Fixed

- <one-line summary>
```

`mops publish` uses `CHANGELOG.md` as the canonical release-notes
source — if it's absent or stale relative to `mops.toml`'s `version`,
the mops UI shows the wrong (or empty) release description. The
`release` skill assumes this has been done by the time `gh release
create` runs.

## Typecheck

Each production client has a `typecheck.sh`:

```bash
cd samples/client/<name>/motoko
bash typecheck.sh
```

Must show: `Summary: N passed, 0 failed` and `✓ mops build OK`.

### INDIVIDUAL flag

Skip per-file `moc --check`, run only `mops build` (faster):
```bash
INDIVIDUAL=0 bash typecheck.sh
```

### Manual typecheck (single file)

```bash
cd samples/client/<name>/motoko/generated
PACKAGE_FLAGS=$(npx ic-mops sources 2>&1)
MOC=/Users/ggreif/Library/Caches/mops/moc/1.3.0/moc
$MOC --check $PACKAGE_FLAGS src/Apis/SomeApi.mo
```

Note: `npx ic-mops check <file>` does not work well due to serde dev-dependency
(`motoko_candid` requires `candid`). Use `ic-mops sources` + `moc --check`.

## Three Toolchain Modes

The template emits a different `http_request` plumbing block per
toolchain.  Pick one in the YAML's `additionalProperties`:

| `additionalProperties` | mustache branch | type source for `HttpRequestArgs` etc. | runtime |
|---|---|---|---|
| (neither) | `{{^useImportedInterface}}` | inline definitions in each `*Api.mo` | vanilla mops (no IC-canister deps) |
| `useDfx: true` | `{{#useDfx}}` | `import { type http_request_args; … } "ic:aaaaa-aa"` (IDL-style) + PascalCase aliases | dfx (canister-alias mechanism) |
| `useIcp: true` | `{{#useIcp}}` | `import { type HttpRequestArgs; … } "mo:ic/Types"` (mops `ic` package) | icp-cli + mops `ic` dep |

Body refs uniformly use **PascalCase** (`HttpRequestArgs`,
`HttpRequestResult`, `HttpHeader`, `HttpMethod`) regardless of
mode.

### Per-mode notes

- **Vanilla**: defines the four types inline in every API module
  and instantiates the management canister directly via
  `(actor "aaaaa-aa" : actor { http_request : ... })`. No external
  deps.
- **DFX (`useDfx: true`)**: currently brittle.  The IC-agent
  dependencies are outdated; `petstore/motoko` (the only
  `useDfx: true` client) typechecks but `--actor-idl` failures are
  pre-existing and expected.  `PUT` and `DELETE` are commented
  out in DFX mode (dfx doesn't expose them yet).
- **ICP-CLI (`useIcp: true`)** — preferred when the client needs
  the `aaaaa-aa` management canister types but doesn't want a
  dfx dependency. Pulls `HttpRequestArgs` etc. from the
  [`ic`](https://mops.one/ic) mops package (`4.0.0`).
  `generate.sh` patches `mops.toml` to add `ic = "4.0.0"` under
  `[dependencies]` so `mops install` + `mops check` work without
  additional setup.  Used by `motoko-spotify.yaml`.

## Current Generated Structure

```
src/
  Config.mo          ← shared: Auth, Config, defaultConfig
  Apis/              ← one .mo file per operation tag
  Models/            ← one .mo file per schema
mops.toml
```

API files import `Config` from `../Config` — no local `Config__`/`Auth__` types.

## Authentication

```motoko
public type Auth = {
    #bearer : Text;                                    // OAuth2, Bearer
    #apiKey : Text;                                    // API key (header/query)
    #basicAuth : { user : Text; password : Text };     // HTTP Basic
};
```

Usage:
```motoko
import { defaultConfig } "mo:<name>-client/Config";

let config = { defaultConfig with auth = ?#bearer "my-token" };
let config = { defaultConfig with auth = ?#basicAuth { user = sid; password = token } };
```

## Writing the connector `SKILL.md` — Caffeine's perspective

Every production client ships a `SKILL.md` at package root (mechanism
documented in the `new-client` skill: `skillFile:` or inline `skill: |`
in the generator YAML, extracted by `generate.sh`, listed in
`mops.toml`'s `files = [...]`). This section is about *content*, not
mechanics.

**Audience: Caffeine, not a human.** The SKILL.md is consumed by an AI
agent (Caffeine) deciding whether to reach for the package and how to
use it. It is NOT a README, NOT a tutorial, NOT marketing copy. Write
it as you would brief a competent peer who has 60 seconds and needs to
produce working canister code.

Implications for content:

- **Open with two things Caffeine actually needs.** What this client
  covers (in one sentence, with the explicit scope boundary), and the
  trigger phrases that should pull it in. Frontmatter `description:` is
  what skill-matching reads first — make it dense and specific.
- **Trigger phrases are weighted hints, not search keywords.** List the
  *concrete language* a user would utter to trigger this skill ("send
  SMS", "buy a phone number", "A2P 10DLC"), not abstract category
  words ("messaging API").
- **Code examples are the load-bearing artifact.** Caffeine will lift
  them nearly verbatim. So: every enum-typed argument uses a real
  variant that exists in the regenerated code (verify with `grep` on
  the actual `*Enum*.mo` modules — don't guess); every code block
  compiles against the current package; placeholders for caller-supplied
  values are obvious (e.g. `accountSid`, `"+15558675309"`). Avoid
  pseudocode.
- **Disambiguate from raw HTTP outcalls explicitly.** Tell Caffeine
  what the wrong path looks like (`ic.http_request` against the
  vendor's host) and why it's wrong (bypasses generated typing /
  parsing / auth). Without this, Caffeine sometimes defaults to raw
  HTTP because it knows that pattern.
- **Surface the non-obvious.** Caffeine can read function signatures
  itself; what it can't infer is: pitfalls, dated deadlines (e.g. "as
  of 2026-06-30, X becomes required"), valid values for `Text`-typed
  enum-in-disguise fields, lowercase variant case-sensitivity,
  rate-limit numbers, common error codes.
- **State the architecture truths the codegen can't express.** If
  the client has unusual properties (e.g. multi-host routing with a
  dead `Config.baseUrl`), name them. Otherwise Caffeine will try
  things that don't apply.
- **Don't repeat what the type signatures already tell.** Listing the
  arguments of a function it's about to call is wasted tokens.
- **Cap length around 200 lines.** Long SKILL files waste context for
  every Caffeine invocation that loads them. The `weatherapi-client`
  SKILL at 53 lines is on the lean end; `twilio-client` at ~194 lines
  is the upper end justifiable by a richer surface.

A SKILL.md that meets these is a force multiplier on the package: with
it, Caffeine produces working canister code on the first attempt;
without it, Caffeine improvises around the package and produces broken
code that compiles. Treat it as a first-class deliverable, not
documentation.

## Common Issues

1. **Stale JAR**: Rebuild the generator after any template or Java change.
2. **`npx ic-mops check` failing**: Use `ic-mops sources` + `moc --check` (serde dev-dep issue).
3. **`mops build` fails but individual files pass**: Wrong test function name in `typecheck.sh`
   Main.mo. Find real exported functions:
   ```bash
   grep "^public func " generated/src/Apis/SomeApi.mo | head -5
   ```
4. **Multi-version deps in summary**: Expected from the transitive dep tree — not errors.
5. **DFX `--actor-idl` failures**: Pre-existing in `petstore/motoko`, ignored for now.
