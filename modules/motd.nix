{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.motd;
  esc = builtins.fromJSON ''"\u001b"'';
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

  # TODO: make this read from LDAP
  config = lib.mkIf cfg.enable {
    users.motd = ''
      Hi, I am ${esc}[31m${config.networking.hostName}${esc}[39m, a ${esc}[31m${builtins.concatStringsSep ", " config.deployment.tags}${esc}[39m at ${esc}[31m169.229.226.${builtins.toString config.ocf.network.lastOctet}${esc}[39m.
      ${cfg.description}

    '';
  };
}
