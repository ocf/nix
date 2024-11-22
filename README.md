# nix

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

