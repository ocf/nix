{ lib, config, ... }:

let
  cfg = config.ocf.tmpfsHome;
in
{
  options.ocf.tmpfsHome = {
    enable = lib.mkEnableOption "Enable /home on tmpfs";
  };

  config = lib.mkIf cfg.enable {
    fileSystems."/home" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "size=16G" "mode=755" ];
    };
  };
}
