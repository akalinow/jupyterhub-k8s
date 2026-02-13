# jupyterhub-k8s
K8S configuration of jupyterhub for Faculty of Physics, University of Warsaw. 


## Installation

```bash
git clone https://github.com/akalinow/jupyterhub-k8s.git
cd jupyterhub-k8s
```

Set the TLS certificate and key. Use the pkcs1 format for the key, as the pkcs8 format is not supported by jupyterhub:

```bash
openssl pkcs8 -topk8 -inform PEM -outform PEM -in key.pem -out key_pkcs1.pem -nocrypt
```

Set the OAuth client id and secret:
(put the values in oauth_secret.sh)

```bash
source oauth_secret.sh
```

Deploy the cluster:

```bash
./deploy.sh
```

Access the JupyterHub instance at https://localhost:32443 and log in with your UW Google account. 

Deploy updates:

```bash
helm upgrade --install jupyterhub jupyterhub/jupyterhub -f config.yaml
```
