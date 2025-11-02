{ lib, config, pkgs, ... }:

let
  cfg = config.ocf.packages;
in
{
  options.ocf.packages= {
    enable = lib.mkEnableOption "Install basic server packages."
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      (python312.withPackages (ps: [ ps.ocflib ]))
      ocf-utils
      openldap
      ldapvi
    ];
  };
}

