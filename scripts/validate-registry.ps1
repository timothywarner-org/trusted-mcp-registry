<#
.SYNOPSIS
    Validates the trusted MCP registry: schema-checks every server manifest,
    schema-checks the allowlist, and runs cross-reference checks against the index.

.PARAMETER RegistryRoot
    Path to the repo root. Defaults to the parent of the scripts folder.

.PARAMETER Strict
    If set, the script exits non-zero on any validation failure (use in CI).

.EXAMPLE
    pwsh ./scripts/validate-registry.ps1 -Strict
#>
[CmdletBinding()]
param(
    [string] $RegistryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch] $Strict
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RegistryRoot     = (Resolve-Path $RegistryRoot).Path
$RegistryDir      = Join-Path $RegistryRoot 'registry'
$ServersDir       = Join-Path $RegistryDir 'servers'
$SchemasDir       = Join-Path $RegistryRoot 'schemas'
$ServerSchema     = Join-Path $SchemasDir 'registry-schema.json'
$AllowlistSchema  = Join-Path $SchemasDir 'allowlist-schema.json'
$AllowlistFile    = Join-Path $RegistryDir 'allowlist.json'
$IndexFile        = Join-Path $RegistryDir 'index.json'

$results = [System.Collections.Generic.List[pscustomobject]]::new()
function Add-Result {
    param([string] $Check, [string] $Target, [bool] $Passed, [string] $Detail = '')
    $results.Add([pscustomobject]@{
        Check  = $Check
        Target = $Target
        Status = if ($Passed) { 'PASS' } else { 'FAIL' }
        Detail = $Detail
    })
}

# 1. Server manifests vs registry-schema.json
$serverFiles = Get-ChildItem -Path $ServersDir -Filter '*.json' -File
if ($serverFiles.Count -eq 0) {
    Add-Result 'servers-present' $ServersDir $false 'No server manifests found.'
}
$serverIdsOnDisk = @{}
foreach ($file in $serverFiles) {
    try {
        $raw  = Get-Content $file.FullName -Raw
        $json = $raw | ConvertFrom-Json -ErrorAction Stop
        $ok   = Test-Json -Json $raw -SchemaFile $ServerSchema -ErrorAction Stop
        Add-Result 'schema:server' $file.Name $ok
        if ($ok -and $json.PSObject.Properties.Name -contains 'id') {
            $serverIdsOnDisk[$json.id] = $file.Name
        }
    } catch {
        Add-Result 'schema:server' $file.Name $false $_.Exception.Message
    }
}

# 2. Allowlist vs allowlist-schema.json
$allowlist = $null
try {
    $rawAllow = Get-Content $AllowlistFile -Raw
    $allowlist = $rawAllow | ConvertFrom-Json -ErrorAction Stop
    $ok = Test-Json -Json $rawAllow -SchemaFile $AllowlistSchema -ErrorAction Stop
    Add-Result 'schema:allowlist' 'allowlist.json' $ok
} catch {
    Add-Result 'schema:allowlist' 'allowlist.json' $false $_.Exception.Message
}

# 3. Cross-checks: allowlist vs server manifests
if ($null -ne $allowlist) {
    $allowed = @()
    if ($allowlist.PSObject.Properties.Name -contains 'allowedServers') {
        $allowed = @($allowlist.allowedServers)
    }
    $blocked = @()
    if ($allowlist.PSObject.Properties.Name -contains 'blockedServers') {
        $blocked = @($allowlist.blockedServers)
    }

    foreach ($id in $allowed) {
        $exists = $serverIdsOnDisk.ContainsKey($id)
        Add-Result 'allowlist:allowed-resolves' $id $exists `
            $(if (-not $exists) { 'No server manifest defines this id.' } else { '' })
    }
    foreach ($id in $blocked) {
        $exists = $serverIdsOnDisk.ContainsKey($id)
        Add-Result 'allowlist:blocked-resolves' $id $exists `
            $(if (-not $exists) { 'No server manifest defines this id.' } else { '' })
    }

    $overlap = @($allowed | Where-Object { $blocked -contains $_ })
    Add-Result 'allowlist:no-overlap' 'allowed/blocked' ($overlap.Count -eq 0) `
        $(if ($overlap.Count -gt 0) { "Overlap: $($overlap -join ', ')" } else { '' })
}

# 4. Cross-checks: index.json
try {
    $index = Get-Content $IndexFile -Raw | ConvertFrom-Json -ErrorAction Stop
    foreach ($entry in $index.servers) {
        # id must match a server file's id
        $idOk = $serverIdsOnDisk.ContainsKey($entry.id)
        Add-Result 'index:id-resolves' $entry.id $idOk `
            $(if (-not $idOk) { 'index.json references id with no matching manifest.' } else { '' })

        # manifest path must exist on disk (strip leading slash, resolve relative to RegistryRoot)
        $relPath  = $entry.manifest.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar)
        $absPath  = Join-Path $RegistryRoot $relPath
        $pathOk   = Test-Path -LiteralPath $absPath
        Add-Result 'index:path-exists' $entry.manifest $pathOk `
            $(if (-not $pathOk) { "Missing file: $absPath" } else { '' })
    }
} catch {
    Add-Result 'schema:index' 'index.json' $false $_.Exception.Message
}

# Render summary
$results | Sort-Object Status, Check, Target | Format-Table -AutoSize | Out-String | Write-Host

$failed = @($results | Where-Object Status -eq 'FAIL')
$passed = @($results | Where-Object Status -eq 'PASS')

Write-Host ("Summary: {0} passed, {1} failed." -f $passed.Count, $failed.Count)

if ($failed.Count -gt 0 -and $Strict.IsPresent) {
    exit 1
}
exit 0
