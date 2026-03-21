#!/bin/bash

set -ouex pipefail

# shellcheck disable=SC1091
source /ctx/common.sh

### Desktop-specific packages and settings

# 1Password
# Redirect /opt to /usr/lib/opt so files land in the immutable image layer
# (default /opt -> /var/opt is stateful and gets wiped on first boot)
install -d /usr/lib/opt
ln -sfn usr/lib/opt /opt
rpm --import https://downloads.1password.com/linux/keys/1password.asc
cat >/etc/yum.repos.d/1password.repo <<'REPO'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
REPO

curl -fsSLo /etc/yum.repos.d/brave-browser.repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

dnf5 install \
    --setopt=install_weak_deps=True \
    --enablerepo=terra,terra-extras,terra-mesa \
    --assumeyes \
    1password brave-browser firefox

rm -f /etc/yum.repos.d/1password.repo
