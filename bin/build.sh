#!/bin/sh
set -eu

usage() { echo "usage: bin/build.sh <package or path>... [-- <makepkg args>]" >&2; exit 1; }

root=$(cd "$(dirname "$0")/.." && pwd)
image=${IMAGE:-archlinux:base-devel}

pkgs=""
while [ $# -gt 0 ]; do
    case "$1" in
        --) shift; break ;;
        -*) usage ;;
        *) pkgs="$pkgs $1"; shift ;;
    esac
done
[ -n "$pkgs" ] || usage

mkdir -p "$root/out"
for pkg in $pkgs; do
    pkg=${pkg%/}
    if [ -f "$pkg/PKGBUILD" ] && [ "${pkg#*/}" != "$pkg" ]; then
        src=$(cd "$pkg" && pwd)
    else
        src=$root/$pkg
    fi
    [ -f "$src/PKGBUILD" ] || { echo "build.sh: no PKGBUILD in $pkg" >&2; exit 1; }
    name=$(basename "$src")
    mkdir -p "$root/work/$name"
    docker run --rm \
        -v "$root/bin:/bin-fnas:ro" \
        -v "$src:/src:ro" \
        -v "$root/out:/out" \
        -v "$root/work/$name:/work" \
        -e MAKEFLAGS="-j$(nproc)" \
        -e FREEDOMNAS_REF="${FREEDOMNAS_REF:-dev}" \
        "$image" sh /bin-fnas/build-inside.sh "$(id -u)" /src /out /work "$@"
done
ls -la "$root/out"
