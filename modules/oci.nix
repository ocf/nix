{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.ocf.oci;
in
{
  options.ocf.oci = {
    enable = lib.mkEnableOption "OCI tooling (podman, skopeo, etc)";

    desktop = lib.mkOption {
      type = lib.types.bool;
      default = config.ocf.gui.enable;
      description = "Whether to enable podman-desktop";
    };

    nvidia = lib.mkOption {
      type = lib.types.bool;
      default = config.ocf.nvidia.enable;
      description = "Whether to enable nvidia-container-toolkit";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.nvidia-container-toolkit = {
      enable = cfg.nvidia;

      # prevent build-vm from failing
      suppressNvidiaDriverAssertion = true;
    };

    virtualisation.podman = {
      enable = true;
      autoPrune.enable = true;
      dockerCompat = true;
    };

    environment.systemPackages =
      with pkgs;
      [
        skopeo
        buildah
        podman-compose
        podman-tui
      ]
      ++ lib.optional cfg.desktop pkgs.podman-desktop;
  };
}
