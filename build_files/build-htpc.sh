#!/bin/bash

set -ouex pipefail

# shellcheck disable=SC1091
source /ctx/common.sh

### HTPC-specific packages and settings

### Remove packages
dnf5 autoremove --assumeyes
