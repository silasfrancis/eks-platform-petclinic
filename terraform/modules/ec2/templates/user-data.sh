#!/bin/bash
set -euo pipefail

# Update system
dnf update -y

# Install base tools (including awscli!)
dnf install -y \
  git \
  jq \
  curl \
  unzip \
  bash-completion \
  bind-utils \
  awscli

# Install aws cli (ARM64)
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install kubectl (ARM64)
KUBECTL_VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt)

curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/arm64/kubectl"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/arm64/kubectl.sha256"

echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

rm -f kubectl kubectl.sha256

# Install Helm (ARM64)
HELM_VERSION="v3.15.0"

curl -LO https://get.helm.sh/helm-${HELM_VERSION}-linux-arm64.tar.gz
tar -zxvf helm-${HELM_VERSION}-linux-arm64.tar.gz
mv linux-arm64/helm /usr/local/bin/helm

rm -rf linux-arm64 helm-${HELM_VERSION}-linux-arm64.tar.gz

# Configure kubectl for ec2-user
sudo -u ec2-user -i << EOF
aws eks update-kubeconfig \
  --name ${cluster_name} \
  --region ${region} \
  --alias ${app}
EOF

# Enable bash completions
kubectl completion bash > /etc/bash_completion.d/kubectl
helm completion bash > /etc/bash_completion.d/helm

echo 'alias k=kubectl' >> /etc/bashrc
echo 'complete -o default -F __start_kubectl k' >> /etc/bashrc

# Signal bootstrap complete
aws ssm put-parameter \
  --name "/${app}/jumphost/bootstrap-status" \
  --value "complete" \
  --type "String" \
  --overwrite \
  --region ${region}

echo "Bootstrap complete"