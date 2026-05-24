# motoko-openapi-client-gen

Motoko codegen for OpenAPI Generator, packaged as an out-of-tree plugin
and consumed by `openapi-generator-cli` from nixpkgs. Produces Motoko
client libraries publishable to [mops](https://mops.one) and usable
from canisters on the Internet Computer.

This repo is the descendant of a fork of
[OpenAPITools/openapi-generator](https://github.com/OpenAPITools/openapi-generator),
pruned down to the parts the Motoko codegen actually owns. The
upstream Java codegens for ~150 other languages, their CLI/Maven/Gradle
build infrastructure, and the per-language sample matrix no longer
live here — the plugin's runtime dependency on the generator core is
satisfied at JAR-load time by whichever `openapi-generator-cli` is on
`PATH` (nixpkgs's vanilla derivation, pinned via `flake.nix`).

## Repo layout

| Path | Purpose |
|---|---|
| `modules/motoko-client-plugin/` | The Motoko codegen — `MotokoClientCodegen.java` + Mustache templates + ServiceLoader registration. Built with Maven; output JAR loaded onto the CLI's classpath. |
| `bin/configs/motoko-*.yaml` | 14 generator configs. One per supported API (spotify, weatherapi, twilio, openai, x, tmdb, …) plus test scaffolds (petstore, jsonplaceholder, enum-test, type-coverage, httpbin-auth, yamaha-musiccast). |
| `samples/client/<api>/motoko/` (and `motoko-test/`) | Per-client packages and test scaffolds. Production client trees are git submodules pointing at `caffeinelabs/<api>-client` mops packages. |
| `tools/spec-merge/` | OCaml helper for merging multi-spec OpenAPI APIs (e.g. Twilio Messaging + Twilio API 2010) into one input before the generator ingests it. |
| `flake.nix` | Pins `openapi-generator-cli`, `openjdk`, `maven`, and the dev shell tooling. |
| `.claude/skills/` | Onboarding / release / regen skills for AI-assisted client maintenance. |

## Build the plugin

```bash
nix develop --command bash -c '(cd modules/motoko-client-plugin && mvn -DskipTests package)'
```

Output JAR: `modules/motoko-client-plugin/target/motoko-client-plugin-1.0.0-SNAPSHOT.jar`.

## Generate a client

Each `samples/client/<api>/motoko/generate.sh` invokes the generator
against the matching `bin/configs/motoko-<api>.yaml`:

```bash
nix develop --command bash samples/client/spotify/motoko/generate.sh
```

The script loads nixpkgs's openapi-generator-cli JAR + the plugin JAR
together on the classpath, runs the generator, then post-processes
the output (extracts the `skill: |` block into `SKILL.md`, patches
`mops.toml`'s `files` list, etc.).

## Add a new client

See [`.claude/skills/new-client/SKILL.md`](.claude/skills/new-client/SKILL.md) — covers
spec research, config drafting, plugin invocation, the SKILL.md
content rubric (research → template → verify), submodule wiring, and
the `mops publish` + GitHub release dance.

## Connector skills

Each generated client ships a `SKILL.md` at its package root
describing how a Caffeine composer should use it: trigger phrases,
authentication shape, real function-name examples, `is_replicated`
policy per endpoint kind, rate-limit handling, credential lifetime.
Drafted via the `skill: |` block in the generator config and
extracted at regen time. See e.g. `bin/configs/motoko-spotify.yaml`
for a worked example.

## License

Apache 2.0 — see [LICENSE](LICENSE). The Motoko codegen is derived
from OpenAPI Generator and inherits its license.
