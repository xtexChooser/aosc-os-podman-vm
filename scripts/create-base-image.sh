#!/usr/bin/env bash
# shellcheck source=utils.sh
source "$(dirname "$0")/utils.sh"

if [[ $# == 0 ]]; then
    cat <<EOF
$0 <OPTIONS>

Create a OCI image for the given tarball.

Options:
    -v --verbose            Verbose logging
    -f --tarball            Tarball

Input:
    Output from find-tarball.sh
EOF
    exit 1
fi

while [ $# -ne 0 ]; do
    case $1 in
    -v | --verbose)
        export AOSCVERBOSE=1
        shift
        ;;
    -f | --tarball)
        tarball="$2"
        shift 2
        ;;
    *)
        adie "Unknown option: $1"
        ;;
    esac
done

aCheckDep jq buildah
aCheckVar tarball

tarballJson="$(cat)"
variant="$(ajqRaw '.variant' <<<"$tarballJson")"
arch="$(ajqRaw '.arch' <<<"$tarballJson")"
date="$(ajqRaw '.date' <<<"$tarballJson")"

trap "aBuildahClean" EXIT
c="$(aBuildahFrom \
    --name "aosc-os-${variant}-${arch}-${date}" \
    scratch)"
aBuildahContainers+=("$c")

ainfo "Setting container configuration ..."
buildah config \
    --annotation org.opencontainers.image.title="AOSC-OS" \
    --annotation org.opencontainers.image.authors="AOSC" \
    --annotation org.opencontainers.image.vendor="AOSC" \
    --annotation org.opencontainers.image.url="https://github.com/AOSC-Dev/aosc-os-podman-vm" \
    --annotation org.opencontainers.image.source="https://github.com/AOSC-Dev/aosc-os-podman-vm" \
    --annotation org.opencontainers.image.version="$date" \
    --annotation org.opencontainers.image.licenses="GPL-3.0-or-later" \
    --annotation org.opencontainers.image.description="AOSC-OS $variant version $date for $arch" \
    --arch "$arch" \
    --env AOSC_CONTAINER_VARIANT="$variant" \
    --env AOSC_CONTAINER_ARCH="$arch" \
    --env AOSC_CONTAINER_DATE="$date" \
    --os linux \
    --cmd '[ "/usr/bin/bash" ]' \
    --workingdir / \
    "$c"

ainfo "Adding contents from tarball ..."
time buildah add "$c" "$tarball" /

ainfo "Committing image ..."
buildah commit "$c"
