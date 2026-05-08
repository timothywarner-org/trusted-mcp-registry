# Trusted MCP Registry

A lightweight, Azure-hosted **Trusted MCP Registry** for VS Code on Windows 11
and GitHub Enterprise Cloud. Built as a teaching example by **Tim Warner**.

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

1. `az group create -n rg-trusted-mcp-registry -l eastus2`
2. `az deployment group create -g rg-trusted-mcp-registry -f infra/main.bicep`
3. Capture the deployment token:
   `az staticwebapp secrets list -n <name> -g rg-trusted-mcp-registry --query properties.apiKey -o tsv`
4. Set repo secret `AZURE_STATIC_WEB_APPS_API_TOKEN` to that value.
5. Push to `main` — the Action runs validation, then deploys.

## Phase 1 scope

See [`docs/trusted_mcp_registry_prd_tim_warner.md`](docs/trusted_mcp_registry_prd_tim_warner.md)
for the PRD, [`docs/architecture.md`](docs/architecture.md) for the design,
and [`docs/teaching-guide.md`](docs/teaching-guide.md) for the demo runbook.

## License

MIT. See [`LICENSE`](LICENSE).
