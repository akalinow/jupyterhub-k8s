# CVMFS: Migration from sciencebox + hostPath to CVMFS CSI Driver

## The Problem

The original setup uses the **sciencebox/cvmfs** Helm chart together with a
`hostPath`-based PersistentVolume. This architecture has one fundamental
requirement: **CVMFS must be installed and running on every bare-metal node**
before any pod can see it.

### How the old setup works (and why it requires the host)

`deploy.sh` installs the sciencebox chart, which runs a CVMFS automount
DaemonSet on each node. That DaemonSet mounts the CVMFS repositories directly
on the host OS using FUSE. `cvmfs/volumes.yaml` then creates a PersistentVolume
that exposes the host directory `/cvmfs` to Kubernetes:

```yaml
# cvmfs/volumes.yaml — the hostPath PV
spec:
  hostPath:
    path: /cvmfs          # the FUSE mount managed on the host
    type: Directory
```

Pods consume this via a PVC and must declare `mountPropagation: HostToContainer`
so that FUSE submounts created on the host are visible inside the container:

```yaml
# config.yaml — current singleuser volume mount
01-cvmfs:
  name: cvmfs
  mountPath: /cvmfs
  readOnly: true
  mountPropagation: HostToContainer   # required because the mount lives on the host
```

The consequence: if sciencebox's DaemonSet is not running, or if a new node
joins the cluster without CVMFS installed, pods fail to start. The setup cannot
run on a pristine node, and cannot be reproduced without re-installing CVMFS on
the host OS.

---

## The Fix: CVMFS CSI Driver

The **cvmfs-contrib/cvmfs-csi** driver moves the FUSE mounting out of the host
OS and into a privileged Kubernetes DaemonSet that the driver manages itself.
Pods request CVMFS repositories directly as CSI volumes — Kubernetes calls the
driver, the driver creates the FUSE mount in an isolated container, and the
volume is provided to the pod. The host OS needs nothing installed.

### What changes

| | Old setup | New setup |
|---|---|---|
| Host CVMFS required | Yes | No |
| Helm chart | `sciencebox/cvmfs` | `cvmfs-contrib/cvmfs-csi` |
| Volume type | `hostPath` PV + PVC | Inline CSI volume per repository |
| `mountPropagation` | `HostToContainer` (required) | Not needed |
| Repository config | Patched into sciencebox ConfigMap | Embedded in `cvmfs-csi/values.yaml` |
| ILC public key | In `cvmfs/ilc.desy.de.yaml` (patch file) | In `cvmfs-csi/values.yaml` (Helm values) |

### New files

```
cvmfs-csi/
  values.yaml              Helm values for the CSI chart
  test-pod.yaml            Verification pod (uses CSI volumes)
  config-singleuser.yaml   Reference: the singleuser block to put in config.yaml
deploy-cvmfs-csi.sh        Standalone deployment script
```

The old files (`cvmfs/`, `deploy.sh`) are **not modified** until you confirm
the CSI setup works.

---

## Step-by-Step Migration

### Prerequisites

- The cluster is running (`minikube status` shows Running).
- The existing JupyterHub deployment is up (`kubectl get pods` shows hub and
  proxy pods).
- `helm` and `kubectl` are available.

---

### Step 1 — Deploy the CSI driver

```bash
./deploy-cvmfs-csi.sh
```

This script:
1. Adds the `cvmfs-csi` Helm repo and installs the chart into the `cvmfs`
   namespace.
2. Embeds the DESY ILC repository config and public key via
   `cvmfs-csi/values.yaml` — no separate `kubectl patch` needed.
3. Deploys `cvmfs-csi/test-pod.yaml` (pod name: `cvmfs-csi-test`) and runs
   `cvmfs/fetch_cvmfs.sh` inside it to verify that all five repositories are
   accessible.

The script ends with a green success message if everything worked, or exits with
a non-zero code on the first failure.

---

### Step 2 — Verify the test pod manually (optional but recommended)

```bash
# Open a shell inside the test pod
kubectl exec -it cvmfs-csi-test -- /bin/bash

# Inside the pod, spot-check each repository
ls /cvmfs/cms.cern.ch
ls /cvmfs/sft.cern.ch/lcg/views/
ls /cvmfs/ilc.desy.de
ls /cvmfs/nova.opensciencegrid.org
exit
```

If any repository directory is empty or the mount hangs, check the CSI driver
logs before proceeding:

```bash
kubectl logs -n cvmfs -l app.kubernetes.io/instance=cvmfs-csi --prefix
```

---

### Step 3 — Update config.yaml (JupyterHub singleuser volumes)

`cvmfs-csi/config-singleuser.yaml` contains the exact replacement for the
`singleuser` block in `config.yaml`. Open `config.yaml`, find the section
between the two `#######` markers near the bottom of the file, and replace it
with the content from `cvmfs-csi/config-singleuser.yaml`.

**What is replaced:**

```yaml
# BEFORE — single PVC, requires host CVMFS
extraVolumes:
  01-cvmfs:
    name: cvmfs
    persistentVolumeClaim:
      claimName: cvmfs-pvc
extraVolumeMounts:
  01-cvmfs:
    name: cvmfs
    mountPath: /cvmfs
    readOnly: true
    mountPropagation: HostToContainer
```

**What it becomes:**

```yaml
# AFTER — per-repository CSI volumes, no host dependency
extraVolumes:
  01-cvmfs-cms:
    name: cvmfs-cms
    csi:
      driver: cvmfs.csi.cern.ch
      volumeAttributes:
        repository: cms.cern.ch
  # ... (sft, grid, ilc, nova — see cvmfs-csi/config-singleuser.yaml)
extraVolumeMounts:
  01-cvmfs-cms:
    name: cvmfs-cms
    mountPath: /cvmfs/cms.cern.ch
    readOnly: true
  # ... (no mountPropagation anywhere)
```

The `cmsse-nfs` and `scratch-local` volume entries are **unchanged**.

---

### Step 4 — Upgrade JupyterHub

```bash
helm upgrade --cleanup-on-fail \
  jupyterhub jupyterhub/jupyterhub \
  --namespace default \
  --version=4.3.2 \
  --timeout=600s \
  --values config.yaml
```

Start a new JupyterHub user session and confirm that `/cvmfs/cms.cern.ch`,
`/cvmfs/sft.cern.ch`, etc. are visible inside the notebook.

---

### Step 5 — Remove the old setup

Once the new setup is confirmed working in production:

```bash
# Remove the sciencebox DaemonSet and its ConfigMap
helm uninstall sciencebox --namespace default

# Remove the hostPath PV and PVC
kubectl delete -f cvmfs/volumes.yaml

# Remove the test pod for the old setup (if still running)
kubectl delete pod cvmfs-test --ignore-not-found

# Remove the CSI test pod
kubectl delete pod cvmfs-csi-test --ignore-not-found
```

The following files can then be deleted from the repository:

```
cvmfs/volumes.yaml        hostPath PV + PVC (replaced by inline CSI)
cvmfs/config.yaml         sciencebox chart values (chart removed)
cvmfs/ilc.desy.de.yaml    sciencebox ConfigMap patch (now in cvmfs-csi/values.yaml)
```

And in `deploy.sh`, replace the `## Add cvmfs` block (lines 35–46) with a
single call to `./deploy-cvmfs-csi.sh`.

---

## Rollback

If anything goes wrong before Step 5, the old setup is untouched. To roll back
from Step 4:

```bash
# Revert config.yaml to the original singleuser block, then:
helm upgrade jupyterhub jupyterhub/jupyterhub \
  --namespace default \
  --version=4.3.2 \
  --timeout=600s \
  --values config.yaml
```

To remove the CSI driver entirely:

```bash
helm uninstall cvmfs-csi --namespace cvmfs
kubectl delete namespace cvmfs
kubectl delete pod cvmfs-csi-test --ignore-not-found
```
