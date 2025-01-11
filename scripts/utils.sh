# shellcheck shell=bash
set -euo pipefail
# shellcheck source=/dev/null
! [ -e .env ] || source .env

alog() {
    [[ -z "${AOSCVERBOSE:-}" ]] || echo "[     ] $*" >&2
}

ainfo() {
    echo "[INFO ] $*" >&2
}

aerror() {
    echo "[ERROR] $*" >&2
}

adie() {
    aerror "$*"
    exit 1
}

aCheckDep() {
    for dep in "$@"; do
        if ! command -v "$dep" &>/dev/null; then
            adie "Dependency could not be found in PATH: $dep"
        else
            alog "Dependency found in PATH: $dep"
        fi
    done
}

aCheckVar() {
    for dep in "$@"; do
        if [[ -z "${!dep:-}" ]]; then
            adie "Variable is empty: $dep"
        else
            alog "Variable is not empty: $dep"
        fi
    done
}

acurl() {
    alog "Sending HTTP request: '$1'"
    command curl \
        --retry 3 \
        --proto '=https' \
        --tlsv1.2 -sSf \
        "$@"
}

ajq() {
    alog "Executing JSON query: '$1'"
    command jq \
        "$@"
}

ajqRaw() {
    alog "Executing JSON query: '$1'"
    command jq \
        --join-output \
        "$@"
}

aSha256() {
    alog "Calculating sha256 checksum of '$1'"
    sha256sum "$1" | cut -d ' ' -f1
}

aRandom() {
    head -c256 /dev/urandom | sha256sum - | head -c16
}

declare -a aBuildahContainers

aBuildahClean() {
    for container in "${aBuildahContainers[@]}"; do
        ainfo "Removing container: '$container'"
        buildah rm "$container"
    done
}

aBuildahFrom() {
    local container
    container="$(buildah from "$@")"
    [[ -n "$container" ]] || exit 1
    ainfo "Created container: '$container'"
    echo -n "$container"
}
