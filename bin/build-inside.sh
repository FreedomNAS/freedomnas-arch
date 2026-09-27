#!/bin/sh
set -eu

usage() { echo "usage: build-inside.sh <uid> <pkgdir> <outdir> <workdir> [<makepkg args>]" >&2; exit 1; }
[ $# -ge 4 ] || usage
uid=$1; src=$2; out=$3; work=$4
shift 4

pacman -Syu --noconfirm --needed base-devel git >/dev/null
deps=$(cd "$src" && bash -c 'source PKGBUILD; printf "%s\n" "${makedepends[@]}" "${depends[@]}"')
avail=""
for d in $deps; do
    d=${d%%[<>=]*}
    if pacman -Si "$d" >/dev/null 2>&1; then avail="$avail $d"; fi
done
if [ -n "$avail" ]; then pacman -S --noconfirm --needed $avail >/dev/null; fi

id builder >/dev/null 2>&1 || useradd -m -u "$uid" builder
build=$(su builder -c 'mktemp -d')
cp -r "$src/." "$build/"
chown -R builder: "$build"
mkdir -p "$out" "$work/sources"
chown builder: "$out" "$work" "$work/sources"

su builder -c "
    cd '$build'
    if [ -d keys/pgp ]; then for k in keys/pgp/*.asc; do gpg -q --import \"\$k\"; done; fi
    FREEDOMNAS_REF='${FREEDOMNAS_REF:-dev}' SRCDEST='$work/sources' BUILDDIR='$work' PKGDEST='$out' makepkg --nodeps --noconfirm $*
"
