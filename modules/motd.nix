{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.ocf.motd;
  ansi-esc = builtins.fromJSON ''"\u001b"'';
  ansi-reset = "${ansi-esc}[0m";
  ansi-resetfg = "${ansi-esc}[39m";
  ansi-bold = "${ansi-esc}[1m";
  ansi-red = "${ansi-esc}[31m";
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
      ${ansi-bold}Hi, I am ${ansi-red}${config.networking.hostName}${ansi-resetfg}, a ${ansi-red}${builtins.concatStringsSep ", " config.deployment.tags}${ansi-resetfg} at ${ansi-red}169.229.226.${builtins.toString config.ocf.network.lastOctet}${ansi-reset}.

      ${cfg.description}
    '';
  };
}
