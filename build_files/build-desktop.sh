#!/bin/bash

set -ouex pipefail

# shellcheck disable=SC1091
source /ctx/common.sh

### Desktop-specific packages and settings

curl -fsSLo /etc/yum.repos.d/brave-browser.repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

dnf5 install \
    --setopt=install_weak_deps=True \
    --enablerepo=terra,terra-extras,terra-mesa,rpmfusion-free,rpmfusion-nonfree \
    --assumeyes \
    brave-browser firefox

### Remove packages
dnf5 autoremove --assumeyes
