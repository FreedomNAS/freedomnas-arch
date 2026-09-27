# freedomnas-arch

The Arch packages of FreedomNAS, for the Arch and Artix editions, published to
Codeberg's Arch package registry. `freedomnas-deb` is the Debian counterpart.

| Package | Source |
|---------|--------|
| `freedomnas-core`, `freedomnas-profiles`, `freedomnas-webui`, `freedomnas-installer` | the component repositories on Codeberg, at a branch (`dev` by default, `FREEDOMNAS_REF` to change it) |
| `linux-freedomnas`, `linux-freedomnas-headers`, `zfs-utils-freedomnas` | Arch's `linux-lts` and OpenZFS, built together |

## Versions

A component built from `dev` is a snapshot, `1.0+<commit date and time>.<commit>`,
so every change gets a version of its own; built from `main` it is the base
version the PKGBUILD names (`_basever`). `1.0+...` sorts after `1.0` and
before `1.1`.

## linux-freedomnas

Kernel packages with the OpenZFS modules built in, the way Proxmox ships its
kernels. A NAS whose `zfs.ko` is built by DKMS on the machine stops booting
the first time that build fails; here the kernel, the ZFS modules and the
matching userspace are compiled together from pinned sources, so an update
brings all of them or none.

| Package | Contents |
|---------|----------|
| `linux-freedomnas` | kernel and modules, ZFS in `extra/zfs`; conflicts with `zfs-dkms` |
| `linux-freedomnas-headers` | headers for building out-of-tree modules |
| `zfs-utils-freedomnas` | OpenZFS userspace and dracut module at the exact version in the kernel; provides `zfs-utils` |

The kernel package depends on `zfs-utils-freedomnas` of its own version and
release (split packages of one build share them), so pacman never pairs a
kernel with a different userspace. Init scripts are not in
`zfs-utils-freedomnas`: they come from each init system's package
(`zfs-openrc`, `zfs-dinit`, ...).

The kernel parts follow `archlinux/packaging/packages/linux-lts` (taken at
6.18.54-1, commit b51edfc8); the docs package is dropped. Following an Arch
update means taking its `pkgver`, patches, `config.x86_64` and checksums.
OpenZFS tarballs are checked against the release key of Tony Hutter
(`4F3BA9AB6D1F8D683DC2DFB56AD860EED4598027`).

## Building

```sh
bin/build.sh freedomnas-webui              # one package, in an Arch container
bin/build.sh freedomnas-core freedomnas-webui
bin/build.sh linux-freedomnas              # about 45 minutes
bin/build.sh linux-freedomnas -- -R        # repackage without recompiling
FREEDOMNAS_REF=main bin/build.sh freedomnas-core
```

`bin/build.sh` needs only docker. Packages land in `out/`; each package's
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
`PACKAGE_REGISTRY_TOKEN` that freedomnas-deb uses. The kernel is rebuilt only
when its version is not in the registry yet.

## License

GPL-2.0-or-later: the GNU General Public License, version 2 or (at your
option) any later version. The text of version 2 is in `LICENSE`.

The packages built from here keep the licenses of what they package —
MPL-2.0 for the FreedomNAS components, the kernel's and OpenZFS's own for
linux-freedomnas.
