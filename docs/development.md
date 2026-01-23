# Development Guide

This guide covers local development, testing, and CI/CD for this repository.

## Local Development

### Prerequisites

Install required tools:

```bash
make install-tools
```

Or manually install:
- `kustomize` or `oc` CLI (includes kustomize)
- `yamllint` - YAML linting
- `kubeconform` - Kubernetes schema validation
- `trivy` - Security scanning

### Available Commands

```bash
make help
```

| Command | Description |
|---------|-------------|
| `make validate` | Run all validations |
| `make validate-yaml` | Check YAML syntax |
| `make validate-kustomize` | Test all Kustomize builds |
| `make validate-schemas` | Validate Kubernetes schemas |
| `make security-scan` | Run Trivy security scan |
| `make build-all` | Render all manifests to `build/` |
| `make build-env ENV=prod` | Build specific environment |
| `make diff-prod` | Compare local vs cluster |
| `make clean` | Remove build artifacts |

### Validating Changes

Before committing:

```bash
make validate
```

This runs:
1. YAML syntax validation
2. Kustomize build tests for all overlays
3. Kubernetes schema validation

### Building Manifests

Render manifests to inspect:

```bash
make build-all
ls build/
```

Output:
```
dev-operator.yaml
dev-instance.yaml
staging-operator.yaml
staging-instance.yaml
prod-operator.yaml
prod-instance.yaml
argocd.yaml
namespaces.yaml
```

### Comparing Changes

See what would change in production:

```bash
make diff-prod
```

Requires cluster access.

## CI/CD Pipeline

### GitHub Actions Workflow

The `.github/workflows/validate.yaml` workflow runs on:
- Push to `main` branch
- Pull requests to `main`
- Changes to manifest files or CI config

### Pipeline Jobs

| Job | Purpose |
|-----|---------|
| `validate-yaml` | YAML syntax with yamllint |
| `validate-kustomize` | Build all 6 overlays in parallel |
| `validate-argocd` | Build ArgoCD and namespace manifests |
| `validate-schemas` | Kubeconform schema validation |
| `security-scan` | Trivy scan for vulnerabilities |
| `validate-argocd-apps` | Check Application specs |
| `dry-run-diff` | Show manifest diffs (PRs only) |
| `summary` | Aggregate results |

### Pipeline Status

Check workflow status:
- GitHub Actions tab in repository
- Status checks on pull requests

### Local CI Simulation

Run the same checks locally:

```bash
# YAML validation
yamllint -c .yamllint .

# Kustomize builds
for env in dev staging prod; do
  for comp in operator instance; do
    oc kustomize overlays/$env/$comp > /dev/null
  done
done

# Schema validation
oc kustomize overlays/prod/operator | kubeconform -strict -ignore-missing-schemas
```

## Making Changes

### Modifying Base Resources

1. Edit files in `base/operator/` or `base/instance/`
2. Run `make validate`
3. Test in dev environment first

### Adding Environment-Specific Patches

1. Create patch file in overlay directory
2. Reference in `kustomization.yaml`
3. Test with `make build-env ENV=<env>`

Example:

```yaml
# overlays/prod/instance/custom-patch.yaml
apiVersion: aap.ansible.com/v1alpha1
kind: AnsibleAutomationPlatform
metadata:
  name: aap
spec:
  controller:
    extra_settings:
      - setting: MAX_PAGE_SIZE
        value: "1000"
```

```yaml
# overlays/prod/instance/kustomization.yaml
patches:
  - path: custom-patch.yaml
```

### Testing Changes

1. Validate locally:
   ```bash
   make validate
   ```

2. Build and inspect:
   ```bash
   make build-env ENV=dev
   cat build/dev-instance.yaml
   ```

3. Create pull request - CI will validate

4. After merge, monitor ArgoCD sync

## Repository Structure for Development

```
.
├── .github/
│   └── workflows/
│       └── validate.yaml    # CI pipeline
├── .gitignore               # Ignore build artifacts
├── .yamllint                # Linting config
├── Makefile                 # Development commands
├── argocd/                  # ArgoCD resources
├── base/                    # Shared resources
├── components/              # Reusable components
├── docs/                    # Documentation
├── namespaces/              # Namespace definitions
└── overlays/                # Environment configs
```

## Code Style

### YAML Formatting

- 2 space indentation
- No trailing whitespace
- Max line length: 200 characters
- Use `true`/`false` for booleans (not `yes`/`no`)

### Kustomize Conventions

- Base resources in `base/`
- Environment patches in `overlays/<env>/`
- Reusable components in `components/`
- Use strategic merge patches when possible
- Use JSON patches for array modifications

### Commit Messages

Follow conventional format:
```
<type>: <description>

[optional body]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Code restructure
- `chore`: Maintenance

Examples:
```
feat: Add EDA support to production overlay
fix: Correct network policy egress rules
docs: Update upgrade guide for 2.6
```
