# API v1 (application release 0.1.0)

HTTPS required outside local browser development. All JSON. A missing configured PostgreSQL database makes writes unavailable; immutable public snapshot mode is supported when no database URL is configured. Error payloads use `{ "error": "message" }`.

| Method / route | Access | Behavior |
|---|---|---|
| GET /health | Public | Process liveness |
| GET /ready | Public | Database/read-only readiness |
| GET /api/config | Public | Countries, categories, configured feature indicators |
| GET /api/directory?version=N | Public | Whole approved snapshot; unchanged marker if version matches |
| GET /api/helplines?country=IN&category=fire&q=&channel=phone&region= | Public | Filters within one explicitly supplied country |
| POST /api/chat | Public, 15/min | `{country,message,allow_online,region?}`; consent required for online model routing |
| GET /api/admin/reviews | Reviewer/publisher token | Pending/history queue, sources, audit |
| POST /api/admin/proposals | Reviewer token | Validated record JSON; no direct publication |
| POST /api/admin/reviews/:id/approve | Publisher token | `{notes}` (10+ characters); atomic version/history update |
| POST /api/admin/reviews/:id/reject | Publisher token | `{notes}`; resolve pending record or source alert |
| POST /api/sos | Public, general rate limit | `{country}`; returns id and one-hour private capability; notifications not sent |
| GET /api/sos/:id | Session capability | Status, expiry and latest shared position |
| POST /api/sos/:id/location | Session capability | `{lat,lng,accuracy}`; active, unexpired sessions only |
| PATCH /api/sos/:id | Session capability | `{status:"safe"|"cancelled"}`; deletes positions |
| DELETE /api/sos/:id | Session capability | Deletes session and positions |

Credentials use `Authorization: Bearer <token>`. A private share URL stores the capability after `#share=`; the viewer passes it in the Authorization header. Never put it in a query string, log or public API response. Public directory requests require no credential. General API limit: 120 requests/minute per client IP. Shared deployment instances require a distributed limiter before scaling.

Record shape is illustrated in shared/directory.json; all categories must exist in shared/categories.json. Contact values must match their channel format. A source must already be manually government-vetted and approved in PostgreSQL. Phone format validity is not evidence of service validity; source review remains mandatory.

The current full-snapshot sync uses one monotonically incrementing PostgreSQL directory version. A client replaces its entire local snapshot in one SQLite transaction, so removed records cannot linger through a partial merge. Deltas and multi-device account synchronization are not implemented.

To withdraw an existing record, the reviewer submits its current JSON with `published:false`. The publisher must approve it normally. The underlying row and historical revisions are preserved; approved snapshots omit it. Reseeding does not republish a withdrawn record.
