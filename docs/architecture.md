# Architecture

## What this is

A **policy plane** for MCP servers. The registry publishes JSON metadata over
HTTPS; the allowlist declares what is trusted; a sync script translates that
policy into a VS Code-shaped `mcp.json`.

It is **not** a runtime, a marketplace, a package manager, or a proxy.

## Data flow

```text
PR opened on registry/ or allowlist
        │
        ▼
GitHub Actions: validate.yml  (schema + cross-refs)
        │ pass
        ▼
Reviewer hits SWA preview environment
        │ approved + merged
        ▼
GitHub Actions: deploy.yml    (Azure/static-web-apps-deploy)
        │
        ▼
Azure Static Web Apps          https://<host>/registry/*.json
        │
        ▼
scripts/Sync-McpClient.ps1     (developer or scheduled task)
        │
        ▼
.vscode/mcp.json               (VS Code MCP client reads this)
```

## Why JSON over Static Web Apps

- The registry is **mostly static metadata**. Git is the database.
- SWA Free tier covers all Phase 1 needs: HTTPS, custom domains, preview
  environments per PR, 100 GB bandwidth/month. Cost target ≈ $0.
- No Functions, no APIM, no DB. Adding any of those before the policy story
  is recorded would be premature complexity.

## Why the sync script exists

VS Code MCP clients (as of 2026) read `.vscode/mcp.json` (workspace) or
`%APPDATA%\Code\User\mcp.json` (user). They do **not** subscribe to a remote
registry URL. Two ways to bridge:

1. **Sync script** (Phase 1): the developer runs
   `Sync-McpClient.ps1 -RegistryUrl ...` after a policy change. It fetches
   `index.json`, `allowlist.json`, and the manifests of every allowed-and-not-blocked
   server, then writes a VS Code-shaped `mcp.json`. The friction is intentional —
   it makes the governance step *visible*.
2. **VS Code extension** (future): a Phase 2+ effort. Out of scope here.

## Allowlist semantics

| Listing | Effect on the synced `mcp.json` |
|---|---|
| In `allowedServers`, not in `blockedServers` | Included |
| In `allowedServers`, also in `blockedServers` | **Excluded** — block wins |
| In `blockedServers` only                    | Excluded (and validator flags overlap) |
| In neither                                  | Excluded (default deny) |

`trust.status` on the manifest itself is informational metadata for auditors and
reviewers; the **allowlist file** is the enforcement boundary. This keeps the
trust posture in one diff-able place.

## Schema discipline

Two schemas, both Draft 2020-12, both with `additionalProperties: false`:

- `schemas/registry-schema.json` — server manifests
- `schemas/allowlist-schema.json` — allowlist

The validator script enforces:

1. Every `registry/servers/*.json` matches the server schema.
2. `registry/allowlist.json` matches the allowlist schema.
3. Every ID in `allowedServers` and `blockedServers` resolves to a manifest.
4. No ID appears in both `allowedServers` and `blockedServers`.
5. Every `index.json` entry has a matching manifest file on disk and an `id`
   that matches the manifest's `id`.

## CORS posture

`Access-Control-Allow-Origin: *` is intentional for this **public** allowlist
demo. Do **not** copy this into a private/internal registry — replace `*` with
an explicit origin or a tenant-scoped policy.

## Cost

| Resource                        | Estimated cost      |
|---|---|
| Azure Static Web Apps (Free)    | $0/month            |
| GitHub Actions (public repo)    | Free minutes        |
| Custom domain (deferred)        | Domain registrar fee only |

Phase 1 target: **< $0.50/month**. Realistically: zero.

## Phase evolution (out of scope here)

| Phase | Adds |
|---|---|
| 2 | Signed manifests, hash validation, publisher verification |
| 3 | Entra ID auth, tenant-aware private registries |
| 4 | APIM in front of remote MCP servers (throttling, audit) |
| 5 | Governance dashboard (approval/denial metrics) |
