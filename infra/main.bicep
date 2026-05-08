// Azure Static Web App for the Trusted MCP Registry (Phase 1 MVP).
// Free tier — public, anonymous reads of /registry/*.json. No Functions, no APIM.
//
// Deploy:
//   az group create -n rg-trusted-mcp-registry -l eastus2
//   az deployment group create -g rg-trusted-mcp-registry -f infra/main.bicep
//
// Then grab the deployment token:
//   az staticwebapp secrets list -n <name> -g rg-trusted-mcp-registry --query properties.apiKey -o tsv
// and store it in the repo secret AZURE_STATIC_WEB_APPS_API_TOKEN.

@description('Static Web App name (must be globally unique within the region).')
param siteName string = 'swa-trusted-mcp-${uniqueString(resourceGroup().id)}'

@description('Azure region for the Static Web App. eastus2, westus2, centralus, eastasia, westeurope are valid for Free tier.')
@allowed([
  'eastus2'
  'westus2'
  'centralus'
  'eastasia'
  'westeurope'
])
param location string = 'eastus2'

@description('Tags applied to all resources.')
param tags object = {
  workload: 'trusted-mcp-registry'
  owner: 'tim-warner'
  costCenter: 'learning'
  environment: 'demo'
}

resource swa 'Microsoft.Web/staticSites@2023-12-01' = {
  name: siteName
  location: location
  tags: tags
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    // GitHub-driven deploy: we publish via the static-web-apps-deploy action,
    // not by binding a repo here, so leave repository fields empty.
    allowConfigFileUpdates: true
    enterpriseGradeCdnStatus: 'Disabled'
  }
}

output staticWebAppName string = swa.name
output defaultHostname string = swa.properties.defaultHostname
output resourceId string = swa.id
