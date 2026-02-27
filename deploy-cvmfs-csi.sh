#!/usr/bin/env bash
# Deploy the CVMFS CSI driver alongside the existing sciencebox setup.
#
# This script is self-contained: it does NOT modify or remove the existing
# sciencebox/cvmfs DaemonSet, PVCs, or JupyterHub config.yaml.
# Run ./deploy.sh first (or make sure the cluster is up), then run this.
#
# Once cvmfs-csi-test pod is verified, proceed with:
#   1. Update config.yaml using cvmfs-csi/config-singleuser.yaml
#   2. Upgrade JupyterHub: helm upgrade jupyterhub jupyterhub/jupyterhub --values config.yaml
#   3. Remove old setup: helm uninstall sciencebox && kubectl delete -f cvmfs/volumes.yaml

set -euo pipefail

TEST_NAMESPACE="${TEST_NAMESPACE:-default}"
CVMFS_NAMESPACE="${CVMFS_NAMESPACE:-cvmfs}"
# Install from CERN OCI registry (no Helm repo add needed).
CVMFS_CSI_CHART_REF="${CVMFS_CSI_CHART_REF:-oci://registry.cern.ch/kubernetes/charts/cvmfs-csi}"
# Pinned for reproducibility; override from env if you want another tested tag.
CVMFS_CSI_CHART_VERSION="${CVMFS_CSI_CHART_VERSION:-2.5.1}"

## ============================================================
## 1. Select CVMFS CSI chart source and version
## ============================================================
printf "\033[1;36mUsing CVMFS CSI chart: %s (version %s)\033[0m\n" "${CVMFS_CSI_CHART_REF}" "${CVMFS_CSI_CHART_VERSION}"

## ============================================================
## 2. Install the CVMFS CSI driver in its own namespace
##    - values.yaml sets CVMFS_HTTP_PROXY=DIRECT in default.local
##    - ILC repo config + public key embedded via extraConfigMaps
##    - Cache stored at /var/lib/cvmfs.csi.cern.ch/cache on each node
## ============================================================
helm upgrade --cleanup-on-fail --install cvmfs-csi "${CVMFS_CSI_CHART_REF}" --version "${CVMFS_CSI_CHART_VERSION}" --namespace "${CVMFS_NAMESPACE}" --create-namespace --values cvmfs-csi/values.yaml

printf "\033[1;36mWaiting for CVMFS CSI DaemonSet to be ready...\033[0m\n"
# kubectl rollout status requires an explicit resource name; label selectors are not supported.
# Dynamically resolve the DaemonSet name created by the chart release.
CVMFS_DS="$(kubectl get daemonset -n "${CVMFS_NAMESPACE}" -l "app.kubernetes.io/instance=cvmfs-csi" -o jsonpath='{.items[0].metadata.name}')"
CVMFS_DS="${CVMFS_DS:?Could not resolve CVMFS CSI DaemonSet name in namespace ${CVMFS_NAMESPACE}}"
kubectl rollout status "daemonset/${CVMFS_DS}" -n "${CVMFS_NAMESPACE}" --timeout=120s

## ============================================================
## 3. Deploy test pod and run repository access checks
##    Pod name: cvmfs-csi-test (does NOT conflict with cvmfs-test)
## ============================================================
if kubectl -n "${TEST_NAMESPACE}" get pod cvmfs-csi-test >/dev/null 2>&1; then
  kubectl -n "${TEST_NAMESPACE}" delete pod cvmfs-csi-test
  kubectl -n "${TEST_NAMESPACE}" wait --for=delete pod/cvmfs-csi-test --timeout=120s
fi
kubectl -n "${TEST_NAMESPACE}" apply -f cvmfs-csi/test-pod.yaml

printf "\033[1;36mWaiting for cvmfs-csi-test pod to be ready...\033[0m\n"
kubectl -n "${TEST_NAMESPACE}" wait --for=condition=ready pod/cvmfs-csi-test --timeout=300s

printf "\033[1;36mRunning repository checks inside cvmfs-csi-test...\033[0m\n"
kubectl -n "${TEST_NAMESPACE}" exec cvmfs-csi-test -- sh -c '
set -eu
require_non_empty_dir() {
  repo_path="$1"
  if [ ! -d "${repo_path}" ]; then
    echo "Missing directory: ${repo_path}" >&2
    exit 1
  fi
  entries="$(ls -A "${repo_path}")" || {
    echo "Cannot list directory: ${repo_path}" >&2
    exit 1
  }
  if [ -z "${entries}" ]; then
    echo "Directory is empty: ${repo_path}" >&2
    exit 1
  fi
}

require_non_empty_dir /cvmfs/cms.cern.ch
require_non_empty_dir /cvmfs/sft.cern.ch
require_non_empty_dir /cvmfs/grid.cern.ch
require_non_empty_dir /cvmfs/ilc.desy.de
require_non_empty_dir /cvmfs/nova.opensciencegrid.org
require_non_empty_dir /cvmfs/sft.cern.ch/lcg/views
'

printf "\033[1;32mCVMFS CSI driver deployed and verified.\033[0m\n"
printf "\033[1;33mNext step: apply cvmfs-csi/config-singleuser.yaml to config.yaml, then upgrade JupyterHub.\033[0m\n"
