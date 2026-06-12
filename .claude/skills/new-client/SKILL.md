---
name: new-client
description: Onboard a new API as a generated Motoko client (spec → submodule)
disable-model-invocation: true
---

# Onboard a New Motoko Client

This skill guides through the full process of adding a new API as a generated
Motoko client, from spec download to a wired git submodule.

## Prerequisites

- Generator is built (`mvn install ...` already done, or do it now)
- You know the API name (e.g. `twilio`, `github`, `openai`)
- The OpenAPI spec URL is known or researchable

## Step 1 — Research the spec

Find the official OpenAPI spec:
- GitHub org (e.g. `twilio/twilio-oai`, `github/rest-api-description`)
- Direct URL (e.g. `api.x.com/2/openapi.json`)

Note:
- OpenAPI version (must be 3.0+ for our generator)
- Number of operations / schemas (tractability check)
- Auth scheme (`bearer`, `apiKey`, `basicAuth`)
- Whether it's a single file or multi-file (Twilio has 56 files — pick the main one)

## Step 2 — Download the spec

```bash
mkdir -p samples/client/<name>/motoko/specs
curl -s <URL> -o samples/client/<name>/motoko/specs/<spec-file>
wc -c samples/client/<name>/motoko/specs/<spec-file>  # sanity check
```

## Step 3 — Create the generator config

Create `bin/configs/motoko-<name>.yaml`:

```yaml
generatorName: motoko
outputDir: samples/client/<name>/motoko/generated
inputSpec: samples/client/<name>/motoko/specs/<spec-file>
# No templateDir: the out-of-tree plugin bundles the ONLY motoko template
# tree (modules/motoko-client-plugin/src/main/resources/motoko). Setting
# templateDir would point at a path that no longer exists.
artifactId: <name>-client
artifactVersion: 0.1.0
additionalProperties:
  hideGenerationTimestamp: "true"
  useIcp: true        # icp-cli toolchain (mo:ic imports + icp.yaml). The
                      # legacy useDfx path is superseded — don't use it.
  diagnostics: true   # emit Runtime.trap at generator-detected gaps during dev
  # allowPATCH: true  # only if the API uses HTTP PATCH (e.g. Google). Emits
                      # `method = #patch`. REQUIRES vanilla mode (omit useIcp
                      # AND useDfx) so the client declares its OWN HttpMethod
                      # and #patch can be added to it. Under useIcp the type
                      # comes from `mo:ic`, which has no #patch and can't be
                      # extended — so allowPATCH only works vanilla. Off = PATCH
                      # ops dropped. PATCH calls still need a PATCH-enabled IC
                      # at runtime (dfinity/portal#6244).
  artifactRepoUrl: "https://github.com/caffeinelabs/<name>-client"
```

## Step 4 — Create generate.sh

Create `samples/client/<name>/motoko/generate.sh`. The canonical path is
the out-of-tree plugin: nixpkgs's vanilla `openapi-generator-cli` JAR plus
the locally-built `modules/motoko-client-plugin/` JAR on the classpath.
This bypasses the wrapper's `java -jar` mode (which would block plugin
loading) and removes the monolithic-fork build from the critical path.

```bash
#!/bin/bash
# Regenerate Motoko client from <Name> API OpenAPI spec
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CONFIG="$REPO_ROOT/bin/configs/motoko-<name>.yaml"
GENERATED="$SCRIPT_DIR/generated"

cd "$REPO_ROOT"

echo "Generating Motoko client from <Name> API OpenAPI spec..."

# Use the out-of-tree Motoko plugin against nixpkgs's vanilla
# openapi-generator-cli JAR.  Override OPENAPI_GENERATOR_JAR /
# MOTOKO_PLUGIN_JAR if either lives elsewhere on your system.
OPENAPI_GENERATOR_JAR="${OPENAPI_GENERATOR_JAR:-$(command -v openapi-generator-cli >/dev/null && readlink -f "$(dirname "$(command -v openapi-generator-cli)")/../share/java/openapi-generator-cli.jar")}"
MOTOKO_PLUGIN_JAR="${MOTOKO_PLUGIN_JAR:-$REPO_ROOT/modules/motoko-client-plugin/target/motoko-client-plugin-1.0.0-SNAPSHOT.jar}"

[ -r "$OPENAPI_GENERATOR_JAR" ] || { echo "openapi-generator-cli.jar not found at $OPENAPI_GENERATOR_JAR"; exit 1; }
[ -r "$MOTOKO_PLUGIN_JAR" ] || { echo "motoko-client-plugin JAR not found at $MOTOKO_PLUGIN_JAR — run 'nix develop --command mvn -DskipTests package' in modules/motoko-client-plugin/"; exit 1; }

java -cp "$OPENAPI_GENERATOR_JAR:$MOTOKO_PLUGIN_JAR" \
  org.openapitools.codegen.OpenAPIGenerator generate \
  -c "$CONFIG"

# SKILL.md emission goes here — see Step 11.

echo "Client generation complete!"
echo "Generated files in: $GENERATED/"
```

```bash
chmod +x samples/client/<name>/motoko/generate.sh
```

If the plugin JAR doesn't exist yet, build it inside the devshell
(`maven` and `openjdk` are pulled in by `flake.nix`, not assumed on the
host):

```bash
nix develop --command bash -c '(cd modules/motoko-client-plugin && mvn -DskipTests package)'
```

## Step 5 — Generate

```bash
nix develop --command bash samples/client/<name>/motoko/generate.sh 2>&1 | tail -10
```

The `nix develop` wrapper ensures `openapi-generator-cli` and `openjdk`
are on PATH from the devshell (matching what the fork pins in
`flake.nix`). The wrapper isn't needed if you've already entered the
devshell with bare `nix develop`.

Verify file counts:
```bash
find samples/client/<name>/motoko/generated -name "*.mo" | wc -l
ls samples/client/<name>/motoko/generated/src/Apis/ | wc -l
ls samples/client/<name>/motoko/generated/src/Models/ | wc -l
```

## Step 6 — Create typecheck.sh

Create `samples/client/<name>/motoko/typecheck.sh` using this template.
Replace `<name>` and `<TestImport>` (a real function from one of the Apis):

```bash
#!/bin/bash
# Typecheck generated code

cd "$(dirname "$0")"

INDIVIDUAL=${INDIVIDUAL:-1}

echo "Installing dependencies..."
(cd generated && npx ic-mops install)

FAILED=0
PASSED=0

if [ "$INDIVIDUAL" != "0" ]; then
  echo ""
  echo "Type checking generated client code..."

  cd generated

  for file in src/Config.mo src/Models/*.mo src/Apis/*.mo; do
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
fi

echo ""
echo "Build testing with mops build..."
TMPBUILD=$(mktemp -d /tmp/<name>-build-test-XXXXXX)
GENERATED_ABS="$(pwd)/generated"
cat > "$TMPBUILD/mops.toml" << EOF
[toolchain]
moc = "1.4.1"   # 1.4.0+ is needed because mo:core/Float references the Float32 primitive type

[package]
name = "<name>-build-test"
version = "0.0.1"

[dependencies]
<name>-client = "$GENERATED_ABS"

[canisters]
test = "Main.mo"
EOF
cat > "$TMPBUILD/Main.mo" << 'EOF'
import { <TestImport> } "mo:<name>-client/Apis/<SomeApi>";
persistent actor {
    public func test() : async Text { "ok" };
}
EOF
echo "Installing build test dependencies..."
(cd "$TMPBUILD" && npx ic-mops install) 2>&1

echo ""
echo "Dependency summary:"
SOURCES=$(cd "$TMPBUILD" && npx ic-mops sources 2>&1)
echo "$SOURCES" | awk '
/^--package / {
    alias=$2
    resolved=$3
    match(resolved, /\/([^\/]+)\/src$/, a)
    ver = a[1]
    split(alias, parts, "@"); base=parts[1]
    aliases[base] = aliases[base] " " alias "=" ver
    count[base]++
}
END {
    for (b in aliases) {
        if (count[b] > 1)
            printf "  %-38s *** MULTI-VERSION:%s\n", b, aliases[b]
        else {
            sub(/^ /, "", aliases[b])
            printf "  %s\n", aliases[b]
        }
    }
}' | sort

echo ""
echo "Running mops build..."
if (cd "$TMPBUILD" && npx ic-mops build) 2>&1; then
    echo "✓ mops build OK"
else
    echo "✗ mops build FAILED"
    ((FAILED++))
fi
rm -rf "$TMPBUILD"

echo "Summary: $PASSED passed, $FAILED failed"
exit $FAILED
```

**Finding the test import**: check a real exported function:
```bash
grep "^public func " samples/client/<name>/motoko/generated/src/Apis/<SomeApi>.mo | head -3
```

## Step 7 — Run typecheck

```bash
cd samples/client/<name>/motoko && bash typecheck.sh
```

Must show: `Summary: N passed, 0 failed` and `✓ mops build OK`.
Fix any errors before proceeding.

> **Next: Step 8 — Draft the SKILL.md.** The content-authoring guide
> lives below the `focusApis` section (the file's reference material
> is kept together). Do Step 8, regenerate (which writes
> `<generated>/SKILL.md`), then continue here with Step 9. **Skipping
> Step 8 ships a connector with no skill — don't do that for
> production clients.**

## Step 9 — Create the GitHub repo

Ask the user to create `caffeinelabs/<name>-client` in the org.

**Visibility constraint**: non-admin members of `caffeinelabs` can only create
repos as **private**. The user creates it private; a `caffeinelabs` admin will
flip it to public afterwards. Don't block on the visibility — proceed with
the push as soon as the repo exists.

Once created, set the mops homepage:

```bash
gh repo edit caffeinelabs/<name>-client --homepage "https://mops.one/<name>-client"
```

## Step 10 — Init git in generated dir and push

```bash
cd samples/client/<name>/motoko/generated
git init
git checkout -b main

# Create .gitignore
echo ".mops/" > .gitignore

# Caffeine conventions: every client repo has Apache-2.0 LICENSE and CODEOWNERS.
# LICENSE: stock Apache 2.0 boilerplate, copyright line set to the current year.
curl -sSLO https://raw.githubusercontent.com/caffeinelabs/motoko-core/main/LICENSE
# motoko-core's LICENSE is attributed to "Copyright 2025 DFINITY Stiftung" — patch
# to the current year so new clients are consistent.
sed -i '' "s/Copyright [0-9]\{4\} DFINITY Stiftung/Copyright $(date +%Y) DFINITY Stiftung/" LICENSE

# CODEOWNERS: single directive pointing at the languages team.
mkdir -p .github
printf "%s\n" "* @caffeinelabs/team-languages" > .github/CODEOWNERS

# CHANGELOG.md: seed a Keep-a-Changelog entry for the initial release.
# Mops uses CHANGELOG.md as the canonical release description; without it
# `mops publish` falls back to the GitHub release body with a warning.
# Use INLINE links in version headings (not link-reference footers): mops
# collects a single version's subtree and drops everything past the next
# same-depth heading, so footer-style `[0.1.0]: url` definitions don't
# cross section boundaries in multi-version CHANGELOGs.
cat > CHANGELOG.md <<EOF
# Changelog

All notable changes to this package are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0](https://github.com/caffeinelabs/<name>-client/releases/tag/v0.1.0) — $(date +%Y-%m-%d)

### Added

- Initial release of the generated Motoko client for the <Name> API.
- <N> API modules, <M> model modules, 1 \`Config\` module (<total> \`.mo\` files total).
EOF
# Edit the CHANGELOG to list focusApis / document known caveats if applicable.

git add .
git status --short | wc -l  # verify .mops/ NOT included

git commit -m "Initial generated Motoko client for <Name> API

<N> APIs, <M> Models, 1 Config — <N+M+1> files total.
All pass moc --check + mops build (0 failures).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

git remote add origin git@github.com:caffeinelabs/<name>-client.git
git push -u origin main
# If remote already has a README commit, force push:
# git push --force origin main
```

## Step 11 — Wire as submodule in parent repo

```bash
cd /Users/ggreif/openapi-generator

# If the dir was already tracked as regular files:
# git rm -r --cached samples/client/<name>/motoko/generated

git submodule add git@github.com:caffeinelabs/<name>-client.git \
  samples/client/<name>/motoko/generated

git add samples/client/<name>/ bin/configs/motoko-<name>.yaml
git commit -m "Add <Name> API Motoko client generation hierarchy

- Spec: <spec-file> (<size>, <N> paths, <M> schemas)
- <X> APIs, <Y> Models, <total> total — all pass, mops build OK

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

git push
```

## Subset Generation with `focusApis`

Large OpenAPI specs (e.g. OpenAI with 23 APIs and 1,211 models) produce unwieldy
clients. The `focusApis` feature lets you generate the full client, then
automatically prune it down to only the APIs you need plus their transitive
model dependencies.

### Configuration

Add a `focusApis` section to the generator config YAML:

```yaml
# bin/configs/motoko-<name>.yaml
generatorName: motoko
outputDir: samples/client/<name>/motoko/generated
inputSpec: samples/client/<name>/motoko/specs/<spec-file>
# No templateDir: the out-of-tree plugin bundles the ONLY motoko template
# tree (modules/motoko-client-plugin/src/main/resources/motoko). Setting
# templateDir would point at a path that no longer exists.
artifactId: <name>-client
artifactVersion: 0.1.0
additionalProperties:
  hideGenerationTimestamp: "true"
  useIcp: true        # icp-cli toolchain (mo:ic imports + icp.yaml). The
                      # legacy useDfx path is superseded — don't use it.
  diagnostics: true   # emit Runtime.trap at generator-detected gaps during dev
  # allowPATCH: true  # only if the API uses HTTP PATCH (e.g. Google). Emits
                      # `method = #patch`. REQUIRES vanilla mode (omit useIcp
                      # AND useDfx) so the client declares its OWN HttpMethod
                      # and #patch can be added to it. Under useIcp the type
                      # comes from `mo:ic`, which has no #patch and can't be
                      # extended — so allowPATCH only works vanilla. Off = PATCH
                      # ops dropped. PATCH calls still need a PATCH-enabled IC
                      # at runtime (dfinity/portal#6244).
  artifactRepoUrl: "https://github.com/caffeinelabs/<name>-client"

# Custom: generate.sh prunes to these APIs + their transitive model deps.
# Remove this section to keep the full API surface.
focusApis:
  - Chat
  - Completions
  - Models
```

The generator itself ignores unknown YAML keys, so `focusApis` is invisible to
`openapi-generator-cli`. It is read exclusively by `generate.sh`.

Tag names match the API file prefix: `Chat` → `ChatApi.mo`, `Models` → `ModelsApi.mo`.

### How `generate.sh` implements pruning

The script runs in three phases:

**Phase 1 — Full generation**: Run the generator normally to produce all APIs,
Models, Config, and supporting files. This ensures the generator's internal
cross-references (inline schemas, shared types) are resolved correctly.

**Phase 2 — API pruning**: Delete every `src/Apis/<Tag>Api.mo` file whose tag
is not listed in `focusApis`. Straightforward filename matching.

**Phase 3 — Model transitive closure**: Keep only the Models that are
(transitively) imported by the surviving APIs. The algorithm:

1. **Seed**: Scan every kept API file and `Config.mo` for import lines matching
   `"../Models/<Name>"`. Collect the set of model names.

2. **Expand**: For each model name in the set, open `src/Models/<Name>.mo` and
   scan for import lines matching `"./<Name>"` (model-to-model imports use
   relative paths). Add any newly discovered names to the set.

3. **Iterate**: Repeat step 2 until the set stops growing (fixed-point).
   This is guaranteed to terminate because the set is monotonically growing
   over a finite universe (the generated model files).

4. **Delete**: Remove every `src/Models/*.mo` file whose name is not in the
   final set.

```
Seed:  {kept APIs, Config.mo}
         │
         ▼  grep "../Models/<Name>"
    needed = {M1, M2, M3}
         │
         ▼  grep "./<Name>" in M1.mo, M2.mo, M3.mo
    needed = {M1, M2, M3, M4, M5}
         │
         ▼  grep "./<Name>" in M4.mo, M5.mo   (M1–M3 already processed)
    needed = {M1, M2, M3, M4, M5}  ← fixed point, done
         │
         ▼  delete everything in Models/ not in needed
```

### Additional fixups

`generate.sh` also patches HTML entities (`&lt;` → `<`, `&gt;` → `>`,
`&amp;` → `&`) that can leak from OpenAPI spec descriptions into generated
Motoko code. This runs before pruning so the model import scanner sees
clean source.

### Example: OpenAI

| | Full | Focused (8 APIs) |
|---|---|---|
| APIs | 23 | 8 |
| Models | 1,211 | 211 |
| Total `.mo` files | 1,235 | 220 |

The 8 focused APIs (Chat, Completions, Models, Embeddings, Images, Audio,
Moderations, Files) cover the most common OpenAI use cases. The remaining
15 APIs (Assistants, Realtime, VectorStores, etc.) and their ~1,000
exclusive models are pruned away.

## Step 8 — Draft the SKILL.md (research → template → verify)

Every Caffeine connector ships a top-level `SKILL.md` (alongside
`README.md` / `mops.toml`) telling the composer **when** to reach for
the package and **how** to call it from a canister. This is the
single piece of content that converts the generated bindings from "a
mops package" into "a Caffeine connector". Do it before the first
push so v0.1.0 ships with the skill already attached.

The skill block lives in `bin/configs/motoko-<name>.yaml`; `generate.sh`
extracts it to `<generated>/SKILL.md` and patches `mops.toml`'s `files
= [...]` to include it. Mechanics are in **§ Mechanics** below. Author
the content first.

### Research the API (do this **before** drafting)

The skill needs to answer questions the OpenAPI spec doesn't. Spend
~15 minutes on the API's developer docs and capture the answers:

| Topic | Concrete questions |
|---|---|
| **Authentication shape** | Bearer? OAuth 2.0 (which flow)? API key (header/query)? Basic auth? Multiple schemes per operation? |
| **Token lifecycle** | Static or expiring? If expiring: lifetime, refresh mechanism, what happens at 401? |
| **Off-chain vs on-chain credential handling** | Where is the token minted? Can the canister hold a client secret safely? Or must the user do an off-chain OAuth dance? |
| **Idempotency & mutations** | Which endpoints are pure reads vs mutations? Is the mutation idempotent (safe to retry / safe to replicate)? |
| **Rate limiting** | Are there per-app or per-user limits? Does the API return `Retry-After`? What status code on throttle (429? 503?)? |
| **Payload sizes** | Largest typical response? Anything that would blow past the IC's 2 MB outcall limit? Pagination convention? |
| **Sensitive surface** | Anything that must never appear in a query string / log / debug_show? PII fields, tokens, keys? |
| **Structural quirks** | Discriminator unions? Nullable everywhere? Date formats? Enum value conventions (kebab-case, SCREAMING_SNAKE)? |

Skim sources: the API's `developer.<service>.com/docs` portal, the
authentication walkthrough page, the rate-limiting page, and the
`/changelog` or `/release-notes` page. Take notes inline — these become
the "Notes" section of the skill.

### The Caffeine connector rubric

A skill is useful to the composer only if it answers these six things
the moment they're loaded. Use this as a checklist when drafting:

1. **When to reach for this package** — what user requests should
   trigger it vs a manual HTTP outcall?
2. **`is_replicated` policy per endpoint kind** — `?false` saves ~13×
   on cycles but loses single-node tamper protection. Reads usually
   `?false`; mutations usually `null` (replicated). State the rule
   explicitly so the composer doesn't guess.
3. **Trigger phrases** — concrete keywords / synonyms that identify a
   user request as targeting this API (not just the service name).
4. **Real code example** — function names, parameter shapes, and
   variant tags must come from the **actual generated code**, not
   from the spec or from memory. Verify via `grep` (see § Verifying).
5. **Credential origin & lifetime** — where does the token come from,
   how long does it live, what does the canister do on expiry?
6. **The gotchas you only learn by hitting walls** — anything the
   spec doesn't say. "Mutations are not idempotent — don't replicate."
   "API returns 200 with empty body on success — handle separately."
   "IDs are base-62, not URIs — strip prefix before passing."

### Skill-block template

Drop into `bin/configs/motoko-<name>.yaml` under `additionalProperties`
and fill in. Aim for **80–150 lines** of body — long enough to cover
the rubric, short enough that the composer reads all of it.

```yaml
additionalProperties:
  ...
  skill: |
    ---
    name: extension-<service>-data
    description: >-
      Use the `<name>-client` mops package whenever the user asks the
      canister to <one-line use case — be concrete about what the
      service does and what kinds of requests should route here>.
      The package wraps the <Service> API at `<base-url>` via
      outbound HTTPS calls.
    version: <artifactVersion>
    compatibility:
      mops:
        <name>-client: "~<artifactVersion>"
    ---

    # <name>-client

    Motoko bindings for the [<Service> API](<docs-url>), generated
    from <Service>'s official OpenAPI spec.

    ## Trigger phrases

    Reach for this skill on any request mentioning: <keyword>,
    <synonym>, <related-concept>, "<verb-phrase>", "<another
    verb-phrase>", … (cast a wide net — surface forms vary).

    ## How <Service> authentication works (read before wiring)

    <Plain-prose explanation of how a caller gets credentials.
    Distinguish between flows if there are several — e.g. "Client
    Credentials = catalog only, Authorization Code = user data".
    State whether the canister mints tokens or receives them.
    State token lifetime and refresh policy.>

    ## Usage

    ```motoko
    // Imports list — copy real paths from generated/src/Apis/*.mo.
    import <Mod> "mo:<name>-client/Apis/<RealApiFile>";
    import { defaultConfig } "mo:<name>-client/Config";

    let cfg = {
      defaultConfig with
        auth               = ?#bearer "<token from off-chain>";
        max_response_bytes = ?<budget>;
        is_replicated      = ?false;       // reads
    };

    // Real function call — verify the name + parameter order
    // against generated/src/Apis/<RealApiFile>.mo:
    let result = await* <Mod>.<realFunctionName>(cfg, <args>);
    ```

    ## Notes

    - `is_replicated = ?false` is safe for <which reads>. ~13×
      cheaper. Leave `is_replicated = null` for <which mutations> —
      consensus replication catches single-node tampering and
      correctness > cycle savings.
    - <Rate-limiting policy: 429 + Retry-After? Surface to caller,
      don't silently retry.>
    - <Credential storage hygiene: stable var, scope per principal,
      never log, never return from a query.>
    - <Cycles budget guidance — what's the typical call cost, when
      to bump `defaultConfig.cycles`.>
    - <Any structural surprise — base-62 IDs vs URIs, date formats,
      empty-200 conventions, discriminator field name, etc.>
```

The frontmatter `compatibility.mops.<name>-client: "~<version>"` is
what the composer-side dispatcher uses to gate which package version
this skill targets. Bump it in lock-step with `artifactVersion`.

### Verifying the skill block

Before committing, every concrete reference in the example code must
exist in the generated output. This is the most common bug — drafts
that name a function that the spec describes but the generator
renamed, or a variant tag that came out as `#snake_case` not
`#camelCase`.

```bash
# (1) Every function name must exist in src/Apis/
grep -E "^[[:space:]]*public func <realFunctionName>" \
  samples/client/<name>/motoko/generated/src/Apis/*.mo

# (2) Every variant tag must appear in src/Models/<Enum>.mo
sed -n '/type <EnumName>/,/^[[:space:]]*};/p' \
  samples/client/<name>/motoko/generated/src/Models/<EnumName>.mo

# (3) mops check passes on the API modules touched by the example
(cd samples/client/<name>/motoko/generated && \
  npx ic-mops check src/Apis/<ApiFile>.mo)
```

If any of these fail, fix the skill text — don't fix the generated
code (it's the source of truth for what consumers will actually call).

### Mechanics

Two mutually-exclusive forms (only one may be set):

```yaml
# (a) Path relative to the YAML's directory; copied verbatim to SKILL.md.
skillFile: skills/<name>.md
```

```yaml
# (b) Inline YAML literal block. Indentation is stripped per YAML rules.
skill: |
  ---
  name: ...
  ---
  ...
```

Prefer **(a) `skillFile:`** once the body grows past ~30 lines —
diff-friendly, lints with normal markdown tooling, easier to review.
Reserve **(b) inline** for tight content (the spotify-client@0.2.1
release uses inline at ~110 lines and it's fine).

`generate.sh` does the extraction. The block below is dormant when
neither key is set, so it's safe to include in every client's
`generate.sh` ahead of need:

```bash
# --- skill / SKILL.md ---
SKILL_FILE=$(grep -E '^[[:space:]]*skillFile:' "$CONFIG" | head -1 | sed 's/^[[:space:]]*skillFile:[[:space:]]*//; s/[[:space:]]*$//' || true)
SKILL_INLINE=$(awk '
  /^[[:space:]]*skill:[[:space:]]*\|[-+]?[[:space:]]*$/ {
    in_block = 1; indent = ""; next
  }
  in_block {
    if (indent == "") {
      if (match($0, /^[[:space:]]+/) == 0) { in_block = 0; next }
      indent = substr($0, 1, RLENGTH)
    }
    if ($0 != "" && substr($0, 1, length(indent)) != indent) {
      in_block = 0; next
    }
    print substr($0, length(indent) + 1)
  }
' "$CONFIG")
if [ -n "$SKILL_FILE" ] && [ -n "$SKILL_INLINE" ]; then
  echo "skill: cannot set both 'skillFile:' and 'skill: |' — they are mutually exclusive" >&2
  exit 1
fi
SKILL_OUT="$GENERATED/SKILL.md"
SKILL_FROM=""
if [ -n "$SKILL_FILE" ]; then
  CONFIG_DIR="$(dirname "$CONFIG")"
  SKILL_SRC="$CONFIG_DIR/$SKILL_FILE"
  if [ ! -f "$SKILL_SRC" ]; then
    echo "skill: $SKILL_SRC not found" >&2
    exit 1
  fi
  cp "$SKILL_SRC" "$SKILL_OUT"
  SKILL_FROM="skillFile: $SKILL_FILE"
elif [ -n "$SKILL_INLINE" ]; then
  printf '%s\n' "$SKILL_INLINE" > "$SKILL_OUT"
  SKILL_FROM="inline 'skill: |' block"
fi
if [ -n "$SKILL_FROM" ]; then
  # portable sed: write to .bak then drop it (macOS + Linux)
  sed -i.bak 's|files = \["src/Config.mo",|files = ["SKILL.md", "src/Config.mo",|' "$GENERATED/mops.toml"
  rm -f "$GENERATED/mops.toml.bak"
  echo "skill: wrote SKILL.md from $SKILL_FROM, patched mops.toml"
fi
```

> **`|| true` on the `grep`** is required — under `set -euo pipefail`,
> a `grep` that finds zero matches exits 1 and kills the script before
> the inline-skill path even runs. The fallback suppresses that.

### Quick reference: existing skills as models

When in doubt, copy the closest existing skill and adapt it:

| Existing client | Auth pattern | Best for |
|---|---|---|
| **spotify-client** (icp-cli mode) | OAuth 2.0 Bearer, dual-flow (Client Credentials / Authorization Code w/ PKCE) | Anything with user-scoped + public-catalog endpoints |
| **weatherapi-client** | Static apiKey | Read-only public APIs with one credential type |
| **x-client** (twitter) | OAuth 2.0 Bearer + extensive `skills/` blueprint | Mutation-heavy social APIs with rate-limit + nullable-field gotchas |

After regen the SKILL.md lands at `<generated>/SKILL.md` and
`mops.toml`'s `files` list includes it — `mops publish` ships it
automatically.

## Key Reminders

- **Force push**: If remote already has a README commit, `git push --force` is needed
- **`.mops/` exclusion**: Always verify before committing — it can be 100K+ files
- **Test import**: Must be a real exported function — check with `grep "^public func"`
- **Homepage**: Always set `https://mops.one/<name>-client` on the GitHub repo
- **Spec is in `.gitignore`?** Check — large specs (1MB+) should be committed (they're source)
- **LICENSE + CODEOWNERS + CHANGELOG**: Caffeine clients must ship Apache-2.0 `LICENSE`, `.github/CODEOWNERS` (`* @caffeinelabs/team-languages`), and a seeded `CHANGELOG.md`. Added in Step 10 — easy to miss on fast pushes. `mops publish` falls back to the GitHub release body when `CHANGELOG.md` is absent (with a warning)
- **SKILL.md is mandatory for production clients** — Step 8 (research → template → verify). A connector without a skill is just a mops package; the skill is what makes it discoverable to the composer
- **Templates & codegen have ONE home**: `modules/motoko-client-plugin/` (the `src/main/resources/motoko/*.mustache` tree and `MotokoClientCodegen.java`). The old fork copies under `modules/openapi-generator/.../motoko` were removed — editing there has no effect. After changing the plugin, rebuild it (`nix develop --command bash -c '(cd modules/motoko-client-plugin && mvn -DskipTests package)'`) before regenerating
- **Dot/punctuation in operationIds** (Google: `calendar.events.list`) are sanitized to underscores by `toOperationId` → `calendar_events_list`. No action needed; just don't expect the dotted name in the generated API
- **HTTP PATCH**: the IC management canister doesn't support PATCH yet (dfinity/portal#6244). For PATCH-using APIs, generate in **vanilla mode** (omit `useIcp`/`useDfx`) and set `allowPATCH: true` — vanilla declares its own `HttpMethod`, so `#patch` is just added there (no `mo:ic`, which can't be extended). PATCH outcalls still need a PATCH-enabled IC/pocket-ic at runtime. Leave `allowPATCH` off to drop PATCH ops and ship the rest. See `.claude/plans/patch.md`
- After wiring, update `MEMORY.md` with the new client entry
