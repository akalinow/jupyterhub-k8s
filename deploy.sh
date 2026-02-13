MINIKUBE_DRIVER='docker'

#   - k8s releases: https://github.com/kubernetes/kubernetes/releases
KUBERNETES_VERSION='v1.34.0'

## Start minikube
minikube start --driver=$MINIKUBE_DRIVER --kubernetes-version=$KUBERNETES_VERSION \
--container-runtime=docker --gpus all

## Create TLS secret
kubectl create secret tls tls-secret --cert=cert.pem --key=key_pkcs1.pem 

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

#kubectl apply -f cvmfs/test-pod.yaml
#kubectl exec -it cvmfs-test -- sh

## Add JupyterHub 
helm upgrade --cleanup-on-fail \
  --install jupyterhub jupyterhub/jupyterhub \
  --namespace default \
  --create-namespace \
  --version=4.3.2 \
  --values config.yaml