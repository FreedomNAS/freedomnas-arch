# freedomnas-arch

The Arch packages of FreedomNAS, for the Arch and Artix editions, published to
Codeberg's Arch package registry. `freedomnas-deb` is the Debian counterpart.

| Package | Source |
|---------|--------|
| `freedomnas-core`, `freedomnas-profiles`, `freedomnas-docs`, `freedomnas-webui`, `freedomnas-installer` | the component repositories on Codeberg, at a branch (`dev` by default, `FREEDOMNAS_REF` to change it) |
| `linux-freedomnas`, `linux-freedomnas-headers`, `zfs-utils-freedomnas` | [linux-freedomnas](https://codeberg.org/FreedomNAS/linux-freedomnas): Arch's `linux-lts` and OpenZFS, built together |

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

The token needs the `package` scope (write). `GROUP` is the registry's
repository: `dev` for snapshots, `main` for releases. The registry refuses a
version it already holds.

On a FreedomNAS machine:

```
[freedomnas]
SigLevel = Required
Server = https://codeberg.org/api/packages/FreedomNAS/arch/dev/$arch
```

after importing the registry's key
(`https://codeberg.org/api/packages/FreedomNAS/arch/repository.key`) with
`pacman-key --add` and `pacman-key --lsign-key`.

`.forgejo/workflows/publish-packages.yml` does the same daily and on demand
on the self-hosted runner, with the secrets `PACKAGE_REGISTRY_USER` and
`PACKAGE_REGISTRY_TOKEN` that freedomnas-deb uses. It clones linux-freedomnas
and rebuilds the kernel only when its version is not in the registry yet.

## License

GPL-2.0-or-later: the GNU General Public License, version 2 or (at your
option) any later version. The text of version 2 is in `LICENSE`.

The packages built from here keep the licenses of what they package —
MPL-2.0 for the FreedomNAS components.
