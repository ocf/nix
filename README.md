# nix

[![Build Hosts](https://github.com/ocf/nix/actions/workflows/build.yml/badge.svg)](https://github.com/ocf/nix/actions/workflows/build.yml)
[![Automated Deploy](https://github.com/ocf/nix/actions/workflows/auto-deploy.yml/badge.svg)](https://github.com/ocf/nix/actions/workflows/auto-deploy.yml)

This repository contains the [NixOS] files used to maintain and configure the
servers and desktops used by the [Open Computing Facility] at UC Berkeley.

[NixOS]: https://nixos.org/
[Open Computing Facility]: https://www.ocf.berkeley.edu/
[Puppet]: https://github.com/ocf/puppet

## Installation on New Lab Devices

Enable PXE boot on the box in question and make sure it's set to boot from UEFI. 

If your boot order is set correctly, the device should boot to the PXECore menu. 

Select:

```
Distributions > Linux Network Installs (64-bit) > "NixOS" > unstable
```

After boot you should be dropped into a shell. The following command will run the [bootstrap script](https://github.com/ocf/nix/blob/main/bootstrap/bootstrap):

```
sudo nix run --extra-experimental-features "nix-command flakes" github:ocf/nix#bootstrap
```

### Note: What if no PXE boot server?

...then you can run one.

Get EFI images from netboot.xyz:

```
wget https://boot.netboot.xyz/ipxe/netboot.xyz.efi
```

Install [Pixiecore](https://github.com/danderson/netboot/tree/main/pixiecore) on a device on the same network)

```
go install go.universe.tf/netboot/cmd/pixiecore@latest  # up-to-date go installation
nix profile install nixpkgs#pixiecore                   # nixos/nixpkgs installation
```

...then run it:

```
pixiecore boot /dev/null --ipxe-efi64 netboot.xyz.efi
```

> [!NOTE]
> You can also use [netboot.xyz's server](https://netboot.xyz/docs/docker) instead of Pixiecore.

## Local deploy

if github actions deploy is broken (often, ocf-nix-deploy-user can't ssh):

1. make a branch, commit and push changes to it
1. open an ssh tunnel on your machine: `ssh -D 8000 -N koi`, or use supernova/tsunami if both login servers are down. youll have to go irl if those are ALSO down.
1. go to https://doorplug.ocf.berkeley.edu:8006, open a console on the host you want to deploy to.
1. log in as root (general root password is in 1pass), then:

`git clone -b yourbranchname https://ocf.io/github/nix /tmp/nix`
`cd /tmp/nix`
`nix develop`
`colmena apply-local --sudo`

## TODO

 - maybe different way of doing admin for IRC. tls certs on yubikey, LDAP, etc..
 - use agenix rekey generators in place of manually generating irc pass hash with ergo

