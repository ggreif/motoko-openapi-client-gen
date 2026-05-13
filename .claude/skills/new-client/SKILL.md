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
templateDir: modules/openapi-generator/src/main/resources/motoko
artifactId: <name>-client
artifactVersion: 0.1.0
additionalProperties:
  hideGenerationTimestamp: "true"
  useDfx: false
  artifactRepoUrl: "https://github.com/caffeinelabs/<name>-client"
```

## Step 4 — Create generate.sh

Create `samples/client/<name>/motoko/generate.sh`:

```bash
#!/bin/bash
# Regenerate Motoko client from <Name> API OpenAPI spec

cd "$(dirname "$0")"
cd ../../../..  # Go to repo root (samples/client/<name>/motoko → 4 levels up)

echo "Generating Motoko client from <Name> API OpenAPI spec..."
java -jar modules/openapi-generator-cli/target/openapi-generator-cli.jar generate \
  -c bin/configs/motoko-<name>.yaml

echo "Client generation complete!"
echo "Generated files in: samples/client/<name>/motoko/generated/"
```

```bash
chmod +x samples/client/<name>/motoko/generate.sh
```

## Step 5 — Generate

```bash
java -jar modules/openapi-generator-cli/target/openapi-generator-cli.jar generate \
  -c bin/configs/motoko-<name>.yaml 2>&1 | tail -5
```

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

## Step 8 — Create the GitHub repo

Ask the user to create `caffeinelabs/<name>-client` in the org.

**Visibility constraint**: non-admin members of `caffeinelabs` can only create
repos as **private**. The user creates it private; a `caffeinelabs` admin will
flip it to public afterwards. Don't block on the visibility — proceed with
the push as soon as the repo exists.

Once created, set the mops homepage:

```bash
gh repo edit caffeinelabs/<name>-client --homepage "https://mops.one/<name>-client"
```

## Step 9 — Init git in generated dir and push

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

## Step 10 — Wire as submodule in parent repo

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
templateDir: modules/openapi-generator/src/main/resources/motoko
artifactId: <name>-client
artifactVersion: 0.1.0
additionalProperties:
  hideGenerationTimestamp: "true"
  useDfx: false
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

## Skill markdown — shipping AI-agent usage notes alongside the client

Clients can ship a top-level `SKILL.md` (alongside `README.md` /
`mops.toml`) documenting how an LLM/agent should use the generated
module — auth setup, calling patterns, common pitfalls, Caffeine-
flavored guidance, anything that isn't already obvious from the type
signatures. Pattern mirrors `focusApis`: configured in the generator
YAML, handled by `generate.sh`, invisible to the generator binary.

### Configuration

Two mutually-exclusive forms in `bin/configs/motoko-<name>.yaml`:

```yaml
# (a) Path relative to the YAML's directory; copied verbatim to SKILL.md.
skillFile: skills/<name>.md
```

```yaml
# (b) Inline YAML literal block. Indentation is stripped per YAML rules.
skill: |
  # Skill name
  …markdown body…
```

Setting both is an error. Prefer **(a) `skillFile:`** for non-trivial
content — diff-friendly, lints with normal markdown tooling, easier to
review. Reserve **(b) inline** for tiny placeholders or quick
experiments.

### How `generate.sh` implements it

After the generator binary runs, the script:

1. Reads `skillFile:` (line) and `skill: |` (literal-block) from the YAML.
2. Refuses both being set simultaneously.
3. Whichever is set, writes the body to `<generated>/SKILL.md` (package
   root, next to `README.md`/`mops.toml`).
4. Patches the just-emitted `mops.toml`'s `files = [...]` to include
   `SKILL.md` so `mops publish` ships it. mops auto-includes
   `README.md`/`LICENSE`/`mops.toml` at root, but anything else must
   be enumerated explicitly.

Snippet (drop in just after the `java -jar … generate` invocation):

```bash
# --- skill / SKILL.md ---
# Two mutually-exclusive ways to declare the skill in the generator YAML:
#   skillFile: <path>     (relative to the YAML's directory)
#   skill: |              (inline YAML literal block)
#     # ... markdown body ...
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

The block is dormant when neither key is set — no harm including it in
every client's `generate.sh` ahead of need (the WeatherAPI client
already carries it).

### What goes in SKILL.md

Free-form markdown. Suggested sections:

- **Auth** — how to obtain credentials, how to pass them via `Config`.
- **Common usage patterns** — typical calling sequences, e.g. "fetch
  current weather, then forecast" or "search → fetch details".
- **Caffeine-specific guidance** — when this client should be preferred
  over manual HTTP calls, project conventions, etc.
- **Caveats** — rate limits, payload-size quirks, fields that don't
  round-trip through Candid, etc.

The markdown is shipped as a first-class package file — consumers
discover it via the same import-time tooling that surfaces other
documentation.

## Key Reminders

- **Force push**: If remote already has a README commit, `git push --force` is needed
- **`.mops/` exclusion**: Always verify before committing — it can be 100K+ files
- **Test import**: Must be a real exported function — check with `grep "^public func"`
- **Homepage**: Always set `https://mops.one/<name>-client` on the GitHub repo
- **Spec is in `.gitignore`?** Check — large specs (1MB+) should be committed (they're source)
- **LICENSE + CODEOWNERS + CHANGELOG**: Caffeine clients must ship Apache-2.0 `LICENSE`, `.github/CODEOWNERS` (`* @caffeinelabs/team-languages`), and a seeded `CHANGELOG.md`. Added in Step 9 — easy to miss on fast pushes. `mops publish` falls back to the GitHub release body when `CHANGELOG.md` is absent (with a warning)
- After wiring, update `MEMORY.md` with the new client entry
