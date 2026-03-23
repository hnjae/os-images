#!/bin/bash

set -ouex pipefail

### Common packages and settings for all variants

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

dnf5 mark dependency --assumeyes \
    adwaita-mono-fonts adwaita-sans-fonts \
    akonadi-server akonadi-server-mysql \
    kate kate-libs kwrite kwrited \
    fedora-bookmarks \
    mariadb mariadb-backup mariadb-common mariadb-connector-c mariadb-connector-c-config mariadb-cracklib-password-check mariadb-errmsg mariadb-gssapi-server mariadb-server \
    ffmpeg ffmpeg-libs lame opus-tools opusfile \
    ntfs-3g ntfs-3g-libs ntfs-3g-system-compression \
    hunspell-en-GB gocryptfs \
    duf btop

dnf5 remove --assumeyes \
    plymouth \
    ibus virtualbox-guest-additions \
    nano nano-default-editor \
    zram-generator \
    waydroid \
    webapp-manager \
    gnome-disk-utility filelight

dnf5 install \
    --setopt=install_weak_deps=True \
    --enablerepo=terra,terra-extras,terra-mesa,rpmfusion-free,rpmfusion-nonfree \
    --assumeyes \
    zsh \
    sarasa-gothic-fonts nerd-fonts \
    podman-docker \
    ghostty

# Pretendard font
PRETENDARD_VERSION=1.3.9
curl -fsSL "https://github.com/orioncactus/pretendard/releases/download/v${PRETENDARD_VERSION}/Pretendard-${PRETENDARD_VERSION}.zip" -o /tmp/pretendard.zip
unzip -q /tmp/pretendard.zip "public/static/*.otf" -d /tmp/pretendard
install -Dm644 /tmp/pretendard/public/static/*.otf -t /usr/share/fonts/OTF

### System configuration
echo "options hid_apple fnmode=2" >/etc/modprobe.d/hid_apple.conf
