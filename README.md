# `migrate-apt-keys`

## _Add signing info to `sources.list.d` Debian `apt` repos_

This script looks at each `deb[-src]` entry in the specified (or default) `SOURCE.list` files and
- adds `[signed-by]` qualifiers if missing
- downloads the corresponding `gpg` key into a designated folder

## Background

In recent (~2022) Ubuntu / Debian's, `/etc/apt/sources.list.d/` repos signed by system-wide keys from `/etc/apt/trusted.gpg` trigger an `apt update` warning. Meanwhile, repos signed by individual `/etc/apt/trusted.gpg.d/*` keys don't; yet this is mostly security theatre, because the `trusted.gpg.d/*` keys still apply to all "unsigned" repos.

This script adds a `[signed-by]` qualifier to each `deb[-src] ...` entry within each `SOURCE.list` repo, and downloads all relevant keys into `/usr/local/share/keyrings/SOURCE-apt-keyring.gpg` (or a specified folder).

## Usage

```sh
migrate-apt-keys --help
migrate-apt-keys [ KEYRING_FOLDER [SOURCE.list]... ]
```

## Copyright

[MIT license](LICENSE.txt): [`Jens Berthold <jens@jebecs.de>`](https://github.com/maxhq), [`Alin Mr. <almr.oss@outlook.com>`](https://github.com/mralusw)
