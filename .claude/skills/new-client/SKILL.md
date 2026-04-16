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
cd ../../..  # Go to repo root

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
moc = "1.3.0"

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

Ask the user to create `caffeinelabs/<name>-client` (public) in the org.
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

## Key Reminders

- **Force push**: If remote already has a README commit, `git push --force` is needed
- **`.mops/` exclusion**: Always verify before committing — it can be 100K+ files
- **Test import**: Must be a real exported function — check with `grep "^public func"`
- **Homepage**: Always set `https://mops.one/<name>-client` on the GitHub repo
- **Spec is in `.gitignore`?** Check — large specs (1MB+) should be committed (they're source)
- After wiring, update `MEMORY.md` with the new client entry
