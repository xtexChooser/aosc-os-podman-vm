#!/usr/bin/env bash
# shellcheck source=utils.sh
source "$(dirname "$0")/utils.sh"

if [[ $# == 0 ]]; then
    cat <<EOF
$0 <OPTIONS>

Download release tarballs.

Options:
    -v --verbose            Verbose logging
    -o --output             Output file

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
    -o | --output)
        output="$2"
        shift 2
        ;;
    -O)
        output="AUTO"
        shift
        ;;
    *)
        adie "Unknown option: $1"
        ;;
    esac
done

: "${RELEASES_URL:=https://releases.aosc.io}"

aCheckDep curl
aCheckVar output

tarballJson="$(cat)"
path="$(ajqRaw '.path' <<<"$tarballJson")"
sha256cksum="$(ajqRaw '.sha256sum' <<<"$tarballJson")"
url="${RELEASES_URL}/${path}"

if [[ "$output" == AUTO ]]; then
    output="$(basename "$path")"
fi

if command -v aria2c &>/dev/null; then
    ainfo "Downloading '$url' with aria2c ..."
    aria2c "$url" -o "$output" -x16 -k8M -s16 &>/dev/stderr
else
    ainfo "Downloading '$url' with cURL ..."
    acurl "$url" -o "$output"
fi

actualCksum="$(aSha256 "$output")"
if [[ "$actualCksum" != "$sha256cksum" ]]; then
    aerror "Invalid SHA-256 checksum: expected ${sha256cksum}, actually ${actualCksum}"
else
    ainfo "SHA-256 checksum valid!"
fi

echo "$output"
