# freedomnas-arch

The Arch packages of FreedomNAS, for the Arch and Artix editions: a signed
pacman repository built here with `repo-add` and published to Codeberg's
generic package registry. `freedomnas-deb` is the Debian counterpart.

| Package | Source |
|---------|--------|
| `freedomnas-core`, `freedomnas-profiles`, `freedomnas-docs`, `freedomnas-webui`, `freedomnas-installer` | the component repositories on Codeberg, at a branch or a release tag (`dev` by default, `FREEDOMNAS_REF` to change it: `main`, or a tag such as `v0.9.10`) |
| `linux-freedomnas`, `linux-freedomnas-headers`, `zfs-utils-freedomnas` | [linux-freedomnas](https://codeberg.org/FreedomNAS/linux-freedomnas): Arch's `linux-lts` and OpenZFS, built together |
| `topgrade-bin` | `topgrade-bin/` here: upstream's statically linked musl release binary, as freedomnas-deb ships it; topgrade is in neither Arch's nor Artix's repositories, and building it pulls the Rust toolchain |
| `zfs-openrc` | [sarahmeow86/zfs-openrc](https://codeberg.org/sarahmeow86/zfs-openrc), the OpenRC service scripts for ZFS (Artix) |
| `zfs-dinit`, `zfs-runit`, `zfs-s6` | [sarahmeow86/zfs-dinit](https://codeberg.org/sarahmeow86/zfs-dinit), the dinit, runit and s6 service scripts for ZFS (Artix) |

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
[linux-freedomnas](https://codeberg.org/FreedomNAS/linux-freedomnas); it is
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

```sh
CODEBERG_USER=<user> CODEBERG_TOKEN=<token> bin/publish-codeberg.sh
GROUP=main ... bin/publish-codeberg.sh out/freedomnas-core-1.0-1-any.pkg.tar.zst
```

The token needs the `package` scope (write), and gpg must hold the signing
key (its public half is `keys/freedomnas-arch.asc`, fingerprint
`015549123DF4D6D5ADBE4179522C9783DC389A3B`). `GROUP` is the channel: `dev`
for snapshots, `main` for releases. A package already in the channel at the
same file name is skipped.

The script signs each new package, adds it to the channel's `freedomnas.db`
with `repo-add --sign` (which also replaces the entry of the version it
supersedes), uploads the packages and their signatures, then replaces the
database and the files list, and finally deletes the files of the superseded
versions. Codeberg's generic registry does not overwrite a file, so the
database is deleted and uploaded again; a `pacman -Sy` in that instant gets a
404 and only needs repeating. The registry's own Arch type is not used: it
writes every package's file list into the `.db` and cuts it at 65535 bytes,
so the kernel's entry ends mid-path and pacman discards the whole repository.
`repo-add` keeps file lists in `freedomnas.files`, as Arch's repositories do.

On a FreedomNAS machine:

```
[freedomnas]
SigLevel = Required
Server = https://codeberg.org/api/packages/FreedomNAS/generic/freedomnas-arch/dev
```

after importing the key
(`https://codeberg.org/api/packages/FreedomNAS/generic/freedomnas-arch/dev/repository.key`)
with `pacman-key --add` and `pacman-key --lsign-key`.

`.forgejo/workflows/publish-packages.yml` does the same daily and on demand,
with the organization secrets `PACKAGE_REGISTRY_USER`,
`PACKAGE_REGISTRY_TOKEN` and `ARCH_SIGNING_KEY` (the armored private key), in
three jobs. `packages` runs on Codeberg's own runners: the five FreedomNAS
packages, the community modules (`freedomnas-module-containers`, `freedomnas-module-proxy`, each from its own
`dev` branch, or its newest tag on `main`), and `topgrade-bin`, `zfs-openrc`
and `zfs-dinit`, and `caddy-bin` with `caddy-openrc`, `caddy-dinit`, `caddy-runit`
(Caddy for Artix, which packages none: upstream's static build and a service
per init, for the reverse proxy module), and `lego-bin` (lego for Artix, upstream's static build, for
the proxy's Let's Encrypt certificates) when `bin/is-published.sh` does not find their version in the
channel. `kernel-check` asks the same of linux-freedomnas on Codeberg's
smallest runner, and `kernel` builds it on the self-hosted runner, where its
ccache lives, only when it is missing, and only after `packages`: both
rewrite the same repository database. With the self-hosted runner off, the
packages are still published and only a new kernel waits.

## License

GPL-2.0-or-later: the GNU General Public License, version 2 or (at your
option) any later version. The text of version 2 is in `LICENSE`.

The packages built from here keep the licenses of what they package —
MPL-2.0 for the FreedomNAS components.
