# Teaching Guide

A runbook for demonstrating the Trusted MCP Registry on camera or in a workshop.
Built around the principle: **the governance loop should be visible**.

## Prereqs

- Windows 11
- VS Code (MCP-capable build)
- PowerShell 7+ (`pwsh`)
- Node 20+ (only for `@azure/static-web-apps-cli` local preview)
- Azure CLI logged into a subscription
- GitHub Enterprise Cloud org with a repo for this code

## Demo 1 — Local validation (5 min)

**Beat:** "Before anything ships, the schema gates it."

```pwsh
pwsh ./scripts/validate-registry.ps1 -Strict
# expect: PASS table, exit 0
```

Then break it intentionally:

```pwsh
# edit registry/servers/github.json: change "transport": "stdio" to "carrier-pigeon"
pwsh ./scripts/validate-registry.ps1 -Strict
# expect: FAIL row pointing at the invalid enum, exit 1
```

Revert.

## Demo 2 — Local preview + sync (5 min)

**Beat:** "The registry is just JSON. Anyone can curl it. The sync script
applies the policy."

```pwsh
npx @azure/static-web-apps-cli start ./
# in another terminal
Invoke-RestMethod http://localhost:4280/registry/index.json
Invoke-RestMethod http://localhost:4280/registry/allowlist.json

./scripts/Sync-McpClient.ps1 -RegistryUrl http://localhost:4280
code .vscode/mcp.json
```

Open VS Code on the workspace and show that the MCP client picks up the three
allowed servers. The blocked Slack server is **not** in `mcp.json`, even though
its manifest is published.

## Demo 3 — Governance via PR (10 min, the headliner)

**Beat:** "One line in `allowlist.json` changes the trust posture for every
client that runs the sync."

1. Open a feature branch.
2. Edit `registry/allowlist.json`: move `"com.slack/slack-mcp"` from
   `blockedServers` to `allowedServers`.
3. Push, open PR.
4. **Show the validate workflow run.** It should pass (overlap check is fine,
   no overlap exists).
5. **Show the SWA preview environment URL** posted on the PR. Hit it:
   `Invoke-RestMethod https://<preview-host>/registry/allowlist.json` — Slack
   appears under `allowedServers`.
6. Reviewer asks: "Where is the security review for this?" — close PR
   without merging.
7. `git blame registry/allowlist.json` — show that the audit trail names the
   reviewer and the date.

## Demo 4 — CI catches an orphan reference (3 min)

**Beat:** "The validator catches mistakes humans miss."

1. Open a feature branch.
2. Add `"com.example/ghost-mcp"` to `allowedServers` *without* creating a
   manifest.
3. Push, open PR.
4. **Show the validate workflow fail** with
   `allowlist:allowed-resolves: FAIL  com.example/ghost-mcp  No server manifest defines this id.`
5. Close branch.

## Demo 5 — Deploy to Azure (5 min)

**Beat:** "This costs zero dollars and ships in seconds."

```pwsh
az group create -n rg-trusted-mcp-registry -l eastus2
az deployment group create -g rg-trusted-mcp-registry -f infra/main.bicep

az staticwebapp secrets list `
  -n <name from output> `
  -g rg-trusted-mcp-registry `
  --query properties.apiKey -o tsv
```

Paste the token into `Settings → Secrets and variables → Actions →
AZURE_STATIC_WEB_APPS_API_TOKEN`. Push to `main`. Watch deploy.yml run.
Final beat:

```pwsh
Invoke-RestMethod https://<deployed-host>.azurestaticapps.net/registry/index.json
./scripts/Sync-McpClient.ps1 -RegistryUrl https://<deployed-host>.azurestaticapps.net
```

## Closing line

> The registry is the policy plane. It does not run MCP servers. It does not
> proxy MCP traffic. It declares — in Git, with PR review — what is trusted.
> Everything else flows from that.
