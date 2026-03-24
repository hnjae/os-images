#!/bin/bash

set -ouex pipefail

# shellcheck disable=SC1091
source /ctx/common.sh

### Desktop-specific packages and settings

curl -fsSLo /etc/yum.repos.d/brave-browser.repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

cat >/etc/yum.repos.d/fury-nushell.repo <<'REPO'
[gemfury-nushell]
name=Gemfury Nushell Repo
baseurl=https://yum.fury.io/nushell/
enabled=1
gpgcheck=0
gpgkey=https://yum.fury.io/nushell/gpg.key
REPO

dnf5 install \
    --setopt=install_weak_deps=True \
    --enablerepo=terra,terra-extras,terra-mesa,rpmfusion-free,rpmfusion-nonfree \
    --assumeyes \
    brave-browser firefox nushell

### Remove packages
dnf5 autoremove --assumeyes
