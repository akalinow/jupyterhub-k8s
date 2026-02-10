MINIKUBE_DRIVER='docker'

#   - k8s releases: https://github.com/kubernetes/kubernetes/releases
KUBERNETES_VERSION='v1.34.0'

## Start minikube
minikube start --driver=$MINIKUBE_DRIVER --kubernetes-version=$KUBERNETES_VERSION \
--container-runtime=docker --gpus all

# Mount local directory to minikube for persistent storage
minikube mount /scratch:/scratch &

## Create TLS secret
kubectl create secret tls tls-secret --cert=cert.pem --key=key_pkcs1.pem 

## Add persistent volume and claim for bare-metal storage
kubectl apply -f local-pvs/persistent-volume.yaml
kubectl apply -f local-pvs/persistent-volume-claim.yaml

## Add cvmfs volumes
kubectl create namespace cvmfs
kubectl apply -k osg-k8s-cvmfs/cvmfs-daemonset
kubectl apply -k osg-k8s-cvmfs/cvmfs-pvcs

## Add JupyterHub Helm repo
helm upgrade --install --cleanup-on-fail \
  --install jupyterhub jupyterhub/jupyterhub \
  --namespace default \
  --create-namespace \
  --version=4.3.2 \
  --values config.yaml