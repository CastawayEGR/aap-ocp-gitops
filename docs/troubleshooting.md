# Troubleshooting

Common issues and solutions for AAP GitOps deployments.

## ArgoCD Issues

### Application Not Syncing

Check application status:

```bash
oc get applications -n openshift-gitops
```

Check for sync errors:

```bash
oc get application <app-name> -n openshift-gitops -o jsonpath='{.status.operationState.message}'
```

Force refresh:

```bash
oc annotate application <app-name> -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite
```

### Application Stuck in Progressing

Check sync operation:

```bash
oc get application <app-name> -n openshift-gitops -o yaml | grep -A 20 operationState
```

Check for resource issues:

```bash
oc get application <app-name> -n openshift-gitops -o jsonpath='{.status.resources[?(@.health.status!="Healthy")]}' | jq
```

### Permission Denied Errors

Verify namespace has ArgoCD label:

```bash
oc get namespace <namespace> -o jsonpath='{.metadata.labels.argocd\.argoproj\.io/managed-by}'
```

Should return `openshift-gitops`. If not:

```bash
oc label namespace <namespace> argocd.argoproj.io/managed-by=openshift-gitops
```

Check AppProject destinations:

```bash
oc get appproject aap -n openshift-gitops -o jsonpath='{.spec.destinations[*].namespace}'
```

## Operator Issues

### Operator Not Installing

Check subscription status:

```bash
oc get subscription ansible-automation-platform-operator -n <namespace> -o yaml
```

Check for pending InstallPlan:

```bash
oc get installplan -n <namespace>
```

Check InstallPlan details:

```bash
oc describe installplan <name> -n <namespace>
```

### InstallPlan Not Approved

Check approver job:

```bash
oc get jobs -n <namespace> installplan-approver
```

Check job logs:

```bash
oc logs -n <namespace> -l job-name=installplan-approver
```

Manually approve:

```bash
oc patch installplan <name> -n <namespace> --type merge --patch '{"spec":{"approved":true}}'
```

### Wrong Operator Version

Verify subscription channel:

```bash
oc get subscription ansible-automation-platform-operator -n <namespace> -o jsonpath='{.spec.channel}'
```

Check installed CSV:

```bash
oc get csv -n <namespace>
```

## AAP Instance Issues

### Instance Not Deploying

Check CR status:

```bash
oc describe ansibleautomationplatform aap -n <namespace>
```

Check operator logs:

```bash
oc logs -n <namespace> -l app.kubernetes.io/name=ansible-automation-platform-operator --tail=100
```

### Components Not Starting

Check pods:

```bash
oc get pods -n <namespace>
```

Check events:

```bash
oc get events -n <namespace> --sort-by='.lastTimestamp'
```

Check resource constraints:

```bash
oc describe pod <pod-name> -n <namespace> | grep -A 5 "Conditions:"
```

### Health Check Shows Degraded

Check AAP status conditions:

```bash
oc get ansibleautomationplatform aap -n <namespace> -o jsonpath='{.status.conditions}' | jq
```

## Network Issues

### Pods Can't Communicate

Check network policies:

```bash
oc get networkpolicy -n <namespace>
```

Test connectivity:

```bash
oc debug -n <namespace> deployment/<deployment> -- curl -v http://<service>:<port>
```

### Can't Pull Images

Check egress policy allows external HTTPS:

```bash
oc get networkpolicy aap-allow-https-egress -n <namespace> -o yaml
```

Check image pull secrets:

```bash
oc get secrets -n <namespace> | grep pull
```

### Route Not Accessible

Check ingress policy:

```bash
oc get networkpolicy aap-allow-openshift-ingress -n <namespace> -o yaml
```

Check route:

```bash
oc get route -n <namespace>
oc describe route <route-name> -n <namespace>
```

## Kustomize Issues

### Build Fails Locally

Validate kustomization:

```bash
make validate-kustomize
```

Or manually:

```bash
oc kustomize overlays/dev/operator
```

### Missing Resources

Check kustomization.yaml includes all resources:

```bash
cat overlays/dev/operator/kustomization.yaml
```

Verify base path:

```bash
ls -la base/operator/
```

## Common Errors

### "namespace not found"

Ensure namespaces are pre-provisioned:

```bash
oc apply -k namespaces/
```

### "resource already exists"

Check if resource was created outside ArgoCD:

```bash
oc get <resource> -n <namespace> -o yaml | grep -A 5 "ownerReferences:"
```

### "CRD not found"

Wait for operator to install CRDs. Check CSV status:

```bash
oc get csv -n <namespace>
```

The instance Application uses `SkipDryRunOnMissingResource=true` to handle this.

## Gathering Debug Information

Collect all relevant information:

```bash
# ArgoCD applications
oc get applications -n openshift-gitops -o yaml > argocd-apps.yaml

# Operator resources
oc get subscription,csv,installplan -n <namespace> -o yaml > operator.yaml

# AAP resources
oc get ansibleautomationplatform -n <namespace> -o yaml > aap.yaml

# Events
oc get events -n <namespace> --sort-by='.lastTimestamp' > events.txt

# Pod logs
oc logs -n <namespace> -l app.kubernetes.io/part-of=ansible-automation-platform --all-containers > pods.log
```

## Getting Help

1. Check ArgoCD UI for detailed sync status
2. Review operator logs for error messages
3. Check Red Hat AAP documentation
4. Open issue in this repository with debug information
