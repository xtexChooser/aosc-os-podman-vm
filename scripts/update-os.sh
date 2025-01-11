#!/usr/bin/env bash
# shellcheck source=utils.sh
source "$(dirname "$0")/utils.sh"

if [[ $# == 0 ]]; then
    cat <<EOF
$0 <OPTIONS>

Update the given image.

Options:
    -v --verbose            Verbose logging
    -i --image              OCI Image
    -t --tag                Tag
EOF
    exit 1
fi

while [ $# -ne 0 ]; do
    case $1 in
    -v | --verbose)
        export AOSCVERBOSE=1
        shift
        ;;
    -i | --image)
        image="$2"
        shift 2
        ;;
    -t | --tag)
        tag="$2"
        shift 2
        ;;
    *)
        adie "Unknown option: $1"
        ;;
    esac
done

aCheckDep buildah
aCheckVar image

: "${tag:=}"

trap "aBuildahClean" EXIT
c="$(aBuildahFrom \
    --name "aosc-os-update-$(aRandom)" \
    "$image")"
aBuildahContainers+=("$c")

ainfo "Setting container configuration ..."
buildah config \
    --annotation org.opencontainers.image.version="latest" \
    "$c"

ainfo "Running oma upgrade ..."
# Fallback on older images, where oma does not support --force-unsafe-io
time buildah run "$c" /usr/bin/oma upgrade -y --force-confnew --no-progress --force-unsafe-io --no-check-dbus ||
    time buildah run "$c" /usr/bin/oma upgrade -y --force-confnew --no-progress --no-check-dbus
ainfo "Running oma autoremove ..."
time buildah run "$c" /usr/bin/oma autoremove -y --no-progress --remove-config
ainfo "Running oma clean ..."
time buildah run "$c" /usr/bin/oma clean --no-progress

ainfo "Committing image ..."
image="$(buildah commit "$c")"
echo -n "$image"

if [[ -n "$tag" ]]; then
    ainfo "Tagging image ..."
    buildah tag "$image" "$tag"
fi
