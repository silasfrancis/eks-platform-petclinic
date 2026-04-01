#!/bin/bash
set -e

dnf update -y

curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl.sha256"
echo "$(cat kubectl.sha256) kubectl" | sha256sum --check
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl kubectl.sha256

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

sudo -u ec2-user bash << EOF
  aws eks update-kubeconfig \
    --name ${cluster_name} \
    --region ${region} \
    --alias ${app}
EOF

dnf install -y \
  git \
  jq \
  curl \
  unzip \
  bash-completion \
  bind-utils

kubectl completion bash > /etc/bash_completion.d/kubectl
echo 'alias k=kubectl' >> /etc/bashrc
echo 'complete -o default -F __start_kubectl k' >> /etc/bashrc
helm completion bash > /etc/bash_completion.d/helm

aws ssm put-parameter \
  --name "/${app}/jumphost/bootstrap-status" \
  --value "complete" \
  --type "String" \
  --overwrite \
  --region ${region}

echo "Bootstrap complete"