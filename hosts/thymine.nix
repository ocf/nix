{ ... }:

{
  imports = [ ../hardware/nucleus-d.nix ];

  networking.hostName = "thymine";
  networking.bonds.bond0 = import ../util/ocfbond.nix [ "enp66s0f0np0" "enp66s0f1np1" ];
  networking.interfaces.bond0 = {
    ipv4.addresses = [{ address = "169.229.226.10"; prefixLength = 24; }];
    ipv6.addresses = [{ address = "2607:f140:8801::1:10"; prefixLength = 64; }];
  };

  services.ocfKubernetes.enable = true;
  services.ocfKubernetes.isLeader = false;
}
