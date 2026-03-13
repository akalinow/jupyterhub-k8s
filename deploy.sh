MINIKUBE_DRIVER='docker'

#   - k8s releases: https://github.com/kubernetes/kubernetes/releases
KUBERNETES_VERSION='v1.34.0'

# Directory for persisten user data and cvmfs cache on the host, mounted as `scratch` in the cluster
LOCAL_SCRATCH_DIR='/scratch0'

## Start minikube
minikube start --mount --mount-string=$LOCAL_SCRATCH_DIR:/scratch --mount-type=virtiofs \
--driver=$MINIKUBE_DRIVER --kubernetes-version=$KUBERNETES_VERSION \
--container-runtime=docker --gpus all

## Setup storage class and volumes
kubectl apply -f scratch/volumes.yaml

## Setup network forwarding for external access
./scripts/setup_network.sh

## Create TLS secret
kubectl create secret tls tls-secret --cert=cert.pem --key=key_pkcs1.pem 

## Add OAuth secret
./scripts/oauth_secret.sh

## Add allowed users secret
./scripts/users_secret.sh assets/users.json

## Add custom spawn page
kubectl create configmap jupyterhub-templates --from-file=assets/spawn.html 

#Set LCG versions to be used
export LCG_VERSION=LCG_105
export LCG_ARCH=x86_64-el9-gcc12-opt
kubectl create configmap configs --from-literal=LCG_VERSION=$LCG_VERSION --from-literal=LCG_ARCH=$LCG_ARCH

## Add cvmfs 
helm repo add sciencebox https://registry.cern.ch/chartrepo/sciencebox
helm repo update
kubectl apply -f cvmfs/volumes.yaml
helm upgrade --cleanup-on-fail \
      --install sciencebox sciencebox/cvmfs \
      --namespace default \
      --create-namespace \
      --values cvmfs/config.yaml 

printf "\033[1;36mWaiting for sciencebox-cvmfs daemonset rollout...\033[0m\n"
kubectl rollout status daemonset/sciencebox-cvmfs --timeout=300s
printf "\033[1;36mWaiting for sciencebox-cvmfs pod initialization...\033[0m\n"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=sciencebox,app.kubernetes.io/name=cvmfs --timeout=300s

# Add DESY ILC repository configuration
kubectl patch configmap sciencebox-cvmfs-cfgmap-config-d --patch-file cvmfs/ilc.desy.de.yaml

# Prefetch some cvmfs directories
kubectl apply -f cvmfs/test-pod.yaml
printf "\033[1;36mWaiting for cvmfs-test pod to be ready...\033[0m\n"
kubectl wait --for=condition=ready pod/cvmfs-test --timeout=300s
kubectl cp cvmfs/fetch_cvmfs.sh cvmfs-test:/tmp/fetch_cvmfs.sh
kubectl exec cvmfs-test -- sh /tmp/fetch_cvmfs.sh

## Add JupyterHub
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
helm repo update
helm upgrade --cleanup-on-fail \
  --install jupyterhub jupyterhub/jupyterhub \
  --namespace default \
  --create-namespace \
  --version=4.3.2 \
  --timeout=600s \
  --values config.yaml

