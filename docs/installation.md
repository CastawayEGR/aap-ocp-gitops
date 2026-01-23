# Installation Guide

This guide covers deploying Ansible Automation Platform on OpenShift using GitOps.

## Prerequisites

- OpenShift 4.12+ cluster
- OpenShift GitOps (ArgoCD) operator installed
- Namespace creation permissions
- Access to Red Hat registry for AAP operator images

## Deployment Steps

### 1. Pre-provision Namespaces

Namespaces must be created before deploying ArgoCD applications. This follows ArgoCD best practices by avoiding cluster-admin permissions for the application controller.

```bash
# Apply all environment namespaces
oc apply -k namespaces/
```

Or apply individually:

```bash
oc apply -f namespaces/aap-dev.yaml
oc apply -f namespaces/aap-staging.yaml
oc apply -f namespaces/aap-prod.yaml
```

The namespaces include:
- `argocd.argoproj.io/managed-by: openshift-gitops` label for ArgoCD access
- Pod Security Standards labels (baseline enforcement, restricted audit/warn)

### 2. Apply ArgoCD Health Checks

Custom health checks enable proper status reporting for AAP resources:

```bash
oc apply -k argocd/config/
```

This adds Lua health check scripts for:
- **AnsibleAutomationPlatform CR** - Reports Healthy/Progressing/Degraded based on deployment status
- **OLM Subscription** - Reports status based on subscription state and installed CSV
- **ArgoCD Application** - Properly evaluates nested Application health in app-of-apps pattern

### 3. Deploy Bootstrap Application

```bash
oc apply -k argocd/
```

This deploys the ApplicationSet which uses a matrix generator to create Applications for enabled environments. By default, only `dev` is enabled. The matrix generator creates both operator and instance Applications for each environment:

- `aap-dev-operator` (sync wave 0) - Deploys the AAP operator
- `aap-dev-instance` (sync wave 5) - Deploys the AAP custom resource

To enable additional environments (staging, prod), uncomment them in `argocd/applicationsets/aap.yaml`.

### 4. Monitor Deployment

```bash
# Watch ArgoCD applications
oc get applications -n openshift-gitops

# Monitor operator installation
oc get csv -n aap-dev

# Check AAP instance status
oc get ansibleautomationplatform -n aap-dev
```

### 5. Access AAP

```bash
# Get the route
oc get route -n aap-dev

# Get admin password
oc get secret aap-admin-password -n aap-dev -o jsonpath='{.data.password}' | base64 -d
```

## Sync Wave Strategy

Resources are deployed in order:

| Wave | Resource | Purpose |
|------|----------|---------|
| -1 | NetworkPolicies | Network isolation first |
| 0 | OperatorGroup | Required before Subscription |
| 1 | Subscription, RBAC | Triggers operator install |
| 2 | InstallPlan Approver Job | Approves pending InstallPlan |
| 5 | AnsibleAutomationPlatform CR | After operator + CRDs ready |

## Forking This Repository

If you fork this repository, update the repository URL in:

| File | Field |
|------|-------|
| `argocd/projects/aap-project.yaml` | `spec.sourceRepos` |
| `argocd/applicationsets/aap.yaml` | `spec.template.spec.source.repoURL` |
| `argocd/bootstrap/aap-bootstrap.yaml` | `spec.source.repoURL` |
