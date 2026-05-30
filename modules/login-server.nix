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
      description = "Whether this is a publicly accessible (to non ocfstaff) login server. Enables PAM limits, enables ttyd, and disables staff-only SSH.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        python3Packages.cached-property
      ];

      ocf.cli.apps.enable = true;

      ocf.nfs = {
        enable = true;
        mount = true;
        asRemote = false;
        kerberos = false;

        # if nfs servers are down, the login servers will be so broken that you
        # might as well freeze all io to the nfs mounts at /home and /services.
        # this would also be better for data integrity.
        softerr = false;
      };

      programs.mosh.enable = true;
      services.openssh.settings = {
        PasswordAuthentication = true;
        LoginGraceTime = 30;
        MaxStartups = "100:30:300";
        PerSourcePenalties = "yes";
      };

      services.fail2ban = {
        enable = true;
        jails.sshd.settings = {
          enabled = true;
          maxretry = 5;
          bantime = "10m";
        };
      };

      networking.firewall = {
        enable = lib.mkForce true;
        extraCommands = ''
          # Rate-limit new SSH connections to 6 per minute per source IP
          iptables -I nixos-fw -p tcp --dport 22 -m state --state NEW \
            -m hashlimit --hashlimit-name ssh-ratelimit \
            --hashlimit-above 6/min --hashlimit-burst 6 \
            --hashlimit-mode srcip -j DROP
        '';
      };
    })

    (lib.mkIf (cfg.enable && cfg.public) {
      ocf.auth.staffOnlySSH = false;
      ocf.ttyd.enable = true;

      # makemysql-real runs as the mysql user for privilege separation
      # TODO rewrite the makemysql script and see if theres a better way to do this?
      # just carrying over what was done on our puppet host, tsunami
      users.users.mysql = {
        isSystemUser = true;
        group = "mysql";
      };
      users.groups.mysql = { };

      security.sudo.extraConfig = ''
        ALL ALL=(mysql) NOPASSWD: /run/current-system/sw/bin/makemysql-real
      '';

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
