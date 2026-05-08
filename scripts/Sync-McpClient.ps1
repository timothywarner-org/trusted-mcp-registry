<#
.SYNOPSIS
    Bridges the trusted MCP registry to a VS Code MCP client by materializing
    .vscode/mcp.json from the published registry, filtered by allowlist/blocklist.

.DESCRIPTION
    VS Code MCP clients read mcp.json (workspace or user scope), not a remote
    registry URL. This script is the governance bridge: it fetches index.json,
    allowlist.json, and the manifests for every allowed-and-not-blocked server,
    then writes a VS Code-shaped mcp.json. Run it after a registry/allowlist
    change has been merged.

.PARAMETER RegistryUrl
    Base URL of the deployed registry (e.g. https://nice-tree.azurestaticapps.net
    or http://localhost:4280 when using @azure/static-web-apps-cli).

.PARAMETER OutFile
    Where to write mcp.json. Defaults to .vscode/mcp.json under the current
    working directory (Workspace scope).

.PARAMETER Scope
    Workspace (default) writes .vscode/mcp.json under -OutFile's directory.
    User writes %APPDATA%\Code\User\mcp.json on Windows.

.PARAMETER WhatIf
    If supplied, prints the resolved mcp.json to the console without writing.

.EXAMPLE
    ./scripts/Sync-McpClient.ps1 -RegistryUrl http://localhost:4280

.EXAMPLE
    ./scripts/Sync-McpClient.ps1 -RegistryUrl https://nice-tree.azurestaticapps.net -Scope User
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string] $RegistryUrl,

    [string] $OutFile,

    [ValidateSet('Workspace', 'User')]
    [string] $Scope = 'Workspace'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $OutFile) {
    if ($Scope -eq 'User') {
        $OutFile = Join-Path $env:APPDATA 'Code\User\mcp.json'
    } else {
        $OutFile = Join-Path (Get-Location) '.vscode\mcp.json'
    }
}

$base = $RegistryUrl.TrimEnd('/')

Write-Host "Fetching index.json from $base ..." -ForegroundColor Cyan
$index     = Invoke-RestMethod -Uri "$base/registry/index.json" -Method GET
$allowlist = Invoke-RestMethod -Uri "$base$($index.allowlist)" -Method GET

$allowed = @($allowlist.allowedServers)
$blocked = @()
if ($allowlist.PSObject.Properties.Name -contains 'blockedServers') {
    $blocked = @($allowlist.blockedServers)
}

# Filter: must be allowed AND must not be blocked. Block always wins.
$wanted = $index.servers | Where-Object {
    ($allowed -contains $_.id) -and ($blocked -notcontains $_.id)
}

$servers = [ordered]@{}
foreach ($entry in $wanted) {
    Write-Host "  Resolving $($entry.id) ..." -ForegroundColor DarkGray
    $manifest = Invoke-RestMethod -Uri "$base$($entry.manifest)" -Method GET

    $serverEntry = [ordered]@{
        type = $manifest.transport
    }

    if ($manifest.PSObject.Properties.Name -contains 'launch' -and $null -ne $manifest.launch) {
        $serverEntry.command = $manifest.launch.command
        if ($manifest.launch.PSObject.Properties.Name -contains 'args') {
            $serverEntry.args = @($manifest.launch.args)
        }
        if ($manifest.launch.PSObject.Properties.Name -contains 'env' -and $null -ne $manifest.launch.env) {
            $serverEntry.env = $manifest.launch.env
        }
    }

    $servers[$manifest.id] = $serverEntry
}

$mcpJson = [ordered]@{
    '$schema'       = 'https://aka.ms/vscode-mcp-schema'
    '_generatedBy'  = 'trusted-mcp-registry/Sync-McpClient.ps1'
    '_generatedAt'  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    '_registryUrl'  = $base
    servers         = $servers
}

$rendered = $mcpJson | ConvertTo-Json -Depth 10

if ($WhatIfPreference) {
    Write-Host ''
    Write-Host '--- mcp.json (preview, not written) ---' -ForegroundColor Yellow
    Write-Host $rendered
    return
}

$outDir = Split-Path -Parent $OutFile
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# UTF-8 NoBOM
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutFile, $rendered, $utf8NoBom)

Write-Host ''
Write-Host ("Wrote {0} server entries to {1}" -f $servers.Count, $OutFile) -ForegroundColor Green
if ($blocked.Count -gt 0) {
    Write-Host ("Blocked (excluded): {0}" -f ($blocked -join ', ')) -ForegroundColor DarkYellow
}
