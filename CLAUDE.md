# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

This is a **teaching/learning example**, not production. It's a Phase 1 MVP of a lightweight, Azure-hosted Trusted MCP Registry built for Tim Warner's Pluralsight content (VS Code on Windows 11 + GitHub Enterprise Cloud + Azure Static Web Apps). Every architectural choice prioritizes *demoability on camera* over production hardening — production-grade complexity (signed manifests, Entra ID, APIM, multi-tenant, dashboards) is explicitly Phase 2+ scope.

When suggesting changes, judge them against: "does this make the governance loop more visible in a recorded demo, or does it muddy it?"

## Commands

```pwsh
# Schema + cross-reference validation (the CI gate)
pwsh ./scripts/validate-registry.ps1 -Strict

# Local SWA preview (serves /registry/*.json on http://localhost:4280)
npx @azure/static-web-apps-cli start ./

# Materialize .vscode/mcp.json from the registry (the VS Code bridge)
./scripts/Sync-McpClient.ps1 -RegistryUrl http://localhost:4280
./scripts/Sync-McpClient.ps1 -RegistryUrl http://localhost:4280 -WhatIf   # preview without writing

# Bicep deploy (Azure CLI must be logged in)
az group create -n rg-trusted-mcp-registry -l eastus2
az deployment group create -g rg-trusted-mcp-registry -f infra/main.bicep
az staticwebapp secrets list -n <name> -g rg-trusted-mcp-registry --query properties.apiKey -o tsv
gh secret set AZURE_STATIC_WEB_APPS_API_TOKEN -R timothywarner-org/trusted-mcp-registry
```

There is no `package.json`, no test framework, no linter — the validator script *is* the test suite.

## Architecture — what you can't see by skimming files

### The control plane / runtime separation

The registry is a **policy plane only**. It publishes JSON over HTTPS and never proxies, hosts, or executes MCP servers. Treat any proposal that blurs this boundary (adding Functions, an MCP-traffic proxy, a runtime) as a Phase 2+ concern that needs explicit pushback in Phase 1. The PRD calls this out as the core architectural insight: *"the moment it starts executing workloads directly, complexity explodes."*

### The VS Code bridge gap

VS Code MCP clients (as of 2026) read `.vscode/mcp.json` (workspace) or `%APPDATA%\Code\User\mcp.json` (user). They do **not** subscribe to a remote registry URL. `scripts/Sync-McpClient.ps1` is the bridge that fetches `index.json`, `allowlist.json`, and the manifests for every allowed-and-not-blocked server, then writes a VS Code-shaped `mcp.json`. Running this script *is* the on-camera governance demo — don't propose changes that hide it (e.g., "let's just have VS Code read the registry directly" — that's not how the client works).

### Allowlist semantics (block always wins)

`registry/allowlist.json` has both `allowedServers[]` and `blockedServers[]`. The PRD only specified allowed; `blockedServers[]` was added because explicit deny is the AppLocker-style teaching beat. Filter logic in `Sync-McpClient.ps1`:

```
included = (id in allowedServers) AND (id NOT in blockedServers)
```

Block always wins. The validator (`scripts/validate-registry.ps1`) flags overlap as an error. Each server manifest also has its own `trust.status` field (`approved|pending|blocked`) — that's *informational* metadata for auditors; the **allowlist file is the enforcement boundary**. Keep trust posture in one diff-able place.

### Validator cross-checks (beyond schema)

Beyond `Test-Json` against the two Draft 2020-12 schemas, the validator enforces:

1. Every ID in `allowedServers` and `blockedServers` resolves to a real manifest in `registry/servers/`.
2. No ID appears in both lists (overlap = error).
3. Every `index.json` entry has a matching manifest file on disk.
4. Each `index.json` entry's `id` matches the manifest's own `id` field.

When adding a server, all four pass states must be considered together — adding a manifest without updating `index.json` is a silent bug the validator catches.

### CI/CD shape

Two workflows, both `runs-on: ubuntu-latest` with `pwsh`:
- `.github/workflows/validate.yml` — PR gate. Runs the validator. Exit 1 fails the PR.
- `.github/workflows/deploy.yml` — Validate → deploy → close-PR-preview. Triggers on `push` to `main` and `pull_request` (preview environments per PR are a key teaching beat — reviewers can `Invoke-RestMethod` against the preview URL pre-merge).

The deploy job will fail until repo secret `AZURE_STATIC_WEB_APPS_API_TOKEN` is set. The validate workflow runs without secrets, so PR validation works from day one.

### Locked-in Phase 1 decisions

- VS Code bridge: PowerShell sync script (not an extension)
- Allowlist shape: both `allowedServers[]` and `blockedServers[]`
- Domain: `azurestaticapps.net` (custom domain is a Phase 1.5 episode)
- CI runner: `ubuntu-latest` with `pwsh`
- SKU: SWA Free tier (~$0/month)
- Hosting shape: pure static — no Functions, no APIM, no DB
- IaC: Bicep, single SWA resource

These are the Phase 1 contract. If a proposed change conflicts with one, push back or escalate.

### Authoring conventions worth knowing

- Schemas are Draft 2020-12 with `additionalProperties: false`. Adding a property to a manifest requires updating the schema.
- Server `id` regex: `^[a-z0-9.-]+/[a-z0-9.-]+$` (reverse-DNS / short-name).
- `version` is strict semver 2.0.0 (regex enforced in schema).
- `lastReviewed` is ISO 8601 date (`YYYY-MM-DD`).
- `.editorconfig` enforces LF for everything except `*.ps1` (CRLF) — git's `core.autocrlf=true` will warn on commit; that's expected.
- `staticwebapp.config.json` ships `Access-Control-Allow-Origin: *` *intentionally* — this is a public allowlist demo. Don't copy that into a private/internal registry.

## Where to look

- `docs/trusted_mcp_registry_prd_tim_warner.md` — original PRD (what Tim asked for)
- `docs/architecture.md` — the design (how it actually works)
- `docs/teaching-guide.md` — 5-demo runbook (what gets recorded)
- `~/.claude/projects/C--github-trusted-mcp-registry/memory/` — prior-conversation context for Phase 1 decisions
