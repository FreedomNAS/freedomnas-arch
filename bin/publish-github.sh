#!/bin/sh
# Publish the packages in out/ to the pacman repository kept as the assets
# of the release pacman-<GROUP> of this GitHub repository:
#
#   https://github.com/FreedomNAS/freedomnas-arch/releases/download/pacman-dev
#
# Only packages the release does not hold yet are signed and uploaded; the
# database is rewritten with repo-add, and the packages it no longer lists
# are deleted.
#
#   GH_TOKEN=<token> GROUP=dev|main sh bin/publish-github.sh [<package>...]
set -eu

GH_REPO="${GH_REPO:-FreedomNAS/freedomnas-arch}"
GROUP="${GROUP:-dev}"
TAG="pacman-$GROUP"
REPO=freedomnas
BASE="https://github.com/$GH_REPO/releases/download/$TAG"
export GH_REPO

root="$(cd "$(dirname "$0")/.." && pwd)"

: "${GH_TOKEN:?set GH_TOKEN to a token that can write this repository's releases}"
for tool in curl gh gpg repo-add; do
    command -v "$tool" >/dev/null || { echo "publish-github.sh: $tool not found" >&2; exit 1; }
done

key="$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1 == "fpr" { print $10; exit }')"
[ -n "$key" ] || { echo "publish-github.sh: no secret key in gpg, import the signing key first" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

gh release view "$TAG" >/dev/null 2>&1 || gh release create "$TAG" --latest=false \
    --title "pacman repository ($GROUP)" \
    --notes "The FreedomNAS pacman repository for Arch and Artix, $GROUP channel. Server = $BASE"
gh release view "$TAG" --json assets --jq '.assets[].name' > "$work/assets"

published() { grep -qxF "$1" "$work/assets"; }

put() {
    mkdir -p "$work/up"
    cp "$1" "$work/up/$2"
    gh release upload "$TAG" "$work/up/$2" --clobber >/dev/null
    rm -f "$work/up/$2"
    echo "    uploaded $2"
}

delete() {
    published "$1" || return 0
    gh release delete-asset "$TAG" "$1" -y >/dev/null
}

db_files() {
    [ -f "$1" ] || return 0
    tar -xzOf "$1" --wildcards '*/desc' | awk '/^%FILENAME%$/ { getline; print }' | sort
}

if [ "$#" -gt 0 ]; then
    PKGS="$*"
else
    PKGS="$(find "$root/out" -maxdepth 1 -name '*.pkg.tar.zst' | sort)"
fi
[ -n "$PKGS" ] || { echo "publish-github.sh: no package in out/" >&2; exit 1; }

new=""
for pkg in $PKGS; do
    name="$(basename "$pkg")"
    if published "$name"; then
        echo "==> $name is already published"
        continue
    fi
    case "$name" in
        *[!A-Za-z0-9._+-]*) echo "publish-github.sh: $name has a character GitHub renames" >&2; exit 1 ;;
    esac
    cp "$pkg" "$work/$name"
    gpg --batch --yes --quiet -u "$key" --detach-sign --no-armor "$work/$name"
    new="$new $work/$name"
done

published repository.key || put "$root/keys/freedomnas-arch.asc" repository.key

if [ -z "$new" ]; then
    echo "Nothing new to publish to $BASE."
    exit 0
fi

for f in db files; do
    if published "$REPO.$f"; then curl -sfL -o "$work/$REPO.$f.tar.gz" "$BASE/$REPO.$f"; fi
done
db_files "$work/$REPO.db.tar.gz" > "$work/before"

repo-add -q -s -k "$key" "$work/$REPO.db.tar.gz" $new
db_files "$work/$REPO.db.tar.gz" > "$work/after"

for pkg in $new; do
    echo "==> $(basename "$pkg")"
    put "$pkg" "$(basename "$pkg")"
    put "$pkg.sig" "$(basename "$pkg").sig"
done

for pkg in $new; do
    case "$(basename "$pkg")" in
        freedomnas-keyring-*.pkg.tar.zst) put "$pkg" freedomnas-keyring.pkg.tar.zst ;;
    esac
done

echo "==> database"
for f in db db.sig files files.sig; do
    src="$work/$REPO.${f%.sig}.tar.gz"
    [ "${f%.sig}" = "$f" ] || src="$src.sig"
    put "$src" "$REPO.$f"
done

comm -23 "$work/before" "$work/after" | while read -r old; do
    echo "==> removing superseded $old"
    delete "$old"
    delete "$old.sig"
done

cat <<EOF

Published to $BASE.

On the FreedomNAS machine:

  curl -fLo /tmp/freedomnas-keyring.pkg.tar.zst $BASE/freedomnas-keyring.pkg.tar.zst
  pacman -U /tmp/freedomnas-keyring.pkg.tar.zst
  pacman -Sy freedomnas-webui
EOF
