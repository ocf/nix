{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.ssh;
in
{
  options.ocf.ssh = {
    enable = lib.mkEnableOption "Enable public OCF SSH access (tsunami equivalent)";
  };

  config = lib.mkIf cfg.enable {
    # staff-only while wip
    #ocf.auth.extra_access_conf = [ "+:(ocf):ALL" "+:(sorry):ALL" ];

    security.sudo.extraRules = [
      { groups = [ "ocf" ]; runAs = "mysql"; commands = [{ command = "/run/current-system/sw/bin/makemysql-real"; options = [ "NOPASSWD" ]; }]; }
    ];

    environment.systemPackages = with pkgs; [
      (python312.withPackages (ps: [ ps.ocflib ]))
      ocf-utils
      openldap
      ldapvi
    ];
  };
}
