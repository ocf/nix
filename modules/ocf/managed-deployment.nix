{ pkgs, lib, config, ... }:

let
  cfg = config.ocf.managed-deployment;
  deploy-user = "ocf-nix-deploy-user";
in
{
  options.ocf.managed-deployment.enable = lib.mkEnableOption "Enable OCF Colmena / GitHub Actions Managed Deployment";

  options.ocf.managed-deployment.automated-deploy = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to enable automated deployments from GitHub. The default setting of true is recommended to ensure nodes are kept up-to-date.";
    default = true;
  };

  config = lib.mkIf cfg.enable {
    nix.settings.trusted-users = [ deploy-user ];

    users.users.${deploy-user} = {
      isNormalUser = true;
      createHome = false;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDMuiOUsjVJSi+0WeMHKquQmwoyz/c3N7HhjJwzz21B3" # github-actions
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGlViRB5HH1bTaS1S7TcqVBSuxKdrbdhL2CmhDqc/t6A" # oliverni
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILOaJJvOUG08qr3yeeQRB71M30cdPMuO69nsf0CodALa" # jaysa
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDLsEX5PgyQwdOtdOo0U+yWdpOu9gOsqpQRXo7xKww5FAAAABHNzaDo=" # jaysa hardware token
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPeJeRNwcPaZupbmCEtUIOuLDfhow35byMp548TUDYP" # rjz
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO6zftyMUeIQVYkRag6CxWqYShjWnErQ24NeaU95Bp2z" # laksith
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIGU0k2swUbmqWcAoOjG64ekaahK05iyRPPQqlsgjp32fAAAABHNzaDo=" # laksith hardware token
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMdAe7sPMxaidnqOah3UVrjt41KFHHOYleS1VWGH+ZUc" # storce
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICW8L5pydSCGwBstSlXWNSQh//wmRB03RmAWaT3u7+8hAAAABHNzaDo=" # sbwilliams primary hardware token
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIIsQXwbC4lVR8qMbduDWHVNvjfqD1m8yYbjdEOGCNVNPAAAABHNzaDo=" # sbwilliams secondary hardware token
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIIe3xdiMA4u6OhEEa8gw1w26G8mBvAC6SXbbgR0sSWO7AAAABHNzaDo=" # michaelzls primary hardware token
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICWs4Daof6LfwMw6376xOfuPgBnZNxnPWpoUvcWdlql5AAAABHNzaDo=" # michaelzls secondary hardware token
        "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDLsEX5PgyQwdOtdOo0U+yWdpOu9gOsqpQRXo7xKww5FAAAABHNzaDo=" # jaysa hardware token
      ];
    };

    security.sudo.extraRules = [
      {
        users = [ deploy-user ];
        commands = [
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
        ];
      }
    ];
  };
}
