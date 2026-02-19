MINIKUBE_DRIVER='docker'

#   - k8s releases: https://github.com/kubernetes/kubernetes/releases
KUBERNETES_VERSION='v1.34.0'

## Start minikube
minikube start --driver=$MINIKUBE_DRIVER --kubernetes-version=$KUBERNETES_VERSION \
--container-runtime=docker --gpus all

## Create TLS secret
kubectl create secret tls tls-secret --cert=cert.pem --key=key_pkcs1.pem 

## add OAuth secret
. oauth_secret.sh

#Set LCG versions to be used
export LCG_VERSION=LCG_105
export LCG_ARCH=x86_64-el9-gcc12-opt

kubectl create configmap configs --from-literal=LCG_VERSION=$LCG_VERSION --from-literal=LCG_ARCH=$LCG_ARCH

## Add scratch volume from bare-metal storage
minikube mount /scratch:/scratch &
kubectl apply -f scratch/volumes.yaml

## Add cvmfs 
helm repo add sciencebox https://registry.cern.ch/chartrepo/sciencebox
helm repo update
helm upgrade --cleanup-on-fail \
      --install sciencebox sciencebox/cvmfs \
      --namespace default \
      --create-namespace \
      --values cvmfs/config.yaml 
kubectl apply -f cvmfs/volumes.yaml

# Add DESY ILC repository configuration
kubectl patch configmap sciencebox-cvmfs-cfgmap-config-d --patch-file cvmfs/ilc.desy.de.yaml

#Prefetch some cvmfs directories
kubectl apply -f cvmfs/test-pod.yaml
kubectl wait --for=condition=ready pod/cvmfs-test --timeout=300s
kubectl cp cvmfs/fetch_cvmfs.sh cvmfs-test:/tmp/fetch_cvmfs.sh
kubectl exec cvmfs-test -- sh /tmp/fetch_cvmfs.sh

## Add JupyterHub 
helm upgrade --cleanup-on-fail \
  --install jupyterhub jupyterhub/jupyterhub \
  --namespace default \
  --create-namespace \
  --version=4.3.2 \
  --timeout=600s \
  --values config.yaml