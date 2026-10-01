#!/bin/sh
set -eu

OWNER="${CODEBERG_OWNER:-FreedomNAS}"
GROUP="${GROUP:-dev}"
REPO=freedomnas
BASE="${BASE:-https://codeberg.org/api/packages/$OWNER/generic/freedomnas-arch/$GROUP}"

root="$(cd "$(dirname "$0")/.." && pwd)"

: "${CODEBERG_USER:?set CODEBERG_USER to your Codeberg username}"
: "${CODEBERG_TOKEN:?set CODEBERG_TOKEN to a token with the package scope}"
for tool in curl gpg repo-add; do
    command -v "$tool" >/dev/null || { echo "publish-codeberg.sh: $tool not found" >&2; exit 1; }
done

key="$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1 == "fpr" { print $10; exit }')"
[ -n "$key" ] || { echo "publish-codeberg.sh: no secret key in gpg, import the signing key first" >&2; exit 1; }

auth() { printf 'user = "%s:%s"\n' "$CODEBERG_USER" "$CODEBERG_TOKEN"; }

published() {
    case "$(curl -s -o /dev/null -w '%{http_code}' -r 0-0 "$BASE/$1")" in
        200|206) return 0 ;;
        *) return 1 ;;
    esac
}

put() {
    status="$(auth | curl --config - -s -S -o /dev/null -w '%{http_code}' --upload-file "$1" "$BASE/$2")"
    case "$status" in
        200|201) echo "    uploaded $2" ;;
        *) echo "publish-codeberg.sh: upload of $2: HTTP $status" >&2; return 1 ;;
    esac
}

delete() {
    status="$(auth | curl --config - -s -S -o /dev/null -w '%{http_code}' -X DELETE "$BASE/$1")"
    case "$status" in
        200|204|404) ;;
        *) echo "publish-codeberg.sh: delete of $1: HTTP $status" >&2; return 1 ;;
    esac
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
[ -n "$PKGS" ] || { echo "publish-codeberg.sh: no package in out/" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

new=""
for pkg in $PKGS; do
    name="$(basename "$pkg")"
    if published "$name"; then
        echo "==> $name is already published"
        continue
    fi
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
    curl -sf -o "$work/$REPO.$f.tar.gz" "$BASE/$REPO.$f" || rm -f "$work/$REPO.$f.tar.gz"
done
db_files "$work/$REPO.db.tar.gz" > "$work/before"

repo-add -q -s -k "$key" "$work/$REPO.db.tar.gz" $new
db_files "$work/$REPO.db.tar.gz" > "$work/after"

for pkg in $new; do
    echo "==> $(basename "$pkg")"
    put "$pkg" "$(basename "$pkg")"
    put "$pkg.sig" "$(basename "$pkg").sig"
done

echo "==> database"
for f in db db.sig files files.sig; do
    src="$work/$REPO.${f%.sig}.tar.gz"
    [ "${f%.sig}" = "$f" ] || src="$src.sig"
    delete "$REPO.$f"
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

  curl -o /tmp/freedomnas.key $BASE/repository.key
  pacman-key --add /tmp/freedomnas.key
  pacman-key --lsign-key $key
  printf '\n[freedomnas]\nSigLevel = Required\nServer = $BASE\n' >> /etc/pacman.conf
  pacman -Sy freedomnas-webui
EOF
