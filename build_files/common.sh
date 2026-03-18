#!/bin/bash

set -ouex pipefail

### Common packages and settings for all variants

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# Terra repository
if ! dnf5 repolist --enabled | grep -q terra; then
    # shellcheck disable=SC2016
    dnf5 install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
fi

dnf5 install -y tmux zsh sarasa-gothic-fonts nerd-fonts

# Ghostty
dnf5 copr enable -y scottames/ghostty
dnf5 install -y ghostty
dnf5 copr disable -y scottames/ghostty

# Pretendard font
PRETENDARD_VERSION=1.3.9
curl -fsSL "https://github.com/orioncactus/pretendard/releases/download/v${PRETENDARD_VERSION}/Pretendard-${PRETENDARD_VERSION}.zip" -o /tmp/pretendard.zip
unzip -q /tmp/pretendard.zip "public/static/*.otf" -d /tmp/pretendard
install -Dm644 /tmp/pretendard/public/static/*.otf -t /usr/share/fonts/OTF

### Remove packages
dnf5 remove -y ibus virtualbox-guest-additions
dnf5 autoremove -y

### System configuration
echo "options hid_apple fnmode=2" >/etc/modprobe.d/hid_apple.conf

### Systemd services
systemctl enable podman.socket
