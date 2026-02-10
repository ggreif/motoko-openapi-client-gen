# SECURITY: vetKeys Memory Persistence Vulnerability & Mitigation

## Problem: Plaintext Credentials Persist in Heap Memory

### The Vulnerability

When using vetKeys for credential storage in IC canisters, decrypted credentials exist as **plaintext in Wasm heap memory** during execution:

```motoko
public func apiCall() : async Result {
    let token = await vetKeys.decrypt(caller, "api_key");  // Plaintext in heap
    
    let result1 = await* api.call1(token);  // ⚠️ await → state serialized
    let result2 = await* api.call2(token);  // ⚠️ await → state serialized
    
    // token persists in heap until function returns
    // Visible during any state inspection between awaits!
};
```

**Attack vectors:**
1. **Controller state dumps** during await suspension
2. **Canister inspection** via `canister_status` or debug tools
3. **Memory persistence** after credential use (no zeroing in Motoko)
4. **Upgrade serialization** if token in scope during `pre_upgrade`

**Current Motoko limitations:**
- No explicit memory zeroing (`memset(0)`)
- No guarantee of cleanup after scope exit
- Immutable types (Text, Blob) can't be overwritten
- GC timing is non-deterministic

## Solution: Compiler-Level Cleanup Primitives

### Proposed Motoko Enhancement

**1. Memory Zeroing Primitive:**
```motoko
// New primitive in mo:prim
Prim.zeroBlob(blob : Blob) : ()
Prim.zeroText(text : Text) : ()
```

**2. Cleanup Thunk Syntax:**
```motoko
// Execute cleanup AFTER Candid encoding, BEFORE await
// Attached to the outcall along with cycles
(with cleaning = cleanup_expr; cycles = cycles_expr) outcall_expr
```

**3. Critical Timing Guarantee:**
```
1. Evaluate: outcall(token) → construct args, Candid encode
2. Execute: cleanup_expr → zero token memory (GC-aware!)
3. Attach: cycles to message
4. Submit: message to outqueue
5. Await: serialize state (token already zeroed) ✅
```

**4. GC Interaction (Critical!):**

The incremental GC may **move the blob at any time** - even BEFORE Candid encoding:

```motoko
let token = await decrypt();                    // Allocate blob at address A
// ... GC runs, moves blob to address B (leaves forwarding pointer at A)
// ... Candid encoding reads from B (follows forwarding pointer)
(with cleaning = Prim.zeroBlob(token); ...) outcall(token);
// ⚠️ Must zero address B (actual data), optionally A too!
```

**Why this matters:**
- Candid encoder automatically follows forwarding pointers (gets data from B)
- Cleanup primitive must ALSO follow forwarding pointers (zero B, not just A)
- If cleanup only zeros A, the actual cleartext at B remains in memory!

**Prim.zeroBlob must:**
1. Check if blob has forwarding pointer at current address
2. If moved: zero the **new location** (address B - the actual data)
3. Optionally: zero old location (address A - defense in depth)

### Example Usage

**User writes:**
```motoko
public func searchSpotify(query: Text) : async Result {
    // Decrypt credential
    let token = await vetKeys.decrypt(caller, "spotify_token");

    // Build config (token still needed)
    let config = {
        baseUrl = "https://api.spotify.com/v1";
        accessToken = ?token;
        cycles = 30_000_000_000;
        // ...
    };

    // Call API using generated client
    await* spotifyApi.search(config, query);

    // ✅ token zeroed before await suspension (follows forwarding pointers)
    // ✅ controller dumps see only zeros
    // ✅ never persists in serialized state
};
```

**Generated client code:**
```motoko
// In generated DefaultApi.mo
public func search(config : Config__, query : Text) : async* Result {
    let accessToken = config.accessToken;

    // ... build headers, request body, etc ...

    // Attach cleanup + cycles to the http_request outcall
    await (with cleaning = Prim.zeroBlob(accessToken); cycles = config.cycles)
        http_request(httpRequest);
};
```

The key: **cleanup happens inside the generated client**, after Candid encoding but before the await point.

## Security Guarantees

### With Compiler Support ✅
- Token zeroed before state serialization
- Controller cannot dump plaintext via canister_status
- Upgrade doesn't persist token in heap
- GC timing irrelevant (already zeroed)

### Unavoidable Window ⚠️
- Token plaintext during Candid encoding (necessary to construct message)
- Token plaintext in outqueue message (necessary for HTTP outcall)
- External API receives plaintext (necessary for authentication)

### Still Requires Trust ⚠️
- Canister code must not exfiltrate credentials
- Code must use cleanup primitives correctly
- Malicious code can still steal credentials before cleanup

## Implementation Status

**Phase 1-4:** Authentication transport (bearer, API keys, basic auth) ✅
**Phase 5:** Secure credential storage with vetKeys
  - **Blocked on:** Motoko compiler enhancement (`Prim.zeroBlob` + cleanup thunks)
  - **Workaround:** Per-call decryption pattern (partial mitigation)
  - **Future:** Generate code ready for primitive when available

## Motoko Team Feature Request

**Minimal Version:**
1. `Prim.zeroBlob(blob : Blob) : ()` primitive
2. Manual cleanup before await (no syntax sugar)

**Full Version:**
1. Memory zeroing primitives
2. `(with cleaning = expr) await_expr` syntax
3. `Sensitive<T>` marker type with automatic tracking
4. Compiler errors if cleanup missed before await

**Complexity:** Moderate - needs changes to:
- RTS: memory zeroing implementation
- Compiler: desugaring of cleanup syntax
- Type checker: escape analysis for safety

## Reference Implementation Pattern

```motoko
// Generated wrapper (Phase 5)
public func withCredential<T>(
    principal: Principal,
    keyName: Text,
    operation: (Text) -> async* T
) : async* T {
    let token = await vetKeys.decrypt(principal, keyName);
    
    #if (has_prim "zeroBlob")
        // Secure: cleanup after use
        (with cleaning = Prim.zeroBlob(token))
            await* operation(token)
    #else
        // Fallback: best-effort (still vulnerable)
        await* operation(token)
        // Pray for GC... 🙏
    #endif
};
```

## Key Insight

**vetKeys solve storage security, but not execution security.**

- ✅ Protects: Credentials at rest (encrypted in replicated state)
- ❌ Doesn't protect: Credentials during use (plaintext in heap)
- 🎯 Solution: Compiler primitives to minimize plaintext lifetime

**This requires language-level support - cannot be solved in userland.**

## Related Discussions

- Phase 5 planning: Authentication implementation plan (git notes --ref=planning)
- vetKeys documentation: IC specification (threshold cryptography)
- Motoko security: Language design for secure credential handling

---

**Action Items for Phase 5:**
1. Implement workaround pattern (per-call decryption)
2. Document limitation in generated code comments
3. File feature request with Motoko team
4. Design API ready for future primitive support
5. Generate conditional code (`#if has_prim "zeroBlob"`)

