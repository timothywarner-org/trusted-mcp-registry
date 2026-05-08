# PRD.md
# Lightweight Trusted MCP Registry for GitHub Enterprise Cloud + VS Code

## Executive Summary

Build a lightweight, inexpensive, Azure-hosted Trusted MCP Registry designed for:

- VS Code on Windows 11
- GitHub Enterprise Cloud experimentation
- Simple allowlist editing
- Enterprise governance demonstrations
- MCP trust and discovery education
- Minimal operational overhead

The system should:

- Implement the Anthropic-style Trusted MCP Registry concept
- Serve registry metadata over HTTPS
- Maintain a human-editable allowlist
- Be deployable cheaply in Azure
- Integrate cleanly with VS Code MCP clients
- Support future evolution toward enterprise governance

This is intentionally NOT:

- A full MCP server platform
- A package manager
- A marketplace
- A runtime execution environment
- An API gateway

This project is a metadata and trust control plane.

---

# Goals

## Primary Goals

1. Create a trusted MCP registry prototype
2. Host the registry inexpensively in Azure
3. Make allowlist editing dead simple
4. Support GitHub Enterprise Cloud testing
5. Work with VS Code MCP clients on Windows 11
6. Demonstrate enterprise MCP governance patterns
7. Keep architecture minimal and understandable

---

# Non-Goals

## Explicit Non-Goals

- Building MCP servers themselves
- Container orchestration
- Complex RBAC systems
- Marketplace ratings/reviews
- Billing/subscriptions
- Multi-tenant SaaS
- High-scale distributed infrastructure
- Kubernetes deployment
- Dynamic package hosting

This is intentionally a small, opinionated MVP.

---

# Conceptual Architecture

## High-Level Flow

```text
VS Code MCP Client
        ↓
Trusted MCP Registry
        ↓
Approved MCP Metadata
        ↓
MCP Server Discovery
        ↓
Direct MCP Server Connection
```

Important:

The registry does NOT proxy MCP traffic.

It only provides:

- metadata
- trust
- discovery
- allowlisting
- governance

---

# Recommended Azure Architecture

## Recommendation

Use:

- Azure Static Web Apps
- Azure Blob Storage
- Azure Front Door optional later
- GitHub Actions deployment

Avoid:

- Kubernetes
- Cosmos DB
- APIM initially
- Container Apps initially
- SQL databases

---

# Why Static Web Apps?

## Benefits

- Dirt cheap
- Fast global hosting
- Native GitHub integration
- HTTPS included
- Minimal operational burden
- Easy custom domain support
- Great for metadata APIs

The registry is mostly static JSON.

That makes Static Web Apps nearly perfect.

---

# Suggested Repository Structure

```text
trusted-mcp-registry/
│
├── registry/
│   ├── index.json
│   ├── servers/
│   │   ├── github.json
│   │   ├── filesystem.json
│   │   ├── azure-ai-search.json
│   │   └── slack.json
│   │
│   └── allowlist.json
│
├── schemas/
│   └── registry-schema.json
│
├── docs/
│   └── architecture.md
│
├── scripts/
│   └── validate-registry.ps1
│
├── .github/
│   └── workflows/
│       └── deploy.yml
│
└── README.md
```

---

# Registry Design

## Registry Philosophy

The registry is:

- simple JSON
- git-backed
- human-editable
- auditable
- version-controlled

No database initially.

Git is the database.

This dramatically simplifies:

- rollback
- auditing
- approvals
- pull requests
- governance demos

---

# Allowlist Design

## Primary Requirement

The allowlist must be extremely easy to edit.

Recommendation:

```json
{
  "allowedServers": [
    "io.github.github/github-mcp",
    "com.microsoft/filesystem-mcp",
    "com.timothywarner/azure-ai-search"
  ]
}
```

That file becomes:

- source control friendly
- PR-review friendly
- easy to diff
- easy to demo
- easy to audit

---

# Why This Matters

This creates a powerful governance story:

```text
Merge PR
    ↓
Registry Updates
    ↓
Allowlist Changes
    ↓
VS Code Clients Respect Policy
```

This mirrors:

- enterprise package approvals
- AppLocker
- extension governance
- trusted publisher models

---

# Suggested Registry Metadata Format

## Example MCP Metadata

```json
{
  "id": "io.github.github/github-mcp",
  "name": "GitHub MCP Server",
  "publisher": "GitHub",
  "version": "1.0.0",
  "description": "GitHub integration MCP server",
  "transport": "stdio",
  "launch": {
    "command": "npx",
    "args": [
      "-y",
      "@github/github-mcp-server"
    ]
  },
  "capabilities": [
    "tools",
    "resources"
  ],
  "authentication": {
    "type": "oauth"
  },
  "trust": {
    "approved": true,
    "reviewedBy": "Tim Warner",
    "lastReviewed": "2026-05-08"
  }
}
```

---

# Initial Technical Stack

## Recommended Stack

| Component | Recommendation |
|---|---|
| Hosting | Azure Static Web Apps |
| Source Control | GitHub Enterprise Cloud |
| Registry Storage | JSON Files |
| Auth | Optional initially |
| CI/CD | GitHub Actions |
| Validation | PowerShell + JSON Schema |
| Client | VS Code |
| Operating System | Windows 11 |

---

# Why NOT Use a Database Initially?

Because this is fundamentally:

- metadata
- governance
- configuration
- policy

Git already solves:

- versioning
- approvals
- rollback
- auditing
- collaboration

Adding a database early would mostly add complexity.

---

# Future Evolution Path

## Phase 1

Static registry.

Manual allowlist.

GitHub PR workflow.

---

## Phase 2

Add signed manifests.

Example:

- manifest signatures
- publisher verification
- hash validation

---

## Phase 3

Add Entra ID authentication.

Potential features:

- tenant-aware access
- internal/private registries
- role-based approvals

---

## Phase 4

Add APIM in front of remote MCP servers.

This enables:

- throttling
- auditing
- conditional access
- rate limiting
- telemetry

---

## Phase 5

Add governance dashboard.

Potential metrics:

- approved servers
- denied servers
- invocation counts
- publisher trust
- security scan status

---

# Security Considerations

## Major Risk Areas

MCP servers may:

- execute local code
- access developer files
- access tokens
- influence agent behavior
- exfiltrate data

Therefore the registry must eventually support:

- provenance
- trust
- auditing
- approval workflows
- policy enforcement

---

# Recommended Governance Model

## Lightweight Governance

### Approved

Explicitly trusted.

### Pending

Awaiting review.

### Blocked

Explicitly denied.

---

# Suggested Future Metadata

```json
{
  "trust": {
    "status": "approved",
    "riskLevel": "medium",
    "publisherVerified": true,
    "signedManifest": false,
    "reviewNotes": "Internal evaluation complete"
  }
}
```

---

# VS Code Client Testing Strategy

## Initial Test Flow

1. Launch VS Code on Windows 11
2. Configure MCP registry endpoint
3. Pull approved registry metadata
4. Attempt MCP server discovery
5. Validate allowlist behavior
6. Test blocked server behavior
7. Validate UX messaging

---

# GitHub Enterprise Cloud Testing Goals

## Desired Outcomes

Validate:

- registry discovery
- allowlist governance
- client compatibility
- metadata parsing
- trusted publisher concepts
- auditability

---

# Simple REST Endpoints

## Suggested API Shape

```text
GET /registry/index.json
GET /registry/allowlist.json
GET /registry/servers/github.json
GET /registry/servers/filesystem.json
```

That is intentionally simple.

No heavy backend required initially.

---

# Why This Architecture Is Smart

This architecture is:

- cheap
- teachable
- explainable
- auditable
- enterprise-relevant
- future-proof
- GitOps-friendly

And most importantly:

It aligns closely with the actual philosophical role of a trusted MCP registry.

---

# Strong Recommendation

Do NOT overbuild this.

The temptation will be:

- databases
- dashboards
- microservices
- orchestration
- APIM everywhere
- Kubernetes

Resist that.

The real value here is demonstrating:

- trust
- discovery
- governance
- metadata-driven control

A static JSON registry is enough to prove the concept.

---

# MVP Definition

## Success Criteria

The MVP succeeds if:

- VS Code can discover approved MCP metadata
- allowlist changes are easy
- GitHub Enterprise Cloud hosts the repo cleanly
- Azure hosting cost stays tiny
- registry metadata is understandable
- governance workflow feels intuitive

---

# Estimated Azure Cost

## MVP Monthly Estimate

| Service | Estimated Cost |
|---|---|
| Azure Static Web Apps | Free or very low |
| Blob Storage | Pennies |
| GitHub Actions | Likely included |
| Custom Domain Optional | Small |

Target:

Less than $10/month.

Potentially near-zero.

---

# Final Architectural Principle

## The Registry Is NOT the Runtime

The registry should remain:

- lightweight
- declarative
- metadata-driven
- policy-oriented
- easy to audit

The moment it starts executing workloads directly, complexity explodes.

Keep the control plane separate from the execution plane.

That separation is one of the core architectural insights behind the trusted MCP registry model.

