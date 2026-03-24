export image_registry := env("IMAGE_REGISTRY", "ghcr.io/hnjae")
export image_name := env("IMAGE_NAME", "os-images")
export default_variant := env("DEFAULT_VARIANT", "desktop")
export default_tag := env("DEFAULT_TAG", "latest")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

[group('ci')]
format:
    prek run --hook-stage pre-commit --all-files

[group('ci')]
check:
    prek run --hook-stage pre-merge-commit --all-files

# Clean Repo
[group('utility')]
clean:
    #!/usr/bin/env bash
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -f output/

# Sudo Clean Repo
[group('utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('utility')]
[private]
sudoif command *args:
    #!/usr/bin/env bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# Build locally, tag as the tracked registry ref, and switch bootc to it
[group('bootc')]
bootc-switch-local variant=default_variant $tag=default_tag target_image=(image_registry + "/" + image_name + "-" + variant): (build variant tag)
    #!/usr/bin/env bash
    set -euo pipefail

    source_image="{{ image_name }}-{{ variant }}:${tag}"
    target_image="{{ target_image }}:${tag}"

    podman tag "${source_image}" "${target_image}"
    just _rootful_load_image "{{ target_image }}" "{{ tag }}"
    just sudoif bootc switch --transport containers-storage "${target_image}"

# Build locally and immediately reboot into the new image
[group('bootc')]
bootc-switch-local-apply variant=default_variant $tag=default_tag target_image=(image_registry + "/" + image_name + "-" + variant): (build variant tag)
    #!/usr/bin/env bash
    set -euo pipefail

    source_image="{{ image_name }}-{{ variant }}:${tag}"
    target_image="{{ target_image }}:${tag}"

    podman tag "${source_image}" "${target_image}"
    just _rootful_load_image "{{ target_image }}" "{{ tag }}"
    just sudoif bootc switch --transport containers-storage --apply "${target_image}"

# Switch back to the tracked remote registry image
[group('bootc')]
bootc-switch-remote variant=default_variant $tag=default_tag target_image=(image_registry + "/" + image_name + "-" + variant):
    just sudoif bootc switch "{{ target_image }}:{{ tag }}"

# Show current bootc deployment status
[group('bootc')]
bootc-status:
    just sudoif bootc status

# Build container image

# Example: just build desktop latest
[group('build')]
build variant=default_variant $tag=default_tag:
    #!/usr/bin/env bash

    BUILD_ARGS=()
    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi

    podman build \
        "${BUILD_ARGS[@]}" \
        --pull=newer \
        --file "Containerfile.{{ variant }}" \
        --tag "{{ image_name }}-{{ variant }}:${tag}" \
        .

[private]
_rootful_load_image $target_image $tag=default_tag:
    #!/usr/bin/bash
    set -eoux pipefail

    # Check if already running as root or under sudo
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    # Try to resolve the image tag using podman inspect
    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    if [[ $return_code -eq 0 ]]; then
        # If the image is found, load it into rootful podman
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            # If the image ID is not found or different from user, copy the image from user podman to root podman
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        # If the image is not found, pull it from the repository
        just sudoif podman pull "${target_image}:${tag}"
    fi

[private]
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v $(pwd)/${config}:/config.toml:ro \
      -v $BUILDTMP:/output \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "${bib_image}" \
      ${args} \
      "${target_image}:${tag}"

    mkdir -p output
    sudo mv -f $BUILDTMP/* output/
    sudo rmdir $BUILDTMP
    sudo chown -R $USER:$USER output/

[private]
_rebuild-bib variant $tag $type $config: (build variant tag) && (_build-bib ("localhost/" + image_name + "-" + variant) tag type config)

# Build a QCOW2 virtual machine image
[group('build-vm-image')]
build-qcow2 variant=default_variant $tag=default_tag: && (_build-bib ("localhost/" + image_name + "-" + variant) tag "qcow2" "disk_config/disk.toml")

# Build a RAW virtual machine image
[group('build-vm-image')]
build-raw variant=default_variant $tag=default_tag: && (_build-bib ("localhost/" + image_name + "-" + variant) tag "raw" "disk_config/disk.toml")

# Build an ISO virtual machine image
[group('build-vm-image')]
build-iso variant=default_variant $tag=default_tag: && (_build-bib ("localhost/" + image_name + "-" + variant) tag "iso" "disk_config/iso.toml")

# Rebuild a QCOW2 virtual machine image
[group('build-vm-image')]
rebuild-qcow2 variant=default_variant $tag=default_tag: && (_rebuild-bib variant tag "qcow2" "disk_config/disk.toml")

# Rebuild a RAW virtual machine image
[group('build-vm-image')]
rebuild-raw variant=default_variant $tag=default_tag: && (_rebuild-bib variant tag "raw" "disk_config/disk.toml")

# Rebuild an ISO virtual machine image
[group('build-vm-image')]
rebuild-iso variant=default_variant $tag=default_tag: && (_rebuild-bib variant tag "iso" "disk_config/iso.toml")

# Run a virtual machine with the specified image type and configuration
[private]
_run-vm $target_image $tag $type $config:
    #!/usr/bin/bash
    set -eoux pipefail

    # Determine the image file based on the type
    image_file="output/${type}/disk.${type}"
    if [[ $type == iso ]]; then
        image_file="output/bootiso/install.iso"
    fi

    # Build the image if it does not exist
    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "$target_image" "$tag"
    fi

    # Determine an available port to use
    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    # Set up the arguments for running the VM
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${image_file}":"/boot.${type}")
    run_args+=(docker.io/qemux/qemu)

    # Run the VM and open the browser to connect
    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run "${run_args[@]}"

# Run a virtual machine from a QCOW2 image
[group('run-vm')]
run-vm-qcow2 variant=default_variant $tag=default_tag: && (_run-vm ("localhost/" + image_name + "-" + variant) tag "qcow2" "disk_config/disk.toml")

# Run a virtual machine from a RAW image
[group('run-vm')]
run-vm-raw variant=default_variant $tag=default_tag: && (_run-vm ("localhost/" + image_name + "-" + variant) tag "raw" "disk_config/disk.toml")

# Run a virtual machine from an ISO
[group('run-vm')]
run-vm-iso variant=default_variant $tag=default_tag: && (_run-vm ("localhost/" + image_name + "-" + variant) tag "iso" "disk_config/iso.toml")

# Run a virtual machine using systemd-vmspawn
[group('run-vm')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash

    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the ISO" && just build-vm {{ rebuild }} {{ type }}

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| /usr/bin/numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i ./output/**/*.{{ type }}
