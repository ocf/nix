{
  pkgs,
  lib,
  config,
  options,
  ...
}:

let
  cfg = config.ocf.managed-deployment;
  deploy-user = "ocf-nix-deploy-user";
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGlViRB5HH1bTaS1S7TcqVBSuxKdrbdhL2CmhDqc/t6A" # oliverni
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILOaJJvOUG08qr3yeeQRB71M30cdPMuO69nsf0CodALa" # jaysa
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDLsEX5PgyQwdOtdOo0U+yWdpOu9gOsqpQRXo7xKww5FAAAABHNzaDo=" # jaysa hardware token
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMdAe7sPMxaidnqOah3UVrjt41KFHHOYleS1VWGH+ZUc" # storce
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICW8L5pydSCGwBstSlXWNSQh//wmRB03RmAWaT3u7+8hAAAABHNzaDo=" # sbwilliams primary hardware token
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIIsQXwbC4lVR8qMbduDWHVNvjfqD1m8yYbjdEOGCNVNPAAAABHNzaDo=" # sbwilliams secondary hardware token
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIIe3xdiMA4u6OhEEa8gw1w26G8mBvAC6SXbbgR0sSWO7AAAABHNzaDo=" # michaelzls hardware token 1
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICWs4Daof6LfwMw6376xOfuPgBnZNxnPWpoUvcWdlql5AAAABHNzaDo=" # michaelzls hardware token 2
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF3DDYaYibt/VjeYDR7cO8tZA2iJUhPBh6jFrB1mBxJA" # chamburr
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDLsEX5PgyQwdOtdOo0U+yWdpOu9gOsqpQRXo7xKww5FAAAABHNzaDo=" # jaysa hardware token
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIK6PlfQq5LYIOHTnPwQvJeiGo3MYDxBRb+KdTqrffxFnAAAABHNzaDo=" # blakeh hardware token
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIPs3+fHihwZSBQVtoXffCtSSmBBDb/0NY+BPDIo+FKh9AAAABHNzaDo=" # blakeh backup hardware token
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIB1zLZffea+7TdFSQOhNBmT1hftFwPzAEK2c8siFeS/7AAAABHNzaDo=" # ericgu hardware token
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIKtH02NTIoDXgcD5UJoxWWBu5EhHoYaP6NZQKZSIWmadAAAABHNzaDo=" # ericgu backup hardware token
  ];
in
{
  options.ocf.managed-deployment.enable = lib.mkEnableOption "Enable OCF Colmena / GitHub Actions Managed Deployment";

  options.ocf.managed-deployment.automated-deploy = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to enable automated deployments from GitHub. The default setting of true is recommended to ensure nodes are kept up-to-date.";
    default = true;
  };

  options.ocf.managed-deployment.emergencyRootSSH = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to add the deploy user's authorized keys (except github actions) to root for emergency access";
    default = true;
  };

  options.ocf.managed-deployment.mac-address = lib.mkOption {
    type = lib.types.str;
    description = "MAC address of the host so that it can be woken up with WoL during deploy";
    default = "";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.optionalAttrs (options ? "deployment") {
        deployment.allowLocalDeployment = true; # for debugging and deploying when github actions deployment breaks
      })
      {
        nix.settings.trusted-users = [ deploy-user ];

        users.groups.${deploy-user} = { };

        users.users.${deploy-user} = {
          isNormalUser = true;
          group = deploy-user;
          createHome = false;
          home = "/var/empty";
          openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDMuiOUsjVJSi+0WeMHKquQmwoyz/c3N7HhjJwzz21B3" # github-actions
          ]
          ++ authorizedKeys;
        };

        # note: this breaks colmena exec, which runs the given command with sudo,
        # but sudo cant ask for a password without a proper terminal
        security.sudo.extraRules = [
          {
            users = [ deploy-user ];
            commands = [
              # needed for colmena apply
              {
                command = "/run/current-system/sw/bin/nix-store --no-gc-warning --realise /nix/store/*";
                options = [ "NOPASSWD" ];
              }
              {
                command = "/run/current-system/sw/bin/nix-env --profile /nix/var/nix/profiles/system --set /nix/store/*";
                options = [ "NOPASSWD" ];
              }
              {
                command = "/nix/store/*/bin/switch-to-configuration *";
                options = [ "NOPASSWD" ];
              }

              # extra commands allowed on colmena exec
              {
                command = "/run/current-system/sw/bin/systemctl *";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];

        # add deploy-user to allowed groups if staffOnlySSH is enabled
        services.openssh.settings.AllowGroups = lib.mkIf config.ocf.auth.staffOnlySSH [
          deploy-user
        ];
      }

      (lib.mkIf cfg.emergencyRootSSH {
        services.openssh.settings.AllowGroups = lib.mkIf config.ocf.auth.staffOnlySSH [
          "root"
        ];
        # for when things really go wrong (for example if ldap doesnt work)
        users.users.root.openssh.authorizedKeys.keys = authorizedKeys;

        # set sensible defaults (and to create the PubKeyAuthentication attribute)
        # but catch it if it changes and show a warning
        services.openssh.settings = {
          PermitRootLogin = lib.mkDefault "prohibit-password";
          PubKeyAuthentication = lib.mkDefault true;
        };

        assertions =
          let
            sshcfg = config.services.openssh.settings;
          in
          lib.singleton {
            assertion = (sshcfg.PermitRootLogin == "prohibit-password" && sshcfg.PubKeyAuthentication or true);
            message = "PermitRootLogin must be set to 'prohibit-password' and PubKeyAuthentication must be set to 'yes' when ocf.managed-deployment.emergencyRootSSH is enabled.";
          };
      })
    ]
  );
}
