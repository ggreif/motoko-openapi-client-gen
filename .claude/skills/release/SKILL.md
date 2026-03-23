---
name: release
description: Release a generated Motoko client API package to the mops registry
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Edit, Write
---

# Release a Motoko Client API Package

This skill guides through releasing a generated Motoko client (e.g. `spotify-client`) to the mops registry.

## Prerequisites

- Generator has been rebuilt and the generated files typecheck cleanly
- `typecheck.sh` passes (158/158 for Spotify), including `mops build`
- All template changes are committed

## Release Workflow

### 1. Determine the new version

Follow semver:
- **patch** (x.y.Z): dep reordering, README fixes, non-functional changes
- **minor** (x.Y.0): new API support, new features
- **major** (X.0.0): breaking changes

### 2. Bump the version

Update in both places:

```bash
# bin/configs/motoko-spotify.yaml
artifactVersion: 0.1.X

# samples/client/spotify/motoko/generated/mops.toml
version = "0.1.X"
```

Also update `mops.toml.mustache` if the template itself changed.

### 3. Rebuild and regenerate

```bash
mvn install -DskipTests -Dmaven.test.skip=true -Dforbiddenapis.skip=true -pl modules/openapi-generator-cli -am -q

java -jar modules/openapi-generator-cli/target/openapi-generator-cli.jar generate \
  -c bin/configs/motoko-spotify.yaml
```

Verify only expected files changed (typically just `mops.toml`, maybe `README.md`).

### 4. Run the full typecheck

```bash
cd samples/client/spotify/motoko
bash typecheck.sh
```

Must show: `Summary: 158 passed, 0 failed` and `✓ mops build OK`.

### 5. Commit and push the submodule

```bash
cd samples/client/spotify/motoko/generated
git add -A
git commit -m "Bump to 0.1.X: <short description>"
git push
```

### 6. Create a GitHub Release (required by mops!)

**Important:** mops requires a GitHub Release, not just a git tag.

```bash
gh release create v0.1.X \
  --repo caffeinelabs/spotify-client \
  --title "v0.1.X" \
  --notes "<short description of changes>"
```

This automatically creates the tag too. Do NOT use `git tag` + `git push origin v0.1.X` alone — mops will reject it with "No GitHub release found".

### 7. Publish to mops (interactive — user runs this)

```bash
cd samples/client/spotify/motoko/generated
npx ic-mops publish
```

The user must enter their mops password interactively.

### 8. Verify with the throwaway test project

```bash
cd /tmp/spotify-test
# Update mops.toml: spotify-client = "0.1.X"
npx ic-mops install
npx ic-mops build
```

Must show: `✓ Built 1 canister successfully`.

### 9. Update the parent repo

```bash
cd /Users/ggreif/openapi-generator
git add samples/client/spotify/motoko/generated \
        bin/configs/motoko-spotify.yaml \
        modules/openapi-generator/src/main/resources/motoko/mops.toml.mustache
git commit -m "Bump spotify-client to 0.1.X: <description>"
git push
```

## Key Reminders

- `mops.toml` in the submodule must stay in sync with `mops.toml.mustache` in the parent
- The GitHub Release (step 6) is what mops uses to find the package — without it, publish fails
- After publishing, update MEMORY.md with the new version
