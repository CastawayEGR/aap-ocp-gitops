# AAP GitOps

GitOps-managed deployment of Ansible Automation Platform on OpenShift using ArgoCD and Kustomize.

## Features

- **App-of-Apps pattern** with ApplicationSet matrix generator for multi-environment management
- **Single source of truth** - enable environments by uncommenting one line
- **Per-environment version control** via Kustomize overlays
- **Pre-provisioned namespaces** following least-privilege principles
- **Network isolation** with default-deny policies
- **Custom health checks** for AAP and OLM resources
- **Automated InstallPlan approval** for initial deployment
- **CI validation pipeline** for manifest testing

## Quick Start

```bash
# 1. Pre-provision namespaces
oc apply -k namespaces/

# 2. Apply ArgoCD health checks
oc apply -k argocd/config/

# 3. Deploy bootstrap application
oc apply -k argocd/

# 4. Monitor deployment
oc get applications -n openshift-gitops
```

## Environments

| Environment | Namespace | Channel | Status |
|-------------|-----------|---------|--------|
| dev | `aap-dev` | `stable-2.6` | Enabled |
| staging | `aap-staging` | `stable-2.6` | Disabled (uncomment to enable) |
| prod | `aap` | `stable-2.6` | Disabled (uncomment to enable) |

Enable additional environments by uncommenting them in `argocd/applicationsets/aap.yaml`.

## Directory Structure

```
├── argocd/           # ArgoCD bootstrap, ApplicationSets, projects
├── namespaces/       # Pre-provisioned namespace definitions
├── base/             # Shared Kustomize bases (operator, instance)
├── overlays/         # Environment-specific patches (dev, staging, prod)
├── components/       # Reusable components (installplan-approver)
└── docs/             # Documentation
```

## Documentation

| Guide | Description |
|-------|-------------|
| [Installation](docs/installation.md) | Deployment steps and prerequisites |
| [Upgrades](docs/upgrades.md) | Version management and staged rollouts |
| [Architecture](docs/architecture.md) | Design patterns and structure |
| [Configuration](docs/configuration.md) | All configurable options |
| [Security](docs/security.md) | RBAC, network policies, pod security |
| [Troubleshooting](docs/troubleshooting.md) | Common issues and solutions |
| [Development](docs/development.md) | Local development and CI/CD |

## Local Development

```bash
make validate           # Run all validations
make build-all          # Render manifests to build/
make diff-prod          # Compare local vs cluster
```

## Forking

Update repository URL in:
- `argocd/projects/aap-project.yaml`
- `argocd/applicationsets/aap.yaml`
- `argocd/bootstrap/aap-bootstrap.yaml`
