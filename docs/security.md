# Security

This document describes the security controls implemented in this GitOps repository.

## Defense in Depth

Security is implemented at multiple layers:

1. **ArgoCD RBAC** - Restricts what can be deployed
2. **Namespace isolation** - Pre-provisioned with security labels
3. **Network policies** - Default-deny with explicit allows
4. **Pod security standards** - Baseline enforcement
5. **Least privilege** - Minimal permissions throughout

## ArgoCD AppProject Security

### Source Repository Restriction

Only the configured repository can be used as a source:

```yaml
sourceRepos:
  - https://github.com/CastawayEGR/aap-ocp-gitops.git
```

### Destination Restrictions

Applications can only deploy to specific namespaces:

```yaml
destinations:
  - namespace: aap
    server: https://kubernetes.default.svc
  - namespace: aap-dev
    server: https://kubernetes.default.svc
  - namespace: aap-staging
    server: https://kubernetes.default.svc
  - namespace: openshift-gitops
    server: https://kubernetes.default.svc
```

### Cluster-Scoped Resource Restrictions

No cluster-scoped resources are allowed. Dangerous resources are explicitly blacklisted:

```yaml
clusterResourceBlacklist:
  - group: ''
    kind: Node
  - group: rbac.authorization.k8s.io
    kind: ClusterRole
  - group: rbac.authorization.k8s.io
    kind: ClusterRoleBinding
```

### Namespace-Scoped Whitelist

Only specific resource types can be created:

- `Application`, `AppProject` (ArgoCD)
- `ConfigMap`, `Secret`
- `ServiceAccount`, `Role`, `RoleBinding`
- `ResourceQuota`, `LimitRange`
- `NetworkPolicy`
- `OperatorGroup`, `Subscription` (OLM)
- `AnsibleAutomationPlatform`
- `Job`

## Namespace Security

### Pre-Provisioned Namespaces

Namespaces are created outside of ArgoCD to:
- Avoid granting cluster-admin to application controller
- Ensure proper labels are applied before workloads
- Follow least-privilege principle

### Pod Security Standards

All namespaces enforce Pod Security Standards:

```yaml
labels:
  pod-security.kubernetes.io/enforce: baseline
  pod-security.kubernetes.io/enforce-version: latest
  pod-security.kubernetes.io/audit: restricted
  pod-security.kubernetes.io/audit-version: latest
  pod-security.kubernetes.io/warn: restricted
  pod-security.kubernetes.io/warn-version: latest
```

This means:
- **Baseline** is enforced (blocks privileged containers)
- **Restricted** violations are logged and warned

## Network Policies

### Default Deny

All ingress and egress is denied by default:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: aap-default-deny
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### Allowed Traffic

| Direction | Source/Destination | Purpose |
|-----------|-------------------|---------|
| Ingress | Same namespace | Pod-to-pod communication |
| Ingress | openshift-ingress | Route traffic |
| Ingress | openshift-monitoring | Prometheus metrics |
| Egress | openshift-dns:5353 | DNS resolution |
| Egress | API server:6443 | Kubernetes API |
| Egress | External:80,443 | Image pulls, webhooks |

### Egress Restrictions

External HTTPS egress excludes private networks:

```yaml
- to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
          - 10.0.0.0/8
          - 172.16.0.0/12
          - 192.168.0.0/16
```

## InstallPlan Approver Security

The job that approves InstallPlans follows strict security:

### Minimal RBAC

```yaml
rules:
  - apiGroups: ["operators.coreos.com"]
    resources: ["installplans"]
    verbs: ["get", "list", "patch"]
```

### Restricted Security Context

```yaml
securityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

### Resource Limits

```yaml
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 10m
    memory: 64Mi
```

## Secrets Management

This repository does not store secrets. Secrets should be managed via:

- OpenShift Secrets (created by operators)
- External Secrets Operator
- HashiCorp Vault
- Sealed Secrets

## Audit Trail

All changes are tracked through:

1. **Git history** - Who changed what, when
2. **ArgoCD audit logs** - Sync events and changes
3. **OpenShift audit logs** - API calls and resource changes

## Security Checklist

Before deploying to production:

- [ ] Repository access is restricted
- [ ] Branch protection is enabled
- [ ] AppProject source repos are correct
- [ ] Namespace destinations are limited
- [ ] Network policies are tested
- [ ] Pod security standards are enforced
- [ ] No secrets in git
- [ ] InstallPlan approval is manual
