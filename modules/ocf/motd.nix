{ lib, config, pkgs, ... }:

let cfg = config.ocf.motd;
in
{
  options.ocf.motd = {
    enable = lib.mkEnableOption "Enable OCF MOTD";

    description = lib.mkOption {
      type = lib.types.str;
      description = "Description of this node, to be included in the MOTD.";
      default = "";
    };
  };

  config = lib.mkIf cfg.enable {
    users.motd = 
    ''
      Hi, I am \e[31m${config.networking.hostName}\e[39m, a \e[31m${builtins.concatStringsSep ", " config.deployment.tags}\e[39m at \e[31m169.229.226.${builtins.toString config.ocf.network.lastOctet}\e[39m.
      ${cfg.description}

    '';
  };
}
