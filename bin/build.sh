#!/bin/sh
set -eu

usage() { echo "usage: bin/build.sh <package>... [-- <makepkg args>]" >&2; exit 1; }

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
    [ -f "$root/$pkg/PKGBUILD" ] || { echo "build.sh: no $pkg/PKGBUILD" >&2; exit 1; }
    mkdir -p "$root/work/$pkg"
    docker run --rm \
        -v "$root/bin:/bin-fnas:ro" \
        -v "$root/$pkg:/src:ro" \
        -v "$root/out:/out" \
        -v "$root/work/$pkg:/work" \
        -e MAKEFLAGS="-j$(nproc)" \
        -e FREEDOMNAS_REF="${FREEDOMNAS_REF:-dev}" \
        "$image" sh /bin-fnas/build-inside.sh "$(id -u)" /src /out /work "$@"
done
ls -la "$root/out"
