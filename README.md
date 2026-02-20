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
Fill OAuth values in `oauth_secret.sh` and create the secret:


```bash
source oauth_secret.sh
```

Add users to `data/users.json`:

```bash
{
    "admin": "your-admin-email@uw.edu.pl",
    "users": [
        "your-user-email@uw.edu.pl",
        "user1@uw.edu.pl",
        "user2@student.ue.wdu.pl"
    ]
}
``` 

Add users list to secret:

```bash
users_secret.sh data/users.json
```

Deploy the cluster:

```bash
./deploy.sh
```

Access the JupyterHub instance at https://localhost:32443 and log in with Google accounts listed in `users.json`.
