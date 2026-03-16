#!/bin/bash

set -ouex pipefail

### Common packages and settings for all variants

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

dnf5 install -y tmux

# Ghostty
dnf5 copr enable -y scottames/ghostty
dnf5 install -y ghostty
dnf5 copr disable -y scottames/ghostty

### Remove packages
dnf5 remove -y ibus virtualbox-guest-additions
dnf5 autoremove -y

#### Example for enabling a System Unit File
systemctl enable podman.socket
