# Motoko codegen: toCandidValue / fromCandidValue rewrite (target: openai-client 0.2.0)

## Goal

Replace the `to_candid(jsonValue) → JSON.toText(blob, …)` pipeline (which
makes Motoko's built-in `to_candid` decide wire shape — wrong for any
construct OpenAPI doesn't map onto a Candid record/variant 1:1) with a
codegen-controlled pipeline:

```
let candidValue = T.toCandidValue(body);              // serde-core Candid ADT
let #ok(blob) = Candid.encodeOne(candidValue, opts);
let #ok(jsonText) = JSON.toText(blob, [], opts);      // serde-core (escapes etc.)
```

The codegen *picks* the Candid ADT shape per construct, so the wire JSON
matches OpenAI exactly. No `to_candid` → no spurious `{"#tag": …}` wraps,
no type-table cycles from Motoko `Map<K,V>`.

## Wire-shape decisions (validated against the working IC.http_request fallback)

| Construct                          | OpenAI wire form                  | toCandidValue emits                        |
|------------------------------------|-----------------------------------|--------------------------------------------|
| record                             | `{ "f1": …, "f2": … }`            | `#Record([("f1", …), ("f2", …)])` (omit nulls) |
| enum                               | `"value"`                         | `#Text("value")`                           |
| string-flatten oneOf               | `"value"`                         | `#Text(value)` (identity on `Text`)        |
| string-or-array oneOf (e.g. `content`) | `"text"` *or* `[…parts]`      | `switch v { case (#string s) #Text s; case (#parts xs) #Array(map …) }` |
| discriminator oneOf (e.g. `messages[i]`) | `{"role":"user", …branch…}` | `switch v { case (#user m) #Record([("role", #Text "user"), …branch fields…]) }` |
| array                              | `[…]`                             | `#Array(Array.map xs)`                     |
| primitive Text/Int/Nat/Bool/Float  | string / number / bool            | `#Text` / `#Int` / `#Nat` / `#Bool` / `#Float` |
| optional `?T`                      | absent (when null)                | omit field at parent level (record-side filter) |
| Map<K,V> field                     | `{k: v, …}`                       | `#Record([(k, …), …])` from `Map.entries`  |

Wire-format observations from the fallback:
- `null` request fields are simply omitted (no `"x": null`). Achieved by record emission filter.
- Numbers (`max_tokens`) are JSON numbers, not strings — use `#Int(…)` / `#Nat(…)`.
- Discriminator literals (`"system"`, `"user"`, `"assistant"`, `"tool"`, `"function"`) are
  the OpenAPI `discriminator.mapping` keys — *not* schema names.
- Strings are properly escaped by serde-core's `JSON.toText` — we never roll our own.

## User-facing types (kept ergonomic, not always 1:1 with wire)

| Construct                          | User-facing Motoko type                                |
|------------------------------------|--------------------------------------------------------|
| record                             | record (unchanged)                                     |
| enum                               | tagged variant `{ #foo; #bar }` (unchanged)            |
| string-flatten oneOf               | `Text` (unchanged from 0.1.2)                          |
| string-or-array oneOf              | `{ #string : Text; #parts : [Part] }` — *renamed* from `#one_of_0` to descriptive arms |
| discriminator oneOf                | `{ #user : User; #system : System; … }` — tag = `discriminator.mapping` key (was: schema name) |
| generic oneOf (no flatten/discrim) | left unchanged — variant tag-wrap is already what OpenAI wants in those rare cases |

Tag-name change for discriminator-oneOf (e.g. `#ChatCompletionRequestUserMessage`
→ `#user`) is a breaking API change. Acceptable in 0.2.0 (pre-1.0); fallback's existing
tag form in caffeinelabs/CatFinity will need a one-line update at the same time.

## Java codegen changes (`MotokoClientCodegen.java`)

New detection passes in `postProcessAllModels`:

1. **Discriminator-oneOf detection** — read `composedSchema.getDiscriminator()` (already
   parsed by the OpenAPI core). For each oneOf model with a discriminator:
   - `m.vendorExtensions.put("x-is-discriminator-oneof", true)`
   - `m.vendorExtensions.put("x-discriminator-property", discriminator.getPropertyName())`
   - For each branch: look up the `mapping` value → store discriminator literal as
     `variant.put("discriminatorValue", "user")` alongside the existing variant fields
     produced in `postProcessModels`.
   - Suppress `x-is-string-flatten` / `x-is-empty-fallback` for discriminator-oneOf.

2. **String-or-array oneOf detection** — when a oneOf has exactly two branches, one
   `Text` (or string-flatten) and one `[X]` (array of anything):
   - `m.vendorExtensions.put("x-is-string-or-array-flatten", true)`
   - Pass per-branch info: which arm is the string, which is the array element type.

3. **Validate plumbing retirement**: drop `x-is-empty-fallback`, `x-needs-fallback-validation`,
   `x-has-fallback-validation` emission entirely. The diagnostic flag stays valuable
   for response-side body suffixing only.

## Mustache template changes

### `model.mustache` — full rewrite of the JSON sub-module per model

Each model's `JSON` sub-module becomes:

```motoko
public module JSON {
    public func toCandidValue(value : T) : Candid = …;       // shape-dependent
    public func fromCandidValue(candid : Candid) : ?T = …;   // shape-dependent
}
```

No more `JSON.JSON` shadow type, no more `toJSON` / `fromJSON` Motoko-record mirrors,
no more `validate` hooks. Per-shape Mustache branches:

- `{{#isEnum}}` → switch over user variants → `#Text(literal)`
- `{{#vendorExtensions.x-is-string-flatten}}` → identity (`#Text(value)` / pattern `#Text(s)`)
- `{{#vendorExtensions.x-is-discriminator-oneof}}` → switch arms → `#Record([("role", #Text discriminatorValue), …branchFields…])`
- `{{#vendorExtensions.x-is-string-or-array-flatten}}` → switch arms → `#Text` or `#Array`
- `{{#vendorExtensions.x-is-oneof}}` (generic) → switch arms → `#Variant(("tag", inner))` (current tag-wrap, kept as fallback)
- record (default) → fold over `vars`, emitting a Record with optional-field filtering

Inverse `fromCandidValue` for each shape, mirror-mapping. For records: pattern-match
`#Record(fields)`, lookup by name, recurse.

### `api.mustache` — pipeline cutover

Replace lines 134–148 with:

```motoko
body = {{#bodyParam}}do ? {
    let candidValue = {{dataType}}.toCandidValue({{paramName}});
    let #ok(blob) = Candid.encodeOne(candidValue, ?{ Candid.defaultOptions with skip_null_fields = true })
        else throw Error.reject("Failed to encode body");
    let #ok(jsonText) = JSON.toText(blob, [], ?{ Candid.defaultOptions with skip_null_fields = true })
        else throw Error.reject("Failed to serialize body to JSON");
    Text.encodeUtf8(jsonText)
}{{/bodyParam}}{{^bodyParam}}null{{/bodyParam}};
```

Drop the `validate(body)` block (top of bodyParam).

Replace response side (lines 163–215) with:

```motoko
(switch (JSON.fromText(_, null)) {
    case (#ok(blob)) blob;
    case (#err(msg)) throw Error.reject(…);
}) |>
Candid.decodeOne(_, [], null) |>
(switch (_) {
    case (#ok(candidValue)) {
        switch ({{returnType}}.fromCandidValue(candidValue)) {
            case (?value) value;
            case null throw Error.reject(…);
        }
    };
    case (#err(msg)) throw Error.reject(…);
})
```

(With branches for array / map / primitive return types, mirroring current.)

The reply-side `— server returned: <body>` suffix (gated on `{{#diagnostics}}`) stays.

## Files to change

- `MotokoClientCodegen.java` — add detection passes, retire validate plumbing.
- `model.mustache` — full rewrite of JSON sub-module emission.
- `api.mustache` — body + response pipeline cutover.
- `bin/configs/motoko-openai.yaml` — `artifactVersion: 0.2.0`.
- `samples/client/openai/motoko/generated/CHANGELOG.md` — 0.2.0 entry.

## Verification gates (must all pass before publish)

1. `mvn -pl modules/openapi-generator-cli -am package -DskipTests -q` — jar rebuilds clean.
2. `samples/client/openai/motoko/generate.sh` — regen succeeds, no Mustache errors.
3. `moc-wrapper --check $(mops sources) src/Apis/ChatApi.mo src/Models/*.mo` — type-checks
   the Chat surface clean (modulo the pre-existing unrelated `oneof-inner-array-tag-unsanitised`
   caveat on Completions models).
4. **Wire-byte parity** — emit the demo's request body
   (`gpt-4o-mini` + system + user + max_tokens=512) via `ChatApi.createChatCompletion`,
   capture the body bytes, compare against the fallback's hand-rolled JSON. Either
   byte-identical, or differs only in field ordering / whitespace (both are
   semantically equal JSON).

## Versioning

- **openai-client**: bump to `0.2.0` (NOT 0.1.4) — discriminator-oneOf tag
  rename is a consumer-visible breaking change.
- **serde-core**: bump to `0.2.0` (per user direction, coordinates with the
  openai-client major). Code targets the existing public surface (`Candid`
  ADT, `encodeOne`, `JSON.toText`, `Candid.decodeOne`).

## Out of scope for 0.2.0

- Generic oneOf (no discriminator, no flatten) — current tag-wrap behaviour stays.
  **User note (2026-04-27)**: a Chat-surface body that hits a generic oneOf will fail
  the same way (`{"#tag": …}` rejected by OpenAI), and we accept that risk for 0.2.0
  on the bet that the Chat surface only uses discriminator + string-flatten +
  string-or-array. Likely a 0.1.5 refinement round if the bet loses.
- Non-Chat surface APIs that may carry shapes we haven't verified.
- Upstream NatLabs/serde PR for the Decoder cycle fix.

## Open questions (resolve at code-time, not now)

- For discriminator-oneOf inverse: how strict on missing/unknown discriminator value?
  Plan: return `null`, let api.mustache convert to `Error.reject` with diagnostic suffix.
- For `Map<Text, V>` request-side encoding: emit as `#Record(map.entries)` — wire
  becomes `{k: v, …}`. (Confirmed against fallback's empty-`metadata` case which is just
  omitted by skip_null_fields.)
