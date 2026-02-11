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
kubectl apply -f scratch/persistent-volume.yaml
kubectl apply -f scratch/persistent-volume-claim.yaml

## Add cvmfs volumes
helm upgrade --install cvmfs-csi oci://registry.cern.ch/kubernetes/charts/cvmfs-csi --values cvmfs/cvmfs-csi-custom-values.yaml
kubectl apply -f cvmfs/volume-pv-pvc.yaml

## Add JupyterHub 
helm upgrade --install --cleanup-on-fail \
  --install jupyterhub jupyterhub/jupyterhub \
  --namespace default \
  --create-namespace \
  --version=4.3.2 \
  --values config.yaml