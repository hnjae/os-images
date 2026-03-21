# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A bootc-based container image build system for creating customized Fedora Linux system images. Builds multiple variants (desktop, HTPC) as OCI container images from Universal Blue's Bazzite base, with optional disk image generation (QCOW2, ISO, RAW). Images are published to GHCR and signed with cosign.

## Build Commands

```bash
# Build OCI container image (requires podman)
just build [variant=desktop] [tag=latest]

# Build disk images (requires privileged/rootful podman)
just build-qcow2 [variant=desktop] [tag=latest]
just build-raw [variant=desktop] [tag=latest]
just build-iso [variant=desktop] [tag=latest]

# Run a built VM image
just run-vm-qcow2 [variant] [tag]        # QEMU with browser VNC
just spawn-vm [rebuild=0] [type=qcow2]    # systemd-vmspawn

# Lint & format
just check       # Runs pre-merge-commit hooks via prek (all files)
just format      # Runs pre-commit hooks via prek (all files)
just clean        # Remove build artifacts
```

## Architecture

**Build flow:** `just build` → `podman build -f Containerfile.{variant}` → runs `build_files/build-{variant}.sh` (which sources `build_files/common.sh`) → `bootc container lint`

**Containerfile pattern:** Uses a two-stage build — `FROM scratch AS ctx` copies build_files as a read-only bind mount into the real build stage, avoiding extra image layers. Cache mounts on `/var/cache` and `/var/log`.

**Variant structure:**

- `Containerfile.desktop` → base: `bazzite:stable` → runs `build-desktop.sh`
- `Containerfile.htpc` → base: `bazzite-deck:stable` → runs `build-htpc.sh`
- `common.sh` is shared across all variants (fonts, repos, services)

**Image naming:** `ghcr.io/{owner}/os-images-{variant}:{tag}`

## Shell Script Conventions

- All scripts use `set -ouex pipefail` (strict mode with command tracing)
- ShellCheck directive `# shellcheck disable=SC1091` on build scripts (source paths resolve at container build time, not locally)
- Formatting: 4-space indent (shfmt), shellharden for quoting safety

## CI/CD

- **build.yml:** Builds OCI images on push to main, daily, and PRs. Pushes to GHCR and signs with cosign (main only). Matrix: `[desktop]`.
- **build-disk.yml:** Manual dispatch + PR changes to `disk_config/`. Builds QCOW2 and anaconda-iso.
- Cosign keys must have empty password (`COSIGN_PASSWORD=""`)

## Commit Convention

Format: `{type}({scope}): {message}` — e.g., `fix(ci): update cosign public key`, `refactor(justfile): simplify check`
