# Architecture

This document describes the design patterns and structure of this GitOps repository.

## Design Patterns

### App-of-Apps Pattern

The repository uses ArgoCD's app-of-apps pattern where a single bootstrap Application manages all other Applications. This provides:

- Single entry point for deployment
- Declarative management of ArgoCD resources
- Self-healing for the ArgoCD configuration itself

### ApplicationSet with Matrix Generator

Instead of manually creating Applications for each environment and component, a single ApplicationSet with a matrix generator creates all combinations dynamically:

```yaml
generators:
  - matrix:
      generators:
        # Environments - uncomment to enable staging/prod
        - list:
            elements:
              - env: dev
                namespace: aap-dev
              # - env: staging
              #   namespace: aap-staging
              # - env: prod
              #   namespace: aap
        # Components - operator must deploy before instance (sync waves)
        - list:
            elements:
              - component: operator
                wave: "0"
              - component: instance
                wave: "5"
```

The matrix generator creates a cross-product of environments × components. With 3 environments and 2 components, it generates 6 Applications automatically.

Benefits:
- Single source of truth for environments (edit once, applies to all components)
- Consistent configuration across environments
- Easy to add/remove environments by uncommenting
- Reduces duplication and drift

### Kustomize Overlays

Base configurations are shared, with environment-specific customizations in overlays:

```
base/           # Shared resources
overlays/
  dev/          # Dev-specific patches
  staging/      # Staging-specific patches
  prod/         # Production-specific patches
```

## Directory Structure

```
aap-gitops/
├── argocd/                           # ArgoCD configuration
│   ├── bootstrap/                    # Root app-of-apps
│   ├── applicationsets/              # Environment generators
│   ├── config/                       # Health checks, patches
│   └── projects/                     # AppProject with RBAC
│
├── namespaces/                       # Pre-provisioned namespaces
│
├── components/                       # Reusable Kustomize components
│   └── installplan-approver/         # Auto-approval job
│
├── base/                             # Shared Kustomize bases
│   ├── operator/                     # OLM resources
│   └── instance/                     # AAP CR
│
├── overlays/                         # Environment overlays
│   ├── dev/
│   ├── staging/
│   └── prod/
│
└── docs/                             # Documentation
```

## Resource Flow

```
Bootstrap App
    │
    ├── AppProject (RBAC)
    │
    └── ApplicationSet (matrix: environments × components)
            │
            │  With dev enabled:
            ├── aap-dev-operator ──► overlays/dev/operator (wave 0)
            └── aap-dev-instance ──► overlays/dev/instance (wave 5)
            │
            │  With staging uncommented:
            ├── aap-staging-operator ──► overlays/staging/operator (wave 0)
            └── aap-staging-instance ──► overlays/staging/instance (wave 5)
            │
            │  With prod uncommented:
            ├── aap-prod-operator ──► overlays/prod/operator (wave 0)
            └── aap-prod-instance ──► overlays/prod/instance (wave 5)
```

The matrix generator automatically creates both operator and instance Applications for each enabled environment.

## Environment Configuration

| Environment | Namespace | Configuration |
|-------------|-----------|---------------|
| dev | `aap-dev` | Single replica controller |
| staging | `aap-staging` | Single replica controller |
| prod | `aap` | 2 replica controller (HA) |

## Component Architecture

### Operator Application

Deploys OLM resources:
- OperatorGroup (namespace scope)
- Subscription (operator channel)
- NetworkPolicies (isolation)
- InstallPlan Approver (bootstrap)

### Instance Application

Deploys AAP resources:
- AnsibleAutomationPlatform CR

The instance Application uses sync wave 5 to ensure the operator and CRDs are ready before deployment.

## Separation of Concerns

| Layer | Responsibility | Files |
|-------|----------------|-------|
| ArgoCD | Application lifecycle | `argocd/` |
| Namespaces | Cluster preparation | `namespaces/` |
| Operator | OLM management | `base/operator/`, `overlays/*/operator/` |
| Instance | AAP deployment | `base/instance/`, `overlays/*/instance/` |
| Components | Reusable tools | `components/` |
