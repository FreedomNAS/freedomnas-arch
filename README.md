# freedomnas-arch

The Arch packages of FreedomNAS, for the Arch and Artix editions: a signed
pacman repository built here with `repo-add` and published in this GitHub
repository's releases. `freedomnas-deb` is the Debian counterpart.

| Package | Source |
|---------|--------|
| `freedomnas-core`, `freedomnas-profiles`, `freedomnas-docs`, `freedomnas-webui`, `freedomnas-installer` | the component repositories on GitHub, at a branch or a release tag (`dev` by default, `FREEDOMNAS_REF` to change it: `main`, or a tag such as `v0.9.10`) |
| `linux-freedomnas`, `linux-freedomnas-headers`, `zfs-utils-freedomnas` | [linux-freedomnas](https://github.com/FreedomNAS/linux-freedomnas): Arch's `linux-lts` and OpenZFS, built together |
| `topgrade-bin` | `topgrade-bin/` here: upstream's statically linked musl release binary, as freedomnas-deb ships it; topgrade is in neither Arch's nor Artix's repositories, and building it pulls the Rust toolchain |
| `zfs-openrc` | [sarahmeow86/zfs-openrc](https://github.com/sarahmeow86/zfs-openrc), the OpenRC service scripts for ZFS (Artix) |
| `zfs-dinit`, `zfs-runit`, `zfs-s6` | [sarahmeow86/zfs-dinit](https://github.com/sarahmeow86/zfs-dinit), the dinit, runit and s6 service scripts for ZFS (Artix) |

## Versions

A component built from `dev` is a snapshot, `1.0+<commit date and time>.<commit>`,
so every change gets a version of its own; built from `main` it is the base
version the PKGBUILD names (`_basever`). `1.0+...` sorts after `1.0` and
before `1.1`.

`freedomnas-docs` is the documentation built with Arch's own `mkdocs` and
`mkdocs-material`, installed in `/usr/lib/freedomnas/docs` for the WebUI to
serve offline; `freedomnas-webui` depends on it and writes its own version to
`webui/VERSION`, which the documentation compares with its own.

## linux-freedomnas

The kernel with the OpenZFS modules built in has a repository of its own,
[linux-freedomnas](https://github.com/FreedomNAS/linux-freedomnas); it is
built and published with the scripts here, from a checkout next to this one.

## Building

```sh
bin/build.sh freedomnas-webui              # one package, in an Arch container
bin/build.sh freedomnas-core freedomnas-webui
bin/build.sh ../linux-freedomnas           # about 45 minutes
bin/build.sh ../linux-freedomnas -- -R     # repackage without recompiling
FREEDOMNAS_REF=main bin/build.sh freedomnas-core
```

`bin/build.sh` takes a package directory here or the path of a checkout
elsewhere, and needs only docker. Packages land in `out/`; each package's
sources and build tree stay in `work/<package>/`, which is what makes `-R`
possible. `bin/build-inside.sh` is the part that runs inside the container,
and the CI calls it directly.

## Publishing

The repository is kept as the assets of this GitHub repository's releases:
`pacman-dev` for snapshots, `pacman-main` for releases (ADR-003 in
freedomnas-specs).

```sh
GH_TOKEN=<token> bin/publish-github.sh
GROUP=main GH_TOKEN=<token> bin/publish-github.sh out/freedomnas-core-0.9.20-1-any.pkg.tar.zst
```

The token must be able to write this repository's releases, and gpg must
hold the signing key (its public half is `keys/freedomnas-arch.asc`,
fingerprint `807A4D2EBFBED77AB609AB0B78840464DBE24D08`). `GROUP` is the
channel. A package already in the release at the same file name is skipped.

The script signs each new package, adds it to the channel's `freedomnas.db`
with `repo-add --sign` (which also replaces the entry of the version it
supersedes), uploads the packages and their signatures, then replaces the
database and the files list, and finally deletes the files of the superseded
versions. `repo-add` keeps file lists in `freedomnas.files`, as Arch's
repositories do. GitHub renames assets whose name holds characters other
than letters, digits and `._+-`, so the script refuses such a package.

On a FreedomNAS machine, `freedomnas-keyring` sets everything up: the key,
`/etc/pacman.d/freedomnas-mirrorlist` for the channel in use and the
`[freedomnas]` section of `/etc/pacman.conf`. It also moves a machine still
pointing at Codeberg:

```
curl -fLo /tmp/freedomnas-keyring.pkg.tar.zst https://github.com/FreedomNAS/freedomnas-arch/releases/download/pacman-main/freedomnas-keyring.pkg.tar.zst
pacman -U /tmp/freedomnas-keyring.pkg.tar.zst
```

pacman installs a local file whose key it does not trust yet
(`LocalFileSigLevel = Optional`), not one given by URL. A new key or address
is a new `pkgver` of `freedomnas-keyring` (its files are made with
`gpg --dearmor < keys/freedomnas-arch.asc` and the fingerprint followed by
`:4:`); `publish-github.sh` also uploads it as
`freedomnas-keyring.pkg.tar.zst`.

`.github/workflows/publish-packages.yml` does the same, with the
organization secret `ARCH_SIGNING_KEY` (the armored private key), in four
jobs. `packages` builds the five FreedomNAS packages, the community modules
(`freedomnas-module-containers`, `freedomnas-module-proxy`, each from its
own `dev` branch, or its newest tag on `main`), and `topgrade-bin`,
`zfs-openrc` and `zfs-dinit`, and `caddy-bin` with `caddy-openrc`,
`caddy-dinit`, `caddy-runit` (Caddy for Artix, which packages none:
upstream's static build and a service per init, for the reverse proxy
module), and `lego-bin` (lego for Artix, upstream's static build, for the
proxy's Let's Encrypt certificates) when `bin/is-published.sh` does not find
their version in the channel. `kernel-check` asks the same of
linux-freedomnas, and `kernel` builds it only when it is missing, with its
ccache kept by `actions/cache`. `publish` runs once at the end with what the
others built, so the database is never rewritten twice at once.

The workflow is started by `gather-pushes`, ten minutes after the last push
to a component (each component's `notify-packages` sends a
`repository_dispatch`, see freedomnas-deb's `docs/ci-setup.md`), every day
as a safety net, or by hand. The Forgejo workflow under `.forgejo/` is
switched off.

## License

GPL-2.0-or-later: the GNU General Public License, version 2 or (at your
option) any later version. The text of version 2 is in `LICENSE`.

The packages built from here keep the licenses of what they package —
MPL-2.0 for the FreedomNAS components.
