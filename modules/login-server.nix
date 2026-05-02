{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.ocf.loginServer;
in
{
  options.ocf.loginServer = {
    enable = lib.mkEnableOption "login server configuration";

    public = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether this is a public-facing login server. Enables stricter SSH rules, enables ttyd, and disables staff-only SSH.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      ocf.cli.apps.enable = true;

      ocf.nfs = {
        enable = true;
        mount = true;
      };

      programs.mosh.enable = true;
      services.openssh.settings = {
        PasswordAuthentication = true;
        LoginGraceTime = 30;
      };

      networking.firewall.enable = lib.mkForce true;

      services.fail2ban = {
        enable = true;
        jails.sshd.settings = {
          enabled = true;
          maxretry = 5;
        };
      };
    })

    (lib.mkIf (cfg.enable && cfg.public) {
      ocf.managed-deployment.staffOnlySsh = false;
      ocf.ttyd.enable = true;

      # this should be in ocf utils package somehow
      security.sudo.extraConfig = ''
        ALL ALL=(mysql) NOPASSWD: /run/current-system/sw/bin/makemysql-real
      '';

      services.openssh.settings = {
        MaxStartups = "100:30:300";
        PerSourcePenalties = "yes";
      };

      networking.firewall = {
        extraCommands = ''
          # Rate-limit new SSH connections to 6 per minute per source IP
          iptables -I nixos-fw -p tcp --dport 22 -m state --state NEW \
            -m hashlimit --hashlimit-name ssh-ratelimit \
            --hashlimit-above 6/min --hashlimit-burst 6 \
            --hashlimit-mode srcip -j DROP
        '';
      };

      services.fail2ban.jails.sshd.settings.bantime = "10m";

      security.pam.loginLimits = [
        {
          domain = "*";
          type = "-";
          item = "cpu";
          value = "60";
        }
        {
          domain = "*";
          type = "soft";
          item = "stack";
          value = "4096";
        }
        {
          domain = "*";
          type = "soft";
          item = "core";
          value = "0";
        }
        {
          domain = "*";
          type = "soft";
          item = "nproc";
          value = "250";
        }
        {
          domain = "*";
          type = "soft";
          item = "nofile";
          value = "1024";
        }
        {
          domain = "*";
          type = "-";
          item = "memlock";
          value = "2047219";
        }
        {
          domain = "*";
          type = "-";
          item = "as";
          value = "12000000";
        }
        {
          domain = "*";
          type = "soft";
          item = "sigpending";
          value = "63810";
        }
        {
          domain = "*";
          type = "soft";
          item = "msgqueue";
          value = "819200";
        }
        {
          domain = "*";
          type = "soft";
          item = "nice";
          value = "0";
        }
        {
          domain = "*";
          type = "soft";
          item = "rtprio";
          value = "0";
        }
      ];
    })
  ];
}
