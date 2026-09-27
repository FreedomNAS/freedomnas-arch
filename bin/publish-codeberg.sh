#!/bin/sh
set -eu

OWNER="${CODEBERG_OWNER:-FreedomNAS}"
GROUP="${GROUP:-dev}"
BASE="https://codeberg.org/api/packages/$OWNER/arch"

root="$(cd "$(dirname "$0")/.." && pwd)"

: "${CODEBERG_USER:?set CODEBERG_USER to your Codeberg username}"
: "${CODEBERG_TOKEN:?set CODEBERG_TOKEN to a token with the package scope}"
command -v curl >/dev/null || { echo "publish-codeberg.sh: curl not found" >&2; exit 1; }

if [ "$#" -gt 0 ]; then
    PKGS="$*"
else
    PKGS="$(find "$root/out" -maxdepth 1 -name '*.pkg.tar.zst' | sort)"
fi
[ -n "$PKGS" ] || { echo "publish-codeberg.sh: no package in out/" >&2; exit 1; }

for pkg in $PKGS; do
    printf '==> %s\n' "$(basename "$pkg")"
    status="$(printf 'user = "%s:%s"\n' "$CODEBERG_USER" "$CODEBERG_TOKEN" \
        | curl --config - \
               --silent --show-error --output /dev/stderr \
               --write-out '%{http_code}' \
               --upload-file "$pkg" \
               "$BASE/$GROUP")"
    case "$status" in
        200|201|202) echo "    published" ;;
        409) echo "    already published at this version" >&2 ;;
        *) echo "    HTTP $status" >&2; exit 1 ;;
    esac
done

cat <<EOF

Published to $BASE/$GROUP.

On the FreedomNAS machine:

  curl -o /tmp/freedomnas.key $BASE/repository.key
  pacman-key --add /tmp/freedomnas.key
  pacman-key --lsign-key <the key's e-mail or fingerprint>
  printf '\n[freedomnas]\nSigLevel = Required\nServer = $BASE/$GROUP/\$arch\n' >> /etc/pacman.conf
  pacman -Sy freedomnas-webui
EOF
