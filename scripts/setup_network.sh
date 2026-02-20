#!/usr/bin/env bash
set -euo pipefail

# Setup persistent network forwarding for external access to JupyterHub
# Run this script after minikube is started

MINIKUBE_IP=$(minikube ip)
echo "Setting up port forwarding for minikube IP: ${MINIKUBE_IP}"

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Add NAT rules for external access to port 32443
sudo iptables -t nat -A PREROUTING -p tcp --dport 32443 -j DNAT --to-destination ${MINIKUBE_IP}:32443
sudo iptables -t nat -A POSTROUTING -d ${MINIKUBE_IP} -p tcp --dport 32443 -j MASQUERADE

# Allow forwarding
sudo iptables -I FORWARD -p tcp --dport 32443 -j ACCEPT

# Make IP forwarding persistent
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-jupyterhub-forwarding.conf

# Save iptables rules
if command -v netfilter-persistent &> /dev/null; then
  sudo netfilter-persistent save
  echo "Rules saved via netfilter-persistent"
elif [ -d /etc/iptables ]; then
  sudo iptables-save | sudo tee /etc/iptables/rules.v4
  echo "Rules saved to /etc/iptables/rules.v4"
else
  echo "Warning: iptables-persistent not installed. Install with:"
  echo "  sudo apt install iptables-persistent"
fi

echo "Network forwarding setup complete!"
echo "Verify with: sudo iptables -t nat -L -n -v | grep 32443"
sudo iptables -t nat -L -n -v | grep 32443