# Trusted MCP Registry

[![Validate](https://github.com/timothywarner-org/trusted-mcp-registry/actions/workflows/validate.yml/badge.svg)](https://github.com/timothywarner-org/trusted-mcp-registry/actions/workflows/validate.yml)
[![Deploy](https://github.com/timothywarner-org/trusted-mcp-registry/actions/workflows/deploy.yml/badge.svg?branch=main)](https://github.com/timothywarner-org/trusted-mcp-registry/actions/workflows/deploy.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A lightweight, Azure-hosted **Trusted MCP Registry** for VS Code on Windows 11
and GitHub Enterprise Cloud. Built as a teaching example by **Tim Warner**.

> Phase 1 MVP — a *policy plane* for MCP, not a runtime. JSON over HTTPS, an
> allowlist file in Git, a PowerShell sync script that materializes
> `.vscode/mcp.json`. Cost target: **~$0/month** on SWA Free tier.

This is a metadata + governance control plane, not a runtime. The registry
publishes JSON manifests over HTTPS; an allowlist file (PR-reviewed, Git-tracked)
declares which servers are trusted; a PowerShell sync script materializes
`.vscode/mcp.json` from the registry, filtered by policy.

> **Honest disclosure.** VS Code MCP clients read `mcp.json` (workspace or user
> scope), not a remote registry URL. The bridge is `scripts/Sync-McpClient.ps1`.
> Running that script *is* the governance demo on camera.

## Repository layout

```text
trusted-mcp-registry/
├── registry/
│   ├── index.json              # manifest of manifests
│   ├── allowlist.json          # allowed + blocked server IDs
│   └── servers/                # one manifest per MCP server
├── schemas/                    # JSON Schema (Draft 2020-12)
├── scripts/
│   ├── validate-registry.ps1   # CI gate
│   └── Sync-McpClient.ps1      # registry → .vscode/mcp.json bridge
├── staticwebapp.config.json    # SWA routes, CORS, MIME
├── infra/main.bicep            # SWA resource as IaC
├── .github/workflows/          # validate.yml, deploy.yml
└── docs/                       # PRD, architecture, teaching guide
```

## Quick start

### 1. Validate locally

```pwsh
pwsh ./scripts/validate-registry.ps1 -Strict
```

### 2. Serve locally with the SWA CLI

```pwsh
npx @azure/static-web-apps-cli start ./
# then in another terminal
Invoke-RestMethod http://localhost:4280/registry/index.json
```

### 3. Sync into VS Code

```pwsh
./scripts/Sync-McpClient.ps1 -RegistryUrl http://localhost:4280
```

Open the workspace in VS Code on Windows 11. The MCP client picks up
`.vscode/mcp.json`. Servers in `blockedServers` are excluded; servers not in
`allowedServers` are excluded.

## Deploy

```pwsh
# 1. Provision the SWA (Free tier, ~$0/month)
az group create -n rg-trusted-mcp-registry -l eastus2
az deployment group create -g rg-trusted-mcp-registry -f infra/main.bicep

# 2. Capture the deployment token and store it as a repo Action secret
$swa   = (az deployment group show -g rg-trusted-mcp-registry -n main --query properties.outputs.staticWebAppName.value -o tsv)
$token = az staticwebapp secrets list -n $swa -g rg-trusted-mcp-registry --query properties.apiKey -o tsv
gh secret set AZURE_STATIC_WEB_APPS_API_TOKEN -R timothywarner-org/trusted-mcp-registry --body $token

# 3. Push to main — validate.yml + deploy.yml take it from here
git push
```

After the deploy job goes green, point the camera at:

```pwsh
$host = (az staticwebapp show -n $swa -g rg-trusted-mcp-registry --query defaultHostname -o tsv)
Invoke-RestMethod "https://$host/registry/index.json"
```

## Phase 1 scope

See [`docs/trusted_mcp_registry_prd_tim_warner.md`](docs/trusted_mcp_registry_prd_tim_warner.md)
for the PRD, [`docs/architecture.md`](docs/architecture.md) for the design,
and [`docs/teaching-guide.md`](docs/teaching-guide.md) for the demo runbook.

## License

MIT. See [`LICENSE`](LICENSE).
