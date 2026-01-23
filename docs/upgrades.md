# Upgrade Guide

This guide covers upgrading AAP operator versions across environments.

## Version Management

Each environment controls its own AAP operator version via inline patches in the overlay's `kustomization.yaml`.

### Current Version Configuration

| Environment | File | Channel |
|-------------|------|---------|
| dev | `overlays/dev/operator/kustomization.yaml` | `stable-2.6` |
| staging | `overlays/staging/operator/kustomization.yaml` | `stable-2.6` |
| prod | `overlays/prod/operator/kustomization.yaml` | `stable-2.6` |

## Upgrading a Single Environment

Edit the overlay's kustomization.yaml and change the channel value:

```yaml
# overlays/dev/operator/kustomization.yaml
patches:
  - target:
      kind: Subscription
      name: ansible-automation-platform-operator
    patch: |-
      - op: replace
        path: /spec/channel
        value: stable-2.6  # Change version here
```

## Staged Rollout Process

### 1. Upgrade Development

```bash
# Edit overlays/dev/operator/kustomization.yaml → stable-2.6
git commit -am "Upgrade dev to AAP 2.6"
git push
```

Wait for ArgoCD to sync, then approve the InstallPlan.

### 2. Upgrade Staging

After validating dev:

```bash
# Edit overlays/staging/operator/kustomization.yaml → stable-2.6
git commit -am "Upgrade staging to AAP 2.6"
git push
```

Wait for ArgoCD to sync, then approve the InstallPlan.

### 3. Upgrade Production

After validating staging:

```bash
# Edit overlays/prod/operator/kustomization.yaml → stable-2.6
git commit -am "Upgrade prod to AAP 2.6"
git push
```

Wait for ArgoCD to sync, then approve the InstallPlan.

## Approving InstallPlans

The operator uses `installPlanApproval: Manual` for controlled upgrades. After changing versions, you must approve the InstallPlan.

### List Pending InstallPlans

```bash
oc get installplan -n aap-dev
```

### Approve an InstallPlan

```bash
oc patch installplan <name> -n aap-dev --type merge --patch '{"spec":{"approved":true}}'
```

### Batch Approval Script

```bash
# Approve all pending InstallPlans in a namespace
for plan in $(oc get installplan -n aap-dev -o jsonpath='{.items[?(@.spec.approved==false)].metadata.name}'); do
  oc patch installplan $plan -n aap-dev --type merge --patch '{"spec":{"approved":true}}'
done
```

## InstallPlan Approver Job

The InstallPlan Approver Job automatically approves the initial InstallPlan during ArgoCD sync. This handles the bootstrap case where the operator is first installed.

For subsequent upgrades, manual approval is required to ensure controlled rollouts.

### Security Features

- Runs as non-root with restricted security context
- Minimal RBAC: only `get`, `list`, `patch` on InstallPlans
- Namespace-scoped (not cluster-wide)
- Job deleted after successful completion

## Rollback

> **Warning:** AAP does not support in-place downgrades due to database schema migrations. Once upgraded, rolling back requires restoring from backup.

### Why Downgrades Don't Work

When AAP upgrades, it runs database migrations that modify the schema. These migrations are not reversible:

- OLM will not automatically downgrade operators
- Changing the subscription channel to a lower version has no effect
- Even forcing operator reinstall fails because the older version cannot read the migrated database schema

### Rollback Options

**Option 1: Restore from Backup (Recommended)**

Before upgrading, create a backup:

```bash
# Create backup before upgrade
oc apply -f - <<EOF
apiVersion: aap.ansible.com/v1alpha1
kind: AnsibleAutomationPlatformBackup
metadata:
  name: pre-upgrade-backup
  namespace: aap-dev
spec:
  deployment_name: aap
EOF
```

To restore after a failed upgrade:

```bash
# Restore from backup
oc apply -f - <<EOF
apiVersion: aap.ansible.com/v1alpha1
kind: AnsibleAutomationPlatformRestore
metadata:
  name: restore-from-backup
  namespace: aap-dev
spec:
  backup_name: pre-upgrade-backup
  deployment_name: aap
EOF
```

**Option 2: Fresh Install**

If no backup exists, you must delete and recreate the environment:

```bash
# Delete the AAP instance and PVCs
oc delete ansibleautomationplatform aap -n aap-dev
oc delete pvc --all -n aap-dev

# Delete and recreate the operator
oc delete csv -l operators.coreos.com/ansible-automation-platform-operator.aap-dev -n aap-dev
oc delete subscription ansible-automation-platform-operator -n aap-dev

# ArgoCD will recreate everything at the specified channel version
```

### Best Practices

1. **Always backup before upgrading** - Use AnsibleAutomationPlatformBackup CR
2. **Test upgrades in dev/staging first** - The staged rollout process exists for this reason
3. **Document the upgrade path** - Keep track of which versions were deployed when

## Monitoring Upgrades

```bash
# Watch operator CSV status
oc get csv -n aap-dev -w

# Check subscription status
oc describe subscription ansible-automation-platform-operator -n aap-dev

# Monitor AAP instance during upgrade
oc get ansibleautomationplatform -n aap-dev -w
```
