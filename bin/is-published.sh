#!/bin/sh
set -eu

[ $# -eq 1 ] || { echo "usage: is-published.sh <pkgbuild-dir>" >&2; exit 2; }
GROUP="${GROUP:-dev}"
BASE="${BASE:-https://github.com/FreedomNAS/freedomnas-arch/releases/download/pacman-$GROUP}"

files="$(cd "$1" && bash -c 'source PKGBUILD; for n in "${pkgname[@]}"; do printf "%s-%s%s-%s-%s.pkg.tar.zst\n" "$n" "${epoch:+$epoch:}" "$pkgver" "$pkgrel" "${arch[0]}"; done')"
for f in $files; do
    case "$(curl -sL -o /dev/null -w '%{http_code}' -r 0-0 "$BASE/$f")" in
        200|206) echo "$f is published" ;;
        *) echo "$f is not published"; exit 1 ;;
    esac
done
