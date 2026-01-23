# Configuration Reference

This document covers all configurable options for AAP deployment.

## Environment Management

### Enabling/Disabling Environments

Edit `argocd/applicationsets/aap.yaml` to control which environments are deployed. The ApplicationSet uses a matrix generator that combines environments with components (operator and instance):

```yaml
generators:
  - matrix:
      generators:
        # Environments - uncomment to enable staging/prod
        - list:
            elements:
              - env: dev
                namespace: aap-dev
              # - env: staging        # Uncomment to deploy staging
              #   namespace: aap-staging
              # - env: prod           # Uncomment to deploy prod
              #   namespace: aap
        # Components - automatically applied to all environments
        - list:
            elements:
              - component: operator
                wave: "0"
              - component: instance
                wave: "5"
```

Uncommenting an environment automatically creates both the operator and instance Applications for that environment.

### Adding a New Environment

1. Create namespace file in `namespaces/`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: aap-qa
  labels:
    argocd.argoproj.io/managed-by: openshift-gitops
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

2. Create overlay directories:

```
overlays/qa/
  operator/
    kustomization.yaml
  instance/
    kustomization.yaml
```

3. Add to the environments list in the ApplicationSet matrix generator:

```yaml
- env: qa
  namespace: aap-qa
```

This single entry creates both `aap-qa-operator` and `aap-qa-instance` Applications.

4. Add namespace to AppProject destinations in `argocd/projects/aap-project.yaml`

## AAP Components

### Controller (Automation Controller)

Enabled by default. Configure in overlay patches:

```yaml
spec:
  controller:
    disabled: false
    replicas: 2          # HA configuration
```

### Hub (Private Automation Hub)

Disabled by default. Enable in overlay:

```yaml
spec:
  hub:
    disabled: false
    replicas: 2
```

### EDA (Event-Driven Ansible)

Disabled by default. Enable in overlay:

```yaml
spec:
  eda:
    disabled: false
    replicas: 1
```

### Lightspeed

Disabled by default. Enable in overlay:

```yaml
spec:
  lightspeed:
    disabled: false
```

## Operator Configuration

### Subscription Settings

Base configuration in `base/operator/subscription.yaml`:

| Field | Default | Description |
|-------|---------|-------------|
| `channel` | `stable-2.6` | Operator channel (overridden per-env) |
| `installPlanApproval` | `Manual` | Requires approval for upgrades |
| `source` | `redhat-operators` | Operator catalog |

### Channel Patching

Each environment patches the channel in its kustomization:

```yaml
# overlays/dev/operator/kustomization.yaml
patches:
  - target:
      kind: Subscription
      name: ansible-automation-platform-operator
    patch: |-
      - op: replace
        path: /spec/channel
        value: stable-2.6
```

## Network Policies

Default-deny with explicit allow rules. Defined in `base/operator/networkpolicy.yaml`:

| Policy | Purpose |
|--------|---------|
| `aap-default-deny` | Block all traffic by default |
| `aap-allow-same-namespace` | Allow intra-namespace communication |
| `aap-allow-openshift-ingress` | Allow traffic from routes |
| `aap-allow-openshift-monitoring` | Allow Prometheus scraping |
| `aap-allow-dns-egress` | Allow DNS queries |
| `aap-allow-apiserver-egress` | Allow Kubernetes API access |
| `aap-allow-https-egress` | Allow external HTTPS (image pulls) |

### Customizing Network Policies

Create an overlay patch to modify policies:

```yaml
# overlays/prod/operator/networkpolicy-patch.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: aap-allow-custom
spec:
  podSelector: {}
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              custom-access: "true"
```

## ArgoCD Configuration

### AppProject Settings

Defined in `argocd/projects/aap-project.yaml`:

| Setting | Value |
|---------|-------|
| Source repos | Repository URL only |
| Destinations | aap, aap-dev, aap-staging, openshift-gitops |
| Cluster resources | None allowed (least privilege) |
| Blacklisted | ClusterRole, ClusterRoleBinding, Node |

### Sync Options

Applications use these sync options:

| Option | Value | Purpose |
|--------|-------|---------|
| `CreateNamespace` | false | Namespaces pre-provisioned |
| `PrunePropagationPolicy` | foreground | Wait for dependents |
| `PruneLast` | true | Delete after sync |
| `ServerSideApply` | true | Better conflict handling |
| `RespectIgnoreDifferences` | true | Honor ignore rules |

## Files Reference

| File | Purpose |
|------|---------|
| `argocd/projects/aap-project.yaml` | AppProject with RBAC |
| `argocd/applicationsets/aap.yaml` | Environment generator |
| `argocd/config/argocd-cm-patch.yaml` | Health checks |
| `base/operator/subscription.yaml` | Operator channel |
| `base/operator/networkpolicy.yaml` | Network isolation |
| `base/instance/ansibleautomationplatform.yaml` | AAP CR |
| `overlays/*/operator/kustomization.yaml` | Version patches |
| `overlays/prod/instance/aap-patch.yaml` | Production config |
