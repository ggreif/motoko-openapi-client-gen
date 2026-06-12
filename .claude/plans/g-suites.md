# Google application API suites — OpenAPI availability & IC feasibility

Google publishes a machine-readable **API Discovery Document** (JSON) for every
Workspace/Cloud API, served unauthenticated from the Discovery Service
([root](https://discovery.googleapis.com/discovery/v1/apis)). These convert to
OpenAPI with [`google-discovery-to-swagger`](https://github.com/APIs-guru/google-discovery-to-swagger)
(OpenAPI 2.0) or the newer [`google-discovery-to-openapi`](https://github.com/stackql/google-discovery-to-openapi)
(OpenAPI 3.x), and **[APIs.guru](https://github.com/APIs-guru/google-discovery-to-swagger)** already hosts
~200 Google APIs (4000+ endpoints) as OpenAPI, refreshed daily. **Maps Platform**
is the exception that *ships its own* official OpenAPI spec
([`googlemaps/openapi-specification`](https://github.com/googlemaps/openapi-specification)).

So spec availability is **not** the constraint — the constraint is the **verb
set**. The IC's HTTP outcalls + this generator support `GET / POST / PUT /
DELETE` but **not `PATCH`** yet. Google REST APIs use `PATCH` for partial
resource updates; the question per app is *how much of the useful surface is
reachable without PATCH*. The decisive pattern: the editor APIs route **all**
edits through a single **`batchUpdate` (POST)** endpoint, and several resources
offer a full-replace **`update` (PUT)** alongside the `patch` — both sidestep
`PATCH` cleanly.

| App | Spec / format | Verb style & PATCH reliance | Auth | IC verdict |
|---|---|---|---|---|
| **Maps Platform** | Own OpenAPI 3 (googlemaps) | GET / POST query services; **no PATCH** | **API key** | ✅ Feasible (best) |
| **Gmail** | Discovery → OpenAPI | `send`/`modify`/`batchModify` are **POST**; no PATCH | OAuth2 | ✅ Feasible |
| **Docs** | Discovery → OpenAPI | `documents.batchUpdate` = **POST**; `get`/`create`; no PATCH | OAuth2 | ✅ Feasible |
| **Sheets** | Discovery → OpenAPI | `batchUpdate` **POST** + `values.update` **PUT**; no PATCH | OAuth2 | ✅ Feasible |
| **Slides** | Discovery → OpenAPI | `presentations.batchUpdate` = **POST**; no PATCH | OAuth2 | ✅ Feasible |
| **Calendar** | Discovery → OpenAPI | `events.update` = **PUT** (full replace) *or* `events.patch` = PATCH | OAuth2 | ✅ Feasible (use PUT) |
| **Drive** | Discovery → OpenAPI | create POST / get·list GET / delete DELETE / copy POST, but **`files.update` is PATCH-only** | OAuth2 | ⚠️ Partial |
| **People / Tasks / YouTube Data** | Discovery → OpenAPI | mixed; updates typically `update` PUT *or* PATCH | OAuth2 | ◐ Per-method |

### Per-app notes

- **Maps Platform** — Geocoding, Directions/Routes, and Places are *query*
  services (mostly `GET`, some `POST` like Routes); there is no `PATCH` surface
  at all, and they authenticate with an **API key** rather than OAuth2 — the
  simplest credential model for a canister. Plus it's the one suite with an
  official Google-authored OpenAPI spec.
  [spec](https://github.com/googlemaps/openapi-specification) ·
  [Places](https://developers.google.com/maps/documentation/places/web-service/overview)
- **Gmail** — core mutations are `POST`: `users.messages.send`,
  `users.messages.modify` / `batchModify`, `users.threads.modify`,
  `users.drafts.send`; reads are `GET`, deletes `DELETE`. No `PATCH` on the
  hot path. [modify](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/modify)
- **Docs** — *all* editing goes through `documents.batchUpdate` (**POST**); plus
  `documents.get` (GET) and `documents.create` (POST). Zero `PATCH`.
  [batchUpdate](https://developers.google.com/workspace/docs/api/reference/rest/v1/documents/batchUpdate)
- **Sheets / Slides** — same `batchUpdate` (POST) pattern as Docs; Sheets also
  has `spreadsheets.values.update` (**PUT**) and `…values.append` (POST). No
  `PATCH` needed.
- **Calendar** — offers **both** `events.update` (**PUT**, full replace) and
  `events.patch` (PATCH, partial). The PUT path (Google even recommends
  `get`-then-`update` with etags) makes Calendar fully usable without PATCH.
  [update](https://developers.google.com/workspace/calendar/api/v3/reference/events/update) ·
  [patch](https://developers.google.com/workspace/calendar/api/v3/reference/events/patch)
- **Drive** — the one genuinely PATCH-gated suite: `files.update`,
  `revisions.update`, `permissions.update`, `drives.update` are **all `PATCH`**.
  Create (POST), get/list (GET), delete (DELETE), copy/export (POST) work, so a
  *read + create + share-by-create + delete* client is feasible; **metadata
  updates are blocked** until PATCH support lands.
  [files.update](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/update)

### Recommendation — target first (given no PATCH)

1. **Maps Platform** — easiest by far: official OpenAPI, **API-key** auth (no
   OAuth2 dance in-canister), pure GET/POST, *zero* PATCH. Highest "works today"
   ratio.
2. **Gmail** — high utility (a canister that sends/triages mail); `send`/`modify`
   are POST, so the whole useful surface is reachable. Needs OAuth2 bearer.
3. **Docs** (then Sheets/Slides for free) — the `batchUpdate`-POST design means
   the **entire editing model** is one POST endpoint; no PATCH ever. The same
   pattern generalises across the three editor apps.

**What PATCH support would unlock:** Drive metadata `files.update` (the main
gap), Calendar's quota-cheaper partial `events.patch`, and partial-update
efficiency everywhere — but none of the three recommended suites *need* it.

---
*Cross-cutting:* Workspace APIs require **OAuth2 bearer tokens** (token
acquisition/refresh is the IC-side work); **Maps uses API keys**. All specs are
obtainable via the Discovery→OpenAPI pipeline above (or APIs.guru) except Maps,
which is first-party OpenAPI.

**Sources:**
[Discovery service](https://discovery.googleapis.com/discovery/v1/apis) ·
[google-discovery-to-swagger](https://github.com/APIs-guru/google-discovery-to-swagger) ·
[google-discovery-to-openapi](https://github.com/stackql/google-discovery-to-openapi) ·
[Maps OpenAPI](https://github.com/googlemaps/openapi-specification) ·
[Drive files.update](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/update) ·
[Gmail messages.modify](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/modify) ·
[Docs batchUpdate](https://developers.google.com/workspace/docs/api/reference/rest/v1/documents/batchUpdate) ·
[Calendar events.update](https://developers.google.com/workspace/calendar/api/v3/reference/events/update)
