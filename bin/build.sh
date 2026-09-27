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
        -v "$root/$pkg:/src:ro" \
        -v "$root/out:/out" \
        -v "$root/work/$pkg:/work" \
        -e MAKEFLAGS="-j$(nproc)" \
        -e FREEDOMNAS_REF="${FREEDOMNAS_REF:-dev}" \
        "$image" sh -euc '
            pacman -Syu --noconfirm --needed base-devel git >/dev/null
            deps=$(cd /src && bash -c "source PKGBUILD; printf \"%s\n\" \"\${makedepends[@]}\" \"\${depends[@]}\"")
            avail=""
            for d in $deps; do
                d=${d%%[<>=]*}
                pacman -Si "$d" >/dev/null 2>&1 && avail="$avail $d"
            done
            [ -z "$avail" ] || pacman -S --noconfirm --needed $avail >/dev/null
            useradd -m -u "$1" builder
            mkdir -p /home/builder/build
            cp -r /src/. /home/builder/build/
            chown -R builder: /home/builder/build
            shift
            su builder -c "
                cd ~/build
                if [ -d keys/pgp ]; then for k in keys/pgp/*.asc; do gpg -q --import \"\$k\"; done; fi
                FREEDOMNAS_REF=$FREEDOMNAS_REF BUILDDIR=/work PKGDEST=/out makepkg --nodeps --noconfirm $*
            "
        ' sh "$(id -u)" "$@"
done
ls -la "$root/out"
