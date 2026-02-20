# jupyterhub-k8s
K8S configuration of jupyterhub for Faculty of Physics, University of Warsaw. 
Setup includes: 

* authentication via Google OAuth, with allowed users listed in a secret
* user directories are persisted on a volume [mounted](deploy.sh#L32) from the bare-metal host
* access to cvmfs repositories, listed in [cvmfs/config.yaml](cvmfs/config.yaml)
* custom spawn page

## Prerequisites

* [Docker](https://docs.docker.com/engine/install/ubuntu/)
* [minikube](https://minikube.sigs.k8s.io/docs/start/)
* [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#docker) (optional, for GPU support)



## Installation

```bash
git clone https://github.com/akalinow/jupyterhub-k8s.git
cd jupyterhub-k8s
```

Set the TLS certificate and key for the server if you do not have them already.
Note selfsigned certificate will generate a warning in the browser.
Use the pkcs1 format for the key, as the pkcs8 format is not supported by jupyterhub:

```bash
openssl pkcs8 -topk8 -inform PEM -outform PEM -in key.pem -out key_pkcs1.pem -nocrypt
```
Fill OAuth values in `oauth_secret.sh` and add users to `data/users.json`., then run the deployment script:
```bash
./deploy.sh
```

Access the JupyterHub instance at https://localhost:32443 and log in with Google accounts listed in `users.json`.
