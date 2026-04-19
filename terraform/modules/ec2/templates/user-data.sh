#!/bin/bash
set -euo pipefail

# Update system
dnf update -y

# Install wireguard tools
dnf install -y \
  wireguard-tools \
  bind-utils \
  bash-completion

echo "WireGuard server ready"