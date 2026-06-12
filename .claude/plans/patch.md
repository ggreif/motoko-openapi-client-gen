# Plan: Enable the PATCH HTTP Method (dogfood via preliminary pocket-ic)

## Background

Google Calendar's REST surface uses `PATCH` for every partial-update op
(`events.patch`, `calendars.patch`, `acl.patch`, `calendarList.patch`). The IC
management-canister `http_request` `method` variant is currently
`{ get; head; post; put; delete }` — **no `patch`** (confirmed in the canonical
`ic.did`). Filed as a feature request: **dfinity/portal#6244**.

`PATCH` is the one verb not idempotent by HTTP contract (RFC 5789 §2): idempotent
only when the body is a field-set *merge* (Google Calendar's is), not a *relative*
mutation. It is otherwise handled exactly like PUT/DELETE — a mutation forced into
**non-replicated mode** (`is_replicated = ?false`), so a single node issues one
request and there is no cross-replica response-consensus problem.

This plan adds `#patch` end-to-end so the `googlecalendar-client` builds **and** can
be runtime-tested against a **preliminary pocket-ic patched with the feature** —
rather than dropping the PATCH ops from v0.1.

## Difference from the PUT/DELETE rollout (important)

When PUT/DELETE were enabled (see git history of this file), the change lived in
`api.mustache`'s **local** `http_method` type, used only by the
`{{^useImportedInterface}}` branch (non-dfx / non-icp). But `googlecalendar-client`
is generated with `useIcp: true`, so its request type comes from the **`ic` mops
package**, not the template:

- `ic@4.0.0/src/Types.mo:190` — `method : { #get; #put; #head; #post; #delete };`

So the **primary** site for PATCH is the `ic` package, not the template. There are
three Motoko-side edits plus the pocket-ic work.

## Changes Required

### 1. `ic` mops package — add `#patch` (primary; feeds `useIcp` clients)

`ic@4.0.0/src/Types.mo`, the `HttpRequestArgs.method` variant:

```motoko
method : { #get; #put; #head; #post; #delete; #patch };
```

This is a third-party dependency. Options, in order of permanence:
- **Temporary (now):** patch the resolved `.mops/ic@4.0.0/src/Types.mo` in the
  generated dir to unblock local typecheck + pocket-ic testing.
- **Durable:** fork the `ic` package (mirror the existing `ggreif/serde` fork
  pattern in `mops.toml`) pinned to a `#patch`-bearing version, until upstream ships.

### 2. `api.mustache` — local `HttpMethod` type (non-icp/dfx clients)

Add `#patch` next to `#put`/`#delete` (lines ~55–61) so non-`useImportedInterface`
clients get it too:

```motoko
type HttpMethod = {
    #get;
    #head;
    #post;
    #put;    // Non-replicated only (is_replicated forced to ?false in generated code)
    #delete; // Non-replicated only (is_replicated forced to ?false in generated code)
    #patch;  // Non-replicated only; NOT idempotent in general (RFC 5789) — merge bodies only
};
```

### 3. `api.mustache` — force `is_replicated = ?false` for PATCH

In the `let request : HttpRequestArgs = { config with ... }` block (~line 152),
mirror the `isPut`/`isDelete` overrides:

```mustache
{{#isPut}}is_replicated = ?false; // PUT requires non-replicated mode on IC
{{/isPut}}{{#isDelete}}is_replicated = ?false; // DELETE requires non-replicated mode on IC
{{/isDelete}}{{#isPatch}}is_replicated = ?false; // PATCH: non-replicated mutation (not idempotent in general)
{{/isPatch}}
```

Unconditional and intentional, as with PUT/DELETE.

### 4. Plugin already handles the operationId (done, unrelated)

`MotokoClientCodegen.toOperationId` was added so Google's dot-separated IDs
(`calendar.events.patch`) sanitize to legal Motoko (`calendar_events_patch`).
Independent of the PATCH-method work; noted so it isn't re-investigated.

## Testing — dogfood against a preliminary pocket-ic

**Goal: typecheck AND runtime.** Unlike the PUT/DELETE rollout (typecheck-only,
because the local replica lacked them), here we build a **preliminary pocket-ic with
PATCH wired in** and exercise a real `events.patch` round-trip.

1. Rebuild plugin + regenerate googlecalendar (the generated code already emits
   `method = #patch` via `{{#lambda.lowercase}}{{httpMethod}}`).
2. Apply edit #1 (patch the resolved `ic` package) and run `typecheck.sh` →
   expect `events.patch` / `calendars.patch` / `acl.patch` / `calendarList.patch`
   to typecheck and `mops build OK`.
3. Stand up the preliminary pocket-ic carrying the PATCH feature; deploy a tiny
   canister importing the client; issue a `calendar_events_patch` against a mock
   Calendar endpoint; assert the outbound request method is `PATCH` and the
   non-replicated path is taken.

## Out of Scope (for now)

- dfx support for PATCH (separate, upstream).
- Publishing a `#patch` `ic` fork to mops (temporary local patch suffices for dogfooding).
- The upstream dfinity PR (offered in #6244; follows this same shape once the
  pocket-ic prototype validates it).
