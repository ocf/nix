{ ... }:

{
  imports = [ ../hardware/hal.nix ];

  networking.hostName = "hal";
  networking.bonds.bond0 = import ../util/ocfbond.nix [ "enp8s0f0np0" "enp8s0f1np1" ];
  networking.interfaces.bond0 = {
    ipv4.addresses = [{ address = "169.229.226.12"; prefixLength = 24; }];
    ipv6.addresses = [{ address = "2607:f140:8801::1:12"; prefixLength = 64; }];
  };
}

