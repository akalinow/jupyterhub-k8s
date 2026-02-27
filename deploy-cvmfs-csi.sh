#!/bin/bash
# Deploy the CVMFS CSI driver alongside the existing sciencebox setup.
#
# This script is self-contained — it does NOT modify or remove the existing
# sciencebox/cvmfs DaemonSet, PVCs, or JupyterHub config.yaml.
# Run ./deploy.sh first (or make sure the cluster is up), then run this.
#
# Once cvmfs-csi-test pod is verified, proceed with:
#   1. Update config.yaml using cvmfs-csi/config-singleuser.yaml
#   2. Upgrade JupyterHub:  helm upgrade jupyterhub jupyterhub/jupyterhub --values config.yaml
#   3. Remove old setup:    helm uninstall sciencebox && kubectl delete -f cvmfs/volumes.yaml

set -e

## ============================================================
## 1. Add the CVMFS CSI Helm repository
## ============================================================
helm repo add cvmfs-csi https://cvmfs-contrib.github.io/cvmfs-csi
helm repo update

## ============================================================
## 2. Install the CVMFS CSI driver in its own namespace
##    - values.yaml sets cmvfsHttpProxy=DIRECT (non-CERN env)
##    - ILC repo config + public key embedded via extraConfigMaps
##    - Cache stored at /var/lib/cvmfs.csi.cern.ch/cache on each node
## ============================================================
helm upgrade --cleanup-on-fail \
  --install cvmfs-csi cvmfs-csi/cvmfs-csi \
  --namespace cvmfs \
  --create-namespace \
  --values cvmfs-csi/values.yaml

printf "\033[1;36mWaiting for CVMFS CSI DaemonSet to be ready...\033[0m\n"
kubectl rollout status daemonset \
  -l "app.kubernetes.io/instance=cvmfs-csi" \
  -n cvmfs \
  --timeout=120s

## ============================================================
## 3. Deploy test pod and run the existing prefetch/verify script
##    Pod name: cvmfs-csi-test (does NOT conflict with cvmfs-test)
## ============================================================
kubectl apply -f cvmfs-csi/test-pod.yaml

printf "\033[1;36mWaiting for cvmfs-csi-test pod to be ready...\033[0m\n"
kubectl wait --for=condition=ready pod/cvmfs-csi-test --timeout=300s

printf "\033[1;36mRunning fetch/verify script inside cvmfs-csi-test...\033[0m\n"
kubectl cp cvmfs/fetch_cvmfs.sh cvmfs-csi-test:/tmp/fetch_cvmfs.sh
kubectl exec cvmfs-csi-test -- sh /tmp/fetch_cvmfs.sh

printf "\033[1;32mCVMFS CSI driver deployed and verified.\033[0m\n"
printf "\033[1;33mNext step: apply cvmfs-csi/config-singleuser.yaml to config.yaml, then upgrade JupyterHub.\033[0m\n"
