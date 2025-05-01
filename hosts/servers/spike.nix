{ pkgs, ... }:

{
  imports = [ ../../hardware/virtualized.nix ];

  networking.hostName = "spike";

  ocf.network = {
    enable = true;
    lastOctet = 24;
  };

  services.github-runners = {
    "nix-build-ci" = {
      enable = true;
      ephemeral = true;
      replace = true;
      name = "spike";
      url = "https://github.com/ocf/nix";
      tokenFile = "/run/secrets/spike-nix-build.token";
      extraPackages = [ pkgs.sudo ];
      serviceOverrides = { NoNewPrivileges = false; };
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
