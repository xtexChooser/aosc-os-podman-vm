#!/usr/bin/env bash
# shellcheck source=utils.sh
source "$(dirname "$0")/utils.sh"

if [[ $# == 0 ]]; then
    cat <<EOF
$0 <OPTIONS>

Helper to find out the latest tarball.

Options:
    -v --verbose            Verbose logging
    --variant               Variant
    --arch                  Architecture
    --date                  Release date
    --refresh               Refresh recipe cache
EOF
    exit 1
fi

while [ $# -ne 0 ]; do
    case $1 in
    -v | --verbose)
        export AOSCVERBOSE=1
        shift
        ;;
    --variant)
        variant="$2"
        shift 2
        ;;
    --arch)
        arch="$2"
        shift 2
        ;;
    --date)
        date="$2"
        shift 2
        ;;
    --refresh)
        refreshRecipe=1
        shift
        ;;
    *)
        adie "Unknown option: $1"
        ;;
    esac
done

variant="${variant,,}"
arch="${arch,,}"
: "${date:=}"
: "${refreshRecipe:=}"
: "${RECIPE_CACHE:=/tmp/aosc-os-podman-vm-recipe.json}"
: "${RECIPE_URL:=https://releases.aosc.io/manifest/recipe.json}"

aCheckDep jq curl
aCheckVar variant arch

if [[ -n "$refreshRecipe" || ! -e "$RECIPE_CACHE" ]] || ! jq '{}' "$RECIPE_CACHE" &>/dev/null; then
    ainfo "Downloading recipe.json ..."
    acurl "$RECIPE_URL" -o "$RECIPE_CACHE"
fi

query=".variants \
| map(select((.name | ascii_downcase) == \"${variant}\").tarballs) \
| flatten \
| map(select(.arch == \"${arch}\")) \
"
if [[ -n "$date" ]]; then
    ainfo "Finding $date AOSC OS tarball for '$variant' '$arch' ..."
    query+="| map(select(.date == \"${date}\")) | .[0]"
else
    ainfo "Finding latest AOSC OS tarball for '$variant' '$arch' ..."
    query+="| sort_by(.date) | reverse | .[0]"
fi
query+="| .variant = \"${variant}\""

alog "Using cached recipe JSON: $RECIPE_CACHE"
ajq "$query" "$RECIPE_CACHE"
