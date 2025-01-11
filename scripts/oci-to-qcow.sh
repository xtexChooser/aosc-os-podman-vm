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
    -o --output             Output
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
    -o | --output)
        output="$2"
        shift 2
        ;;
    *)
        adie "Unknown option: $1"
        ;;
    esac
done

aCheckDep buildah virt-make-fs
aCheckVar image output

! [[ -e "$output" ]] || adie "Output file '$output' already exists"

trap "buildah unmount \"\$c\"; aBuildahClean" EXIT

ainfo "Mounting container image ..."
c="$(aBuildahFrom \
    --name "aosc-os-mkqcow2-$(aRandom)" \
    "$image")"
aBuildahContainers+=("$c")
imgroot="$(buildah mount "$c")"

ainfo "Creating FS ..."
virt-make-fs --format=qcow2 --type=ext3 "$imgroot" "$output"
