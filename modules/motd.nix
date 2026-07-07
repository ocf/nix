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
  ansi-dim = "${ansi-esc}[2m";
  ansi-cyan = "${ansi-esc}[96m";

  greeting = "${ansi-reset}${ansi-bold}Hi, I am ${ansi-cyan}${config.networking.hostName}${ansi-resetfg}, a ${ansi-cyan}${
    builtins.concatStringsSep ", " config.deployment.tags or [ ]
  }${ansi-resetfg} at ${ansi-cyan}169.229.226.${builtins.toString config.ocf.network.lastOctet}${ansi-reset}.\n";
  version = "${ansi-reset}${ansi-dim}${config.system.nixos.label}${ansi-reset}\n";
  motd = cfg.description + "\n";
  ssh-motd = pkgs.writeText "ssh-motd" "${greeting}\n${motd}";
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
    users.motd = motd;

    # on ssh:
    # - print motd after login
    # - greeting is prepended to motd
    security.pam.services.sshd.rules.session.motd.args = lib.mkForce [ "motd=${ssh-motd}" ];

    # on getty:
    # - print greeting before login as greetingLine
    # - print motd after login
    services.getty.greetingLine = greeting + version;
  };
}
